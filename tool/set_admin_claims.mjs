#!/usr/bin/env node
// NovaRide — set, show or clear the `role` custom claim on a Firebase Auth
// account. OPTIONAL for now: the console and the security rules both fall
// back to admins/{uid}.role when no claim is set, and that is how all three
// operator accounts resolve today. Set a claim when you want the role to
// travel in the ID token itself, which saves the rules one document read per
// request and survives the admins/ document being edited by mistake.
//
//   node set_admin_claims.mjs <email> <superAdmin|dispatcher|viewer|helmetService>
//   node set_admin_claims.mjs <email> --show
//   node set_admin_claims.mjs <email> --clear
//
// Role values are the AdminRole enum names verbatim. The aliases the console
// tolerates on read (administrator, admin, operator) are refused here: they
// are never written. `helmetService` is the ESP32 firmware's identity, not a
// console role — the console rejects it as unprovisioned.
//
// ┌──────────────────────────────────────────────────────────────────────┐
// │  KEY SAFETY — READ BEFORE RUNNING                                    │
// │                                                                      │
// │  This script authenticates with a service-account key. That key     │
// │  grants FULL ADMIN ACCESS TO THE ENTIRE FIREBASE PROJECT and         │
// │  BYPASSES EVERY SECURITY RULE — it can read every rider's live       │
// │  position, rewrite the audit trail and delete the database. It      │
// │  lives OUTSIDE the repository (for example $HOME\novaride-admin-     │
// │  key.json), is never shared, never committed, never pasted into a    │
// │  chat or an issue. The .gitignore patterns for *-key.json and        │
// │  friends are a backstop, not the safeguard. If a key is ever         │
// │  exposed, revoke it in Google Cloud → IAM → Service Accounts first   │
// │  and ask questions afterwards.                                       │
// └──────────────────────────────────────────────────────────────────────┘
//
// PowerShell (Windows) — the shell this project is developed in:
//
//   cd tool
//   npm i firebase-admin
//   $env:GOOGLE_APPLICATION_CREDENTIALS="$HOME\novaride-admin-key.json"
//   node set_admin_claims.mjs qrlunatal@tip.edu.ph superAdmin
//
// (bash-style `VAR=x node script.mjs` does not work in PowerShell; the
// $env: assignment above lasts for the rest of that terminal session.)
//
// Where the key comes from: Firebase console → Project settings → Service
// accounts → "Generate new private key". Save it outside the repo.
//
// AFTER A CHANGE the operator must SIGN OUT AND BACK IN. Claims travel in
// the ID token, which is minted at sign-in and refreshed roughly hourly; a
// session that is already open keeps its old token until then.

import { readFileSync, existsSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const ROLES = ['superAdmin', 'dispatcher', 'viewer', 'helmetService'];
const REFUSED_ALIASES = ['administrator', 'admin', 'operator'];

function usage(message) {
  if (message) console.error(`\n${message}\n`);
  console.error(
    'Usage:\n' +
      '  node set_admin_claims.mjs <email> <role>     role: ' + ROLES.join(' | ') + '\n' +
      '  node set_admin_claims.mjs <email> --show\n' +
      '  node set_admin_claims.mjs <email> --clear\n' +
      '\nRequires $env:GOOGLE_APPLICATION_CREDENTIALS pointing at a service-account key\n' +
      'kept OUTSIDE the repository. See the header of this file.',
  );
  process.exit(2);
}

const [email, action] = process.argv.slice(2);
if (!email || !action) usage();
if (!email.includes('@')) usage(`"${email}" does not look like an email address.`);

const mode = action === '--show' ? 'show' : action === '--clear' ? 'clear' : 'set';
if (mode === 'set') {
  if (REFUSED_ALIASES.includes(action)) {
    usage(
      `"${action}" is a read-side alias, not a role. The console tolerates it when ` +
        `found, but it is never written. Use one of: ${ROLES.join(', ')}.`,
    );
  }
  if (!ROLES.includes(action)) usage(`Unknown role "${action}". Use one of: ${ROLES.join(', ')}.`);
}

// --- key and project guard ---------------------------------------------------

const keyPath = process.env.GOOGLE_APPLICATION_CREDENTIALS;
if (!keyPath) {
  usage(
    'GOOGLE_APPLICATION_CREDENTIALS is not set. In PowerShell:\n' +
      '  $env:GOOGLE_APPLICATION_CREDENTIALS="$HOME\\novaride-admin-key.json"',
  );
}
if (!existsSync(keyPath)) usage(`No file at GOOGLE_APPLICATION_CREDENTIALS: ${keyPath}`);

const here = dirname(fileURLToPath(import.meta.url));
const repoRoot = resolve(here, '..');
if (resolve(keyPath).toLowerCase().startsWith(repoRoot.toLowerCase() + '\\') ||
    resolve(keyPath).toLowerCase().startsWith(repoRoot.toLowerCase() + '/')) {
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

// The repo's Firebase CLI alias is the source of truth for which project this
// checkout targets. A key for a different project — say, the abandoned
// novaride-266bc — must not be able to touch it by accident.
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

// --- the work ------------------------------------------------------------------

const { initializeApp, applicationDefault } = await import('firebase-admin/app');
const { getAuth } = await import('firebase-admin/auth');

initializeApp({ credential: applicationDefault(), projectId: repoProject });
const auth = getAuth();

let user;
try {
  user = await auth.getUserByEmail(email);
} catch (error) {
  if (error.code === 'auth/user-not-found') {
    console.error(`\nNo Firebase Auth account for ${email} in ${repoProject}.`);
    console.error('Create it under Authentication → Users first; this script never creates accounts.');
    process.exit(1);
  }
  throw error;
}

const existing = user.customClaims ?? {};
const current = existing.role;

if (mode === 'show') {
  console.log(`${email}  uid=${user.uid}  project=${repoProject}`);
  console.log(`  role claim : ${current ?? '(none — the console falls back to admins/' + user.uid + ')'}`);
  const others = Object.keys(existing).filter((k) => k !== 'role');
  if (others.length) console.log(`  other claims: ${others.join(', ')}`);
  process.exit(0);
}

// setCustomUserClaims REPLACES the whole claims object, so carry over anything
// that is not ours.
const { role: _dropped, ...rest } = existing;
const next = mode === 'clear' ? rest : { ...rest, role: action };

await auth.setCustomUserClaims(user.uid, Object.keys(next).length ? next : null);

if (mode === 'clear') {
  console.log(`Cleared the role claim on ${email} (was ${current ?? 'none'}).`);
  console.log(`The console now resolves this account from admins/${user.uid}.`);
} else {
  console.log(`Set role=${action} on ${email} (was ${current ?? 'none'}).`);
}
console.log('\nThe operator must SIGN OUT AND BACK IN before the change takes effect.');
if (mode === 'set' && action !== 'helmetService') {
  console.log(`Keep admins/${user.uid}.role in step with the claim; the claim wins when both exist.`);
}
