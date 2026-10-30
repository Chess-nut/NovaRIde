// riders/{riderId} — console-owned roster. Read by every operator, written
// by Super Admins, with two narrow exceptions on `status`.

import { after, before, beforeEach, describe, it } from 'node:test';
import { assertFails, assertSucceeds } from '@firebase/rules-unit-testing';
import { deleteDoc, doc, setDoc, updateDoc } from 'firebase/firestore';
import {
  asDispatcher, asHelmetService, asSuperAdmin, asViewer, newTestEnv, reset,
} from './helpers.js';

let env;
before(async () => { env = await newTestEnv(); });
after(async () => { await env.cleanup(); });
beforeEach(async () => {
  await reset(env, async (db) => {
    await setDoc(doc(db, 'riders', 'R-001'), {
      name: 'Rider One', phone: '+639170000001', helmetId: 'NR-H1-001', status: 'idle',
    });
  });
});

describe('riders/', () => {
  it('lets a Super Admin create a rider', async () => {
    await assertSucceeds(
      setDoc(doc(asSuperAdmin(env), 'riders', 'R-002'), { name: 'Rider Two', status: 'idle' }),
    );
  });

  it('refuses a rider created by a dispatcher or a viewer', async () => {
    await assertFails(setDoc(doc(asDispatcher(env), 'riders', 'R-003'), { name: 'X' }));
    await assertFails(setDoc(doc(asViewer(env), 'riders', 'R-004'), { name: 'X' }));
  });

  it('lets a Super Admin edit any field', async () => {
    await assertSucceeds(
      updateDoc(doc(asSuperAdmin(env), 'riders', 'R-001'), { phone: '+639170000099' }),
    );
  });

  it('lets a dispatcher change only status', async () => {
    await assertSucceeds(updateDoc(doc(asDispatcher(env), 'riders', 'R-001'), { status: 'idle' }));
    await assertFails(updateDoc(doc(asDispatcher(env), 'riders', 'R-001'), { name: 'Renamed' }));
    await assertFails(
      updateDoc(doc(asDispatcher(env), 'riders', 'R-001'), { status: 'idle', name: 'Renamed' }),
    );
  });

  // The firmware contract in FIRESTORE_SCHEMA.md §2: whoever raises a crash
  // or sos also flips the rider to emergency.
  it('lets the helmet service set status and nothing else', async () => {
    await assertSucceeds(
      updateDoc(doc(asHelmetService(env), 'riders', 'R-001'), { status: 'emergency' }),
    );
    await assertFails(
      updateDoc(doc(asHelmetService(env), 'riders', 'R-001'), { helmetId: 'NR-H1-999' }),
    );
  });

  it('refuses an edit by a viewer', async () => {
    await assertFails(updateDoc(doc(asViewer(env), 'riders', 'R-001'), { status: 'idle' }));
  });

  // Alert history references riders; deactivate instead.
  it('refuses deletion by anyone', async () => {
    await assertFails(deleteDoc(doc(asSuperAdmin(env), 'riders', 'R-001')));
    await assertFails(deleteDoc(doc(asHelmetService(env), 'riders', 'R-001')));
  });
});
