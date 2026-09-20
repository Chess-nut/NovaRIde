# NovaRide — Cloud Firestore Schema

Project `novaride-7a68c` (project number `885956155129`, org `tip.edu.ph`,
Spark plan), Cloud Firestore, location `asia-southeast1`, production mode.
Console: <https://console.firebase.google.com/project/novaride-7a68c/firestore>

> **History.** The first project, `novaride-266bc`, was abandoned on
> 20 Sep 2026 and `novaride-7a68c` started empty. Nothing carried over: the
> phantom `users/*` documents, the `emergencyalerts` scaffold and the
> hand-made `devices/helmet01` document described in earlier revisions of
> this file do not exist in the new project. The project id is not written
> anywhere in `lib/` — the console reads it from the loaded config
> (`assets/config/firebase.json`) at runtime, and `.firebaserc` is the only
> other place it appears.

This document is the contract between the three things that touch the
database: the TNVS Operator console (`lib/admin/`), the rider app, and the
ESP32 helmet firmware. Change the schema here first.

---

## 1. Why Cloud Firestore, when Chapter 2 says Realtime Database

Chapter 2 (System Architecture, Data Tier) and the Conceptual Framework both
name **Firebase Realtime Database**. The project uses **Cloud Firestore**, and
the paper should be revised to match. Same vendor, same tier in the three-tier
diagram; the reasons are technical:

1. **The Reports tab needs compound queries.** Response-time metrics,
   alerts-by-district, false-positive rate and date-range filters are all
   `where` + `orderBy` combinations. Firestore indexes these natively
   (`firestore.indexes.json`); Realtime Database would require pulling whole
   nodes and filtering on the client.
2. **The audit trail is a subcollection.** An alert's acknowledge → dispatch →
   resolve history is `alerts/{id}/history`, appended with `.add()` and read
   with `orderBy('at')`. In Realtime Database it would be a push-keyed list
   sorted by hand, and two operators acting at once could clobber each other.
3. **Schema work had already begun in Firestore.** The first project's
   `devices/helmet01` carried the firmware-shaped `ax / ay / az /
   vector_magnitude` fields from the MPU6050 resultant-vector formula
   A = √(X² + Y² + Z²) in Chapter 2. That document is gone with the old
   project, but the `devices/` shape below still follows it.

For Chapter 3: replace "Firebase Realtime Database" with "Cloud Firestore" in
the Data Tier description and the framework figure; the flow (helmet → cloud
database → operator console, "without delay", Objective 2) is unchanged.

---

## 2. Collections

Flat top-level collections. The first project had a `users/admin/admins/…`
nesting that used a document as a folder: `users/admin` had no fields, so it
was a phantom that rendered in the console but matched no query and needed a
rules block per level. **Those phantoms and the `emergencyalerts` scaffold
are gone** — `novaride-7a68c` started empty and only the collections below
are ever created. If a `users/` or `emergencyalerts` collection appears in
the new project, something outside this document wrote it.

### `riders/{riderId}` — dashboard-owned, camelCase

Document id is the rider id shown in the console (`R-001`).

| Field | Type | Required | Notes |
|---|---|---|---|
| `fullName` | string | yes | A document without it is skipped. |
| `helmetId` | string | yes | Helmet serial; **this is the join key to `devices/`** (see §3). Unique across riders — enforced by the console; cannot become a rule (§4). |
| `phone` | string | | E.164 or local format, displayed as written. |
| `status` | string | | `riding` \| `idle` \| `offline` \| `emergency`. Default `idle`. |
| `isActive` | bool | | Default `true`. Deactivated riders are kept, never deleted — alert history references them. |
| `registeredAt` | timestamp | | Default: now, if missing. |

Written by the console (`set` with merge on create, `update` on edit).

### `devices/{deviceId}` — **firmware-owned, snake_case**

Document id is the helmet serial (`NR-H1-001`). This is the document the
ESP32 writes; the console only reads it (and the seed writes it once).

