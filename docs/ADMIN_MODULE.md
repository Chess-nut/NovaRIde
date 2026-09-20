# NovaRide Admin Module — Architecture & Status

The operations console used by NovaRide dispatchers to watch the helmet fleet
and respond to accident alerts. This document covers how it is put together,
why those choices were made, and — explicitly — which parts are simulated.

**Run it:**

```bash
flutter run -t lib/main_admin.dart -d chrome --web-port 5173
```

**Signing in:** with `assets/config/firebase.json` present the console runs
on Cloud Firestore and sign-in is Firebase Auth — use one of the operator
accounts in [§6](#6-role-matrix). Without the file it runs on the in-process
simulation and the login page lists three demo accounts with their
passwords, which are not real credentials. First-time project setup (rules,
indexes, seed) is in [FIRESTORE_SCHEMA.md §6](FIRESTORE_SCHEMA.md#6-running-the-console-against-firestore).

---

## 1. Two-entrypoint architecture

The repository ships two independent Flutter applications from one codebase:

| Entrypoint | App | Audience |
|---|---|---|
| `lib/main.dart` | `NovaRideApp` — rider app | Motorcycle riders wearing the helmet |
| `lib/main_admin.dart` | `AdminApp` — operations console | Dispatchers and fleet administrators |

```
lib/
├── main.dart              rider entrypoint
├── main_admin.dart        admin entrypoint
├── rider/                 rider screens and widgets
├── admin/                 admin console  ← this document
│   ├── console_format.dart    shared duration/date/CSV formatting
│   ├── data/                  FleetRepository contract, mock + Firestore implementations
│   ├── mock/                  seed data
│   ├── screens/               one file per tab, plus login
│   ├── state/                 controller, scopes, validation, session
│   └── widgets/               panels, charts, table, map, dialogs
└── shared/                theme + domain models used by BOTH apps
```

### Why two entrypoints rather than one app with a role switch

1. **Different devices.** The rider app is a portrait phone UI; the console is
   a dense desktop grid designed for ≥1280px. One responsive app would have
   compromised both.
2. **Different people own them.** The rider app and the admin module are
   developed in parallel by different contributors. Separate entrypoints mean
   neither side's work can break the other's build.
3. **Shared where it matters.** `lib/shared/` holds the domain models and the
   colour palette, so the two apps stay consistent about what a `Rider`, an
   `AlertEvent` and NovaRide blue actually are. There is no duplication of
   domain logic.

Nothing in `lib/admin/` imports from `lib/rider/`, and nothing in `lib/rider/`
imports from `lib/admin/`. The only shared surface is `lib/shared/`.

---

## 2. State management

**Decision: `ChangeNotifier` + `InheritedNotifier`, with zero third-party
packages.**

Apart from `firebase_core`, `cloud_firestore` and `firebase_auth` (the data
tier and its identity) and the rider app's `google_maps_flutter`,
`pubspec.yaml` has no non-Flutter dependencies. That is deliberate:

- **Defensibility.** Every mechanism in the console can be explained from the
  Flutter SDK alone. There is no "the package does it" answer to a panel
  question.
- **Reviewability.** No transitive dependency tree to audit for a student
  project, and no version drift breaking the build before a defence.
- **It is genuinely enough.** The console has one source of truth and a
  handful of consumers. `provider`, `riverpod` or `bloc` would add
  vocabulary without removing work at this size.

Concretely this means:

| Concern | Standard package choice | What this project uses |
|---|---|---|
| State container | `provider` / `riverpod` | `ChangeNotifier` + `InheritedNotifier` |
| Navigation | `go_router` | `IndexedStack` + an index |
| Charts | `fl_chart` | `CustomPainter` (`SimpleBarChart`, `WeeklyAlertsChart`) |
| Maps | `google_maps_flutter` | `CustomPainter` (`FleetMapView`) |
| Date formatting | `intl` | `lib/admin/console_format.dart` |
| CSV export / file save | `csv` + `share_plus` | String builder + selectable dialog |

### The widget tree

```
AdminApp                            OWNS the AdminAuth (one instance, app lifetime)
└── FleetSourceScope                the backend: createRepository + auth + projectId
    └── MaterialApp
        └── AdminLoginPage          await auth.signIn() → AdminUser
            └── AdminShell(user)    LISTENS to auth.authStateChanges(); leaves on null
                ├── AdminSessionScope       who is signed in (InheritedWidget)
                └── FleetHost               OWNS the FleetController (+ its repository)
                    └── FleetScope          the controller (InheritedNotifier)
                        └── AdminNavScope   cross-tab navigation requests
                            └── Scaffold
                                ├── AdminSidebar   role-filtered nav items
                                └── IndexedStack   role-filtered pages
```

`FleetHost` is a `StatefulWidget` that constructs the controller in
`initState` and disposes it in `dispose`. This matters: an earlier version
constructed the controller inside `DashboardPage`, so every other tab read
frozen seed data and the dashboard's `dispose()` could kill the simulation.
Ownership now sits above every page, and pages are pure consumers.

`AdminShell` is stateful for a parallel reason: it subscribes to the auth
stream in `initState` and cancels in `dispose`, so the subscription lives
exactly as long as the session it guards (§4).

Pages read state with `FleetScope.of(context)` and wrap the reactive part in a
`ListenableBuilder`.

---

## 3. The repository seam — `FleetRepository`

The controller never talks to a store. It is handed one `FleetRepository`
and reads everything through that repository's streams:

```
lib/admin/data/
├── fleet_repository.dart            the contract (streams + narrow writes)
├── mock_fleet_repository.dart       in-process simulation, timers, seed data
├── firestore_fleet_repository.dart  Cloud Firestore snapshots + batched writes
├── admin_auth.dart                  AdminAuth contract + LocalAdminAuth (demo accounts)
├── firebase_admin_auth.dart         Firebase Auth + role resolution (§4)
├── fleet_bootstrap.dart             picks data source AND auth at startup (see below)
├── firestore_seed.dart              one-time seed, gated by --dart-define
└── fleet_geography.dart             district table + map window

lib/admin/state/
├── admin_session.dart               AdminRole, AdminUser, parseAdminRole, AdminSessionScope
├── fleet_controller.dart            workflow rules, derived metrics, selection
└── fleet_scope.dart                 FleetScope / FleetSourceScope / FleetHost
```

Division of labour:

| `FleetController` (state) | `FleetRepository` (data) |
|---|---|
| Legal alert transitions, roster uniqueness, when a rider comes off emergency | Carrying a validated write to the store |
| Validates against its **local copy**, throws `StateError` synchronously | Echoes the resulting state back through `watchRiders / watchTelemetry / watchAlerts` |
| Shows a roster write **optimistically** — an overlay on the store's list, withdrawn if the store refuses or does not answer in 20 s (`FleetWriteException`) | Re-checks what the local copy cannot: claims the rider id and the helmet pairing in a **transaction**, so two consoles cannot collide |
| Trails, selection, `lastSync`, `statusCounts`, response-time averages | `FleetSource` (simulation / firestore) and `FleetConnection` for the top-bar chips |

The streams are the source of truth: a write is only "done" once it comes
back through them. The mock's streams deliver synchronously, which is why the
controller and widget tests can stay synchronous; Firestore's are async and
the pages never notice, because they only read the controller's getters.

### Choosing the backend

`main_admin.dart` calls `FleetBootstrap.resolve()` once, before `runApp`. It
returns a `ConsoleBackend` — data source, sign-in provider and project id,
decided together so the console can never mix a real database with a
pretend login or vice versa:

1. `--dart-define=NOVARIDE_FORCE_SIMULATION=true` → simulation + `LocalAdminAuth`.
2. `assets/config/firebase.json` absent or unusable → simulation + `LocalAdminAuth`.
3. `Firebase.initializeApp` fails → simulation + `LocalAdminAuth` (reason printed).
4. Otherwise → `FirestoreFleetRepository` + `FirebaseAdminAuth`, and the
   project id from the loaded config for the top bar's tooltip.

`AdminApp` mounts the result as a `FleetSourceScope` above the `MaterialApp`;
the login page reads `auth` from it and `FleetHost` reads `createRepository`
in `initState`. Widget tests pump `AdminApp()` bare and get the simulation
and the local accounts, so they never reach the network; tests that need a
scripted provider pass `AdminApp(auth: fake)`. The top bar shows the
outcome: a `FIRESTORE` or `SIMULATION` chip, and a `LIVE / CONNECTING /
OFFLINE` pill fed by the repository's own connection report (snapshot
metadata, for Firestore).

The schema, naming convention, firmware contract and the live rules are in
[FIRESTORE_SCHEMA.md](FIRESTORE_SCHEMA.md).

---

## 4. Authentication

The panel's comment on the first review was *"login — static only"*. It was
right: `authenticate()` compared the typed password against three strings
in source, which is a demo convenience, not authentication, and it was why
the Firestore rules had to be deny-all — there was no principal for them to
trust. This section is what replaced it.

### The seam — `AdminAuth`

Same shape as `FleetRepository`. Widgets never touch `FirebaseAuth.instance`;
they see one small interface, and everything below the login page sees only
an `AdminUser`, exactly as before:

```dart
abstract class AdminAuth {
  Future<AdminUser> signIn(String email, String password);  // throws AdminAuthException
  Future<void> signOut();
  Stream<AdminUser?> authStateChanges();                    // null = signed out
  AdminUser? get currentUser;
}
```

| Implementation | Used when | What it does |
|---|---|---|
| `FirebaseAdminAuth` | Firestore path | Firebase Auth email/password, then role resolution below. |
| `LocalAdminAuth` | Simulation path, and every widget test | Wraps the old `demoAccounts` / `authenticate()`. Not authentication, and never presented as such — it exists so a checkout with no Firebase config is fully usable and the console can be demoed offline. |

### Role resolution — and the decision not to default

`FirebaseAdminAuth.signIn` resolves the role in this order; first hit wins:

1. The `role` custom claim on the ID token. Values are the `AdminRole` enum
   names verbatim: `superAdmin`, `dispatcher`, `viewer`. `administrator` /
   `admin` → `superAdmin` and `operator` → `dispatcher` are tolerated on
   read, so a claim set by hand with the wrong spelling degrades to the
   intended role instead of locking someone out. They are never written;
   the tooling refuses them.
2. `admins/{uid}.role` in Firestore, read from the server, never the local
   cache. This is the only source today — **no claims are set yet** — and
   the path must work on its own.
3. **Neither → denied.** The Firebase session is ended and the login page
   shows: *"This account is not provisioned for the operations console. Ask
   a Super Admin to add it to the admins list."*

There is deliberately no default role. Granting `viewer` to an unknown
account would be a quiet security failure — a valid Firebase account from
anywhere in the `tip.edu.ph` org could read every rider's live position and
nobody would notice. Granting `superAdmin` would be a loud one. Denying is
the only option whose failure mode is visible.

The security rules resolve the role the same way, in the same order
(FIRESTORE_SCHEMA.md §4), so the console and the database cannot disagree
about who someone is. If they ever did, the rules win.

The display name is `admins/{uid}.name`, then Firebase `displayName`, then
the email's local part. Setting a claim later is optional (it saves the
rules one read per request) and is done with `tool/set_admin_claims.mjs`
using a service-account key that lives outside the repository; the operator
must sign out and back in for a changed claim to take effect, because claims
travel in the ID token.

