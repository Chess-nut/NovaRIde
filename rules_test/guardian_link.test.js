// guardianInvites/, guardianLinks/ and the rider data a link opens; and
// riderProfiles/{uid}/emergencyContacts/.
//
// The flow under test: a rider writes an invite code; a guardian, within
// 15 minutes, writes guardianLinks/{their uid} naming it; from then on that
// guardian reads the rider's account, roster entry and alerts — with the
// same queries the app makes — and nobody else's.

import { after, before, beforeEach, describe, it } from 'node:test';
import { assertFails, assertSucceeds } from '@firebase/rules-unit-testing';
import {
  addDoc, collection, deleteDoc, doc, getDoc, getDocs, limit, orderBy, query,
  serverTimestamp, setDoc, Timestamp, updateDoc, where,
} from 'firebase/firestore';
import {
  asDispatcher, asGuardian, asOtherRider, asRider, GUARDIAN_UID, newTestEnv,
  OTHER_UID, reset, RIDER_UID,
} from './helpers.js';

const account = (role, fullName) => ({
  email: `${role}@example.test`, username: role, fullName, role,
  createdAt: Timestamp.now(), updatedAt: Timestamp.now(),
});

const minutesAgo = (m) => Timestamp.fromMillis(Date.now() - m * 60 * 1000);

const link = (overrides = {}) => ({
  riderUid: RIDER_UID,
  inviteCode: 'K7P2QM',
  guardianName: 'Guardian Person',
  relationship: 'Sibling',
  createdAt: serverTimestamp(),
  ...overrides,
});

let env;
before(async () => { env = await newTestEnv(); });
after(async () => { await env.cleanup(); });

// Seeds with rules off. `linked` adds an existing guardian link.
async function seed({ linked = false } = {}) {
  await reset(env, async (db) => {
    await setDoc(doc(db, 'users', RIDER_UID), account('rider', 'Rider One'));
    await setDoc(doc(db, 'users', OTHER_UID), account('rider', 'Rider Two'));
    await setDoc(doc(db, 'users', GUARDIAN_UID), account('guardian', 'Guardian Person'));
    await setDoc(doc(db, 'riders', 'R-001'), {
      fullName: 'Rider One', helmetId: 'NR-H1-001', status: 'riding', authUid: RIDER_UID,
    });
    await setDoc(doc(db, 'riders', 'R-002'), {
      fullName: 'Rider Two', helmetId: 'NR-H1-002', status: 'riding', authUid: OTHER_UID,
    });
    await setDoc(doc(db, 'alerts', 'A-mine'), {
      riderId: 'R-001', type: 'crash', status: 'open', timestamp: Timestamp.now(),
    });
    await setDoc(doc(db, 'alerts', 'A-theirs'), {
      riderId: 'R-002', type: 'crash', status: 'open', timestamp: Timestamp.now(),
    });
    await setDoc(doc(db, 'guardianInvites', 'K7P2QM'), {
      riderUid: RIDER_UID, riderName: 'Rider One', createdAt: minutesAgo(2),
    });
    await setDoc(doc(db, 'guardianInvites', 'EXP234'), {
      riderUid: RIDER_UID, riderName: 'Rider One', createdAt: minutesAgo(20),
    });
    if (linked) {
      await setDoc(doc(db, 'guardianLinks', GUARDIAN_UID), {
        riderUid: RIDER_UID, inviteCode: 'K7P2QM', guardianName: 'Guardian Person',
        relationship: 'Sibling', createdAt: Timestamp.now(),
      });
    }
  });
}

