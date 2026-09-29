// The catch-all. Everything without a rule of its own is denied to
// everybody, and that includes the collections the mobile auth work is
// about to introduce. These tests are deliberately written to FAIL-to-write
// today: when a phase opens one of these paths, the matching case here is
// the thing that must be rewritten, so no collection can quietly become
// readable without someone editing this file.

import { after, before, beforeEach, describe, it } from 'node:test';
import { assertFails } from '@firebase/rules-unit-testing';
import { doc, getDoc, setDoc } from 'firebase/firestore';
import {
  asAnonymous, asSuperAdmin, asUnprovisioned, newTestEnv, reset, SUPER_ADMIN,
} from './helpers.js';

// The Option A collections, plus the one the schema doc reserves.
const closedPaths = [
  ['users', 'some-uid'],
  ['riderProfiles', 'some-uid'],
  ['guardianProfiles', 'some-uid'],
  ['usernames', 'somerider'],
  ['emergencyContacts', 'some-id'],
  ['anythingElse', 'some-id'],
];

let env;
before(async () => { env = await newTestEnv(); });
after(async () => { await env.cleanup(); });
beforeEach(async () => { await reset(env); });

describe('paths with no rule of their own', () => {
  for (const [collectionName, id] of closedPaths) {
    it(`denies ${collectionName}/ to every principal`, async () => {
      for (const db of [asSuperAdmin(env), asUnprovisioned(env), asAnonymous(env)]) {
        await assertFails(getDoc(doc(db, collectionName, id)));
        await assertFails(setDoc(doc(db, collectionName, id), { x: 1 }));
      }
    });
  }

  // A rider signing in on the mobile app lands here until Phase 1 opens
  // users/{uid}. Worth naming explicitly: it is the first permission-denied
  // anyone will hit, and it is correct.
  it('denies a signed-in rider their own users/{uid} document', async () => {
    await assertFails(getDoc(doc(asUnprovisioned(env), 'users', 'uid-no-admin-doc')));
  });

  it('denies a Super Admin a path that merely looks official', async () => {
    await assertFails(getDoc(doc(asSuperAdmin(env), 'admin', SUPER_ADMIN)));
    await assertFails(getDoc(doc(asSuperAdmin(env), 'alert', 'alerttest')));
    await assertFails(getDoc(doc(asSuperAdmin(env), 'rider', 'ridertest')));
  });
});