### Session lifecycle

The earlier `AdminSessionScope` comment said *"the session never changes
while signed in."* That stopped being true the moment a real identity
provider was involved: a refresh token can be revoked, an account disabled,
another tab can sign in as someone else, and the SDK signs the user out
underneath the widget tree.

So `AdminShell` subscribes to `authStateChanges()` for as long as it is
mounted and replaces itself with the login page the moment the stream stops
naming its user — null, or a different operator. The sidebar's Logout goes
through `auth.signOut()` and comes back on the same stream, so there is one
exit path, not two, and no way to be signed out underneath and still see
the board. The whole subtree below `AdminSessionScope` is torn down: no
page ever sees a partially signed-out user, and no stale data survives into
the next session.

### The login page

- `signIn` is awaited; the button is disabled with a spinner while a
  sign-in is in flight, so a double-click (or Enter plus a click) cannot
  start two.
- Provider errors are translated before they reach the page.
  `[firebase_auth/invalid-credential]` means nothing to a dispatcher at
  2 a.m.; they see *"Incorrect email or password."* Too many attempts,
  disabled account, no network, not provisioned, and rules-not-deployed
  each have a sentence; anything unrecognised gets a generic one and the
  code goes to the debug log. **Raw exception text is never shown**, and
  `test/admin_auth_test.dart` asserts it.
