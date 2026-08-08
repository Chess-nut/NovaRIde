# NovaRide Admin Module — Architecture & Status

The operations console used by NovaRide dispatchers to watch the helmet fleet
and respond to accident alerts. This document covers how it is put together,
why those choices were made, and — explicitly — which parts are simulated.

**Run it:**

```bash
flutter run -t lib/main_admin.dart -d chrome
```

**Demo credentials** are listed on the login screen itself; see
[Roles](#role-matrix) below.

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
AdminApp
└── AdminLoginPage                  authenticate() → AdminUser
    └── AdminShell(user)
        ├── AdminSessionScope       who is signed in (InheritedWidget)
        └── FleetHost               OWNS the MockFleetController
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

Pages read state with `FleetScope.of(context)` and wrap the reactive part in a
`ListenableBuilder`.

---

## 3. `FleetScope` — the Firebase injection seam

`FleetScope` is the single place a Firestore-backed controller gets injected.

```dart
// lib/admin/state/fleet_scope.dart
class FleetScope extends InheritedNotifier<MockFleetController> { ... }

class _FleetHostState extends State<FleetHost> {
  late final MockFleetController _fleet;

  @override
  void initState() {
    super.initState();
    _fleet = MockFleetController();   // ← the one line that changes
  }
}
```

Migration plan, when the ESP32 telemetry feed and Firestore are connected:

| Today (mock) | Later (Firestore) |
|---|---|
| `Timer.periodic` jitter loop | `snapshots()` on `telemetry/{riderId}` |
| `Timer` alert spawner | `snapshots()` on `alerts` |
| `List<Rider> _riders` in memory | `snapshots()` on `riders` |
| `_transition()` mutates the list | `update()` on `alerts/{id}` + append to `alerts/{id}/history`; the snapshot echoes the write back |
| `addRider` / `updateRider` | `set()` / `update()` on `riders/{id}` |
| `RiderValidation` runs client-side | same predicates as Firestore security rules, plus a uniqueness constraint on `helmetId` |
| `authenticate()` over `demoAccounts` | Firebase Auth + a custom claim carrying `AdminRole` |

Because every page consumes only the controller's public getters and
mutations, none of them change. Seam comments marking these points are kept
in `mock_data.dart`, `mock_fleet_controller.dart`, `fleet_scope.dart`,
`rider_validation.dart` and `admin_session.dart`.

---

## 4. The alert lifecycle state machine

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

## 5. Role matrix

Three demo accounts, documented on the login screen and clickable to fill the
form.

| Email | Password | Role |
|---|---|---|
| `admin@novaride.ph` | `admin123` | Super Admin |
| `dispatch@novaride.ph` | `dispatch123` | Dispatcher |
| `viewer@novaride.ph` | `viewer123` | Viewer |

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

## 6. Screen inventory

| Screen | File | Status |
|---|---|---|
| Login | `admin_login_page.dart` | ✅ Complete — three roles, demo card |
| Shell (sidebar, top bar) | `admin_shell.dart` | ✅ Complete — role-filtered nav, session chip |
| Dashboard | `dashboard_page.dart` | ✅ Complete — six live panels |
| Rider Monitoring | `rider_monitoring_page.dart` | ✅ Complete — map + roster + telemetry detail + breadcrumb trail |
| Alerts | `admin_alerts_page.dart` | ✅ Complete — KPIs, filters, sort, detail panel, full workflow |
| User Management | `user_management_page.dart` | ✅ Complete — CRUD, validation, sortable roster |
| Reports | `reports_page.dart` | ✅ Complete — response times, district/type breakdowns, incident log, CSV export |

Supporting widgets: `fleet_map_view.dart` (shared by the dashboard panel and
the monitoring page — one painter, not two), `fleet_table.dart`,
`kpi_card.dart`, `weekly_alerts_chart.dart`, `simple_bar_chart.dart`,
`dash_panel.dart`, `alert_feed_tile.dart`, `status_pill.dart`,
`filter_controls.dart`, `rider_form_dialog.dart`.

---

## 7. Simulated vs. real — full disclosure

**Everything below the UI is currently simulated. No hardware, network or
database is involved.** This section states exactly what that means, because
a reviewer who discovers undisclosed mocking is entitled to treat the whole
module with suspicion.

### What is simulated

| Area | How it is faked today | What the real implementation will be |
|---|---|---|
| **Helmet telemetry** | `MockFleetController` jitters lat/lng/speed for every `riding` rider every 3s via `Timer.periodic`. Battery, alcohol and GPS-fix are fixed seed values that never change. | ESP32 publishes MPU6050 + MQ-3 + NEO-6M readings; the app subscribes to a Firestore/RTDB stream. |
| **Accident detection** | No detection at all. Alerts are *invented* on a random 10–14s timer, with a weighted type roll (18% crash, 16% SOS, 30% alcohol, 36% low battery) and a random rider and district. | On-helmet edge algorithm: MPU6050 magnitude threshold **intersected** with the YL-99 impact switch, so bumps and drops do not fire. The helmet raises the alert; the console only receives it. |
| **GPS position** | Random walk inside a fixed lat/lng box over Metro Manila, clamped to the window. | NEO-6M coordinates. |
| **Map** | `FleetMapView` paints a *stylized* basemap — a street grid, four avenues and a river drawn from hardcoded normalized coordinates. It is **not** Metro Manila's real road network. District centroids and the projection are real coordinates, so relative dot movement is geographically meaningful. No pan or zoom; the controls are decorative. | Google Maps Platform tiles with real markers. |
| **Breadcrumb trail** | Last 20 simulated fixes per rider, capped in memory. | Trip history from stored telemetry. |
| **Street addresses** | Hardcoded per district in `kFleetDistricts`; an alert borrows its district's address string. | Reverse geocode of the real coordinates. |
| **Authentication** | `authenticate()` compares against three hardcoded accounts in `admin_session.dart`. Passwords are plaintext in source. | Firebase Auth; role as a custom claim. |
| **Responder dispatch** | Choosing a `ResponderType` records an audit entry. **Nobody is contacted.** | Integration with emergency services / the rider's emergency contacts. |
| **Persistence** | None. All state is in memory and is lost on refresh or logout. | Firestore. |
| **"Resolved Today" / date ranges** | Operate on real data, but the seeded alerts are only minutes-to-hours old and the board caps at 40, so nearly everything falls inside "Today". The ranges filter correctly; they just have little history to separate. | Meaningful once real history accumulates. |
| **Weekly alerts chart** | Real counts bucketed from actual alert timestamps over the last 7 calendar days — but see the point above about how little history exists. | Same code, real history. |

### What is real

- The **alert lifecycle state machine** and its enforcement, including the
  audit trail — this is production logic, not a mock.
- **Response-time arithmetic** — computed from real recorded timestamps.
- **Rider validation** — helmet ID format and uniqueness, Philippine mobile
  normalization, sequential ID allocation.
- **Role-based access control** — the capability checks are real; only the
  identity behind them is mocked.
- **CSV export** — genuine RFC 4180 quoting over real in-memory data.
- All **layout, filtering, sorting and aggregation** logic.

### Known gaps

- No persistence, so a refresh resets the demo.
- Battery, alcohol level and GPS-fix are static per rider; only position and
  speed move.
- The map cannot pan or zoom, and "Locate on map" highlights rather than
  re-centres (the window is fixed).
- Export is copy-from-dialog only — no file download, by design, to avoid a
  plugin dependency.
- Rider deactivation is reversible from the roster but there is no audit
  trail for roster changes (only alerts carry history).

---

## 8. Tests

```bash
flutter test
```

| File | Covers |
|---|---|
| `test/alert_workflow_test.dart` | Legal transitions, rejected transitions, audit-trail ordering, rider release on resolve, response metrics, stand-down safety |
| `test/fleet_controller_test.dart` | `statusCounts` / `alertsByArea` / `alertsByPriority` / `alertsByType` consistency after mutations, the 40-alert cap, ID uniqueness, roster CRUD guards, unmodifiable collections |
| `test/rider_validation_test.dart` | Helmet ID format and uniqueness, PH phone normalization, sequential IDs |
| `test/admin_shell_test.dart` | Boot, login, every tab renders, narrow layout, role gating, top-bar/page agreement, shared live feed |
| `test/widget_test.dart` | Rider app still boots (guards the two-entrypoint split) |

The controller exposes `debugEmitAlert()` (`@visibleForTesting`) so tests can
step the simulation deterministically; calling the timer path directly would
reschedule and orphan the pending timer.

Note that the console never settles — the map pulse animation and two
simulation timers run continuously — so tests use explicit `pump(Duration)`
calls rather than `pumpAndSettle()`.