| Field | Type | Owner | Notes |
|---|---|---|---|
| `alcohol_level` | number | firmware | MQ-3, mg/L. Warning above 0.05. |
| `ax`, `ay`, `az` | number | firmware | MPU6050 axes. |
| `vector_magnitude` | number | firmware | √(ax² + ay² + az²). |
| `severity` | string | firmware | Firmware's own classification; not interpreted by the console yet. |
| `latitude`, `longitude` | number | firmware | NEO-6M fix. |
| `speed_kmh` | number | **firmware — to add** | Required by the Rider Monitoring table (Ch. 1 scope). Defaults to 0 when absent. |
| `battery_pct` | number | **firmware — to add** | 0–100. Defaults to 0 when absent. |
| `gps_fix` | bool | **firmware — to add** | Defaults to `true` if lat/lng are non-zero, else `false`. |
| `last_update` | timestamp | **firmware — to add** | Use a server timestamp. Defaults to the moment the snapshot arrived, which overstates freshness — add this field. |
| `assigned_rider_id` | string | rider app / console | Optional. If absent, the console joins by `riders.helmetId == deviceId`. |
| `state`, `firmware_version`, `paired_at` | string, string, timestamp | rider app | Pairing metadata; informational. |

The reader also accepts camelCase spellings of every field above, so a
firmware or app that writes `speedKmh` still renders. Pick one and stay on it.

### `alerts/{alertId}` — created by firmware, worked by the console, camelCase

Document id: any. The seed uses `A-101`; firmware should use auto-ids.

| Field | Type | Required | Notes |
|---|---|---|---|
| `riderId` | string | yes | `riders/{riderId}`. |
| `riderName` | string | | Denormalised for the feed; the console fills it from `riders/` if empty. |
| `deviceId` | string | | Helmet that raised it. |
| `type` | string | yes | `crash` \| `sos` \| `alcoholWarning` \| `lowBattery`. Aliases accepted: `fall`, `impact`, `collision` → crash; `alcohol` → alcoholWarning; `battery` → lowBattery; `panic`, `emergency` → sos. Anything else is shown as SOS and logged — a live alert with an odd label beats a hidden one. |
| `lat`, `lng` | number | yes | Also accepted: `latitude`/`longitude`, or a `location` GeoPoint / map. |
| `address` | string | | Street-level label. Falls back to the nearest district's address. |
| `timestamp` | timestamp | **yes** | When the helmet raised it. **The board is `orderBy('timestamp')` — a document without this field is invisible.** |
| `status` | string | | `open` \| `acknowledged` \| `dispatched` \| `resolved`. Default `open`. Only the console changes it. |
| `acknowledgedAt`, `dispatchedAt`, `resolvedAt` | timestamp | console | Server timestamps stamped on each transition, for Reports queries. |

The console listens to the newest **100** alerts. Response-time averages are
computed over what is on the board.

**Firmware contract for critical alerts:** whoever creates a `crash` or `sos`
alert must also set `riders/{riderId}.status = "emergency"`. The console
clears it back to `idle` when the last active critical alert for that rider
is resolved. Until the firmware or a Cloud Function does this, an alert
inserted by hand shows on the board but does not turn the rider's dot red.

#### `alerts/{alertId}/history/{autoId}` — console-owned, append-only

| Field | Type | Notes |
|---|---|---|
| `toStatus` | string | The status this entry moved the alert to. |
| `actorName` | string | Signed-in operator. |
| `note` | string \| null | Free text. |
| `responder` | string \| null | `medical` \| `police` \| `fireRescue` \| `barangay`; dispatch only. |
| `at` | timestamp | **Server timestamp.** Response-time metrics are the study's evidence; operator machine clocks are not trusted for them. |

Written with `.add()` in the same batch as the parent's `status` update, so
neither can land without the other. Read through a `collectionGroup('history')`
listener (newest 500) and stitched onto the alerts — one listener rather
than one per alert. Needs the collection-group index on `at`.

### `admins/{uid}` — provisioning, camelCase

Document id is the **Firebase Auth UID** of the operator. This is what makes
an authenticated account a console operator: Firebase Auth says who you
are, this document says what you may do. An account with no document and no
`role` claim is denied at sign-in (see §4 and ADMIN_MODULE.md).

| Field | Type | Required | Notes |
|---|---|---|---|
| `name` | string | | Display name in the top bar. Falls back to the Auth `displayName`, then the email's local part. |
| `email` | string | | Informational; the Auth record is authoritative. |
| `role` | string | **yes** | `superAdmin` \| `dispatcher` \| `viewer` — the `AdminRole` enum names verbatim. `administrator`/`admin` and `operator` are tolerated on read (→ `superAdmin` / `dispatcher`) so a hand-typed document degrades rather than locks someone out; never write them. Anything else is "not provisioned". |

