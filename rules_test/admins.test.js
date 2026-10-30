// admins/{uid} — provisioning. Nothing writes here from a client: a
// compromised operator session must not be able to mint an operator.

import { after, before, beforeEach, describe, it } from 'node:test';
import { assertFails } from '@firebase/rules-unit-testing';
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
  it('denies document reads to all client principals', async () => {
    await assertFails(getDoc(doc(asDispatcher(env), 'admins', VIEWER)));
    await assertFails(getDoc(doc(asViewer(env), 'admins', DISPATCHER)));
    await assertFails(getDoc(doc(asSuperAdmin(env), 'admins', DISPATCHER)));
    await assertFails(getDoc(doc(asUnprovisioned(env), 'admins', UNPROVISIONED)));
    await assertFails(getDoc(doc(asAnonymous(env), 'admins', SUPER_ADMIN)));
  });

  it('denies collection listing to every client principal', async () => {
    await assertFails(getDocs(collection(asSuperAdmin(env), 'admins')));
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
});
