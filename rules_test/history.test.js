// alerts/{alertId}/history/{entryId} — the audit trail, append-only, and the
// collectionGroup read the console's single history listener depends on.

import { after, before, beforeEach, describe, it } from 'node:test';
import { assertFails, assertSucceeds } from '@firebase/rules-unit-testing';
import {
  addDoc, collection, collectionGroup, deleteDoc, doc, getDocs,
  serverTimestamp, setDoc, Timestamp, updateDoc,
} from 'firebase/firestore';
import {
  asAnonymous, asDispatcher, asSuperAdmin, asUnprovisioned, asViewer,
  newTestEnv, reset,
} from './helpers.js';

const trail = (db) => collection(db, 'alerts', 'A-open', 'history');

let env;
before(async () => { env = await newTestEnv(); });
after(async () => { await env.cleanup(); });
beforeEach(async () => {
  await reset(env, async (db) => {
    await setDoc(doc(db, 'alerts', 'A-open'), {
      riderId: 'R-001', type: 'crash', status: 'open', timestamp: Timestamp.now(),
    });
    await setDoc(doc(db, 'alerts', 'A-open', 'history', 'h1'), {
      toStatus: 'acknowledged', actorName: 'Dispatcher', at: Timestamp.now(),
    });
  });
});

describe('alerts/{id}/history/', () => {
  it('accepts an entry from a dispatcher or a Super Admin', async () => {
    await assertSucceeds(addDoc(trail(asDispatcher(env)), {
      toStatus: 'acknowledged', actorName: 'Dispatcher', note: null, at: serverTimestamp(),
    }));
    await assertSucceeds(addDoc(trail(asSuperAdmin(env)), {
      toStatus: 'dispatched', actorName: 'Super Admin', responder: 'medical',
      at: serverTimestamp(),
    }));
  });

  // Response-time metrics are the study's evidence; operator clocks are not
  // trusted for them.
  it('refuses an entry stamped from the operator machine clock', async () => {
    await assertFails(addDoc(trail(asDispatcher(env)), {
      toStatus: 'acknowledged', actorName: 'Dispatcher', at: Timestamp.now(),
    }));
  });

  it('refuses an entry missing toStatus, actorName or at', async () => {
    const db = asDispatcher(env);
    await assertFails(addDoc(trail(db), { actorName: 'D', at: serverTimestamp() }));
    await assertFails(addDoc(trail(db), { toStatus: 'acknowledged', at: serverTimestamp() }));
    await assertFails(addDoc(trail(db), { toStatus: 'acknowledged', actorName: 'D' }));
  });

  it('refuses an entry whose toStatus or actorName is not a string', async () => {
    const db = asDispatcher(env);
    await assertFails(addDoc(trail(db), {
      toStatus: 3, actorName: 'D', at: serverTimestamp(),
    }));
    await assertFails(addDoc(trail(db), {
      toStatus: 'resolved', actorName: 3, at: serverTimestamp(),
    }));
  });

  it('refuses an entry from a viewer', async () => {
    await assertFails(addDoc(trail(asViewer(env)), {
      toStatus: 'acknowledged', actorName: 'Viewer', at: serverTimestamp(),
    }));
  });

  it('is append-only: no edit, no delete, not even for a Super Admin', async () => {
    const db = asSuperAdmin(env);
    await assertFails(
      updateDoc(doc(db, 'alerts', 'A-open', 'history', 'h1'), { actorName: 'Someone else' }),
    );
    await assertFails(deleteDoc(doc(db, 'alerts', 'A-open', 'history', 'h1')));
  });

  it('is readable by any operator, directly and as a collection group', async () => {
    await assertSucceeds(getDocs(trail(asViewer(env))));
    await assertSucceeds(getDocs(collectionGroup(asViewer(env), 'history')));
  });

  it('refuses the collection-group read to a non-operator', async () => {
    await assertFails(getDocs(collectionGroup(asAnonymous(env), 'history')));
    await assertFails(getDocs(collectionGroup(asUnprovisioned(env), 'history')));
  });
});
