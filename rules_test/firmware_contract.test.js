// docs/FIRMWARE_CONTRACT.md, replayed. The firmware developer copies the
// JSON bodies in that file verbatim, so they are tested verbatim: every
// block marked `<!-- contract-example: <name> expect=<status> -->` is sent
// to the emulator's REST endpoint — the one the ESP32 uses, not the JS SDK —
// as the helmet identity, and must get exactly that status. An edit to the
// rules that breaks a documented body fails here, and so does an edit to
// the document that breaks the rules.
//
// Alongside the bodies, the behaviour the document promises about them:
// that a retry is a 409, that dropping the timestamp transform is a 403,
// and that telemetry without an updateMask wipes the pairing.

import { readFileSync } from 'node:fs';
import { after, before, beforeEach, describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { doc, getDoc, setDoc, Timestamp } from 'firebase/firestore';
import { newTestEnv, PROJECT_ID, reset } from './helpers.js';

const examples = new Map();
const docText = readFileSync('docs/FIRMWARE_CONTRACT.md', 'utf8');
for (const m of docText.matchAll(
  /<!-- contract-example: (\S+) expect=(\d+) -->\s*```json\r?\n([\s\S]*?)```/g,
)) {
  examples.set(m[1], { expect: Number(m[2]), body: JSON.parse(m[3]) });
}

const example = (name) => {
  const found = examples.get(name);
  assert.ok(found, `docs/FIRMWARE_CONTRACT.md has no contract-example "${name}"`);
  return { expect: found.expect, body: structuredClone(found.body) };
};

// The unsigned token the emulator accepts in place of a real one, carrying
// the claim the provisioning script sets. The live project would reject it;
// the emulator is built to take it.
function helmetToken() {
  const b64 = (o) => Buffer.from(JSON.stringify(o)).toString('base64url');
  const now = Math.floor(Date.now() / 1000);
  return [
    b64({ alg: 'none', kid: 'fakekid', typ: 'JWT' }),
    b64({
      iss: `https://securetoken.google.com/${PROJECT_ID}`,
      aud: PROJECT_ID,
      iat: now,
      exp: now + 3600,
      auth_time: now,
      sub: 'uid-helmet',
      user_id: 'uid-helmet',
      firebase: { sign_in_provider: 'password', identities: {} },
      role: 'helmetService',
    }),
    '',
  ].join('.');
}

async function commit(body) {
  const host = process.env.FIRESTORE_EMULATOR_HOST;
  assert.ok(host, 'FIRESTORE_EMULATOR_HOST is not set — run through `npm test`');
  const res = await fetch(
    `http://${host}/v1/projects/${PROJECT_ID}/databases/(default)/documents:commit`,
    {
      method: 'POST',
      headers: { Authorization: `Bearer ${helmetToken()}`, 'Content-Type': 'application/json' },
      body: JSON.stringify(body),
    },
  );
  return { status: res.status, json: await res.json() };
}

let env;
before(async () => { env = await newTestEnv(); });
after(async () => { await env.cleanup(); });
beforeEach(async () => {
  // What the console would already have written on the live project.
  await reset(env, async (db) => {
    await setDoc(doc(db, 'riders', 'R-001'), { fullName: 'Rider One', status: 'riding' });
    await setDoc(doc(db, 'devices', 'NR-H1-001'), {
      assigned_rider_id: 'R-001', paired_at: Timestamp.now(),
    });
  });
});

const read = async (path) => {
  let snap;
  await env.withSecurityRulesDisabled(async (context) => {
    snap = await getDoc(doc(context.firestore(), path));
  });
  return snap;
};

describe('docs/FIRMWARE_CONTRACT.md — the documented bodies', () => {
  it('marks the three bodies the firmware copies', () => {
    assert.deepEqual([...examples.keys()].sort(), ['alert', 'rider-status', 'telemetry']);
  });

  for (const name of ['alert', 'rider-status', 'telemetry']) {
    it(`"${name}" gets the status the document says`, async () => {
      const { expect, body } = example(name);
      const res = await commit(body);
      assert.equal(res.status, expect, JSON.stringify(res.json));
    });
  }

  it('the alert lands with a server timestamp', async () => {
    const res = await commit(example('alert').body);
    const stamped = res.json.writeResults[0].transformResults[0].timestampValue;
    const alert = await read('alerts/k3F9qTz2VbX8mLw4NcR7');
    assert.equal(alert.get('timestamp').toDate().toISOString(), new Date(stamped).toISOString());
  });
});

describe('docs/FIRMWARE_CONTRACT.md — what it promises about them', () => {
  it('§3.3: resending the same alert is a 409, not a second alert', async () => {
    const { body } = example('alert');
    assert.equal((await commit(body)).status, 200);
    const again = await commit(body);
    assert.equal(again.status, 409);
    assert.equal(again.json.error.status, 'ALREADY_EXISTS');
  });

  it('§3.4: the alert without its timestamp transform is a 403', async () => {
    const { body } = example('alert');
    delete body.writes[0].updateTransforms;
    const res = await commit(body);
    assert.equal(res.status, 403);
    assert.equal(res.json.error.status, 'PERMISSION_DENIED');
  });

  it('§3.5: the rider-status body is refused for a rider that does not exist', async () => {
    const { body } = example('rider-status');
    body.writes[0].update.name = body.writes[0].update.name.replace('R-001', 'R-404');
    assert.equal((await commit(body)).status, 403);
  });

  it('§4.2: the telemetry body leaves the pairing alone and stamps last_update', async () => {
    assert.equal((await commit(example('telemetry').body)).status, 200);
    const device = await read('devices/NR-H1-001');
    assert.equal(device.get('assigned_rider_id'), 'R-001');
    assert.ok(device.get('paired_at'));
    assert.ok(device.get('last_update') instanceof Timestamp);
  });

  it('§3.1: a crash with no fix, and with a field the rules do not name, still lands', async () => {
    // The shape firmware/novaride_helmet sends before its first GPS fix,
    // with the MQ-3 reading as raw ADC counts rather than mg/L.
    const { body } = example('alert');
    const fields = body.writes[0].update.fields;
    delete fields.location;
    delete fields.alcoholLevel;
    fields.alcoholRaw = { integerValue: '1834' };
    assert.equal((await commit(body)).status, 200);
    const alert = await read('alerts/k3F9qTz2VbX8mLw4NcR7');
    assert.equal(alert.get('location'), undefined);
    assert.equal(alert.get('alcoholRaw'), 1834);
  });

  it('§4.1: telemetry with no current fix leaves the last stored position alone', async () => {
    assert.equal((await commit(example('telemetry').body)).status, 200);
    const { body } = example('telemetry');
    const write = body.writes[0];
    for (const k of ['latitude', 'longitude', 'speed_kmh', 'alcohol_level']) {
      delete write.update.fields[k];
    }
    write.update.fields.gps_fix = { booleanValue: false };
    write.update.fields.imu_ok = { booleanValue: true };
    write.update.fields.alcohol_raw = { integerValue: '1834' };
    write.updateMask.fieldPaths = Object.keys(write.update.fields);
    assert.equal((await commit(body)).status, 200);
    const device = await read('devices/NR-H1-001');
    assert.equal(device.get('gps_fix'), false);
    assert.equal(device.get('latitude'), 14.5995);
    assert.equal(device.get('assigned_rider_id'), 'R-001');
  });

  it('§4.3: the same body without updateMask is accepted and wipes the pairing', async () => {
    const { body } = example('telemetry');
    delete body.writes[0].updateMask;
    assert.equal((await commit(body)).status, 200);
    const device = await read('devices/NR-H1-001');
    assert.equal(device.get('assigned_rider_id'), undefined);
  });
});
