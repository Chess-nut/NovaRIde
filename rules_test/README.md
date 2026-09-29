# Security-rules tests

56 tests over `firestore.rules`, run against the Firestore emulator.

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
| `alerts.test.js` | who creates; the linear lifecycle; server-clock stamps |
| `history.test.js` | append-only; required fields; the `collectionGroup('history')` read |
| `admins.test.js` | own-document reads, Super Admin lists, no client writes at all |
| `closed.test.js` | the catch-all: every path without a rule is denied to everyone |

`closed.test.js` is the one to watch. It asserts that `users/`,
`riderProfiles/`, `guardianProfiles/` and `usernames/` are closed **today**,
which they must be until the mobile auth work opens them. When a phase adds
a rule for one of those, the matching case there is what has to be rewritten
— so no collection can quietly become readable without someone editing that
file on purpose.

## Writing a test

`helpers.js` exports one Firestore per principal — `asSuperAdmin(env)`,
`asDispatcher(env)`, `asViewer(env)`, `asHelmetService(env)`,
`asUnprovisioned(env)`, `asAnonymous(env)`, and two claim-carrying ones —
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
