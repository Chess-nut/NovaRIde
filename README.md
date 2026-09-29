# NovaRIde
An Integrated Internet of Things (IoT) Helmet Framework for Real-Time Accident Detection and Emergency Response Among Ride-Hailing Riders.

NovaRide ESP32 based high calibrated smart helmet system developed to overcome a crucial issue in emergency medical response time: the "Golden Hour", particularly for the Philippines motorcycle riders. Localizing computation (edge computing) and cross multiple sensors with intersecting triggering logic,NovaRide detects only the true collision while ignoring false triggers like road bump or dropped helmet.


## 🖥️ Admin Console

The operations console is a second Flutter entrypoint in the same repository,
used by dispatchers to monitor the helmet fleet and respond to accident alerts.

```bash
flutter run -t lib/main_admin.dart -d edge --web-port 5173   # admin console
flutter run -t lib/main.dart                                   # mobile app
```

Five tabs: **Dashboard** (live fleet grid), **Rider Monitoring** (map + telemetry
drill-down), **User Management** (rider CRUD), **Alerts** (the
open → acknowledged → dispatched → resolved response workflow with an audit
trail), and **Reports** (response-time analytics and CSV export).

### Two ways to run it

The console decides at startup, from one file, whether it is real or simulated,
and says which in its top bar:

| `assets/config/firebase.json` | Data | Sign-in | Top-bar chip |
|---|---|---|---|
| present | Cloud Firestore, project `novaride-7a68c` | **Firebase Auth** — the operator accounts below | `FIRESTORE` |
| absent (a fresh clone) | in-memory simulation | local demo accounts | `SIMULATION` |

A fresh clone is a simulation build with no extra steps; nothing about Firebase
can break a teammate who has never touched it.

**Operator accounts (Firestore path).** Passwords are held by their owners and
are not in this repository, and the login page names no account. Tick
*Remember my email on this browser* to skip retyping the address next time —
the address only is kept, in that browser's local storage.

| Email | Role |
|---|---|
| `qrlunatal@tip.edu.ph` | Super Admin — everything |
| `qhjcagbayani@tip.edu.ph` | Dispatcher — alert workflow, no rider management |
| `qdplegarde@tip.edu.ph` | Viewer — read-only |

**Demo accounts (simulation path).** Not real credentials, and not shown on
the login screen either — it looks the same on both paths, apart from a
*Simulation mode* line in its footer.

| Email | Password | Role |
|---|---|---|
| `admin@novaride.ph` | `admin123` | Super Admin |
| `dispatch@novaride.ph` | `dispatch123` | Dispatcher |
| `viewer@novaride.ph` | `viewer123` | Viewer |

### First-time setup against Firebase

Once per project, from the repo root, with the Firebase CLI signed in
(`firebase use` should print `novaride-7a68c`). PowerShell:

```powershell
# 1. Security rules, then indexes. Rules first: without them every read is
#    refused, including the admins/{uid} lookup sign-in depends on.
firebase deploy --only firestore:rules
firebase deploy --only firestore:indexes

# 2. Web config — gitignored, never committed. Trim the CLI preamble so the
#    file is just the JSON object (assets/config/firebase.example.json shows the shape).
firebase apps:sdkconfig WEB 1:885956155129:web:21670e7270e1ccc7dc3428 > assets/config/firebase.json

# 3. Seed the empty database with the simulation's fleet, ONCE. Start with the
#    flag, then sign in as the Super Admin — the seed runs at that moment,
#    because the rules only accept its writes from a signed-in Super Admin.
#    The terminal prints "seedFirestore: wrote 10 riders, …" when it lands.
flutter run -t lib/main_admin.dart -d edge --web-port 5173 --dart-define=SEED_FIRESTORE=true
```

Adding an operator: create the account under Authentication → Users, then
create `admins/{uid}` with `name`, `email` and `role` (`superAdmin` |
`dispatcher` | `viewer`). An authenticated account with no such document is
refused at the console, not given a default role. Optionally,
`tool/set_admin_claims.mjs` puts the role in the ID token as a custom claim —
it needs a service-account key, which **grants full admin access to the whole
project, bypasses every security rule, and lives outside the repository**.
The script header has the PowerShell steps and the warnings.

