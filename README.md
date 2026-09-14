# NovaRIde
An Integrated Internet of Things (IoT) Helmet Framework for Real-Time Accident Detection and Emergency Response Among Ride-Hailing Riders.

NovaRide ESP32 based high calibrated smart helmet system developed to overcome a crucial issue in emergency medical response time: the "Golden Hour", particularly for the Philippines motorcycle riders. Localizing computation (edge computing) and cross multiple sensors with intersecting triggering logic,NovaRide detects only the true collision while ignoring false triggers like road bump or dropped helmet.


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
