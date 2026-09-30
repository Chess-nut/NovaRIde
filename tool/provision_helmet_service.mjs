#!/usr/bin/env node
// NovaRide — grant, show or revoke the helmet-service identity: the Firebase
// Auth account the ESP32 firmware signs in as. The security rules know it by
// the custom claim `role: helmetService` and by nothing else. It may create
// alerts/, write devices/ telemetry and set a rider's `status`; it may read
// nothing at all. docs/FIRMWARE_CONTRACT.md is what it may write.
//
//   node provision_helmet_service.mjs <email>              grant the claim
//   node provision_helmet_service.mjs <email> --show
//   node provision_helmet_service.mjs <email> --revoke     claim off, sessions revoked, account disabled
//
// Against the local emulators — no key, nothing leaves the machine:
//
//   node provision_helmet_service.mjs <email> --emulator --create <password>
//   node provision_helmet_service.mjs <email> --emulator [--show | --revoke]
//
// Why not set_admin_claims.mjs, which accepts `helmetService` too: that one
// is written for operators, who are people with an admins/{uid} document to
// keep in step, and it checks nothing about what else the account is. A
// helmet identity needs the opposite. Its password lives in the flash of a
// device that rides around the city, so this script refuses any account
// that would let those credentials do more than write telemetry:
//
//   - an admins/{uid} document. `helmetService` is not a console role, so
//     the rules fall through to that document — a helmet with one would
//     read every rider's live position.
//   - a console role already in its claims. That is an operator's account.
//   - a users/{uid} document. That is a rider's or guardian's phone account,
//     and its owner would be able to forge alerts for any helmet.
//
// It also requires the email/password sign-in the firmware uses, and it can
// target the emulator, which set_admin_claims.mjs deliberately cannot.
//
// ┌──────────────────────────────────────────────────────────────────────┐
// │  KEY SAFETY — the same key, and the same rules, as                   │
// │  set_admin_claims.mjs. It grants FULL ADMIN ACCESS TO THE ENTIRE     │
// │  PROJECT and bypasses every security rule. It lives OUTSIDE the      │
// │  repository, is never shared, never committed. This script refuses   │
// │  a key inside the checkout and a key for any other project.          │
// │  --emulator needs no key at all.                                     │
// └──────────────────────────────────────────────────────────────────────┘
//
// PowerShell (Windows), against the live project:
//
//   cd tool
//   npm i firebase-admin
//   $env:GOOGLE_APPLICATION_CREDENTIALS="$HOME\novaride-admin-key.json"
//   node provision_helmet_service.mjs helmet-nr-h1-001@novaride.invalid
//
// The account itself is created in the Firebase console first (Authentication
// → Users → Add user); live mode never creates accounts and never sees the
// password. The step-by-step is in docs/FIRMWARE_CONTRACT.md §2.
//
// AFTER A GRANT the helmet must SIGN IN AGAIN (or refresh its token). The
// claim travels in the ID token, and a token minted before the grant has no
// claim — every write it makes is permission-denied.

