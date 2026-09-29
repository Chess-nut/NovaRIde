// alerts/{alertId} — the response workflow. The lifecycle is linear and each
// step stamps its own server timestamp; the Reports tab's response times are
// the study's evidence, so an operator machine clock must never set one.

import { after, before, beforeEach, describe, it } from 'node:test';
import { assertFails, assertSucceeds } from '@firebase/rules-unit-testing';
import {
  deleteDoc, doc, getDoc, serverTimestamp, setDoc, Timestamp, updateDoc,
} from 'firebase/firestore';
import {
  asAnonymous, asDispatcher, asHelmetService, asSuperAdmin, asUnprovisioned,
  asViewer, newTestEnv, reset,
} from './helpers.js';

const openAlert = {
  riderId: 'R-001', riderName: 'Rider One', type: 'crash',
  lat: 14.6, lng: 121.0, status: 'open',
};

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
    await assertSucceeds(
      setDoc(doc(asHelmetService(env), 'alerts', 'A-new'), {
        ...openAlert, timestamp: serverTimestamp(),
      }),
    );
    await assertSucceeds(
      setDoc(doc(asSuperAdmin(env), 'alerts', 'A-101'), {
        ...openAlert, timestamp: serverTimestamp(),
      }),
    );
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
