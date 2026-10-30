// users/, riderProfiles/, guardianProfiles/ and usernames/ — the four
// paths Phase 3 opened.
//
// Each was denied to everybody until now. What each one permits is
// written out here rather than inferred from firestore.rules, because
// "who can read a rider's account record" is the question somebody will
// ask in a review and this is the answer.

import { after, before, beforeEach, describe, it } from 'node:test';
import { assertFails, assertSucceeds } from '@firebase/rules-unit-testing';
import {
  collection, deleteDoc, doc, getDoc, getDocs, runTransaction,
  serverTimestamp, setDoc,
  Timestamp, updateDoc,
} from 'firebase/firestore';
import {
  asAnonymous, asGuardian, asOtherRider, asRider, asSuperAdmin,
  GUARDIAN_EMAIL, GUARDIAN_UID, newTestEnv, reset, RIDER_EMAIL, RIDER_UID,
} from './helpers.js';

/// What ensureProfile writes when it creates users/{uid}.
const newUser = (email, role) => ({
  email,
  username: 'riderone',
  fullName: 'Rider One',
  role,
  createdAt: serverTimestamp(),
  updatedAt: serverTimestamp(),
});

let env;
before(async () => { env = await newTestEnv(); });
after(async () => { await env.cleanup(); });

/// Seeds an existing rider account, for the update and read cases.
const seedRider = async (db) => {
  const { setDoc: s, doc: d } = await import('firebase/firestore');
  await s(d(db, 'users', RIDER_UID), {
    email: RIDER_EMAIL,
    username: 'riderone',
    fullName: 'Rider One',
    role: 'rider',
    createdAt: Timestamp.now(),
    updatedAt: Timestamp.now(),
  });
  await s(d(db, 'riderProfiles', RIDER_UID), {
    createdAt: Timestamp.now(),
    updatedAt: Timestamp.now(),
  });
  await s(d(db, 'usernames', 'riderone'), {
    uid: RIDER_UID,
    email: RIDER_EMAIL,
    createdAt: Timestamp.now(),
  });
};

beforeEach(async () => { await reset(env); });

describe('users/{uid} — create', () => {
  it('lets an account create its own record', async () => {
    await assertSucceeds(
      setDoc(doc(asRider(env), 'users', RIDER_UID), newUser(RIDER_EMAIL, 'rider')),
    );
    await assertSucceeds(
      setDoc(doc(asGuardian(env), 'users', GUARDIAN_UID),
        newUser(GUARDIAN_EMAIL, 'guardian')),
    );
  });

  // The document id is the uid. Anything else is somebody else's record.
  it('refuses a record under another uid', async () => {
    await assertFails(
      setDoc(doc(asRider(env), 'users', GUARDIAN_UID), newUser(RIDER_EMAIL, 'rider')),
    );
  });

  it('refuses an unrecognised role, and the console roles', async () => {
    for (const role of ['superAdmin', 'dispatcher', 'viewer', 'admin', '', 'Rider']) {
      await assertFails(
        setDoc(doc(asRider(env), 'users', RIDER_UID), newUser(RIDER_EMAIL, role)),
      );
    }
  });

  // Without this an account could write somebody else's address into its
  // own record — and into the world-readable usernames/ entry.
  it('refuses an email that is not the one on the ID token', async () => {
    await assertFails(
      setDoc(doc(asRider(env), 'users', RIDER_UID),
        newUser('someone.else@example.test', 'rider')),
    );
  });

  it('accepts the token email in a different case', async () => {
    await assertSucceeds(
      setDoc(doc(asRider(env), 'users', RIDER_UID),
        newUser(RIDER_EMAIL.toUpperCase(), 'rider')),
    );
  });

  it('refuses timestamps from the client clock', async () => {
    const db = asRider(env);
    await assertFails(setDoc(doc(db, 'users', RIDER_UID), {
      ...newUser(RIDER_EMAIL, 'rider'), createdAt: Timestamp.now(),
    }));
    await assertFails(setDoc(doc(db, 'users', RIDER_UID), {
      ...newUser(RIDER_EMAIL, 'rider'), updatedAt: Timestamp.now(),
    }));
  });

  it('refuses a record with no username', async () => {
    const db = asRider(env);
    const { username, ...withoutUsername } = newUser(RIDER_EMAIL, 'rider');
    await assertFails(setDoc(doc(db, 'users', RIDER_UID), withoutUsername));
    await assertFails(setDoc(doc(db, 'users', RIDER_UID), {
      ...newUser(RIDER_EMAIL, 'rider'), username: '',
    }));
  });

  it('refuses an anonymous create', async () => {
    await assertFails(
      setDoc(doc(asAnonymous(env), 'users', RIDER_UID), newUser(RIDER_EMAIL, 'rider')),
    );
  });
});