import { readFileSync, existsSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const HELMET_ROLE = 'helmetService';
const CONSOLE_ROLES = ['superAdmin', 'dispatcher', 'viewer', 'administrator', 'admin', 'operator'];

// The rules tests and docs/FIRMWARE_CONTRACT.md start the emulators under
// this id. The `demo-` prefix tells the Firebase tooling the project does
// not exist, so nothing started with it can reach novaride-7a68c.
const EMULATOR_PROJECT = 'demo-novaride';

function usage(message) {
  if (message) console.error(`\n${message}\n`);
  console.error(
    'Usage:\n' +
      '  node provision_helmet_service.mjs <email> [--show | --revoke]\n' +
      '  node provision_helmet_service.mjs <email> --emulator [--show | --revoke | --create <password>]\n' +
      '\nLive mode requires $env:GOOGLE_APPLICATION_CREDENTIALS pointing at a service-account\n' +
      'key kept OUTSIDE the repository. See the header of this file.',
  );
  process.exit(2);
}

// --- arguments ---------------------------------------------------------------

const args = process.argv.slice(2);
const email = args.shift();
if (!email || email.startsWith('--')) usage();
if (!email.includes('@')) usage(`"${email}" does not look like an email address.`);

let emulator = false;
let mode = 'grant';
let password;
while (args.length) {
  const flag = args.shift();
  if (flag === '--emulator') emulator = true;
  else if (flag === '--show' || flag === '--revoke') {
    if (mode !== 'grant') usage('Give one of --show, --revoke or --create, not several.');
    mode = flag.slice(2);
  } else if (flag === '--create') {
    if (mode !== 'grant') usage('Give one of --show, --revoke or --create, not several.');
    mode = 'create';
    password = args.shift();
    if (!password || password.startsWith('--')) usage('--create needs the password to give the account.');
  } else usage(`Unknown argument "${flag}".`);
}
if (mode === 'create' && !emulator) {
  usage(
    '--create is for the emulator only. On the live project, create the account in the\n' +
      'Firebase console (Authentication → Users → Add user) so the password never passes\n' +
      'through a terminal, then run this script without --create.',
  );
}

const here = dirname(fileURLToPath(import.meta.url));
const repoRoot = resolve(here, '..');

// --- target: emulator or live ------------------------------------------------

// The Admin SDK routes to the emulators whenever these variables are set,
// whatever else is configured. A "live" run in a terminal that still has them
// would quietly provision a throwaway emulator account instead.
const emulatorVars = ['FIREBASE_AUTH_EMULATOR_HOST', 'FIRESTORE_EMULATOR_HOST'];
const leftover = emulatorVars.filter((v) => process.env[v]);
if (!emulator && leftover.length) {
  console.error(
    `\nRefusing: ${leftover.join(' and ')} ${leftover.length > 1 ? 'are' : 'is'} set, so this ` +
      'would go to the emulator, not the live project.\n' +
      `Pass --emulator if that is what you meant, or clear ${leftover.length > 1 ? 'them' : 'it'} first:\n` +
      leftover.map((v) => `  Remove-Item Env:${v}`).join('\n'),
  );
  process.exit(3);
}

let projectId;
if (emulator) {
  let ports = {};
  try {
    ports = JSON.parse(readFileSync(resolve(repoRoot, 'firebase.json'), 'utf8')).emulators ?? {};
  } catch {
    /* fall back to the defaults below */
  }
  process.env.FIREBASE_AUTH_EMULATOR_HOST ??= `127.0.0.1:${ports.auth?.port ?? 9099}`;
  process.env.FIRESTORE_EMULATOR_HOST ??= `127.0.0.1:${ports.firestore?.port ?? 8080}`;
  projectId = EMULATOR_PROJECT;
} else {
  projectId = liveProject();
}

// Same guards as set_admin_claims.mjs: a key, outside the checkout, for the
// project .firebaserc targets.
function liveProject() {
  const keyPath = process.env.GOOGLE_APPLICATION_CREDENTIALS;
  if (!keyPath) {
    usage(
      'GOOGLE_APPLICATION_CREDENTIALS is not set. In PowerShell:\n' +
        '  $env:GOOGLE_APPLICATION_CREDENTIALS="$HOME\\novaride-admin-key.json"\n' +
        'Or pass --emulator to work against the local emulators instead.',
    );
  }
  if (!existsSync(keyPath)) usage(`No file at GOOGLE_APPLICATION_CREDENTIALS: ${keyPath}`);

  const key = resolve(keyPath).toLowerCase();
  const root = repoRoot.toLowerCase();
  if (key.startsWith(root + '\\') || key.startsWith(root + '/')) {
    console.error(
      `\nRefusing: the key at ${keyPath} is INSIDE the repository.\n` +
        'Move it outside (e.g. $HOME\\novaride-admin-key.json) and point the variable there.\n' +
        'A key that lives in the checkout is one careless `git add -A` from being public.',
    );
    process.exit(3);
  }

  let keyProject;
  try {
    keyProject = JSON.parse(readFileSync(keyPath, 'utf8')).project_id;
  } catch (error) {
    usage(`Could not read the service-account key: ${error.message}`);
  }

  let repoProject;
  try {
    repoProject = JSON.parse(readFileSync(resolve(repoRoot, '.firebaserc'), 'utf8')).projects?.default;
  } catch {
    /* handled below */
  }
  if (!repoProject) usage('Could not read projects.default from .firebaserc at the repo root.');
  if (keyProject !== repoProject) {
    console.error(
      `\nRefusing: the key belongs to project "${keyProject}" but .firebaserc targets "${repoProject}".\n` +
        'Use a key generated from the project this checkout points at.',
    );
    process.exit(3);
  }
  return repoProject;
}

// --- the work ------------------------------------------------------------------

const { initializeApp, applicationDefault } = await import('firebase-admin/app');
const { getAuth } = await import('firebase-admin/auth');
const { getFirestore } = await import('firebase-admin/firestore');

initializeApp(emulator ? { projectId } : { credential: applicationDefault(), projectId });
const auth = getAuth();
const db = getFirestore();
const where = emulator ? `the emulator (${projectId})` : projectId;

try {
  await run();
} catch (error) {
  if (emulator && /ECONNREFUSED|fetch failed|UNAVAILABLE/i.test(`${error.code} ${error.message}`)) {
    console.error(
      '\nThe emulators are not answering. Start them from the repository root first:\n' +
        `  firebase emulators:start --only auth,firestore --project ${EMULATOR_PROJECT}\n` +
        'See docs/FIRMWARE_CONTRACT.md §1.',
    );
    process.exit(1);
  }
  throw error;
}

async function run() {
  if (mode === 'create') await createOrReset();

  let user;
  try {
    user = await auth.getUserByEmail(email);
  } catch (error) {
    if (error.code === 'auth/user-not-found') {
      console.error(`\nNo Firebase Auth account for ${email} in ${where}.`);
      console.error(
        emulator
          ? 'Create it with --create <password>, or in the Emulator UI (http://localhost:4000/auth).'
          : 'Create it under Authentication → Users → Add user first; live mode never creates accounts.',
      );
      process.exit(1);
    }
    throw error;
  }

  const claims = user.customClaims ?? {};

  if (mode === 'show') {
    const [admin, profile] = await Promise.all([
      db.doc(`admins/${user.uid}`).get(),
      db.doc(`users/${user.uid}`).get(),
    ]);
    console.log(`${email}  uid=${user.uid}  ${where}`);
    console.log(`  role claim     : ${claims.role ?? '(none)'}`);
    console.log(`  password login : ${hasPassword(user) ? 'yes' : 'NO — the firmware cannot sign in'}`);
    console.log(`  disabled       : ${user.disabled ? 'YES' : 'no'}`);
    console.log(`  admins/${user.uid}: ${admin.exists ? 'EXISTS — must not, for a helmet' : 'none (correct)'}`);
    console.log(`  users/${user.uid} : ${profile.exists ? 'EXISTS — must not, for a helmet' : 'none (correct)'}`);
    process.exit(0);
  }

  if (mode === 'revoke') {
    const { role: _dropped, ...rest } = claims;
    await auth.setCustomUserClaims(user.uid, Object.keys(rest).length ? rest : null);
    await auth.revokeRefreshTokens(user.uid);
    await auth.updateUser(user.uid, { disabled: true });
    console.log(`Revoked ${email} (role was ${claims.role ?? 'none'}): claim removed, refresh tokens revoked, account disabled.`);
    console.log(
      '\nAn ID token the helmet already holds stays valid for Firestore until it expires —\n' +
        'up to one hour. Change the password before you enable the account again, then\n' +
        're-grant with this script.',
    );
    process.exit(0);
  }

  // grant (and the tail of create)
  const [admin, profile] = await Promise.all([
    db.doc(`admins/${user.uid}`).get(),
    db.doc(`users/${user.uid}`).get(),
  ]);
  refuseUnlessDedicated(user, claims, admin, profile);

  // setCustomUserClaims REPLACES the whole claims object, so carry over
  // anything that is not ours.
  await auth.setCustomUserClaims(user.uid, { ...claims, role: HELMET_ROLE });
  console.log(`Set role=${HELMET_ROLE} on ${email} (uid ${user.uid}) in ${where} (was ${claims.role ?? 'none'}).`);
  const others = Object.keys(claims).filter((k) => k !== 'role');
  if (others.length) console.log(`  Kept other claims: ${others.join(', ')}`);
  if (user.disabled) {
    console.log('\nThe account is DISABLED, so the helmet cannot sign in. Enable it in the console once its password is one you trust.');
  }
  console.log('\nThe helmet must SIGN IN AGAIN (or refresh its token) before its writes are allowed.');
}

async function createOrReset() {
  try {
    const existing = await auth.getUserByEmail(email);
    await auth.updateUser(existing.uid, { password, disabled: false });
    console.log(`${email} already exists in ${where}; password reset and account enabled.`);
  } catch (error) {
    if (error.code !== 'auth/user-not-found') throw error;
    const created = await auth.createUser({ email, password });
    console.log(`Created ${email} (uid ${created.uid}) in ${where}.`);
  }
}

function hasPassword(user) {
  return user.providerData.some((p) => p.providerId === 'password');
}

function refuseUnlessDedicated(user, claims, admin, profile) {
  const problems = [];
  if (admin.exists) {
    problems.push(
      `admins/${user.uid} exists (role "${admin.get('role')}"). The rules would read it, because\n` +
        `    ${HELMET_ROLE} is not a console role, and the helmet would get an operator's reads.`,
    );
  }
  if (CONSOLE_ROLES.includes(claims.role)) {
    problems.push(`its role claim is "${claims.role}" — this is an operator's account.`);
  }
  if (profile.exists) {
    problems.push(
      `users/${user.uid} exists — this is a phone-app account, and its owner could\n` +
        '    then forge alerts and telemetry for any helmet.',
    );
  }
  if (!hasPassword(user)) {
    problems.push('it has no email/password sign-in, which is the only way the firmware signs in.');
  }
  if (!problems.length) return;

  console.error(`\nRefusing to make ${email} a helmet identity:\n`);
  for (const p of problems) console.error(`  - ${p}`);
  console.error('\nUse a dedicated account that exists for the helmet and nothing else.');
  process.exit(3);
}