describe('invite codes', () => {
  beforeEach(() => seed());

  it('a rider makes one, with the server clock', async () => {
    await assertSucceeds(setDoc(doc(asRider(env), 'guardianInvites', 'ABC234'), {
      riderUid: RIDER_UID, riderName: 'Rider One', createdAt: serverTimestamp(),
    }));
  });

  it('not with a chosen time, an extra field, or someone else\'s uid', async () => {
    const db = asRider(env);
    await assertFails(setDoc(doc(db, 'guardianInvites', 'ABC234'), {
      riderUid: RIDER_UID, riderName: 'Rider One', createdAt: Timestamp.now(),
    }));
    await assertFails(setDoc(doc(db, 'guardianInvites', 'ABC235'), {
      riderUid: RIDER_UID, riderName: 'Rider One', createdAt: serverTimestamp(), extra: 1,
    }));
    await assertFails(setDoc(doc(db, 'guardianInvites', 'ABC236'), {
      riderUid: OTHER_UID, riderName: 'Rider Two', createdAt: serverTimestamp(),
    }));
  });

  it('only with a well-formed code as its id', async () => {
    for (const bad of ['abc234', 'ABC23', 'ABC2340', 'ABC0O1']) {
      await assertFails(setDoc(doc(asRider(env), 'guardianInvites', bad), {
        riderUid: RIDER_UID, riderName: 'Rider One', createdAt: serverTimestamp(),
      }));
    }
  });

  it('a guardian cannot make one', async () => {
    await assertFails(setDoc(doc(asGuardian(env), 'guardianInvites', 'ABC234'), {
      riderUid: GUARDIAN_UID, riderName: 'Guardian', createdAt: serverTimestamp(),
    }));
  });

  it('nobody can overwrite an existing code', async () => {
    await assertFails(setDoc(doc(asOtherRider(env), 'guardianInvites', 'K7P2QM'), {
      riderUid: OTHER_UID, riderName: 'Rider Two', createdAt: serverTimestamp(),
    }));
    await assertFails(updateDoc(doc(asRider(env), 'guardianInvites', 'K7P2QM'), {
      riderName: 'Renamed',
    }));
  });

  it('any signed-in account can look one up by its code', async () => {
    await assertSucceeds(getDoc(doc(asGuardian(env), 'guardianInvites', 'K7P2QM')));
  });

  it('only the rider lists theirs', async () => {
    await assertSucceeds(getDocs(query(
      collection(asRider(env), 'guardianInvites'), where('riderUid', '==', RIDER_UID),
    )));
    await assertFails(getDocs(query(
      collection(asGuardian(env), 'guardianInvites'), where('riderUid', '==', RIDER_UID),
    )));
    await assertFails(getDocs(collection(asRider(env), 'guardianInvites')));
  });

  it('only the rider cancels theirs', async () => {
    await assertFails(deleteDoc(doc(asOtherRider(env), 'guardianInvites', 'K7P2QM')));
    await assertFails(deleteDoc(doc(asGuardian(env), 'guardianInvites', 'K7P2QM')));
    await assertSucceeds(deleteDoc(doc(asRider(env), 'guardianInvites', 'K7P2QM')));
  });
});

describe('linking', () => {
  beforeEach(() => seed());

  it('a guardian links with a live code', async () => {
    await assertSucceeds(setDoc(doc(asGuardian(env), 'guardianLinks', GUARDIAN_UID), link()));
  });

  it('not with an expired code', async () => {
    await assertFails(setDoc(doc(asGuardian(env), 'guardianLinks', GUARDIAN_UID),
      link({ inviteCode: 'EXP234' })));
  });

  it('not with a code that does not exist, or for a different rider', async () => {
    const db = asGuardian(env);
    await assertFails(setDoc(doc(db, 'guardianLinks', GUARDIAN_UID), link({ inviteCode: 'ZZZ999' })));
    await assertFails(setDoc(doc(db, 'guardianLinks', GUARDIAN_UID), link({ riderUid: OTHER_UID })));
  });

  it('not under someone else\'s name, or for someone else\'s uid', async () => {
    const db = asGuardian(env);
    await assertFails(setDoc(doc(db, 'guardianLinks', GUARDIAN_UID), link({ guardianName: 'Someone Else' })));
    await assertFails(setDoc(doc(db, 'guardianLinks', 'uid-another'), link()));
  });

  it('a rider account cannot link as a guardian', async () => {
    await assertFails(setDoc(doc(asOtherRider(env), 'guardianLinks', OTHER_UID),
      link({ guardianName: 'Rider Two' })));
  });

  it('not with extra fields or a chosen time', async () => {
    const db = asGuardian(env);
    await assertFails(setDoc(doc(db, 'guardianLinks', GUARDIAN_UID), link({ extra: true })));
    await assertFails(setDoc(doc(db, 'guardianLinks', GUARDIAN_UID), link({ createdAt: Timestamp.now() })));
  });
});

describe('an existing link', () => {
  beforeEach(() => seed({ linked: true }));

  it('cannot be changed to another rider: one guardian, one rider', async () => {
    await assertFails(setDoc(doc(asGuardian(env), 'guardianLinks', GUARDIAN_UID),
      link({ riderUid: OTHER_UID })));
    await assertFails(updateDoc(doc(asGuardian(env), 'guardianLinks', GUARDIAN_UID),
      { relationship: 'Parent' }));
  });

  it('is read by the guardian and the rider, and listed by the rider', async () => {
    await assertSucceeds(getDoc(doc(asGuardian(env), 'guardianLinks', GUARDIAN_UID)));
    await assertSucceeds(getDoc(doc(asRider(env), 'guardianLinks', GUARDIAN_UID)));
    await assertSucceeds(getDocs(query(
      collection(asRider(env), 'guardianLinks'), where('riderUid', '==', RIDER_UID),
    )));
  });

  it('is invisible to another rider', async () => {
    await assertFails(getDoc(doc(asOtherRider(env), 'guardianLinks', GUARDIAN_UID)));
    await assertFails(getDocs(query(
      collection(asOtherRider(env), 'guardianLinks'), where('riderUid', '==', RIDER_UID),
    )));
  });

  it('can be ended by the rider', async () => {
    await assertSucceeds(deleteDoc(doc(asRider(env), 'guardianLinks', GUARDIAN_UID)));
  });

  it('can be ended by the guardian, but not by another rider', async () => {
    await assertFails(deleteDoc(doc(asOtherRider(env), 'guardianLinks', GUARDIAN_UID)));
    await assertSucceeds(deleteDoc(doc(asGuardian(env), 'guardianLinks', GUARDIAN_UID)));
  });
});

