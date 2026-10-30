// alerts/{alertId} — the response workflow. The lifecycle is linear and each
// step stamps its own server timestamp; the Reports tab's response times are
// the study's evidence, so an operator machine clock must never set one.

import { after, before, beforeEach, describe, it } from 'node:test';
import { assertFails, assertSucceeds } from '@firebase/rules-unit-testing';
import {
  deleteDoc, doc, GeoPoint, getDoc, serverTimestamp, setDoc, Timestamp, updateDoc,
} from 'firebase/firestore';
import {
  asAnonymous, asDispatcher, asHelmetService, asSuperAdmin, asUnprovisioned,
  asViewer, newTestEnv, reset,
} from './helpers.js';

const openAlert = {
  riderId: 'R-001', riderName: 'Rider One', type: 'crash',
  lat: 14.6, lng: 121.0, status: 'open',
};

// What the helmet raises, per docs/FIRMWARE_CONTRACT.md. Tests below take
// one thing away or get one thing wrong, so each refusal has one cause.
const helmetAlert = () => ({
  riderId: 'R-001', deviceId: 'NR-H1-001', type: 'crash', severity: 'high',
  status: 'open', location: new GeoPoint(14.5995, 120.9842),
  alcoholLevel: 0.01, impactMagnitude: 31.4, timestamp: serverTimestamp(),
});

const without = (field) => {
  const alert = helmetAlert();
  delete alert[field];
  return alert;
};

// assertFails, naming the case — so a loop that fails says which one.
const refused = (promise, label) =>
  assertFails(promise).catch((error) => { throw new Error(`${label}: ${error.message}`); });

let env;
before(async () => { env = await newTestEnv(); });
after(async () => { await env.cleanup(); });
beforeEach(async () => {
  await reset(env, async (db) => {
    await setDoc(doc(db, 'alerts', 'A-open'), { ...openAlert, timestamp: Timestamp.now() });
    await setDoc(doc(db, 'alerts', 'A-ack'), {
      ...openAlert, status: 'acknowledged', timestamp: Timestamp.now(),
    });
    await setDoc(doc(db, 'alerts', 'A-dispatched'), {
      ...openAlert, status: 'dispatched', timestamp: Timestamp.now(),
    });
  });
});

describe('alerts/ — access', () => {
  it('is readable by any operator and by nobody else', async () => {
    await assertSucceeds(getDoc(doc(asViewer(env), 'alerts', 'A-open')));
    await assertFails(getDoc(doc(asAnonymous(env), 'alerts', 'A-open')));
    await assertFails(getDoc(doc(asUnprovisioned(env), 'alerts', 'A-open')));
  });

  it('is created by the helmet service or by a Super Admin (the seed)', async () => {
    await assertSucceeds(setDoc(doc(asHelmetService(env), 'alerts', 'A-new'), helmetAlert()));
    await assertSucceeds(
      setDoc(doc(asSuperAdmin(env), 'alerts', 'A-101'), {
        ...openAlert, timestamp: serverTimestamp(),
      }),
    );
  });

  it('lets the seed keep its own historical timestamps, but not omit one', async () => {
    const db = asSuperAdmin(env);
    await assertSucceeds(
      setDoc(doc(db, 'alerts', 'A-102'), {
        ...openAlert, timestamp: Timestamp.fromDate(new Date('2026-09-01T08:00:00Z')),
      }),
    );
    await assertFails(setDoc(doc(db, 'alerts', 'A-103'), openAlert));
  });

  it('refuses an alert created by a dispatcher or a viewer', async () => {
    await assertFails(setDoc(doc(asDispatcher(env), 'alerts', 'A-x'), openAlert));
    await assertFails(setDoc(doc(asViewer(env), 'alerts', 'A-y'), openAlert));
  });

  it('refuses deletion by anyone', async () => {
    await assertFails(deleteDoc(doc(asSuperAdmin(env), 'alerts', 'A-open')));
    await assertFails(deleteDoc(doc(asHelmetService(env), 'alerts', 'A-open')));
  });
});