- A wrong password and an unknown email get the **same** sentence. A login
  page that answers differently tells an unauthenticated visitor which
  addresses are registered — account enumeration — and the test asserts the
  two codes map to one string.
- No account is named on the screen, on either path. The email address is
  the one thing the page will keep, and only when asked: *Remember my email
  on this browser* stores the address (never the password) in the browser's
  local storage, so a returning operator lands on the password field.
  Unticking forgets it immediately.
- The form is keyboard-complete: Enter submits from either field, the email
  is checked for shape on blur and on submit before any round-trip, the
  button enables once both fields are filled, tab order is email → password
  → sign in, and the fields carry `AutofillHints` so a browser password
  manager offers to save and fill.
- The footer shows the version and build (`console_build.dart`, overridable
  with `--dart-define=NOVARIDE_BUILD=…`) and, on the simulation only, a
  *Simulation mode* line so nobody mistakes mock data for live Firestore.

### ISO/IEC 25010 — Security

This is the module's first real evidence for the Security characteristic;
before it, "role-based access control" was a UI gate in front of a string
comparison. Mapped to the sub-characteristics:

| Sub-characteristic | Evidence |
|---|---|
| **Authenticity** | Operators are Firebase Auth email/password accounts; the console never decides identity itself. The simulation's `LocalAdminAuth` is labelled as such in code, in the UI (`SIMULATION` chip) and here. |
| **Confidentiality** | Firestore rules deny by default. Rider positions (`riders/`, `devices/`) and alerts are readable only by a signed-in account whose role the rules can establish; `admins/` is readable by its own subject and Super Admins only; `emergencyContacts/` and everything unlisted are closed. The Firebase web config is a gitignored asset; the service-account key that could bypass all of this lives outside the repository and is refused by the tooling if found inside it. |
| **Integrity** | The alert lifecycle is enforced server-side: one step forward, only `status` and its own `<status>At`, which must be the server clock. `history/` is append-only with a server-clock `at`. A dispatcher's only write to a rider is `status`. Telemetry (`devices/`) is updatable only by the helmet service identity. Nothing deletes riders, devices, alerts or history. |
| **Non-repudiation** | Every transition writes a `history` entry naming the actor and stamped by the server, and that entry cannot be edited or removed by any client. *Honest caveat:* `actorName` is the display name the client sends, not the uid; a stronger record would store `request.auth.uid` — noted as follow-up work, not claimed. |
| **Accountability** | Roles are provisioned in `admins/{uid}` (or a claim), never inferred; an unprovisioned account is denied, not defaulted. Provisioning is a console/Admin-SDK act, refused from clients, so an operator session cannot create operators. |

