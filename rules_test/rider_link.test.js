// riders/{id}.authUid — the link between a roster entry and the rider's own
// app account — and the one thing it opens: that rider reading their own
// roster entry and their own alerts. The countdown listens on exactly the
// alerts query tested here.

import { after, before, beforeEach, describe, it } from 'node:test';
import { assertFails, assertSucceeds } from '@firebase/rules-unit-testing';
import {
  collection, deleteField, doc, getDoc, getDocs, limit, orderBy, query, setDoc,
  Timestamp, updateDoc, where,
} from 'firebase/firestore';
import {
  asDispatcher, asGuardian, asHelmetService, asOtherRider, asRider,
  asSuperAdmin, GUARDIAN_UID, newTestEnv, OTHER_UID, reset, RIDER_UID,
} from './helpers.js';

const account = (role) => ({
  email: `${role}@example.test`, username: role, fullName: role, role,
  createdAt: Timestamp.now(), updatedAt: Timestamp.now(),
});

let env;
before(async () => { env = await newTestEnv(); });
after(async () => { await env.cleanup(); });
beforeEach(async () => {
  await reset(env, async (db) => {
    await setDoc(doc(db, 'users', RIDER_UID), account('rider'));
    await setDoc(doc(db, 'users', OTHER_UID), account('rider'));
    await setDoc(doc(db, 'users', GUARDIAN_UID), account('guardian'));
    await setDoc(doc(db, 'riders', 'R-001'), {
      fullName: 'Rider One', helmetId: 'NR-H1-001', status: 'riding', authUid: RIDER_UID,
    });
    await setDoc(doc(db, 'riders', 'R-002'), {
      fullName: 'Rider Two', helmetId: 'NR-H1-002', status: 'riding',
    });
    await setDoc(doc(db, 'alerts', 'A-mine'), {
      riderId: 'R-001', type: 'crash', status: 'open', timestamp: Timestamp.now(),
    });
    await setDoc(doc(db, 'alerts', 'A-theirs'), {
      riderId: 'R-002', type: 'crash', status: 'open', timestamp: Timestamp.now(),
    });
  });
});

describe('linking: who may write authUid', () => {
  it('a Super Admin may link a roster entry to a rider account', async () => {
    await assertSucceeds(updateDoc(doc(asSuperAdmin(env), 'riders', 'R-002'), { authUid: OTHER_UID }));
  });

  it('and unlink it again', async () => {
    await assertSucceeds(updateDoc(doc(asSuperAdmin(env), 'riders', 'R-001'), { authUid: deleteField() }));
  });

  it('and register a rider already linked', async () => {
    await assertSucceeds(setDoc(doc(asSuperAdmin(env), 'riders', 'R-003'), {
      fullName: 'Rider Three', helmetId: 'NR-H1-003', authUid: OTHER_UID,
    }));
  });

  it('edits that leave the link alone are unaffected', async () => {
    await assertSucceeds(updateDoc(doc(asSuperAdmin(env), 'riders', 'R-001'), { phone: '+63 917 000 0000' }));
  });

  it('never to a guardian account, which would then read this rider\'s alerts', async () => {
    await assertFails(updateDoc(doc(asSuperAdmin(env), 'riders', 'R-002'), { authUid: GUARDIAN_UID }));
  });

  it('never to a uid with no account behind it', async () => {
    await assertFails(updateDoc(doc(asSuperAdmin(env), 'riders', 'R-002'), { authUid: 'uid-nobody' }));
    await assertFails(updateDoc(doc(asSuperAdmin(env), 'riders', 'R-002'), { authUid: 42 }));
  });

  it('a dispatcher, the helmet and the rider themself may not', async () => {
    await assertFails(updateDoc(doc(asDispatcher(env), 'riders', 'R-002'), { authUid: OTHER_UID }));
    await assertFails(updateDoc(doc(asHelmetService(env), 'riders', 'R-002'), { authUid: OTHER_UID }));
    await assertFails(updateDoc(doc(asOtherRider(env), 'riders', 'R-002'), { authUid: OTHER_UID }));
  });
});

describe('a linked rider reads their own roster entry', () => {
  it('by get', async () => {
    await assertSucceeds(getDoc(doc(asRider(env), 'riders', 'R-001')));
  });

  it('by the query the app makes', async () => {
    const db = asRider(env);
    const snap = await assertSucceeds(
      getDocs(query(collection(db, 'riders'), where('authUid', '==', RIDER_UID))),
    );
    if (snap.size !== 1 || snap.docs[0].id !== 'R-001') throw new Error(`got ${snap.size}`);
  });

  it('and no one else\'s', async () => {
    const db = asRider(env);
    await assertFails(getDoc(doc(db, 'riders', 'R-002')));
    await assertFails(getDocs(collection(db, 'riders')));
    await assertFails(getDocs(query(collection(db, 'riders'), where('authUid', '==', OTHER_UID))));
  });

  it('an unlinked rider account reads none', async () => {
    const db = asOtherRider(env);
    await assertFails(getDoc(doc(db, 'riders', 'R-001')));
    await assertFails(getDoc(doc(db, 'riders', 'R-002')));
  });
});

describe('a linked rider reads their own alerts', () => {
  it('by get', async () => {
    await assertSucceeds(getDoc(doc(asRider(env), 'alerts', 'A-mine')));
  });

  it('by a query on their riderId, the countdown\'s listener', async () => {
    const db = asRider(env);
    const snap = await assertSucceeds(getDocs(query(
      collection(db, 'alerts'), where('riderId', '==', 'R-001'), where('status', '==', 'open'),
    )));
    if (snap.size !== 1) throw new Error(`got ${snap.size}`);
  });

  it('by the exact queries FirestoreRiderAlertRepository makes', async () => {
    const db = asRider(env);
    await assertSucceeds(getDocs(query(
      collection(db, 'riders'), where('authUid', '==', RIDER_UID), limit(1),
    )));
    await assertSucceeds(getDocs(query(
      collection(db, 'alerts'), where('riderId', '==', 'R-001'),
      orderBy('timestamp', 'desc'), limit(20),
    )));
  });

  it('and no one else\'s', async () => {
    const db = asRider(env);
    await assertFails(getDoc(doc(db, 'alerts', 'A-theirs')));
    await assertFails(getDocs(query(collection(db, 'alerts'), where('riderId', '==', 'R-002'))));
    await assertFails(getDocs(collection(db, 'alerts')));
  });

  it('nor does an unlinked rider or a guardian', async () => {
    await assertFails(getDoc(doc(asOtherRider(env), 'alerts', 'A-mine')));
    await assertFails(getDoc(doc(asGuardian(env), 'alerts', 'A-mine')));
    await assertFails(getDocs(query(collection(asGuardian(env), 'alerts'), where('riderId', '==', 'R-001'))));
  });

  it('reading is all it is: no edits', async () => {
    await assertFails(updateDoc(doc(asRider(env), 'alerts', 'A-mine'), { status: 'resolved' }));
  });
});
