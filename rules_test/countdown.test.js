// The false-positive countdown (FIRMWARE_CONTRACT.md §3.8): a crash
// arrives `pending`; its own linked rider may cancel it for 15 s of server
// time, and stand themself down from `emergency`; after that only the
// console moves it. The countdown can suppress an alert, never stop one.

import { after, before, beforeEach, describe, it } from 'node:test';
import { assertFails, assertSucceeds } from '@firebase/rules-unit-testing';
import {
  doc, serverTimestamp, setDoc, Timestamp, updateDoc, writeBatch,
} from 'firebase/firestore';
import {
  asDispatcher, asGuardian, asHelmetService, asOtherRider, asRider,
  GUARDIAN_UID, newTestEnv, OTHER_UID, reset, RIDER_UID,
} from './helpers.js';

const account = (role) => ({
  email: `${role}@example.test`, username: role, fullName: role, role,
  createdAt: Timestamp.now(), updatedAt: Timestamp.now(),
});
const secondsAgo = (s) => Timestamp.fromMillis(Date.now() - s * 1000);
const alert = (riderId, status, timestamp) => ({
  riderId, deviceId: 'NR-H1-001', type: 'crash', severity: 'high', status, timestamp,
});
const cancel = { status: 'cancelled', cancelledAt: serverTimestamp() };

let env;
before(async () => { env = await newTestEnv(); });
after(async () => { await env.cleanup(); });
beforeEach(async () => {
  await reset(env, async (db) => {
    await setDoc(doc(db, 'users', RIDER_UID), account('rider'));
    await setDoc(doc(db, 'users', OTHER_UID), account('rider'));
    await setDoc(doc(db, 'users', GUARDIAN_UID), account('guardian'));
    await setDoc(doc(db, 'riders', 'R-001'), {
      fullName: 'Rider One', helmetId: 'NR-H1-001', status: 'emergency', authUid: RIDER_UID,
    });
    await setDoc(doc(db, 'riders', 'R-002'), {
      fullName: 'Rider Two', helmetId: 'NR-H1-002', status: 'emergency', authUid: OTHER_UID,
    });
    await setDoc(doc(db, 'alerts', 'P-fresh'), alert('R-001', 'pending', secondsAgo(2)));
    await setDoc(doc(db, 'alerts', 'P-stale'), alert('R-001', 'pending', secondsAgo(20)));
    await setDoc(doc(db, 'alerts', 'P-theirs'), alert('R-002', 'pending', secondsAgo(2)));
    await setDoc(doc(db, 'alerts', 'O-open'), alert('R-001', 'open', secondsAgo(2)));
    await setDoc(doc(db, 'alerts', 'C-recent'), alert('R-001', 'cancelled', secondsAgo(30)));
    await setDoc(doc(db, 'alerts', 'C-old'), alert('R-001', 'cancelled', secondsAgo(120)));
  });
});

describe('the helmet raises a crash as pending', () => {
  const raised = (fields) => ({
    riderId: 'R-001', deviceId: 'NR-H1-001', type: 'crash', severity: 'high',
    status: 'pending', timestamp: serverTimestamp(), ...fields,
  });

  it('a crash may arrive pending', async () => {
    await assertSucceeds(setDoc(doc(asHelmetService(env), 'alerts', 'new'), raised({})));
  });

  it('and still open, for firmware that predates the countdown', async () => {
    await assertSucceeds(setDoc(doc(asHelmetService(env), 'alerts', 'new'), raised({ status: 'open' })));
  });

  it('nothing else may: an SOS is deliberate, and so is an alcohol warning', async () => {
    const db = asHelmetService(env);
    await assertFails(setDoc(doc(db, 'alerts', 'a'), raised({ type: 'sos' })));
    await assertFails(setDoc(doc(db, 'alerts', 'b'), raised({ type: 'alcoholWarning' })));
  });

  it('never already cancelled, or carrying cancelledAt', async () => {
    const db = asHelmetService(env);
    await assertFails(setDoc(doc(db, 'alerts', 'a'), raised({ status: 'cancelled' })));
    await assertFails(setDoc(doc(db, 'alerts', 'b'), raised({ cancelledAt: serverTimestamp() })));
  });
});

