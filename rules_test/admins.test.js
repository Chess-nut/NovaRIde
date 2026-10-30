// admins/{uid} — provisioning. Nothing writes here from a client: a
// compromised operator session must not be able to mint an operator.

import { after, before, beforeEach, describe, it } from 'node:test';
import { assertFails, assertSucceeds } from '@firebase/rules-unit-testing';
import { collection, deleteDoc, doc, getDoc, getDocs, setDoc, updateDoc } from 'firebase/firestore';
import {
  asAnonymous, asDispatcher, asSuperAdmin, asUnprovisioned, asViewer,
  DISPATCHER, newTestEnv, reset, SUPER_ADMIN, UNPROVISIONED, VIEWER,
} from './helpers.js';

let env;
before(async () => { env = await newTestEnv(); });
after(async () => { await env.cleanup(); });
beforeEach(async () => { await reset(env); });

describe('admins/', () => {
  // This is the read sign-in depends on, before any claim exists.
  it('lets an operator read their own document', async () => {
    await assertSucceeds(getDoc(doc(asDispatcher(env), 'admins', DISPATCHER)));
    await assertSucceeds(getDoc(doc(asViewer(env), 'admins', VIEWER)));
  });

  // A signed-in rider resolving to nothing: the get is allowed because the
  // uid matches, and returns a document that does not exist. That is how the
  // console learns the account is unprovisioned.
  it('lets any signed-in user look for their own document', async () => {
    await assertSucceeds(getDoc(doc(asUnprovisioned(env), 'admins', UNPROVISIONED)));
  });

  it('refuses one operator reading another', async () => {
    await assertFails(getDoc(doc(asDispatcher(env), 'admins', VIEWER)));
    await assertFails(getDoc(doc(asViewer(env), 'admins', DISPATCHER)));
  });

  it('lets a Super Admin read and list them all', async () => {
    await assertSucceeds(getDoc(doc(asSuperAdmin(env), 'admins', DISPATCHER)));
    await assertSucceeds(getDocs(collection(asSuperAdmin(env), 'admins')));
  });

  it('refuses the list to a dispatcher, a viewer and an anonymous caller', async () => {
    await assertFails(getDocs(collection(asDispatcher(env), 'admins')));
    await assertFails(getDocs(collection(asViewer(env), 'admins')));
    await assertFails(getDocs(collection(asAnonymous(env), 'admins')));
  });

  it('refuses every client write, including a Super Admin promoting someone', async () => {
    const db = asSuperAdmin(env);
    await assertFails(setDoc(doc(db, 'admins', 'uid-new'), { role: 'superAdmin' }));
    await assertFails(updateDoc(doc(db, 'admins', VIEWER), { role: 'superAdmin' }));
    await assertFails(deleteDoc(doc(db, 'admins', VIEWER)));
    await assertFails(
      updateDoc(doc(asDispatcher(env), 'admins', DISPATCHER), { role: 'superAdmin' }),
    );
  });

  it('refuses an anonymous read of a known operator', async () => {
    await assertFails(getDoc(doc(asAnonymous(env), 'admins', SUPER_ADMIN)));
  });
});