### Security-rules tests

`firestore.rules` is the only thing standing between the internet and the
riders' live positions, so it has tests of its own — 56 of them, run against
the Firestore emulator:

```powershell
cd rules_test
npm install     # once
npm test        # starts the emulator, runs the tests, shuts it down
```

They need a JDK on the PATH (Temurin 21) and download the emulator jar on
the first run. Nothing else leaves the machine: the tests use the project id
`demo-novaride`, which the Firebase tooling treats as non-existent, so they
can never reach `novaride-7a68c`. Run them before deploying rules.
See **[rules_test/README.md](rules_test/README.md)**.

See **[docs/ADMIN_MODULE.md](docs/ADMIN_MODULE.md)** for the architecture, the
authentication design, the alert state machine, the role matrix, and a full
"simulated vs. real" disclosure, and
**[docs/FIRESTORE_SCHEMA.md](docs/FIRESTORE_SCHEMA.md)** for the collections
and the security rules.

## 📱 Mobile app

```bash
flutter run -t lib/main.dart          # rider + guardian app
```

Riverpod for state, `go_router` for navigation — **mobile only**. The admin
console shares none of it (see
[docs/ADMIN_MODULE.md](docs/ADMIN_MODULE.md#2-state-management)).

```
lib/
  app/        app.dart (MaterialApp.router) · router.dart (routes + the auth
              gate) · di.dart (the composition root)
  core/       theme/ (colour, type and spacing tokens) · widgets/ (the
              shared form controls) · errors/ (Failure + the Firebase
              message mapper) · utils/ (AppLogger, Validators) ·
              constants/ (collection names, route names)
  features/   onboarding/ · auth/ · rider/ · guardian/
              each: domain/ (entities, repository interfaces)
                    data/   (implementations)
                    presentation/ (pages, widgets, providers)
  shared/     models and the admin console's palette
  admin/      the operations console — a separate entrypoint, untouched
```

**The auth gate.** One redirect in `app/router.dart` decides everything:
splash while the session is unknown, the signed-out screens when there is
no session, the verify-email screen when an account has not confirmed its
address, and otherwise the home for that account's role. It reads
`authStateProvider`, which is a **placeholder** until Phase 3: the login
screen's demo credential (`admin` / `admin123`) sets it, and there is no
Firebase behind it. Signing in does not navigate — it sets the session and
lets the gate do the navigating, which is the path real auth will take.
`test/mobile_router_test.dart` pins the behaviour down so swapping in
Firebase cannot change it by accident.

### Design: direction Signal

Dark, quiet, typographic. Two rules hold it together and both are worth
keeping when adding a screen:

1. **One action colour.** `AppColors.action` (the green) is the only
   saturated thing a person is meant to press. Two green things on one
   screen means one of them is wrong.
2. **Colour elsewhere always means status.** `safe`, `riding`, `warning`,
   `critical`, `sos`, `offline`, `resolved`. Nothing is coloured to look
   nice — an accent spent on decoration is attention taken from the
   critical states.

Tokens live in [lib/core/theme/](lib/core/theme/): `app_colors.dart`
(semantic colours), `app_typography.dart` (a seven-step scale),
`app_spacing.dart` (spacing, radii, sizes, durations).

**Widgets never name a colour.** `AppColors` is a `ThemeExtension`, read
as `context.colors.action`, so the palette arrives through the theme
rather than by import. `AppTheme.from(palette)` takes the palette as an
argument and hardcodes nothing.

**A light theme is not built, and adding one is three steps:** write
`AppColors.light`, pass `AppTheme.from(AppColors.light, brightness:
Brightness.light)` as `MaterialApp.theme`, and set `themeMode`. No widget
changes and no `if (isDark)` anywhere. `themeMode` is already wired
through `MaterialApp` from `themeModeProvider`.

`test/theme_contract_test.dart` enforces this rather than trusting it: it
proves a second palette reaches widgets untouched, and it scans
`core/widgets/`, `features/auth/` and `features/onboarding/` for
`Color(0x…)` literals, `Colors.*` constants and imports of the admin
palette. Those tests fail the first time a colour is written into a
widget.

**Font.** Signal was specified with Inter; this ships on Roboto, the SDK's
own face, already bundled and already what the layout tests measure
against. `AppTypography.fontFamily` is the one line that changes if Inter
is ever added, which would mean committing four font files and a `fonts:`
block.

**Two rules worth knowing before adding code here.** No feature file spells
a Firestore collection name as a string — they are all in
`core/constants/firestore_collections.dart`. And no feature file shows a
raw exception: a data source catches once, maps with
`core/errors/firebase_failure_mapper.dart`, and everything above handles a
`Failure` whose `message` is already a sentence.

## 🛠️ Tools & Technologies Used

### Hardware / IoT Components
 - **NodeMCU ESP32:** Dual-core 32-bit central microcontroller managing the localized edge computing crash detection algorithms.
 - **MPU6050 Accelerometer/Gyroscope:** Continuously measures tri-axial acceleration changes ($A = \sqrt{X^2 + Y^2 + Z^2}$).
 - **YL-99 Crash Collision Sensor:** Mechanical impact switch utilized in tandem with the MPU6050 for intersecting trigger validation.
 - **MQ-3 Alcohol Gas Sensor:** Preventive sensor situated in the mouth vent to monitor breath alcohol concentration levels.
 - **NEO-6M GPS Module:** Captures high-precision geographical coordinates (Latitude and Longitude) in real-time.

### Software Stack
 - **Firmware:** Arduino IDE
 - **Mobile App Development:** Flutter SDK & Dart Language (Cross-platform for Android clients)
 - **Web Portal Development:** HTML5, CSS3, and PHP
 - **Backend & Cloud Database:** Firebase Realtime Database & Firebase Authentication
 - **Mapping Integration:** Google Maps Platform API

## Google Maps keys

The rider and family screens use `google_maps_flutter`. **Keys are supplied at
build time and no tracked file holds one.** There are three keys, not one,
because Google Cloud lets a key carry a single application restriction — HTTP
referrers, *or* an Android package + signing SHA-1, *or* an iOS bundle id — so
a key locked to one platform cannot serve another.

| Platform | Define / setting | Where it is read |
|---|---|---|
| Android | `GOOGLE_MAPS_API_KEY_ANDROID` (`--dart-define`) | `android/app/build.gradle.kts` decodes the build's dart-defines into the manifest placeholder |
| Web | `GOOGLE_MAPS_API_KEY_WEB` (`--dart-define`) | `lib/shared/maps/` injects the Maps JS `<script>` at startup; `web/index.html` carries no key |
| iOS | `GOOGLE_MAPS_API_KEY_IOS` (Xcode build setting) | `ios/Flutter/Secrets.xcconfig`, gitignored — copy `Secrets.example.xcconfig` |

Day to day, put the defines in a gitignored file and pass it once:

```powershell
Copy-Item dart_defines.example.json dart_defines.local.json   # then fill it in
flutter run -t lib/main.dart --dart-define-from-file=dart_defines.local.json
```

Rotating a key is a one-line edit of that file. Without a key the build still
succeeds and the map renders blank tiles, which is the intended state of a
checkout without credentials.

> **History.** Commit `d9f4ce0` (14 Sep 2026) committed a Maps browser key
> into `web/index.html`, and replaced the placeholder *names* in the Android
> and iOS config with the key literal, which broke those two platforms. The
> key lives in git history, so treat it as compromised: regenerate it in
> Google Cloud and restrict the replacements as described above.

## Family Live Location

The Family Map route is `/guardian/map` (`AppRoutes.guardianMapPath`; it was
`/family-map` before the router landed). It currently consumes the existing
`FamilyRepository` mock stream, which is permission-gated by the connected
rider's `liveLocation` permission. The location payload shape is represented by
`RiderLocation` and is ready to be populated by a Firestore listener when the
rider app is connected to Firebase.

Useful checks:

```text
flutter pub get
flutter analyze
flutter test
```