Known limits, stated rather than hidden: no MFA; no password policy beyond
Firebase's default; no rate limiting beyond Firebase's; rider-app and
firmware identities are designed for in the rules but not yet issued; helmet
ID uniqueness stays a client check because the rules language cannot express
it.

---

## 5. The alert lifecycle state machine

The thesis problem is emergency **response time** — the Golden Hour. The
console therefore does not just detect incidents, it moves them through a
strictly linear workflow and records who did what, when.

```
                  ┌──────────────────────────────────────────────┐
                  │                                              │
   helmet fires   ▼                                              │
   an alert   ┌────────┐  acknowledge  ┌──────────────┐          │
   ─────────► │  OPEN  │ ────────────► │ ACKNOWLEDGED │          │
              └────────┘               └──────────────┘          │
                  │                            │                 │
                  │                            │ dispatch        │
                  │                            │ (+ responder,   │
                  │                            │    optional note)
                  │                            ▼                 │
                  │                    ┌──────────────┐          │
                  │                    │  DISPATCHED  │          │
                  │                    └──────────────┘          │
                  │                            │                 │
                  │                            │ resolve         │
                  │                            ▼                 │
                  │                    ┌──────────────┐          │
                  │                    │   RESOLVED   │ ── terminal
                  │                    └──────────────┘
                  │                            │
                  │   every transition appends an AlertAction
                  └──────────────►  { toStatus, actorName, note,
                                      responder, at }  ──────────┘

  REJECTED (throws StateError, surfaced as a SnackBar):
    • skipping a step        OPEN ──✗──► DISPATCHED / RESOLVED
    • repeating a step       ACKNOWLEDGED ──✗──► ACKNOWLEDGED
    • moving backwards       DISPATCHED ──✗──► ACKNOWLEDGED
    • anything after         RESOLVED ──✗──► *
    • an unknown alert id
```