Written only from the Firebase console or the Admin SDK — the rules refuse
every client write to `admins/`, so a compromised operator session cannot
mint operators. Read by the console at sign-in (`get`, from the server, never
the cache) and by the rules whenever a request carries no usable `role`
claim.

The three provisioned operators (20 Sep 2026):

| UID | Email | `role` |
|---|---|---|
| `2zDb1Xg8STZxks8OdBTvOQKZkBA3` | `qrlunatal@tip.edu.ph` | `superAdmin` |
| `fYWvZF9O5ucHLRHYASAn48Rpthz1` | `qhjcagbayani@tip.edu.ph` | `dispatcher` |
| `ZTYyMk4xyONT5mDGstEjoJC9hoZ2` | `qdplegarde@tip.edu.ph` | `viewer` |

To add an operator: create the account under Authentication → Users, then
create `admins/{that uid}` with `name`, `email`, `role`. Optionally set the
claim with `tool/set_admin_claims.mjs` (§4). To remove one: disable the Auth
account (the SDK signs them out at the next token refresh and the shell
returns to the login page) and delete or re-role the document.

### `emergencyContacts/{id}` — reserved

Not read or written yet. Intended shape:

```
emergencyContacts/{id}    { riderId, name, phone, relationship }
```

No rule admits it; it stays closed until one is written (§4).

---

## 3. Naming convention

Two conventions, split by owner. The split was first chosen because it was
not known whether firmware had been written against the old project's
`devices/helmet01`; the fresh project settled that (nothing writes
`devices/` yet — §7), and the split is kept as the agreed contract because
snake_case is what the Arduino side naturally produces:

- **`devices/` is snake_case** — the firmware's existing spelling. The
  dashboard-required fields it still lacks (`speed_kmh`, `battery_pct`,
  `gps_fix`, `last_update`) follow the same convention so the document
  stays consistent.
- **Everything the dashboard owns is camelCase** — `riders/`, `alerts/`,
  `history/`, `admins/`, `emergencyContacts/` — matching the Dart models in
  `lib/shared/models/models.dart` one-to-one.

Translation happens in exactly one place, `FirestoreFleetRepository`. Should
the firmware team prefer camelCase after all, collapsing `devices/` is a
one-file change there plus the seed — a free choice now, not a migration.

---

## 4. Security rules — live

