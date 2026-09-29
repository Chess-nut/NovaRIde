// Role resolution: claim first, then admins/{uid}, with alias tolerance.
// These tests pin the half of the rules that every other file depends on.

import { after, before, beforeEach, describe, it } from 'node:test';
import { assertFails, assertSucceeds } from '@firebase/rules-unit-testing';
import { doc, getDoc, setDoc } from 'firebase/firestore';
import {
  asAliasAdmin, asAliasOperator, asAnonymous, asBogusClaim, asClaimSuperAdmin,
  asDispatcher, asHelmetService, asSuperAdmin, asUnprovisioned, asViewer,
  newTestEnv, reset,
} from './helpers.js';

let env;
before(async () => { env = await newTestEnv(); });
after(async () => { await env.cleanup(); });
beforeEach(async () => {
  await reset(env, async (db) => {
    await setDoc(doc(db, 'riders', 'R-001'), { name: 'Rider One', status: 'idle' });
  });
});

// riders/ read is `isOperator()` and nothing else, so it is the cheapest
// probe for "did this principal resolve to a console role".
const canRead = (db) => getDoc(doc(db, 'riders', 'R-001'));

describe('role resolution', () => {
  it('resolves a role from admins/{uid} when no claim is set', async () => {
    await assertSucceeds(canRead(asSuperAdmin(env)));
    await assertSucceeds(canRead(asDispatcher(env)));
    await assertSucceeds(canRead(asViewer(env)));
  });

  it('resolves a role from the ID token without an admins document', async () => {
    await assertSucceeds(canRead(asClaimSuperAdmin(env)));
  });

  it('reads administrator and operator as their canonical roles', async () => {
    await assertSucceeds(canRead(asAliasAdmin(env)));
    await assertSucceeds(canRead(asAliasOperator(env)));
  });

  it('refuses a signed-in user with neither claim nor admins document', async () => {
    await assertFails(canRead(asUnprovisioned(env)));
  });

  it('refuses an unrecognised claim that has no document behind it', async () => {
    await assertFails(canRead(asBogusClaim(env)));
  });

  it('refuses an anonymous caller', async () => {
    await assertFails(canRead(asAnonymous(env)));
  });

  it('refuses the helmet service, which is not a console role', async () => {
    await assertFails(canRead(asHelmetService(env)));
  });
});