describe('what a link opens to the guardian', () => {
  beforeEach(() => seed({ linked: true }));

  it('the rider\'s account, and no one else\'s', async () => {
    await assertSucceeds(getDoc(doc(asGuardian(env), 'users', RIDER_UID)));
    await assertFails(getDoc(doc(asGuardian(env), 'users', OTHER_UID)));
  });

  it('the rider\'s roster entry, by the query the app makes', async () => {
    const snap = await assertSucceeds(getDocs(query(
      collection(asGuardian(env), 'riders'), where('authUid', '==', RIDER_UID), limit(1),
    )));
    if (snap.size !== 1 || snap.docs[0].id !== 'R-001') throw new Error(`got ${snap.size}`);
    await assertFails(getDocs(query(
      collection(asGuardian(env), 'riders'), where('authUid', '==', OTHER_UID),
    )));
  });

  it('the rider\'s alerts, by the query the app makes, and no one else\'s', async () => {
    const db = asGuardian(env);
    await assertSucceeds(getDocs(query(
      collection(db, 'alerts'), where('riderId', '==', 'R-001'),
      orderBy('timestamp', 'desc'), limit(20),
    )));
    await assertSucceeds(getDoc(doc(db, 'alerts', 'A-mine')));
    await assertFails(getDoc(doc(db, 'alerts', 'A-theirs')));
    await assertFails(getDocs(query(collection(db, 'alerts'), where('riderId', '==', 'R-002'))));
  });

  it('read only: the guardian cannot touch the alert', async () => {
    await assertFails(updateDoc(doc(asGuardian(env), 'alerts', 'A-mine'), { status: 'cancelled' }));
  });

  it('none of it once unlinked', async () => {
    await deleteDoc(doc(asGuardian(env), 'guardianLinks', GUARDIAN_UID));
    await assertFails(getDoc(doc(asGuardian(env), 'users', RIDER_UID)));
    await assertFails(getDoc(doc(asGuardian(env), 'alerts', 'A-mine')));
  });
});

describe('phone-only emergency contacts', () => {
  beforeEach(() => seed());

  const contact = (o = {}) => ({
    name: 'Lola', relationship: 'Grandparent', phone: '+63 917 000 0000',
    createdAt: serverTimestamp(), updatedAt: serverTimestamp(), ...o,
  });
  const contacts = (db, uid = RIDER_UID) =>
    collection(db, 'riderProfiles', uid, 'emergencyContacts');

  it('a rider adds, reads, edits and deletes their own', async () => {
    const db = asRider(env);
    const ref = await assertSucceeds(addDoc(contacts(db), contact()));
    await assertSucceeds(getDocs(query(contacts(db), orderBy('createdAt'))));
    await assertSucceeds(updateDoc(ref, { phone: '+63 917 111 1111', updatedAt: serverTimestamp() }));
    await assertSucceeds(deleteDoc(ref));
  });

  it('nobody else writes or reads them; operators read them', async () => {
    const ref = await addDoc(contacts(asRider(env)), contact());
    await assertFails(getDoc(doc(asOtherRider(env), ref.path)));
    await assertFails(getDoc(doc(asGuardian(env), ref.path)));
    await assertFails(addDoc(contacts(asOtherRider(env)), contact()));
    await assertSucceeds(getDoc(doc(asDispatcher(env), ref.path)));
  });

  it('only the expected fields, a real name and a phone-length number', async () => {
    const db = asRider(env);
    await assertFails(addDoc(contacts(db), contact({ name: '' })));
    await assertFails(addDoc(contacts(db), contact({ phone: '12' })));
    await assertFails(addDoc(contacts(db), contact({ notes: 'x' })));
    await assertFails(addDoc(contacts(db), contact({ createdAt: Timestamp.now() })));
  });

  it('a guardian account cannot keep them', async () => {
    await assertFails(addDoc(contacts(asGuardian(env), GUARDIAN_UID), contact()));
  });
});