describe('users/{uid} — credentials are never stored', () => {
  // The brief's last rule, enforced by the rules rather than trusted to
  // the app: nothing that looks like a secret reaches Firestore.
  for (const field of [
    'password', 'passwordHash', 'passwordSalt', 'idToken', 'accessToken',
    'refreshToken', 'token', 'secret', 'apiKey', 'privateKey',
  ]) {
    it(`refuses a record carrying ${field}`, async () => {
      await assertFails(setDoc(doc(asRider(env), 'users', RIDER_UID), {
        ...newUser(RIDER_EMAIL, 'rider'), [field]: 'whatever',
      }));
    });
  }

  // A push token is an address, not a secret, and the app writes one.
  it('allows fcmToken', async () => {
    await assertSucceeds(setDoc(doc(asRider(env), 'users', RIDER_UID), {
      ...newUser(RIDER_EMAIL, 'rider'), fcmToken: 'a-push-token',
    }));
  });
});

describe('users/{uid} — read', () => {
  beforeEach(async () => {
    await env.withSecurityRulesDisabled((c) => seedRider(c.firestore()));
  });

  it('lets an account read its own record', async () => {
    await assertSucceeds(getDoc(doc(asRider(env), 'users', RIDER_UID)));
  });

  it('refuses every other reader, operators included', async () => {
    await assertFails(getDoc(doc(asOtherRider(env), 'users', RIDER_UID)));
    await assertFails(getDoc(doc(asGuardian(env), 'users', RIDER_UID)));
    await assertFails(getDoc(doc(asAnonymous(env), 'users', RIDER_UID)));
    // The console has no code that reads users/ and no reason to.
    await assertFails(getDoc(doc(asSuperAdmin(env), 'users', RIDER_UID)));
  });

  // Nobody may enumerate the accounts, not even to count them.
  it('refuses a listing to everybody', async () => {
    await assertFails(getDocs(collection(asRider(env), 'users')));
    await assertFails(getDocs(collection(asSuperAdmin(env), 'users')));
  });
});