The machine itself lives on the enum, so the controller, the UI and this
document all read one definition:

```dart
// lib/shared/models/models.dart
AlertStatus? get nextStatus => switch (this) {
      AlertStatus.open         => AlertStatus.acknowledged,
      AlertStatus.acknowledged => AlertStatus.dispatched,
      AlertStatus.dispatched   => AlertStatus.resolved,
      AlertStatus.resolved     => null,
    };

bool canTransitionTo(AlertStatus target) => nextStatus == target;
```

### Side effects

- **Resolving releases the rider.** When an alert is resolved and its rider is
  in `RiderStatus.emergency` with no other *active* critical alert, the rider
  returns to `idle` — their dot on the map goes from red to normal. A rider is
  held red through `dispatched`, because responders are still en route.
- **The automatic stand-down never overwrites operator work.** The simulation
  clears emergencies once three pile up, but only for riders with **no active
  critical alert**. An alert the operator is working is untouchable until it
  is resolved or ages off the 40-alert board.
  *Consequence during a demo:* if nobody resolves anything, emergencies now
  persist rather than self-clearing. Clearing them is the operator's job.

### Derived response metrics

| Getter | Definition |
|---|---|
| `averageAcknowledgeTime` | mean of `acknowledged.at − alert.timestamp` |
| `averageResolveTime` | mean of `resolved.at − alert.timestamp` |
| `openCriticalCount` | crash/SOS alerts not yet resolved |

Elapsed time is measured **from when the helmet raised the alert**, not from
when the operator opened the page — that is the number the research is about.

---

## 6. Role matrix

Three roles, one account each in both worlds. The login page lists whichever
set applies and a tap fills the form (email only on the Firestore path).

**Firestore path — Firebase Auth accounts** in project `novaride-7a68c`.
Passwords are held by their owners and appear nowhere in this repository or
the UI. Roles come from `admins/{uid}` (FIRESTORE_SCHEMA.md §2).

| Email | Role |
|---|---|
| `qrlunatal@tip.edu.ph` | Super Admin |
| `qhjcagbayani@tip.edu.ph` | Dispatcher |
| `qdplegarde@tip.edu.ph` | Viewer |

**Simulation path — local demo accounts**, `LocalAdminAuth`. Not real
credentials; they exist so a checkout without Firebase config is usable.

| Email | Password | Role |
|---|---|---|
| `admin@novaride.ph` | `admin123` | Super Admin |
| `dispatch@novaride.ph` | `dispatch123` | Dispatcher |
| `viewer@novaride.ph` | `viewer123` | Viewer |

The capability matrix is identical on both paths — this work changed how an
operator authenticates, not what each role may do.

| Capability | Super Admin | Dispatcher | Viewer |
|---|:---:|:---:|:---:|
| Dashboard | ✅ | ✅ | ✅ |
| Rider Monitoring | ✅ | ✅ | ✅ |
| Alerts — view board | ✅ | ✅ | ✅ |
| Alerts — acknowledge / dispatch / resolve | ✅ | ✅ | ❌ |
| Reports & analytics, CSV export | ✅ | ✅ | ✅ |
| User Management tab visible | ✅ | ❌ | ❌ |
| Add / edit / deactivate riders | ✅ | ❌ | ❌ |

**Capability, not just visibility.** Hiding the User Management tab is a
convenience. The gate is `AdminRole.canManageRiders`, re-checked on the page
itself, and `AdminRole.canActOnAlerts`, checked in the alert detail panel.
Controls a role cannot use render disabled with a tooltip explaining why,
rather than vanishing — reviewers can see that the permission model exists.

**Nav/page index safety.** The shell builds one list of `(navItem, page)`
pairs from the role and indexes into that. A filtered nav list next to a
static page list would desynchronise, and the top bar would name a different
tab than the one on screen. `test/admin_shell_test.dart` asserts the title
matches the visible page for all three roles.

---

## 7. Screen inventory