`firestore.rules` (what `firebase.json` deploys) is the real ruleset as of
20 Sep 2026. It replaced the deny-all rules that stood in while the console's
login was a string comparison. Firebase Auth is now wired
(`lib/admin/data/firebase_admin_auth.dart`; architecture in
[ADMIN_MODULE.md](ADMIN_MODULE.md#4-authentication)), so there is a principal
the rules can trust, and they trust nothing else.

Deploy:

```powershell
firebase deploy --only firestore:rules
```

The CLI compiles the file before releasing it; a syntax error aborts the
deploy and leaves the live ruleset untouched.

### Principals

| Principal | How it authenticates | How the rules know its role |
|---|---|---|
| **Operator** (`superAdmin` \| `dispatcher` \| `viewer`) | Firebase Auth email/password, from the console | `request.auth.token.role` (custom claim) first; if absent or not one of the three, `admins/{uid}.role`. Aliases `administrator`/`admin` → `superAdmin`, `operator` → `dispatcher` are read-tolerated. |
| **Helmet service** | A Firebase Auth user the ESP32 will sign in as, carrying the claim `role: helmetService` | The claim only. It is not a console role; the console rejects it as unprovisioned. **No such account exists yet** — how the firmware authenticates is an open item (§7). A bridge using the Admin SDK bypasses these rules and needs nothing here. |
| Anyone else | — | Denied everywhere. |

**No custom claims are set today.** All three operators resolve through
`admins/{uid}`, which costs the rules one document read per request (cached
within a request). Setting the claim with `tool/set_admin_claims.mjs` is
optional and removes that read; the console resolves the role in the same
order, so a claim and a document that disagree resolve to the claim in both
places. Keep them in step.

### What each principal may do

| Path | read | create | update | delete |
|---|---|---|---|---|
| `riders/{id}` | operator | superAdmin | superAdmin; dispatcher **or** helmet service if only `status` changes | never (deactivate instead) |
| `devices/{id}` | operator | helmet service; superAdmin (registering a helmet; the seed) | helmet service only | never |
| `alerts/{id}` | operator | helmet service; superAdmin (the seed) | superAdmin / dispatcher, **one lifecycle step forward**, touching only `status` + the matching `<status>At`, which must be the server clock | never |
| `alerts/{id}/history/{e}` | operator (single alert and collection group) | superAdmin / dispatcher, `at` must be the server clock | never | never |
| `admins/{uid}` | own document: any signed-in user; all: superAdmin | never from a client | never | never |
| everything else (incl. `emergencyContacts/`) | — | — | — | — |

Beyond "who", the rules enforce three of the schema's promises that used to
live only in Dart:

- **The alert lifecycle is linear.** An update must move
  `open → acknowledged → dispatched → resolved` by exactly one step and stamp
  exactly that step's `<status>At` with `request.time`. Skipping, repeating,
  reversing, or a client-supplied timestamp is refused.
- **`history/` is append-only** and its `at` is the server clock. The
  response-time metrics in Reports are the study's evidence, and an operator's
  machine clock is not admissible.
- **A dispatcher's only write to a rider is its status** — the automatic
  stand-down when a critical alert is resolved.

What the rules do **not** enforce: `helmetId` uniqueness and phone format.
Uniqueness needs a lookup index the rules language cannot express; both stay
in `RiderValidation` on the client, and a Super Admin is the only principal
who can write those fields anyway.

### Three things worth knowing before you debug a `permission-denied`

1. **The history listener is a collection-group query.** A nested
   `match /alerts/{id}/history/{e}` rule does not cover it; the file carries
   a second `match /{path=**}/history/{e}` read rule for exactly that
   listener. Remove it and every alert's audit trail disappears from the
   board while the alerts themselves still load.
2. **The seed runs after sign-in now.** It writes `riders/`, `devices/` and
   `alerts/` through the client SDK, and the rules admit those creates only
   from a signed-in Super Admin, so `FleetBootstrap` no longer runs it
   before `runApp` (where there is no principal) — the shell triggers it
   once a Super Admin signs in (§6). It would be refused for a dispatcher,
   and it would be refused if a `devices/` document already existed, since
   `set` on an existing document is an update and only the helmet service
   may update telemetry.
3. **The role lookup reads from the server.** If the rules are not deployed
   yet, sign-in succeeds at Firebase Auth and then fails at
   `get(admins/{uid})`; the console shows *"the console was not allowed to
   read this account's role. The Firestore security rules may not be
   deployed yet."* and signs the session out. That message means: run the
   deploy above.

### Removed: the demo window

`firestore.rules.demo` and `firebase.demo.json` — a time-boxed, unauthenticated
opening of the three console collections — were deleted on 20 Sep 2026. The
window was drafted for the old project and never deployed to this one, and an
expiring escape hatch in the repo is an invitation to deploy it later and then
debug a silent `permission-denied` after the date passes. There is one
ruleset and one deploy command.

### Still to write

The rider app does not authenticate yet, so the draft's rider-facing clauses
(`request.auth.uid == resource.data.authUid`, `ownsHelmet(...)`) have nothing
to bind to — `riders/` has no `authUid` field and the app has no Firebase
sign-in. They are deliberately absent rather than present-but-dead. When the
rider app lands: add `authUid` to `riders/`, decide the helmet's identity
(§7), and extend the `riders/`, `devices/` and `alerts/` reads here first.

---

## 5. Indexes

`firestore.indexes.json`, deployed with `firebase deploy --only
firestore:indexes`. The 15 Sep 2026 deployment went to the abandoned project;
**`novaride-7a68c` has no composite indexes until this is run again** (§6):

| Collection | Fields | Used by |
|---|---|---|
| `alerts` | `status` ASC, `timestamp` DESC | Reports: open/active incidents by recency |
| `alerts` | `riderId` ASC, `timestamp` DESC | Rider detail: "View alerts" for one rider |
| `alerts` | `type` ASC, `timestamp` DESC | Reports: alerts by type over a date range |
| `history` (collection group) | `at` ASC / DESC | The audit-trail listener |

Composite indexes are committed rather than created from console error links,
because those links only appear at runtime — a poor way to discover a missing
index mid-demo.

---

## 6. Running the console against Firestore

First-time setup for a fresh project, in order. Steps 1–3 are one-off and
done from the repository root with the Firebase CLI signed in and pointed at
`novaride-7a68c` (`firebase use` should print it):

```powershell
# 1. Rules and indexes. Rules first — without them every read is refused,
#    including the admins/{uid} lookup that sign-in depends on.
firebase deploy --only firestore:rules
firebase deploy --only firestore:indexes

# 2. Web config (gitignored). Print it with the Firebase CLI, then trim the
#    CLI's preamble so the file is just the JSON object
#    (see assets/config/firebase.example.json for the shape).
firebase apps:sdkconfig WEB 1:885956155129:web:21670e7270e1ccc7dc3428 > assets/config/firebase.json

# 3. One-time seed of the simulation's fleet into the EMPTY database.
#    Start with the flag, then SIGN IN AS A SUPER ADMIN — the seed runs at
#    that moment, not at startup, because the rules only accept its writes
#    from a signed-in Super Admin. Watch the terminal for
#    "seedFirestore: wrote 10 riders, …". It refuses if riders/ already has
#    a document, and a Dispatcher or Viewer sign-in skips it with a message.
flutter run -t lib/main_admin.dart -d chrome --web-port 5173 --dart-define=SEED_FIRESTORE=true

# Day to day. With the config present the top bar shows FIRESTORE; sign in
# with one of the operator accounts (§2, admins/).
flutter run -t lib/main_admin.dart -d chrome --web-port 5173

# Rehearse offline on a configured machine (simulation + local demo login):
flutter run -t lib/main_admin.dart -d chrome --dart-define=NOVARIDE_FORCE_SIMULATION=true

# Optional: put the role in the ID token as a custom claim (see §4 and the
# header of tool/set_admin_claims.mjs — the key lives OUTSIDE the repo).
cd tool
npm i firebase-admin
$env:GOOGLE_APPLICATION_CREDENTIALS="$HOME\novaride-admin-key.json"
node set_admin_claims.mjs qrlunatal@tip.edu.ph superAdmin
```

Delete `assets/config/firebase.json` and the console runs on the simulation
with the `SIMULATION` chip and the local demo accounts — no code change, no
flag. That build never touches Firebase Auth or Firestore.

**Why an asset and not `lib/firebase_options.dart`:** Dart imports are
resolved at compile time, so a gitignored `firebase_options.dart` breaks the
build for anyone who has not run `flutterfire configure`. An asset that may
or may not exist is a runtime question, which is what "falls back to the
simulation" needs. `lib/firebase_options.dart` stays in `.gitignore` so a
stray `flutterfire configure` can never commit credentials.

---

## 7. Open with the schema owner

Settled by starting `novaride-7a68c` from empty (20 Sep 2026):

- ~~Is firmware already writing `devices/helmet01`?~~ **No.** Nothing writes
  `devices/` in the new project. The snake_case convention stays as the
  firmware contract (§3); there is no legacy document to migrate.
- ~~Delete the phantom `users/*` documents and the `emergencyalerts`
  scaffold.~~ **Gone** — they were never created in the new project.

Still open:

1. Firmware to add `speed_kmh`, `battery_pct`, `gps_fix`, `last_update`.
2. Who sets `riders/{id}.status = "emergency"` on a critical alert — firmware,
   or a Cloud Function on `alerts` create? (The rules already let the helmet
   service make that one write; a Cloud Function would use the Admin SDK and
   need nothing.)
3. Rider ↔ device pairing: does the rider app write `assigned_rider_id`, or is
   `riders.helmetId` the only link?
4. **How does the ESP32 authenticate?** The rules reserve a Firebase Auth
   identity carrying the claim `role: helmetService` (one account for the
   fleet, or one per helmet — the rules do not care). The alternative is a
   bridge that writes through the Admin SDK, which bypasses the rules. Either
   way the firmware team decides; nothing exists yet.
5. Rider-app access: `riders/` needs an `authUid` field before any rider can
   read their own record or alerts (§4, "Still to write").
