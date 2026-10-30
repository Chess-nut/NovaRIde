# Security-rules tests

Security-rules tests over `firestore.rules`, run against the Firestore emulator.

```bash
cd rules_test
npm install     # once
npm test        # starts the emulator, runs the tests, shuts it down
```

The first run downloads the emulator jar (~60 MB) and needs a JDK on the
PATH — Temurin 21 is what this machine has. Nothing else touches the
network: the project id is `demo-novaride`, and the `demo-` prefix is what
tells the Firebase tooling the project does not exist, so no credentials are
read and a stray call can never reach `novaride-7a68c`.

`npm run emulators` starts the emulator and leaves it up, with the UI on
<http://localhost:4000>, for poking at rules by hand.

## What is covered

| File | Subject |
|---|---|
| `roles.test.js` | `role()` — claim first, then `admins/{uid}`, with the `administrator`/`operator` aliases, and the four ways to be nobody |
| `riders.test.js` | Super Admin writes; the dispatcher's and the helmet's `status`-only exceptions; no deletes |
| `devices.test.js` | firmware writes readings, console writes only `assigned_rider_id` and `paired_at` |
| `alerts.test.js` | who creates; what a helmet alert must carry (server-clock `timestamp`, fixed `type`/`severity`, well-formed position); the linear lifecycle; server-clock stamps |
| `history.test.js` | append-only; required fields; the `collectionGroup('history')` read |
| `admins.test.js` | own-document reads, Super Admin lists, no client writes at all |
| `accounts.test.js` | the phone app's four collections: who may create, read and update `users/`, `riderProfiles/`, `guardianProfiles/`, and how a `usernames/` claim works |
| `families.test.js` | owner/member setup and migration, invitation acceptance/replay/email/expiry, membership changes, and family permission gates for riders/devices/alerts/history |
| `closed.test.js` | the catch-all: every path without a rule is denied to everyone |
| `firmware_contract.test.js` | the JSON bodies in `docs/FIRMWARE_CONTRACT.md`, sent verbatim over REST as the helmet — the doc and the rules cannot drift apart |
| `payload_contract.test.js` | the payloads the **Dart app actually sends**, replayed against the real ruleset — see below |

`closed.test.js` is the one to watch. It asserts that every path without a
rule of its own is denied to everybody — today `emergencyContacts/`,
`riderLinks/` (superseded by family members) and anything unnamed. When a phase opens one, the matching
case there is what has to be rewritten, so no collection can quietly
become readable without someone editing that file on purpose. Phase 3 is
what that looks like in practice: it moved `users/`, `riderProfiles/`,
`guardianProfiles/` and `usernames/` out of that list and into
`accounts.test.js`, where what each one permits is spelled out.


## The payload contract

Every test here except one uses a fixture typed in JavaScript. That
proves the rules are right about *a* payload — not about the one
`FirebaseAuthRepository` sends. A field the app omits and the rules
require passes all of them and fails at sign-up, on a phone.

So `payload_contract.test.js` does not invent its payloads. It reads
`fixtures/auth_payloads.json`, which is written by

```bash
flutter test test/auth_payload_contract_test.dart
```

straight out of the production builders on `FirebaseAuthRepository`
(`buildUserDocument`, `buildProfileDocument`, `buildUsernameClaim`,
`buildLoginTouch`) — the same functions `ensureProfile` calls. Server
timestamps travel as the marker `__SERVER_TIMESTAMP__` and become real
ones on this side, which is the only reason the payloads can be built
outside a Firebase app.

The approved family rules additionally require a rider's `familyId` and
the owner family/member records in that same transaction. The Node test
adds those schema records around the exported payload and separately asserts
that the current payload without `familyId` is refused; the Dart app-side
change is intentionally outside this rules-only update.

**Run `flutter test` before `npm test`.** The fixture is committed, so a
change to the payload is visible in review as a change to that JSON, and
the Node side refuses to run at all if the file is missing.

It is checked both ways: one case asserts the real payload is accepted,
another asserts the same payload *without* `fullName` is refused — so a
rule that quietly stopped checking anything would not leave the suite
green.

## Writing a test

`helpers.js` exports one Firestore per principal — `asSuperAdmin(env)`,
`asDispatcher(env)`, `asViewer(env)`, `asHelmetService(env)`,
`asUnprovisioned(env)`, `asAnonymous(env)`, two claim-carrying ones, and
the phone app's `asRider(env)`, `asGuardian(env)` and `asOtherRider(env)`,
which carry an email on the ID token because the account rules check it —
plus `reset(env, seed)`, which clears the database and re-seeds `admins/`
with rules disabled. Fixture data a test needs to read or update goes in
that `seed` callback; anything a test asserts about goes through
`assertSucceeds` / `assertFails`.

The rules are read from `../firestore.rules` on every run, so a rule that is
edited but not re-read cannot pass a stale test.

## Against the real project

These tests never touch it. Deploying is a separate, manual step, and the
tests are what should pass first:

```bash
firebase deploy --only firestore:rules
firebase deploy --only firestore:indexes
```