| Screen | File | Status |
|---|---|---|
| Login | `admin_login_page.dart` | ✅ Complete — Firebase Auth on Firestore, demo accounts on the simulation; no accounts named, remembered email (address only), inline validation, keyboard-complete, autofill hints, in-flight guard, translated errors, version footer |
| Shell (sidebar, top bar) | `admin_shell.dart` | ✅ Complete — role-filtered nav, session chip, auth-stream listener that ends the session on sign-out or revocation |
| Dashboard | `dashboard_page.dart` | ✅ Complete — six live panels |
| Rider Monitoring | `rider_monitoring_page.dart` | ✅ Complete — map + roster + telemetry detail + breadcrumb trail |
| Alerts | `admin_alerts_page.dart` | ✅ Complete — KPIs, filters, sort, detail panel, full workflow |
| User Management | `user_management_page.dart` | ✅ Complete — register / edit / deactivate persisted to `riders/` with helmet pairing written to `devices/` in one transaction; optimistic roster with rollback; write failures shown as sentences that stay until dismissed; validation; sortable roster |
| Reports | `reports_page.dart` | ✅ Complete — response times, district/type breakdowns, incident log, CSV export |

Supporting widgets: `fleet_map_view.dart` (shared by the dashboard panel and
the monitoring page — one painter, not two), `fleet_table.dart`,
`kpi_card.dart`, `weekly_alerts_chart.dart`, `simple_bar_chart.dart`,
`dash_panel.dart`, `alert_feed_tile.dart`, `status_pill.dart`,
`filter_controls.dart`, `rider_form_dialog.dart`.

---

## 8. Simulated vs. real — full disclosure

**The console has two data sources and says which one it is on.** With
`assets/config/firebase.json` present it reads and writes Cloud Firestore
(`FIRESTORE` chip in the top bar); without it, everything below the UI is
simulated in-process (`SIMULATION` chip). Even on Firestore, no hardware is
involved yet — the seeded riders and their positions are the simulation's
fixtures written into the database once. This section states exactly what
that means, because a reviewer who discovers undisclosed mocking is entitled
to treat the whole module with suspicion.

### What is simulated

| Area | How it is faked today | What the real implementation will be |
|---|---|---|
| **Helmet telemetry** | Simulation: `MockFleetRepository` jitters lat/lng/speed for every `riding` rider every 3s via `Timer.periodic`. Battery, alcohol and GPS-fix are fixed seed values that never change. Firestore: whatever is in `devices/`, which today is the seed's static readings. | ESP32 publishes MPU6050 + MQ-3 + NEO-6M readings into `devices/{helmetId}`; the console already subscribes to that collection. |
| **Accident detection** | No detection at all. Alerts are *invented* on a random 10–14s timer, with a weighted type roll (18% crash, 16% SOS, 30% alcohol, 36% low battery) and a random rider and district. | On-helmet edge algorithm: MPU6050 magnitude threshold **intersected** with the YL-99 impact switch, so bumps and drops do not fire. The helmet raises the alert; the console only receives it. |
| **GPS position** | Random walk inside a fixed lat/lng box over Metro Manila, clamped to the window. | NEO-6M coordinates. |
| **Map** | `FleetMapView` paints a *stylized* basemap — a street grid, four avenues and a river drawn from hardcoded normalized coordinates. It is **not** Metro Manila's real road network. District centroids and the projection are real coordinates, so relative dot movement is geographically meaningful. No pan or zoom; the controls are decorative. | Google Maps Platform tiles with real markers. |
| **Breadcrumb trail** | Last 20 simulated fixes per rider, capped in memory. | Trip history from stored telemetry. |
| **Street addresses** | Hardcoded per district in `kFleetDistricts`; an alert borrows its district's address string. | Reverse geocode of the real coordinates. |
| **Authentication** | Simulation only: `LocalAdminAuth` compares against three demo accounts in `admin_session.dart`, labelled as such. **Firestore: real** — Firebase Auth email/password, role from a custom claim or `admins/{uid}`, unprovisioned accounts denied (§4). | Done on the Firestore path. Remaining: MFA, and rider/firmware identities. |
| **Responder dispatch** | Choosing a `ResponderType` records an audit entry. **Nobody is contacted.** | Integration with emergency services / the rider's emergency contacts. |
| **Persistence** | Simulation: none — state is in memory and lost on refresh or logout. Firestore: riders (register, edit, deactivate) and their helmet pairing, alerts and the acknowledge → dispatch → resolve audit trail persist across refresh and between operators, behind Auth-backed rules (FIRESTORE_SCHEMA.md §4). Roster writes are transactions: a refused or offline write is rolled back on screen and reported, never left looking saved. | Done on the Firestore path. |
| **"Resolved Today" / date ranges** | Operate on real data, but the seeded alerts are only minutes-to-hours old and the board caps at 40, so nearly everything falls inside "Today". The ranges filter correctly; they just have little history to separate. | Meaningful once real history accumulates. |
| **Weekly alerts chart** | Real counts bucketed from actual alert timestamps over the last 7 calendar days — but see the point above about how little history exists. | Same code, real history. |