describe('alerts/ — what the helmet must send', () => {
  const raise = (alert) => setDoc(doc(asHelmetService(env), 'alerts', 'A-helmet'), alert);

  it('refuses an alert with no timestamp, which the board could never show', async () => {
    await assertFails(raise(without('timestamp')));
  });

  it('refuses a timestamp from the helmet clock', async () => {
    await assertFails(raise({ ...helmetAlert(), timestamp: Timestamp.now() }));
  });

  it('refuses an alert missing any field the board queries on', async () => {
    for (const field of ['riderId', 'deviceId', 'type', 'severity', 'status']) {
      await refused(raise(without(field)), `without ${field}`);
    }
    await assertFails(raise({ ...helmetAlert(), riderId: '' }));
  });

  it('takes severity as exactly low, moderate or high', async () => {
    for (const severity of ['low', 'moderate', 'high']) {
      await assertSucceeds(
        setDoc(doc(asHelmetService(env), 'alerts', `A-${severity}`), { ...helmetAlert(), severity }),
      );
    }
    for (const severity of ['High', 'medium', 'critical', 3]) {
      await refused(raise({ ...helmetAlert(), severity }), `severity ${severity}`);
    }
  });

  it('takes type as one of the four canonical names', async () => {
    for (const type of ['sos', 'alcoholWarning', 'lowBattery']) {
      await assertSucceeds(
        setDoc(doc(asHelmetService(env), 'alerts', `A-${type}`), { ...helmetAlert(), type }),
      );
    }
    for (const type of ['Crash', 'fall', 'alcohol_warning']) {
      await refused(raise({ ...helmetAlert(), type }), `type ${type}`);
    }
  });

  it('refuses an alert that arrives already worked', async () => {
    await assertFails(raise({ ...helmetAlert(), status: 'resolved' }));
    await assertFails(raise({ ...helmetAlert(), acknowledgedAt: serverTimestamp() }));
  });

  it('accepts lat/lng in place of a GeoPoint, and no position at all', async () => {
    const flat = { ...without('location'), lat: 14.5995, lng: 120.9842 };
    await assertSucceeds(raise(flat));
    await assertSucceeds(
      setDoc(doc(asHelmetService(env), 'alerts', 'A-nofix'), without('location')),
    );
  });

  it('refuses a malformed position', async () => {
    const bare = without('location');
    await refused(raise({ ...bare, lat: 14.5995 }), 'lat without lng');
    await refused(raise({ ...bare, lat: 120.9842, lng: 14.5995 }), 'swapped');
    await refused(raise({ ...bare, lat: '14.5995', lng: '120.9842' }), 'strings');
    await refused(
      raise({ ...bare, location: { latitude: 14.5995, longitude: 120.9842 } }), 'map, not GeoPoint',
    );
  });

  it('accepts the snake_case aliases and holds them to the same types', async () => {
    const snake = { ...without('alcoholLevel'), alcohol_level: 0.01 };
    delete snake.impactMagnitude;
    snake.impact_magnitude = 31.4;
    await assertSucceeds(raise(snake));
    await assertFails(raise({ ...snake, alcohol_level: '0.01' }));
    await assertFails(raise({ ...snake, impact_magnitude: '31.4' }));
  });

  it('refuses readings that are not numbers', async () => {
    await assertFails(raise({ ...helmetAlert(), alcoholLevel: '0.08' }));
    await assertFails(raise({ ...helmetAlert(), impactMagnitude: null }));
  });
});

describe('alerts/ — the lifecycle', () => {
  it('walks open to acknowledged to dispatched to resolved', async () => {
    const db = asDispatcher(env);
    await assertSucceeds(updateDoc(doc(db, 'alerts', 'A-open'), {
      status: 'acknowledged', acknowledgedAt: serverTimestamp(),
    }));
    await assertSucceeds(updateDoc(doc(db, 'alerts', 'A-ack'), {
      status: 'dispatched', dispatchedAt: serverTimestamp(),
    }));
    await assertSucceeds(updateDoc(doc(db, 'alerts', 'A-dispatched'), {
      status: 'resolved', resolvedAt: serverTimestamp(),
    }));
  });

  it('lets a Super Admin work the lifecycle too', async () => {
    await assertSucceeds(updateDoc(doc(asSuperAdmin(env), 'alerts', 'A-open'), {
      status: 'acknowledged', acknowledgedAt: serverTimestamp(),
    }));
  });

  it('refuses a skipped step', async () => {
    const db = asDispatcher(env);
    await assertFails(updateDoc(doc(db, 'alerts', 'A-open'), {
      status: 'dispatched', dispatchedAt: serverTimestamp(),
    }));
    await assertFails(updateDoc(doc(db, 'alerts', 'A-open'), {
      status: 'resolved', resolvedAt: serverTimestamp(),
    }));
  });

  it('refuses a step backwards and a reopen', async () => {
    const db = asDispatcher(env);
    await assertFails(updateDoc(doc(db, 'alerts', 'A-dispatched'), {
      status: 'acknowledged', acknowledgedAt: serverTimestamp(),
    }));
    await assertFails(updateDoc(doc(db, 'alerts', 'A-ack'), { status: 'open' }));
  });

  it('refuses a transition stamped from the operator machine clock', async () => {
    await assertFails(updateDoc(doc(asDispatcher(env), 'alerts', 'A-open'), {
      status: 'acknowledged', acknowledgedAt: Timestamp.now(),
    }));
  });

  it('refuses a transition with no stamp at all', async () => {
    await assertFails(
      updateDoc(doc(asDispatcher(env), 'alerts', 'A-open'), { status: 'acknowledged' }),
    );
  });

  it('refuses a transition that stamps the wrong field', async () => {
    await assertFails(updateDoc(doc(asDispatcher(env), 'alerts', 'A-open'), {
      status: 'acknowledged', resolvedAt: serverTimestamp(),
    }));
  });

  it('refuses a transition that also edits the alert', async () => {
    await assertFails(updateDoc(doc(asDispatcher(env), 'alerts', 'A-open'), {
      status: 'acknowledged', acknowledgedAt: serverTimestamp(), riderName: 'Someone else',
    }));
  });

  it('refuses a viewer and the helmet service working an alert', async () => {
    await assertFails(updateDoc(doc(asViewer(env), 'alerts', 'A-open'), {
      status: 'acknowledged', acknowledgedAt: serverTimestamp(),
    }));
    await assertFails(updateDoc(doc(asHelmetService(env), 'alerts', 'A-open'), {
      status: 'acknowledged', acknowledgedAt: serverTimestamp(),
    }));
  });
});
