// Shared setup for the firestore.rules tests.
//
// Everything runs against the Firestore emulator under the project id
// `demo-novaride`. The `demo-` prefix is what tells the Firebase tooling the
// project does not exist: no credentials are read, and a stray call can never
// reach novaride-7a68c. The rules under test are the repository's own
// firestore.rules, read from disk on every run, so a rule that is edited but
// not re-read cannot pass a stale test.

import { readFileSync } from 'node:fs';
import { initializeTestEnvironment } from '@firebase/rules-unit-testing';
import { doc, setDoc, setLogLevel } from 'firebase/firestore';

// Half of these tests assert a denial, and the SDK logs a PERMISSION_DENIED
// stack for each one. Silence it: the test names say what is expected, and
// a real failure is reported by the assertion, not by this log.
setLogLevel('silent');

export const PROJECT_ID = 'demo-novaride';

// Operators resolve their role through admins/{uid} today (no custom claims
// are set on the real project), so most contexts below carry no claim and
// rely on the seeded document. The claim-carrying ones exist to prove the
// other half of `role()`.
export const SUPER_ADMIN = 'uid-super-admin';
export const DISPATCHER = 'uid-dispatcher';
export const VIEWER = 'uid-viewer';
export const ALIAS_ADMIN = 'uid-alias-administrator';
export const ALIAS_OPERATOR = 'uid-alias-operator';
export const UNPROVISIONED = 'uid-no-admin-doc';

export async function newTestEnv() {
  return initializeTestEnvironment({
    projectId: PROJECT_ID,
    firestore: { rules: readFileSync('firestore.rules', 'utf8') },
  });
}

/// Wipes the database and re-seeds the provisioning documents plus whatever
/// fixture data a test needs to update or read. Runs with rules disabled —
/// nothing here is under test; it is the world the rules are evaluated
/// against.
export async function reset(env, seed) {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await setDoc(doc(db, 'admins', SUPER_ADMIN), {
      name: 'Super Admin',
      email: 'super@example.test',
      role: 'superAdmin',
    });
    await setDoc(doc(db, 'admins', DISPATCHER), {
      name: 'Dispatcher',
      email: 'dispatch@example.test',
      role: 'dispatcher',
    });
    await setDoc(doc(db, 'admins', VIEWER), {
      name: 'Viewer',
      email: 'viewer@example.test',
      role: 'viewer',
    });
    // Alias tolerance: a document written by hand with the wrong spelling
    // must degrade to the intended role, not lock the operator out.
    await setDoc(doc(db, 'admins', ALIAS_ADMIN), { role: 'administrator' });
    await setDoc(doc(db, 'admins', ALIAS_OPERATOR), { role: 'operator' });
    if (seed) await seed(db);
  });
}

// The principals. `db(...)` returns a Firestore bound to that identity.
export const asSuperAdmin = (env) => env.authenticatedContext(SUPER_ADMIN).firestore();
export const asDispatcher = (env) => env.authenticatedContext(DISPATCHER).firestore();
export const asViewer = (env) => env.authenticatedContext(VIEWER).firestore();
export const asAliasAdmin = (env) => env.authenticatedContext(ALIAS_ADMIN).firestore();
export const asAliasOperator = (env) => env.authenticatedContext(ALIAS_OPERATOR).firestore();

/// Signed in, but no admins/{uid} document and no claim — a rider account
/// once the mobile app authenticates. Every console path must refuse it.
export const asUnprovisioned = (env) => env.authenticatedContext(UNPROVISIONED).firestore();

/// The role in the ID token, with no admins/{uid} document behind it: the
/// state the project moves to after tool/set_admin_claims.mjs runs.
export const asClaimSuperAdmin = (env) =>
  env.authenticatedContext('uid-claim-super', { role: 'superAdmin' }).firestore();

/// A claim the rules do not recognise. `role()` must fall through to the
/// document, which for this uid does not exist — so: not an operator.
export const asBogusClaim = (env) =>
  env.authenticatedContext('uid-claim-bogus', { role: 'wizard' }).firestore();

/// The ESP32 identity reserved by the rules. Never a console role.
export const asHelmetService = (env) =>
  env.authenticatedContext('uid-helmet', { role: 'helmetService' }).firestore();

export const asAnonymous = (env) => env.unauthenticatedContext().firestore();

// ---------------------------------------------------- mobile accounts

/// A rider and a guardian of the phone app. No claim, no admins/{uid}
/// document — an account is whoever its uid says it is.
///
/// The email matters: the rules check the document's `email` against the
/// one on the ID token, so a test that writes a different address is
/// testing the rejection path, not the happy one.
export const RIDER_UID = 'uid-mobile-rider';
export const RIDER_EMAIL = 'rider@example.test';
export const GUARDIAN_UID = 'uid-mobile-guardian';
export const GUARDIAN_EMAIL = 'guardian@example.test';

export const asRider = (env) =>
  env.authenticatedContext(RIDER_UID, { email: RIDER_EMAIL }).firestore();

export const asGuardian = (env) =>
  env.authenticatedContext(GUARDIAN_UID, { email: GUARDIAN_EMAIL }).firestore();

/// A second rider, for "someone else's document" cases.
export const OTHER_UID = 'uid-mobile-other';
export const asOtherRider = (env) =>
  env.authenticatedContext(OTHER_UID, { email: 'other@example.test' }).firestore();
