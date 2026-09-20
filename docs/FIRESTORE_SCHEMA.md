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
| `helmetId` | string | yes | Helmet serial; **this is the join key to `devices/`** (see §3). Unique across riders — enforced by the console; will become a rule. |
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

### `admins/{adminId}` and `emergencyContacts/{id}` — reserved

Not read or written yet. Intended shapes, for when Auth lands:

```
admins/{uid}              { name, email, role: superAdmin|dispatcher|viewer }
emergencyContacts/{id}    { riderId, name, phone, relationship }
```

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

## 4. Security rules — current state, stated plainly

`firestore.rules` (what `firebase.json` deploys) is **deny-all**.

Firebase Auth is not wired. `admin_login_page.dart` compares hardcoded
strings, which is not authentication, so there is no principal the rules can
trust. The database will eventually hold live GPS positions of the TNVS riders
in the study; open rules would expose their real-time location to anyone with
the project id. That is a safety problem for real people, independent of
grading.

**Consequence:** with the locked rules deployed, the console shows the
`FIRESTORE` chip with the pill `OFFLINE — Firestore denied access`, and every
write is refused with a red toast. This is correct behaviour, not a bug.

### Demo window

`firestore.rules.demo` (deployed with `--config firebase.demo.json`) opens
exactly `riders/`, `devices/`, `alerts/` and `alerts/*/history` (create only)
until **22 September 2026**, then denies by itself. Use it only while the
database holds seeded, fake riders; re-deploy `firestore.rules` before any
real helmet writes real positions:

```bash
firebase deploy --only firestore:rules --config firebase.demo.json   # open for demo
firebase deploy --only firestore:rules                                 # lock again
```

### What changes when Auth lands

```
match /riders/{riderId} {
  allow read:   if isOperator() || request.auth.uid == resource.data.authUid;
  allow create, update: if isOperator() && hasRole(['superAdmin']);
}
match /devices/{deviceId} {
  allow read:   if isOperator() || ownsHelmet(deviceId);
  allow write:  if isHelmetService();          // the ESP32's service identity only
}
match /alerts/{alertId} {
  allow read:   if isOperator() || request.auth.uid == riderUid(resource.data.riderId);
  allow create: if isHelmetService() || ownsHelmet(request.resource.data.deviceId);
  allow update: if isOperator() && hasRole(['superAdmin', 'dispatcher'])
                && onlyChanges(['status', 'acknowledgedAt', 'dispatchedAt', 'resolvedAt']);
  match /history/{entryId} {
    allow read:   if isOperator();
    allow create: if isOperator() && hasRole(['superAdmin', 'dispatcher']);
    allow update, delete: if false;            // append-only audit trail
  }
}
match /admins/{uid} {
  allow read: if request.auth.uid == uid || hasRole(['superAdmin']);
}
```

where `isOperator()` checks `request.auth.token.role in ['superAdmin',
'dispatcher', 'viewer']` (a custom claim), `isHelmetService()` matches the
service account the firmware authenticates as, and the linear lifecycle
(`open → acknowledged → dispatched → resolved`) is enforced with
`resource.data.status` / `request.resource.data.status` pairs. The
`RiderValidation` predicates (unique `helmetId`, phone format) become rule
functions at the same time.

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

```bash
# 1. Web config (gitignored). Print it with the Firebase CLI:
firebase apps:sdkconfig WEB 1:885956155129:web:21670e7270e1ccc7dc3428 > assets/config/firebase.json
#    …then trim the CLI's preamble so the file is just the JSON object
#    (see assets/config/firebase.example.json for the shape).

# 2. Run. With the file present the top bar shows FIRESTORE.
flutter run -t lib/main_admin.dart -d chrome

# 3. One-time seed of the simulation's fleet into an EMPTY database.
#    Refuses if riders/ has any document. Needs rules that allow writes.
flutter run -t lib/main_admin.dart -d chrome --dart-define=SEED_FIRESTORE=true

# Rehearse offline on a configured machine:
flutter run -t lib/main_admin.dart -d chrome --dart-define=NOVARIDE_FORCE_SIMULATION=true
```

Delete `assets/config/firebase.json` and the console runs on the simulation
with the `SIMULATION` chip — no code change, no flag.

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
   or a Cloud Function on `alerts` create?
3. Rider ↔ device pairing: does the rider app write `assigned_rider_id`, or is
   `riders.helmetId` the only link?