describe('users/{uid} — update', () => {
  beforeEach(async () => {
    await env.withSecurityRulesDisabled((c) => seedRider(c.firestore()));
  });

  // What ensureProfile does on every sign-in.
  it('accepts the sign-in touch: lastLoginAt, fcmToken, updatedAt', async () => {
    await assertSucceeds(updateDoc(doc(asRider(env), 'users', RIDER_UID), {
      lastLoginAt: serverTimestamp(),
      fcmToken: 'a-push-token',
      updatedAt: serverTimestamp(),
    }));
  });

  it('refuses a write that does not stamp updatedAt from the server', async () => {
    const db = asRider(env);
    await assertFails(updateDoc(doc(db, 'users', RIDER_UID), {
      lastLoginAt: serverTimestamp(),
    }));
    await assertFails(updateDoc(doc(db, 'users', RIDER_UID), {
      updatedAt: Timestamp.now(),
    }));
    await assertFails(updateDoc(doc(db, 'users', RIDER_UID), {
      lastLoginAt: Timestamp.now(), updatedAt: serverTimestamp(),
    }));
  });

  // The role decides which home screen and, in later phases, which rider
  // data an account can reach. It is the single most important field in
  // the database to hold still.
  it('refuses a change of role', async () => {
    await assertFails(updateDoc(doc(asRider(env), 'users', RIDER_UID), {
      role: 'guardian', updatedAt: serverTimestamp(),
    }));
  });

  it('refuses a change of createdAt, email or username', async () => {
    const db = asRider(env);
    await assertFails(updateDoc(doc(db, 'users', RIDER_UID), {
      createdAt: serverTimestamp(), updatedAt: serverTimestamp(),
    }));
    await assertFails(updateDoc(doc(db, 'users', RIDER_UID), {
      email: 'new@example.test', updatedAt: serverTimestamp(),
    }));
    await assertFails(updateDoc(doc(db, 'users', RIDER_UID), {
      username: 'somethingelse', updatedAt: serverTimestamp(),
    }));
  });

  // Phase 7's profile editing needs this; the rule already allows it.
  it('accepts an edit to a displayable field', async () => {
    await assertSucceeds(updateDoc(doc(asRider(env), 'users', RIDER_UID), {
      fullName: 'Rider One Renamed',
      phoneNumber: '+639171234567',
      updatedAt: serverTimestamp(),
    }));
  });

  it('refuses an update by anybody else', async () => {
    await assertFails(updateDoc(doc(asOtherRider(env), 'users', RIDER_UID), {
      fullName: 'Hijacked', updatedAt: serverTimestamp(),
    }));
    await assertFails(updateDoc(doc(asSuperAdmin(env), 'users', RIDER_UID), {
      fullName: 'Hijacked', updatedAt: serverTimestamp(),
    }));
  });

  it('refuses deletion by anybody', async () => {
    await assertFails(deleteDoc(doc(asRider(env), 'users', RIDER_UID)));
    await assertFails(deleteDoc(doc(asSuperAdmin(env), 'users', RIDER_UID)));
  });
});

