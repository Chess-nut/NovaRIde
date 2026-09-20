# NovaRIde
An Integrated Internet of Things (IoT) Helmet Framework for Real-Time Accident Detection and Emergency Response Among Ride-Hailing Riders.

NovaRide ESP32 based high calibrated smart helmet system developed to overcome a crucial issue in emergency medical response time: the "Golden Hour", particularly for the Philippines motorcycle riders. Localizing computation (edge computing) and cross multiple sensors with intersecting triggering logic,NovaRide detects only the true collision while ignoring false triggers like road bump or dropped helmet.


## 🖥️ Admin Console

The operations console is a second Flutter entrypoint in the same repository,
used by dispatchers to monitor the helmet fleet and respond to accident alerts.

```bash
flutter run -t lib/main_admin.dart -d chrome --web-port 5173   # admin console
flutter run -t lib/main.dart                                   # rider app
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
are not in this repository. The login page lists these and a tap fills the
email only.

| Email | Role |
|---|---|
| `qrlunatal@tip.edu.ph` | Super Admin — everything |
| `qhjcagbayani@tip.edu.ph` | Dispatcher — alert workflow, no rider management |
| `qdplegarde@tip.edu.ph` | Viewer — read-only |

**Demo accounts (simulation path).** Not real credentials; also listed on the
login screen, click a row to fill the form.

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
flutter run -t lib/main_admin.dart -d chrome --web-port 5173 --dart-define=SEED_FIRESTORE=true
```

Adding an operator: create the account under Authentication → Users, then
create `admins/{uid}` with `name`, `email` and `role` (`superAdmin` |
`dispatcher` | `viewer`). An authenticated account with no such document is
refused at the console, not given a default role. Optionally,
`tool/set_admin_claims.mjs` puts the role in the ID token as a custom claim —
it needs a service-account key, which **grants full admin access to the whole
project, bypasses every security rule, and lives outside the repository**.
The script header has the PowerShell steps and the warnings.

See **[docs/ADMIN_MODULE.md](docs/ADMIN_MODULE.md)** for the architecture, the
authentication design, the alert state machine, the role matrix, and a full
"simulated vs. real" disclosure, and
**[docs/FIRESTORE_SCHEMA.md](docs/FIRESTORE_SCHEMA.md)** for the collections
and the security rules.

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

## Family Live Location

The Family Map route is `/family-map`. It currently consumes the existing
`FamilyRepository` mock stream, which is permission-gated by the connected
rider's `liveLocation` permission. The location payload shape is represented by
`RiderLocation` and is ready to be populated by a Firebase Realtime Database
listener at `riderTelemetry/{riderId}/location` when Firebase is added to the
project.

Google Maps keys are intentionally supplied through native build settings and
are not stored in this repository. For Android, provide the Gradle property
`GOOGLE_MAPS_API_KEY` when building. For iOS, set the `GOOGLE_MAPS_API_KEY`
build setting for the Runner target. The Android manifest and iOS delegate read
these values at runtime.

Useful checks:

```text
flutter pub get
flutter analyze
flutter test test/family_module_test.dart test/rider_location_test.dart
```