describe('the rider cancels during the countdown', () => {
  it('their own pending crash, inside 15 s', async () => {
    await assertSucceeds(updateDoc(doc(asRider(env), 'alerts', 'P-fresh'), cancel));
  });

  it('not once 15 s of server time have passed', async () => {
    await assertFails(updateDoc(doc(asRider(env), 'alerts', 'P-stale'), cancel));
  });

  it('not an alert that is already open, or already cancelled', async () => {
    const db = asRider(env);
    await assertFails(updateDoc(doc(db, 'alerts', 'O-open'), cancel));
    await assertFails(updateDoc(doc(db, 'alerts', 'C-recent'), cancel));
  });

  it('not somebody else\'s, and not as a guardian', async () => {
    await assertFails(updateDoc(doc(asRider(env), 'alerts', 'P-theirs'), cancel));
    await assertFails(updateDoc(doc(asOtherRider(env), 'alerts', 'P-fresh'), cancel));
    await assertFails(updateDoc(doc(asGuardian(env), 'alerts', 'P-fresh'), cancel));
  });

  it('a cancel is exactly status and a server-clock cancelledAt', async () => {
    const db = asRider(env);
    await assertFails(updateDoc(doc(db, 'alerts', 'P-fresh'), { status: 'cancelled' }));
    await assertFails(updateDoc(doc(db, 'alerts', 'P-fresh'), {
      status: 'cancelled', cancelledAt: Timestamp.now(),
    }));
    await assertFails(updateDoc(doc(db, 'alerts', 'P-fresh'), { ...cancel, severity: 'low' }));
    await assertFails(updateDoc(doc(db, 'alerts', 'P-fresh'), {
      status: 'resolved', resolvedAt: serverTimestamp(),
    }));
  });
});

describe('the rider stands themself down from emergency', () => {
  const standDown = (alertId) => ({ status: 'riding', statusClearedBy: alertId });

  it('in the same batch as the cancel', async () => {
    const db = asRider(env);
    const batch = writeBatch(db);
    batch.update(doc(db, 'alerts', 'P-fresh'), cancel);
    batch.update(doc(db, 'riders', 'R-001'), standDown('P-fresh'));
    await assertSucceeds(batch.commit());
  });

  it('or afterwards, when the helmet\'s emergency write arrived late', async () => {
    await assertSucceeds(updateDoc(doc(asRider(env), 'riders', 'R-001'), standDown('C-recent')));
  });

  it('not on the strength of an old cancellation', async () => {
    await assertFails(updateDoc(doc(asRider(env), 'riders', 'R-001'), standDown('C-old')));
  });

  it('not naming an alert that is still live, or somebody else\'s', async () => {
    const db = asRider(env);
    await assertFails(updateDoc(doc(db, 'riders', 'R-001'), standDown('O-open')));
    await assertFails(updateDoc(doc(db, 'riders', 'R-001'), standDown('P-fresh')));
    await assertFails(updateDoc(doc(db, 'riders', 'R-001'), standDown('P-theirs')));
    await assertFails(updateDoc(doc(db, 'riders', 'R-001'), standDown('no-such-alert')));
  });

  it('only emergency → riding, only their own entry, nothing else on it', async () => {
    const db = asRider(env);
    await assertFails(updateDoc(doc(db, 'riders', 'R-001'), { status: 'idle', statusClearedBy: 'C-recent' }));
    await assertFails(updateDoc(doc(db, 'riders', 'R-001'), { status: 'riding' }));
    await assertFails(updateDoc(doc(db, 'riders', 'R-001'), { ...standDown('C-recent'), fullName: 'X' }));
    await assertFails(updateDoc(doc(db, 'riders', 'R-002'), standDown('C-recent')));
  });

  it('and not when they are not in emergency', async () => {
    await env.withSecurityRulesDisabled(async (context) => {
      await updateDoc(doc(context.firestore(), 'riders', 'R-001'), { status: 'idle' });
    });
    await assertFails(updateDoc(doc(asRider(env), 'riders', 'R-001'), standDown('C-recent')));
  });
});

describe('the console is never held back by the countdown', () => {
  it('a dispatcher may acknowledge a pending crash at once', async () => {
    await assertSucceeds(updateDoc(doc(asDispatcher(env), 'alerts', 'P-fresh'), {
      status: 'acknowledged', acknowledgedAt: serverTimestamp(),
    }));
  });

  it('after which the rider can no longer cancel it', async () => {
    await updateDoc(doc(asDispatcher(env), 'alerts', 'P-fresh'), {
      status: 'acknowledged', acknowledgedAt: serverTimestamp(),
    });
    await assertFails(updateDoc(doc(asRider(env), 'alerts', 'P-fresh'), cancel));
  });

  it('a cancelled alert has no next step', async () => {
    await assertFails(updateDoc(doc(asDispatcher(env), 'alerts', 'C-recent'), {
      status: 'acknowledged', acknowledgedAt: serverTimestamp(),
    }));
  });
});