describe('riderProfiles/ and guardianProfiles/', () => {
  const newProfile = () => ({
    createdAt: serverTimestamp(),
    updatedAt: serverTimestamp(),
  });

  it('lets an account create its own, under its own uid', async () => {
    await assertSucceeds(
      setDoc(doc(asRider(env), 'riderProfiles', RIDER_UID), newProfile()),
    );
    await assertSucceeds(
      setDoc(doc(asGuardian(env), 'guardianProfiles', GUARDIAN_UID), newProfile()),
    );
  });

  it('refuses one under somebody else\'s uid', async () => {
    await assertFails(
      setDoc(doc(asRider(env), 'riderProfiles', GUARDIAN_UID), newProfile()),
    );
    await assertFails(
      setDoc(doc(asOtherRider(env), 'riderProfiles', RIDER_UID), newProfile()),
    );
  });

  it('refuses client-clock timestamps', async () => {
    await assertFails(setDoc(doc(asRider(env), 'riderProfiles', RIDER_UID), {
      createdAt: Timestamp.now(), updatedAt: serverTimestamp(),
    }));
  });

  // The profile collection has to match the role on users/{uid}. During
  // sign-up users/ does not exist yet, so the create is admitted; once it
  // does, the role decides.
  describe('once the account exists', () => {
    beforeEach(async () => {
      await env.withSecurityRulesDisabled((c) => seedRider(c.firestore()));
    });

    it('refuses a rider a guardianProfiles document', async () => {
      await assertFails(
        setDoc(doc(asRider(env), 'guardianProfiles', RIDER_UID), newProfile()),
      );
    });

    it('still allows the rider to create its own', async () => {
      // The seed already wrote one, so remove it first — otherwise this
      // is an update that moves createdAt, which is denied for its own
      // reasons and would prove nothing about the role check.
      await env.withSecurityRulesDisabled(
        (c) => deleteDoc(doc(c.firestore(), 'riderProfiles', RIDER_UID)),
      );
      await assertSucceeds(
        setDoc(doc(asRider(env), 'riderProfiles', RIDER_UID), newProfile()),
      );
    });

    it('is readable only by its owner', async () => {
      await assertSucceeds(getDoc(doc(asRider(env), 'riderProfiles', RIDER_UID)));
      await assertFails(getDoc(doc(asOtherRider(env), 'riderProfiles', RIDER_UID)));
      await assertFails(getDoc(doc(asGuardian(env), 'riderProfiles', RIDER_UID)));
      await assertFails(getDoc(doc(asAnonymous(env), 'riderProfiles', RIDER_UID)));
      await assertFails(getDoc(doc(asSuperAdmin(env), 'riderProfiles', RIDER_UID)));
    });

    it('accepts an owner edit that keeps createdAt and stamps updatedAt',
      async () => {
        await assertSucceeds(
          updateDoc(doc(asRider(env), 'riderProfiles', RIDER_UID), {
            helmetId: 'NR-H1-001', updatedAt: serverTimestamp(),
          }),
        );
      });

    it('refuses an edit that moves createdAt or forgets updatedAt', async () => {
      const db = asRider(env);
      await assertFails(updateDoc(doc(db, 'riderProfiles', RIDER_UID), {
        createdAt: serverTimestamp(), updatedAt: serverTimestamp(),
      }));
      await assertFails(updateDoc(doc(db, 'riderProfiles', RIDER_UID), {
        helmetId: 'NR-H1-001',
      }));
    });

    it('refuses credential fields here too', async () => {
      await assertFails(updateDoc(doc(asRider(env), 'riderProfiles', RIDER_UID), {
        passwordHash: 'nope', updatedAt: serverTimestamp(),
      }));
    });

    it('refuses deletion', async () => {
      await assertFails(deleteDoc(doc(asRider(env), 'riderProfiles', RIDER_UID)));
    });

    it('refuses a listing', async () => {
      await assertFails(getDocs(collection(asRider(env), 'riderProfiles')));
      await assertFails(getDocs(collection(asSuperAdmin(env), 'riderProfiles')));
    });
  });
});