### What is real

- The **alert lifecycle state machine** and its enforcement, including the
  audit trail — this is production logic, not a mock.
- **Response-time arithmetic** — computed from real recorded timestamps.
- **Rider validation** — helmet ID format and uniqueness, Philippine mobile
  normalization, sequential ID allocation.
- **Role-based access control** — the capability checks are real, and on
  the Firestore path so is the identity behind them: Firebase Auth, a role
  from `admins/{uid}` or a claim, and server-side rules that re-check it on
  every read and write (§4). Only the simulation's identity is mocked.
- **CSV export** — genuine RFC 4180 quoting over real in-memory data.
- All **layout, filtering, sorting and aggregation** logic.

### Known gaps

- On the simulation there is no persistence, so a refresh resets the demo.
- Battery, alcohol level and GPS-fix are static per rider; only position and
  speed move.
- The map cannot pan or zoom, and "Locate on map" highlights rather than
  re-centres (the window is fixed).
- Export is copy-from-dialog only — no file download, by design, to avoid a
  plugin dependency.
- Rider deactivation is reversible from the roster but there is no audit
  trail for roster changes (only alerts carry history).
- A deactivated rider keeps their helmet pairing, so the helmet cannot be
  given to a new rider until the old record is edited to a different
  serial. Releasing the helmet on deactivation is a one-line change in
  `FirestoreFleetRepository.setRiderActive`; it was left as is because it
  is a fleet-policy question (is a deactivation temporary?), not a code one.

---

## 9. Tests

```bash
flutter test
```

| File | Covers |
|---|---|
| `test/alert_workflow_test.dart` | Legal transitions, rejected transitions, audit-trail ordering, rider release on resolve, response metrics, stand-down safety |
| `test/fleet_controller_test.dart` | `statusCounts` / `alertsByArea` / `alertsByPriority` / `alertsByType` consistency after mutations, the 40-alert cap, ID uniqueness, roster CRUD guards, unmodifiable collections |
| `test/rider_validation_test.dart` | Helmet ID format and uniqueness, PH phone normalization, sequential IDs |
| `test/admin_shell_test.dart` | Boot, login, every tab renders, narrow layout, role gating, top-bar/page agreement, shared live feed |
| `test/admin_auth_test.dart` | `parseAdminRole` (verbatim, aliases, never defaults), `LocalAdminAuth`, error-message mapping never leaks a code, and — via a scripted `AdminAuth` — the login page's keyboard paths, validation, in-flight guard, remembered email, deny-on-unprovisioned, no raw exception text, and the shell leaving on a null or foreign auth event |
| `test/admin_layout_test.dart` | Every page's empty state and the simulation at 1280–1440 × 500–657 (projector, laptop, browser chrome) without a RenderFlex overflow, with the real font loaded |
| `test/roster_persistence_test.dart` | Optimistic roster writes against a scripted store: shown at once, kept through an older snapshot, withdrawn on refusal or after the 20 s deadline, following a store-assigned id; the narrow deactivation write; write-error messages never leak a code; the page's dismissable failure toast and inline duplicate-helmet refusal |
| `test/widget_test.dart` | Rider app still boots (guards the two-entrypoint split) |

The controller exposes `debugEmitAlert()` (`@visibleForTesting`) so tests can
step the simulation deterministically; calling the timer path directly would
reschedule and orphan the pending timer.

Note that the console never settles — the map pulse animation and two
simulation timers run continuously — so tests use explicit `pump(Duration)`
calls rather than `pumpAndSettle()`.
