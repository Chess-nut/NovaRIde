// The catch-all. Everything without a rule of its own is denied to
// everybody.
//
// **Phase 3 rewrote this file.** It used to assert that users/,
// riderProfiles/, guardianProfiles/ and usernames/ were closed, with a
// note saying whichever phase opened one had to come here and change it
// on purpose. Phase 3 is that phase, so those four moved out — their real
// permissions are pinned down in accounts.test.js — and what is left is
// the paths that genuinely have no rule.
//
// The discipline is the point, not this particular list: a collection
// should never become readable without someone editing a test that says
// it was not.

import { after, before, beforeEach, describe, it } from 'node:test';
import { assertFails } from '@firebase/rules-unit-testing';
import { doc, getDoc, setDoc } from 'firebase/firestore';
import {
  asAnonymous, asSuperAdmin, asUnprovisioned, newTestEnv, reset, SUPER_ADMIN,
} from './helpers.js';

const closedPaths = [
  // Reserved in docs/FIRESTORE_SCHEMA.md §2 and still unbuilt. The rider
  // app's emergency contacts live on riderProfiles/ for now.
  ['emergencyContacts', 'some-id'],
  // The guardian-to-rider link Phase 7 will need. Named here so the day
  // it is added, this line is what has to change.
  ['riderLinks', 'some-id'],
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

  it('denies a Super Admin a path that merely looks official', async () => {
    await assertFails(getDoc(doc(asSuperAdmin(env), 'admin', SUPER_ADMIN)));
    await assertFails(getDoc(doc(asSuperAdmin(env), 'alert', 'alerttest')));
    await assertFails(getDoc(doc(asSuperAdmin(env), 'rider', 'ridertest')));
  });

  // The four paths Phase 3 opened are open to their owner and to nobody
  // else. The operator console has no code that reads them and no reason
  // to, so a Super Admin is refused exactly like anyone else — which is
  // worth asserting here rather than only in accounts.test.js, because
  // this is the file people read to find out what is closed.
  it('still denies an operator another account holder\'s documents', async () => {
    for (const path of ['users', 'riderProfiles', 'guardianProfiles']) {
      await assertFails(getDoc(doc(asSuperAdmin(env), path, 'uid-someone-else')));
      await assertFails(setDoc(doc(asSuperAdmin(env), path, 'uid-someone-else'), { x: 1 }));
    }
  });
});