describe('usernames/{usernameLower}', () => {
  const claim = (uid, email) => ({
    uid,
    email,
    createdAt: serverTimestamp(),
  });

  it('lets a signed-in account claim a free username', async () => {
    await assertSucceeds(
      setDoc(doc(asRider(env), 'usernames', 'riderone'),
        claim(RIDER_UID, RIDER_EMAIL)),
    );
  });

  // The one open read in the database. Logging in by username means
  // resolving it to an email, and whoever is doing that is not signed in
  // yet, so this has to work.
  it('is readable by an unauthenticated visitor', async () => {
    await env.withSecurityRulesDisabled((c) => seedRider(c.firestore()));
    await assertSucceeds(getDoc(doc(asAnonymous(env), 'usernames', 'riderone')));
  });

  // Open to `get`, closed to `list`: a name can be checked, the
  // collection cannot be harvested.
  it('cannot be enumerated by anybody', async () => {
    await env.withSecurityRulesDisabled((c) => seedRider(c.firestore()));
    await assertFails(getDocs(collection(asAnonymous(env), 'usernames')));
    await assertFails(getDocs(collection(asRider(env), 'usernames')));
    await assertFails(getDocs(collection(asSuperAdmin(env), 'usernames')));
  });

  // Uniqueness is the rules' job, not only the app's: a claim is a
  // create, and writing over a name somebody holds is an update.
  it('refuses a claim on a username somebody already holds', async () => {
    await env.withSecurityRulesDisabled((c) => seedRider(c.firestore()));
    await assertFails(
      setDoc(doc(asOtherRider(env), 'usernames', 'riderone'),
        claim('uid-mobile-other', 'other@example.test')),
    );
    // Not even the holder may rewrite it.
    await assertFails(
      setDoc(doc(asRider(env), 'usernames', 'riderone'),
        claim(RIDER_UID, RIDER_EMAIL)),
    );
  });

  it('refuses a claim that points at another uid', async () => {
    await assertFails(
      setDoc(doc(asRider(env), 'usernames', 'riderone'),
        claim(GUARDIAN_UID, RIDER_EMAIL)),
    );
  });

  it('refuses a claim carrying an email that is not the token\'s', async () => {
    await assertFails(
      setDoc(doc(asRider(env), 'usernames', 'riderone'),
        claim(RIDER_UID, 'someone.else@example.test')),
    );
  });

  // The document is world-readable, so nothing may be smuggled into it.
  it('refuses any field beyond uid, email and createdAt', async () => {
    await assertFails(setDoc(doc(asRider(env), 'usernames', 'riderone'), {
      ...claim(RIDER_UID, RIDER_EMAIL), fullName: 'Rider One',
    }));
    await assertFails(setDoc(doc(asRider(env), 'usernames', 'riderone'), {
      ...claim(RIDER_UID, RIDER_EMAIL), passwordHash: 'nope',
    }));
  });

  // The id is the lowercased username. Allowing 'RiderOne' as well as
  // 'riderone' would mean two people could hold the same name.
  it('refuses a document id that is not lowercase', async () => {
    await assertFails(
      setDoc(doc(asRider(env), 'usernames', 'RiderOne'),
        claim(RIDER_UID, RIDER_EMAIL)),
    );
  });

  it('refuses ids outside the 3 to 20 character range', async () => {
    await assertFails(
      setDoc(doc(asRider(env), 'usernames', 'ab'), claim(RIDER_UID, RIDER_EMAIL)),
    );
    await assertFails(
      setDoc(doc(asRider(env), 'usernames', 'a'.repeat(21)),
        claim(RIDER_UID, RIDER_EMAIL)),
    );
  });

  it('refuses a client-clock createdAt', async () => {
    await assertFails(setDoc(doc(asRider(env), 'usernames', 'riderone'), {
      uid: RIDER_UID, email: RIDER_EMAIL, createdAt: Timestamp.now(),
    }));
  });

  it('refuses an anonymous claim', async () => {
    await assertFails(
      setDoc(doc(asAnonymous(env), 'usernames', 'riderone'),
        claim(RIDER_UID, RIDER_EMAIL)),
    );
  });

  // Freeing a name would let the next person inherit whatever the last
  // one is remembered by.
  it('refuses release and transfer', async () => {
    await env.withSecurityRulesDisabled((c) => seedRider(c.firestore()));
    await assertFails(deleteDoc(doc(asRider(env), 'usernames', 'riderone')));
    await assertFails(updateDoc(doc(asRider(env), 'usernames', 'riderone'), {
      uid: 'uid-mobile-other',
    }));
  });
});

describe('a mobile account reaches nothing else', () => {
  beforeEach(async () => {
    await env.withSecurityRulesDisabled(async (context) => {
      const db = context.firestore();
      await seedRider(db);
      await setDoc(doc(db, 'riders', 'R-001'), { name: 'Rider One', status: 'idle' });
      await setDoc(doc(db, 'alerts', 'A-open'), {
        riderId: 'R-001', status: 'open', timestamp: Timestamp.now(),
      });
      await setDoc(doc(db, 'devices', 'NR-H1-001'), { alcohol_level: 0 });
    });
  });

  // Opening four paths for the phone app must not have opened a fifth.
  it('cannot read the roster, the alerts or the telemetry', async () => {
    const db = asRider(env);
    await assertFails(getDoc(doc(db, 'riders', 'R-001')));
    await assertFails(getDoc(doc(db, 'alerts', 'A-open')));
    await assertFails(getDoc(doc(db, 'devices', 'NR-H1-001')));
    await assertFails(getDocs(collection(db, 'riders')));
  });

  it('cannot write to them either', async () => {
    const db = asRider(env);
    await assertFails(updateDoc(doc(db, 'riders', 'R-001'), { status: 'emergency' }));
    await assertFails(setDoc(doc(db, 'alerts', 'A-new'), { riderId: 'R-001' }));
  });

  // It may look for its own admins/{uid} and find nothing — that is how
  // the console tells an unprovisioned account apart — but no more.
  it('cannot read an operator record', async () => {
    await assertFails(getDoc(doc(asRider(env), 'admins', 'uid-super-admin')));
    await assertFails(getDocs(collection(asRider(env), 'admins')));
  });
});

// The exact write sequence FirebaseAuthRepository.ensureProfile issues.
//
// The cases above check each path on its own. This one checks the
// combination, because a transaction is all-or-nothing: one illegal
// write in it fails every other write in it too, and the app would show
// a permission-denied for a sign-in that looked entirely reasonable.
describe('the ensureProfile transaction', () => {
  const claimId = 'riderone';

  /// Everything a first sign-up writes, in one transaction.
  const signUpTransaction = (db, uid, email) =>
    runTransaction(db, async (tx) => {
      const userRef = doc(db, 'users', uid);
      const claimRef = doc(db, 'usernames', claimId);
      // Both reads happen first, which is what puts the username in the
      // transaction's read set and makes the claim atomic.
      await tx.get(userRef);
      await tx.get(claimRef);

      tx.set(userRef, {
        email,
        username: 'riderone',
        fullName: 'Rider One',
        role: 'rider',
        createdAt: serverTimestamp(),
        updatedAt: serverTimestamp(),
        lastLoginAt: serverTimestamp(),
      });
      tx.set(doc(db, 'riderProfiles', uid), {
        createdAt: serverTimestamp(),
        updatedAt: serverTimestamp(),
      });
      tx.set(claimRef, { uid, email, createdAt: serverTimestamp() });
    });

  it('is accepted whole on a first sign-up', async () => {
    await assertSucceeds(signUpTransaction(asRider(env), RIDER_UID, RIDER_EMAIL));
  });

  it('is accepted again as a touch once the documents exist', async () => {
    await env.withSecurityRulesDisabled((c) => seedRider(c.firestore()));
    const db = asRider(env);
    await assertSucceeds(
      runTransaction(db, async (tx) => {
        const userRef = doc(db, 'users', RIDER_UID);
        await tx.get(userRef);
        // Three fields and no others. role and createdAt are absent from
        // this map and must stay absent.
        tx.update(userRef, {
          lastLoginAt: serverTimestamp(),
          fcmToken: 'a-push-token',
          updatedAt: serverTimestamp(),
        });
      }),
    );
  });

  // The failure mode worth knowing about: a touch that also rewrote the
  // role would fail, and take the whole sign-in with it.
  it('is refused whole when one write in it is illegal', async () => {
    await env.withSecurityRulesDisabled((c) => seedRider(c.firestore()));
    const db = asRider(env);
    await assertFails(
      runTransaction(db, async (tx) => {
        const userRef = doc(db, 'users', RIDER_UID);
        await tx.get(userRef);
        tx.update(userRef, {
          lastLoginAt: serverTimestamp(),
          updatedAt: serverTimestamp(),
          role: 'guardian',
        });
      }),
    );
  });

  // Two accounts racing for one username: the rules refuse the second
  // write rather than letting it overwrite the first.
  it('refuses a sign-up onto a username another account already holds',
    async () => {
      await assertSucceeds(
        signUpTransaction(asRider(env), RIDER_UID, RIDER_EMAIL),
      );
      await assertFails(
        signUpTransaction(asOtherRider(env), 'uid-mobile-other',
          'other@example.test'),
      );
    });
});
