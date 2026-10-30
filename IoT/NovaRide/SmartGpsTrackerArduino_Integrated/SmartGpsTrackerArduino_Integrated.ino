#include <Arduino.h>
#include <DNSServer.h>
#include <HardwareSerial.h>
#include <HTTPClient.h>
#include <Preferences.h>
#include <TinyGPS++.h>
#include <WebServer.h>
#include <WiFi.h>
#include <WiFiClientSecure.h>
#include <Wire.h>
#include <Update.h>

#include "config.h"

#ifndef TRACKER_AP_SSID
#define TRACKER_AP_SSID "AppSetup"
#endif  

#ifndef TRACKER_AP_PASSWORD
#define TRACKER_AP_PASSWORD "12345678"
#endif

#ifndef CELLULAR_APN
#define CELLULAR_APN ""
#endif

#ifndef CELLULAR_APN_USER
#define CELLULAR_APN_USER ""
#endif

#ifndef CELLULAR_APN_PASSWORD
#define CELLULAR_APN_PASSWORD ""
#endif

#ifndef CELLULAR_PDP_TYPE
#define CELLULAR_PDP_TYPE "IPV4V6"
#endif

// 1 = Cloud Firestore devices/{DEVICE_ID}; 0 = legacy Realtime Database paths.
#ifndef USE_FIRESTORE
#define USE_FIRESTORE 1
#endif

#ifndef FIRMWARE_VERSION
#define FIRMWARE_VERSION "2026.10.30-fs"
#endif

// Seeed XIAO ESP32-C3 current project pinout
constexpr int AIR_RX = 5;      // ESP32 RX <- AIR780E TXD
constexpr int AIR_TX = 4;      // ESP32 TX -> AIR780E RXD
constexpr int GPS_RX = 20;     // ESP32 RX <- NEO-6M TX
constexpr int GPS_TX = 21;     // ESP32 TX -> NEO-6M RX (optional)
constexpr int BUZZER_PIN = 2;  // XIAO D0/GPIO2; GPIO1 is not exposed on standard XIAO headers
constexpr int SW420_PIN = 8;   // SW-420 digital OUT
constexpr int LED_PIN = 10;
constexpr int MPU_SDA = 6;
constexpr int MPU_SCL = 7;
constexpr int MQ3_PIN = 3;     // MQ-3 AO; must be <= 3.3 V
constexpr uint8_t MPU6050_ADDR = 0x68;
constexpr uint8_t MPU6050_REG_PWR_MGMT_1 = 0x6B;
constexpr uint8_t MPU6050_REG_ACCEL_XOUT_H = 0x3B;

constexpr uint32_t GPS_BAUD = 9600;
constexpr uint32_t AIR_BAUD = 9600;
constexpr uint32_t SERIAL_BAUD = 115200;

constexpr uint32_t WIFI_CONNECT_TIMEOUT_MS = 15000;
constexpr uint32_t WIFI_ALERT_CONNECT_TIMEOUT_MS = 30000;
constexpr uint32_t GPS_FIX_TIMEOUT_MS = 30000;
constexpr uint32_t ALARM_DURATION_MS = 5000;
constexpr uint32_t SMS_RESPONSE_TIMEOUT_MS = 90000;
constexpr uint32_t AIR_STATUS_CHECK_INTERVAL_MS = 30000;
constexpr uint32_t FIREBASE_STATUS_CHECK_INTERVAL_MS = 30000;
constexpr uint32_t FIREBASE_HTTP_TIMEOUT_MS = 12000;
constexpr uint32_t PERIODIC_LOCATION_UPLOAD_INTERVAL_MS = 300000;
constexpr uint32_t PERIODIC_LOCATION_MAX_AGE_MS = 30000;
constexpr uint32_t CELLULAR_CONNECT_TIMEOUT_MS = 60000;
constexpr uint32_t CELLULAR_HTTP_TIMEOUT_MS = 90000;
constexpr uint32_t CELLULAR_STATUS_CHECK_INTERVAL_MS = 60000;
constexpr uint32_t MORSE_UNIT_MS = 80;
constexpr uint32_t MORSE_DOT_MS = MORSE_UNIT_MS;
constexpr uint32_t MORSE_DASH_MS = MORSE_UNIT_MS * 3;
constexpr uint32_t MORSE_SYMBOL_GAP_MS = MORSE_UNIT_MS;
constexpr uint32_t MORSE_LETTER_GAP_MS = MORSE_UNIT_MS * 3;
constexpr uint32_t MORSE_WORD_GAP_MS = MORSE_UNIT_MS * 7;
constexpr uint32_t ACCEL_SAMPLE_INTERVAL_MS = 50;
constexpr uint32_t FALL_FREEFALL_MIN_MS = 120;
constexpr uint32_t FALL_IMPACT_WINDOW_MS = 1500;
constexpr uint32_t FALL_ALERT_COOLDOWN_MS = 30000;
constexpr float FALL_FREEFALL_THRESHOLD_G = 0.35f;
constexpr float FALL_IMPACT_THRESHOLD_G = 2.50f;
constexpr bool SHAKE_TEST_MODE = false;
constexpr float SHAKE_TEST_THRESHOLD_G = 1.25f;
constexpr byte DNS_PORT = 53;

HardwareSerial air780e(1);
HardwareSerial gpsSerial(0);
TinyGPSPlus gps;
WebServer webServer(80);
DNSServer dnsServer;
Preferences preferences;

struct LocationFix {
  bool valid = false;
  double lat = 0;
  double lng = 0;
  double speedKmph = 0;
  double altitudeM = 0;
  uint32_t satellites = 0;
  uint32_t ageMs = 0;
};

struct AccelReading {
  bool valid = false;
  float xG = 0;
  float yG = 0;
  float zG = 0;
  float magnitudeG = 0;
};

uint32_t lastAirStatusCheckMs = 0;
uint32_t lastFirebaseCheckMs = 0;
uint32_t lastCellularStatusCheckMs = 0;
uint32_t lastPeriodicLocationUploadMs = 0;
uint32_t wifiDisconnectedSinceMs = 0;
uint32_t lastAccelSampleMs = 0;
uint32_t freefallStartMs = 0;
uint32_t impactWindowStartMs = 0;
uint32_t lastFallAlertMs = 0;
uint32_t morseNextStepMs = 0;
uint32_t gpsCharsReceived = 0;
uint32_t lastNmeaMs = 0;
LocationFix lastKnownFix;
AccelReading latestAccel;
String savedWifiSsid;
String savedWifiPassword;
String savedRecipientPhone;
String activeNmeaSentence;
String latestNmeaSentence = "Waiting for NMEA data...";
bool air780eReady = false;
bool gpsStartupReady = false;
bool firebaseConnected = false;
bool cellularDataReady = false;
bool adxl345Ready = false; // retained name; represents MPU6050 readiness
bool waitingForImpact = false;
bool alertInProgress = false;
bool alarmActive = false;
bool morseToneActive = false;
uint8_t adxl345Address = MPU6050_ADDR;
size_t morsePatternIndex = 0;
int lastFirebaseHttpStatus = 0;
String lastWifiStatus = "Wi-Fi not connected";
String lastFirebaseStatus = "Firebase not checked yet";
String lastSmsStatus = "No SMS yet";
String lastAccelStatus = "Accelerometer not checked yet";
String lastCellularStatus = "Cellular data not checked yet";

String lastTrackingStatus = "Tracking upload not sent yet";
int mq3Raw = 0;
float mq3Voltage = 0.0f;
float alcoholRelativeIndex = 0.0f; // relative index until calibrated against known gas
int alcoholThresholdPpm = 300;
bool sw420Active = false;
String customSmsMessage = "Emergency! Possible rider crash detected.";
String alertPattern = "rapid";
uint16_t alertToneHz = 2200;
uint32_t lastSafetyUploadMs = 0, lastVibrationMs = 0, gpsStationarySinceMs = 0;
uint32_t tiltedSinceMs = 0, lastRiderCheckMs = 0, bootBlinkMs = 0;
bool bootLedState = false, alcoholAlertActive = false, crashAlertLatched = false;
bool baselineOrientationSet = false;
float baselineXG = 0, baselineYG = 0, baselineZG = 1, tiltDegrees = 0;
double stationaryLat = 0, stationaryLng = 0;
String orientationText = "Unknown";
String safetyEventStatus = "Monitoring";

void feedGps(uint32_t durationMs);
void processGpsChar(char c);
bool gpsHasNmeaData();
void waitForGpsStartup();
bool waitForGpsFix(LocationFix &fix, uint32_t timeoutMs);
bool connectWifi(uint32_t timeoutMs);
bool checkFirebaseConnection(bool force);
bool checkFirebaseConnectionOverCellular();
bool uploadLocationToFirebase(const LocationFix &fix, const char *reason);
bool uploadLocationToFirebaseOverCellular(const LocationFix &fix, const char *reason);
bool uploadPeriodicLocationToFirebase(const LocationFix &fix);
bool uploadPeriodicLocationToFirebaseOverCellular(const LocationFix &fix);
void handlePeriodicLocationUpload();
bool ensureAir780eGprs(bool force);
bool air780eHttpPost(const String &url, const String &payload, int &httpStatus, String &response);
String firebaseUrlWithMethodOverride(const String &path, const String &method);
String appendUrlParam(const String &url, const String &key, const String &value);
String buildDeviceStatusJson(const char *transport);
String buildTrackingLocationJson(const LocationFix &fix);
bool sendSmsLocation(const LocationFix &fix, const char *reason);
bool sendAT(const String &command, const String &expected, uint32_t timeoutMs);
String readAir780eUntil(const String &expected, uint32_t timeoutMs);
String readAir780eUntilHttpAction(uint32_t timeoutMs);
bool initializeAir780e();
String buildMapsUrl(const LocationFix &fix);
String firebaseUrl(const String &path);
String buildLocationJson(const LocationFix &fix, const char *reason, const char *transport);
void setAlarm(bool enabled);
void serviceAlarm();
void keepAlarmActive(uint32_t durationMs);
void playReadyMorseOk();
void playMorsePatternBlocking(const char *pattern);
void buzzerOn();
void buzzerOff();
void handleEmergencyAlert(const char *reason, bool sendSmsEvenIfUploaded);
bool initializeAdxl345();
bool readAdxlRegister(uint8_t address, uint8_t reg, uint8_t &value);
bool writeAdxlRegister(uint8_t reg, uint8_t value);
bool readAdxlBytes(uint8_t reg, uint8_t *buffer, size_t length);
bool readAccelerometer(AccelReading &reading);
void processFallDetector();
void loadWifiSettings();
String configuredWifiSsid();
String configuredWifiPassword();
String configuredRecipientPhone();
void startAccessPoint();
void setupWebServer();
void handleWebClients();
void handleRoot();
void handleSaveWifi();
void handleSaveRecipient();
void handleSaveSafetySettings();
void handleFirmwareUpdateComplete();
void handleFirmwareUpload();
void handleApiStatus();
void handleClearWifi();
void handleNotFound();
String buildStatusPage();
String htmlEscape(const String &value);
String gpsStatusText();
String airStatusText();
String wifiStatusText();
String wifiStatusCodeText(wl_status_t status);
String firebaseStatusText();
String recipientStatusText();
String accelStatusText();
String cellularStatusText();
bool checkAir780e(bool force);
void sampleAlcoholSensor();
void updateBootIndicator();
void uploadSafetyTelemetryIfDue();
bool writeMpuRegister(uint8_t reg, uint8_t value);
bool readMpuBytes(uint8_t reg, uint8_t *buffer, size_t length);
#if USE_FIRESTORE
bool firestoreWriteTelemetry(bool overCellular, int &httpStatus, String &statusText);
String buildFirestoreTelemetryCommit();
#endif

void setup() {
  pinMode(BUZZER_PIN, OUTPUT);
  pinMode(LED_PIN, OUTPUT);
  pinMode(SW420_PIN, INPUT_PULLUP);
  pinMode(MQ3_PIN, INPUT);
  lastVibrationMs = millis();
  setAlarm(false);

  Serial.begin(SERIAL_BAUD);
  delay(500);

  analogReadResolution(12);
  analogSetPinAttenuation(MQ3_PIN, ADC_11db);
  gpsSerial.begin(GPS_BAUD, SERIAL_8N1, GPS_RX, GPS_TX);
  air780e.begin(AIR_BAUD, SERIAL_8N1, AIR_RX, AIR_TX);
  Wire.begin(MPU_SDA, MPU_SCL);

  // Do not block boot waiting for GPS: keep the web interface available while acquiring signals.

  Serial.println();
  Serial.println("Smart GPS Tracker prototype starting...");

  loadWifiSettings();
  startAccessPoint();
  setupWebServer();

  if (initializeAir780e()) {
    Serial.println("AIR780E ready.");
  } else {
    Serial.println("AIR780E did not respond. Check power, GND, and RX/TX wiring.");
  }

  if (initializeAdxl345()) {
    Serial.println("MPU6050 ready.");
  } else {
    Serial.println("MPU6050 not detected. Check VCC, GND, SDA, SCL, and AD0.");
  }

  connectWifi(WIFI_CONNECT_TIMEOUT_MS);
  if (air780eReady && adxl345Ready) {
    playReadyMorseOk();
  }
}

void loop() {
  serviceAlarm();
  feedGps(20);
  sw420Active = (digitalRead(SW420_PIN) == LOW);
  if (sw420Active) lastVibrationMs = millis();
  processFallDetector();
  handlePeriodicLocationUpload();
  handleWebClients();

  if (millis() - lastAirStatusCheckMs > AIR_STATUS_CHECK_INTERVAL_MS) {
    checkAir780e(false);
  }

  if (WiFi.status() == WL_CONNECTED && millis() - lastFirebaseCheckMs > FIREBASE_STATUS_CHECK_INTERVAL_MS) {
    checkFirebaseConnection(false);
  }

  if (WiFi.status() != WL_CONNECTED) {
    if (wifiDisconnectedSinceMs == 0) {
      wifiDisconnectedSinceMs = millis();
    }

    static uint32_t lastReconnectAttemptMs = 0;
    if (millis() - lastReconnectAttemptMs > 30000) {
      lastReconnectAttemptMs = millis();
      connectWifi(5000);
    }

    if (millis() - wifiDisconnectedSinceMs > WIFI_ALERT_CONNECT_TIMEOUT_MS &&
        millis() - lastCellularStatusCheckMs > CELLULAR_STATUS_CHECK_INTERVAL_MS) {
      lastCellularStatusCheckMs = millis();
      checkFirebaseConnection(false);
    }

    if (!firebaseConnected && millis() - wifiDisconnectedSinceMs <= WIFI_ALERT_CONNECT_TIMEOUT_MS) {
      lastFirebaseStatus = "Waiting for Wi-Fi, cellular fallback starts after 30 seconds";
    }
  } else {
    wifiDisconnectedSinceMs = 0;
  }

  sampleAlcoholSensor();
  updateBootIndicator();
  uploadSafetyTelemetryIfDue();
}

void handleEmergencyAlert(const char *reason, bool sendSmsEvenIfUploaded) {
  if (alertInProgress) {
    return;
  }

  alertInProgress = true;
  Serial.print("Emergency alert triggered: ");
  Serial.println(reason);
  setAlarm(true);

  LocationFix fix;
  bool hasFreshFix = waitForGpsFix(fix, GPS_FIX_TIMEOUT_MS);
  if (!hasFreshFix && lastKnownFix.valid) {
    fix = lastKnownFix;
    Serial.println("Using last known GPS fix.");
  }

  if (!fix.valid) {
    Serial.println("No GPS fix available yet. Move the GPS antenna near a window or outdoors.");
    keepAlarmActive(ALARM_DURATION_MS);
    setAlarm(false);
    alertInProgress = false;
    return;
  }

  Serial.print("Location: ");
  Serial.print(fix.lat, 6);
  Serial.print(",");
  Serial.println(fix.lng, 6);

  bool uploaded = false;
  if (connectWifi(WIFI_ALERT_CONNECT_TIMEOUT_MS)) {
    uploaded = uploadLocationToFirebase(fix, reason);
  }

  if (!uploaded) {
    Serial.println("Wi-Fi Firebase upload failed or Wi-Fi unavailable. Trying AIR780E cellular data.");
    uploaded = uploadLocationToFirebaseOverCellular(fix, reason);
  }

  if (sendSmsEvenIfUploaded || !uploaded) {
    if (!uploaded) {
      Serial.println("Firebase upload failed on Wi-Fi and cellular. Sending SMS fallback.");
    } else {
      Serial.println("Firebase upload finished. Sending SMS for this alert.");
    }
    sendSmsLocation(fix, reason);
  }

  keepAlarmActive(ALARM_DURATION_MS);
  setAlarm(false);
  alertInProgress = false;
}

void feedGps(uint32_t durationMs) {
  uint32_t startMs = millis();
  do {
    serviceAlarm();
    while (gpsSerial.available()) {
      processGpsChar(char(gpsSerial.read()));
    }
  } while (millis() - startMs < durationMs);

  if (gps.location.isValid()) {
    lastKnownFix.valid = true;
    lastKnownFix.lat = gps.location.lat();
    lastKnownFix.lng = gps.location.lng();
    lastKnownFix.speedKmph = gps.speed.isValid() ? gps.speed.kmph() : 0;
    lastKnownFix.altitudeM = gps.altitude.isValid() ? gps.altitude.meters() : 0;
    lastKnownFix.satellites = gps.satellites.isValid() ? gps.satellites.value() : 0;
    lastKnownFix.ageMs = gps.location.age();
  }
}

void processGpsChar(char c) {
  gps.encode(c);
  gpsCharsReceived++;

  if (c == '\r') {
    return;
  }

  if (c == '\n') {
    if (activeNmeaSentence.length() > 0) {
      latestNmeaSentence = activeNmeaSentence;
      lastNmeaMs = millis();
      activeNmeaSentence = "";
    }
    return;
  }

  if (c == '$') {
    activeNmeaSentence = "$";
    return;
  }

  if (activeNmeaSentence.length() < 120) {
    activeNmeaSentence += c;
  }
}

bool gpsHasNmeaData() {
  return gps.passedChecksum() > 0 || latestNmeaSentence.startsWith("$");
}

void waitForGpsStartup() { /* startup is non-blocking */ }

bool waitForGpsFix(LocationFix &fix, uint32_t timeoutMs) {
  uint32_t startMs = millis();
  while (millis() - startMs < timeoutMs) {
    feedGps(100);
    if (gps.location.isValid() && gps.location.age() < 5000) {
      fix.valid = true;
      fix.lat = gps.location.lat();
      fix.lng = gps.location.lng();
      fix.speedKmph = gps.speed.isValid() ? gps.speed.kmph() : 0;
      fix.altitudeM = gps.altitude.isValid() ? gps.altitude.meters() : 0;
      fix.satellites = gps.satellites.isValid() ? gps.satellites.value() : 0;
      fix.ageMs = gps.location.age();
      lastKnownFix = fix;
      return true;
    }
  }
  return false;
}

bool connectWifi(uint32_t timeoutMs) {
  if (WiFi.status() == WL_CONNECTED) {
    lastWifiStatus = "Connected. IP: " + WiFi.localIP().toString() + ", RSSI: " + String(WiFi.RSSI()) + " dBm";
    return true;
  }

  String ssid = configuredWifiSsid();
  String password = configuredWifiPassword();

  if (ssid.length() == 0 || ssid == "YOUR_WIFI_NAME") {
    lastWifiStatus = "No Wi-Fi credentials saved";
    Serial.println(lastWifiStatus);
    return false;
  }

  Serial.print("Connecting to Wi-Fi: ");
  Serial.print(ssid);
  WiFi.mode(WIFI_AP_STA);
  WiFi.begin(ssid.c_str(), password.c_str());

  uint32_t startMs = millis();
  while (WiFi.status() != WL_CONNECTED && millis() - startMs < timeoutMs) {
    Serial.print(".");
    delay(500);
    serviceAlarm();
    feedGps(5);
  }
  Serial.println();

  if (WiFi.status() == WL_CONNECTED) {
    Serial.print("Wi-Fi connected. IP: ");
    Serial.println(WiFi.localIP());
    lastWifiStatus = "Connected. IP: " + WiFi.localIP().toString() + ", RSSI: " + String(WiFi.RSSI()) + " dBm";
    return true;
  }

  lastWifiStatus = "Connection failed: " + wifiStatusCodeText(WiFi.status());
  Serial.println(lastWifiStatus);
  return false;
}

bool uploadLocationToFirebase(const LocationFix &fix, const char *reason) {
  if (WiFi.status() != WL_CONNECTED) {
    lastFirebaseStatus = "Skipped: Wi-Fi disconnected";
    firebaseConnected = false;
    return false;
  }

#if USE_FIRESTORE
  firebaseConnected = firestoreWriteTelemetry(false, lastFirebaseHttpStatus, lastFirebaseStatus);
  return firebaseConnected;
#else
  String latestPayload = buildLocationJson(fix, reason, "wifi");
  String latestUrl = firebaseUrl("/devices/" + String(DEVICE_ID) + "/latest.json");

  WiFiClientSecure latestClient;
  latestClient.setInsecure();  // Prototype only. For production, validate Firebase's CA certificate.

  HTTPClient http;
  http.begin(latestClient, latestUrl);
  http.addHeader("Content-Type", "application/json");
  http.setTimeout(FIREBASE_HTTP_TIMEOUT_MS);
  int latestStatus = http.PUT(latestPayload);
  String latestResponse = http.getString();
  http.end();

  Serial.print("Firebase latest status: ");
  Serial.println(latestStatus);
  if (latestStatus < 200 || latestStatus >= 300) {
    Serial.println(latestResponse);
    lastFirebaseStatus = "Latest write failed: HTTP " + String(latestStatus);
    firebaseConnected = false;
    lastFirebaseHttpStatus = latestStatus;
    return false;
  }

  String logPayload = buildLocationJson(fix, reason, "wifi");
  String logUrl = firebaseUrl("/gpsLogs/" + String(DEVICE_ID) + ".json");

  WiFiClientSecure logClient;
  logClient.setInsecure();  // Prototype only. For production, validate Firebase's CA certificate.

  HTTPClient logHttp;
  logHttp.begin(logClient, logUrl);
  logHttp.addHeader("Content-Type", "application/json");
  logHttp.setTimeout(FIREBASE_HTTP_TIMEOUT_MS);
  int logStatus = logHttp.POST(logPayload);
  String logResponse = logHttp.getString();
  logHttp.end();

  Serial.print("Firebase log status: ");
  Serial.println(logStatus);
  if (logStatus < 200 || logStatus >= 300) {
    Serial.println(logResponse);
    lastFirebaseStatus = "Log write failed: HTTP " + String(logStatus);
    firebaseConnected = false;
    lastFirebaseHttpStatus = logStatus;
    return false;
  }

  lastFirebaseStatus = "Uploaded to Firebase";
  firebaseConnected = true;
  lastFirebaseHttpStatus = logStatus;
  return true;
#endif
}

bool uploadLocationToFirebaseOverCellular(const LocationFix &fix, const char *reason) {
  if (!ensureAir780eGprs(true)) {
    lastFirebaseStatus = "Cellular upload skipped: GPRS unavailable";
    return false;
  }

#if USE_FIRESTORE
  if (!firestoreWriteTelemetry(true, lastFirebaseHttpStatus, lastFirebaseStatus)) {
    return false;
  }
  lastCellularStatus = "Cellular Firestore upload OK";
  firebaseConnected = true;
  cellularDataReady = true;
  return true;
#else
  String latestPayload = buildLocationJson(fix, reason, "cellular");
  String latestUrl = firebaseUrlWithMethodOverride("/devices/" + String(DEVICE_ID) + "/latest.json", "PUT");
  int latestStatus = 0;
  String latestResponse;

  if (!air780eHttpPost(latestUrl, latestPayload, latestStatus, latestResponse)) {
    Serial.println(latestResponse);
    lastFirebaseStatus = "Cellular latest write failed: HTTP " + String(latestStatus);
    lastFirebaseHttpStatus = latestStatus;
    return false;
  }

  String logPayload = buildLocationJson(fix, reason, "cellular");
  String logUrl = firebaseUrl("/gpsLogs/" + String(DEVICE_ID) + ".json");
  int logStatus = 0;
  String logResponse;

  if (!air780eHttpPost(logUrl, logPayload, logStatus, logResponse)) {
    Serial.println(logResponse);
    lastFirebaseStatus = "Cellular log write failed: HTTP " + String(logStatus);
    lastFirebaseHttpStatus = logStatus;
    return false;
  }

  lastFirebaseStatus = "Uploaded to Firebase over AIR780E cellular";
  lastCellularStatus = "Cellular Firebase upload OK";
  firebaseConnected = true;
  cellularDataReady = true;
  lastFirebaseHttpStatus = logStatus;
  return true;
#endif
}

bool uploadPeriodicLocationToFirebase(const LocationFix &fix) {
  if (WiFi.status() != WL_CONNECTED) {
    lastTrackingStatus = "Periodic tracking skipped: Wi-Fi disconnected";
    return false;
  }

#if USE_FIRESTORE
  int status = 0;
  return firestoreWriteTelemetry(false, status, lastTrackingStatus);
#else
  String payload = buildTrackingLocationJson(fix);
  String latestUrl = firebaseUrl("/devices/" + String(DEVICE_ID) + "/tracking.json");

  WiFiClientSecure latestClient;
  latestClient.setInsecure();  // Prototype only. For production, validate Firebase's CA certificate.

  HTTPClient http;
  http.begin(latestClient, latestUrl);
  http.addHeader("Content-Type", "application/json");
  http.setTimeout(FIREBASE_HTTP_TIMEOUT_MS);
  int latestStatus = http.PUT(payload);
  String latestResponse = http.getString();
  http.end();

  if (latestStatus < 200 || latestStatus >= 300) {
    Serial.println(latestResponse);
    lastTrackingStatus = "Periodic latest write failed: HTTP " + String(latestStatus);
    return false;
  }

  String logUrl = firebaseUrl("/trackingLogs/" + String(DEVICE_ID) + ".json");

  WiFiClientSecure logClient;
  logClient.setInsecure();  // Prototype only. For production, validate Firebase's CA certificate.

  HTTPClient logHttp;
  logHttp.begin(logClient, logUrl);
  logHttp.addHeader("Content-Type", "application/json");
  logHttp.setTimeout(FIREBASE_HTTP_TIMEOUT_MS);
  int logStatus = logHttp.POST(payload);
  String logResponse = logHttp.getString();
  logHttp.end();

  if (logStatus < 200 || logStatus >= 300) {
    Serial.println(logResponse);
    lastTrackingStatus = "Periodic log write failed: HTTP " + String(logStatus);
    return false;
  }

  lastTrackingStatus = "Periodic GPS uploaded over Wi-Fi";
  return true;
#endif
}

bool uploadPeriodicLocationToFirebaseOverCellular(const LocationFix &fix) {
  if (!ensureAir780eGprs(true)) {
    lastTrackingStatus = "Periodic tracking skipped: GPRS unavailable";
    return false;
  }

#if USE_FIRESTORE
  int status = 0;
  if (!firestoreWriteTelemetry(true, status, lastTrackingStatus)) {
    return false;
  }
  cellularDataReady = true;
  return true;
#else
  String payload = buildTrackingLocationJson(fix);
  String latestUrl = firebaseUrlWithMethodOverride("/devices/" + String(DEVICE_ID) + "/tracking.json", "PUT");
  int latestStatus = 0;
  String latestResponse;

  if (!air780eHttpPost(latestUrl, payload, latestStatus, latestResponse)) {
    Serial.println(latestResponse);
    lastTrackingStatus = "Periodic cellular latest failed: HTTP " + String(latestStatus);
    return false;
  }

  String logUrl = firebaseUrl("/trackingLogs/" + String(DEVICE_ID) + ".json");
  int logStatus = 0;
  String logResponse;

  if (!air780eHttpPost(logUrl, payload, logStatus, logResponse)) {
    Serial.println(logResponse);
    lastTrackingStatus = "Periodic cellular log failed: HTTP " + String(logStatus);
    return false;
  }

  lastTrackingStatus = "Periodic GPS uploaded over AIR780E cellular";
  cellularDataReady = true;
  return true;
#endif
}

void handlePeriodicLocationUpload() {
  if (alertInProgress) {
    return;
  }

  uint32_t nowMs = millis();
  if (lastPeriodicLocationUploadMs != 0 &&
      nowMs - lastPeriodicLocationUploadMs < PERIODIC_LOCATION_UPLOAD_INTERVAL_MS) {
    return;
  }

  if (!lastKnownFix.valid || lastKnownFix.ageMs > PERIODIC_LOCATION_MAX_AGE_MS) {
    lastTrackingStatus = "Periodic tracking waiting for fresh GPS fix";
    return;
  }

  lastPeriodicLocationUploadMs = nowMs;

  bool uploaded = false;
  if (WiFi.status() == WL_CONNECTED) {
    uploaded = uploadPeriodicLocationToFirebase(lastKnownFix);
  }

  if (!uploaded) {
    uploadPeriodicLocationToFirebaseOverCellular(lastKnownFix);
  }
}

bool ensureAir780eGprs(bool force) {
  if (!force && cellularDataReady) {
    return true;
  }

  if (!checkAir780e(true)) {
    cellularDataReady = false;
    lastCellularStatus = "AIR780E not responding";
    return false;
  }

  lastCellularStatus = "Checking SIM and cellular data registration";
  sendAT("AT+CPIN?", "READY", 5000);

  bool attached = false;
  uint32_t startMs = millis();
  while (millis() - startMs < CELLULAR_CONNECT_TIMEOUT_MS) {
    if (sendAT("AT+CGATT?", "+CGATT: 1", 5000)) {
      attached = true;
      break;
    }
    sendAT("AT+CEREG?", "OK", 3000);
    serviceAlarm();
    delay(1500);
  }

  if (!attached) {
    cellularDataReady = false;
    lastCellularStatus = "GPRS/LTE data not attached";
    return false;
  }

  String pdpCommand = "AT+CGDCONT=1,\"";
  pdpCommand += CELLULAR_PDP_TYPE;
  pdpCommand += "\",\"";
  pdpCommand += CELLULAR_APN;
  pdpCommand += "\"";
  sendAT(pdpCommand, "OK", 5000);

  sendAT("AT+SAPBR=0,1", "OK", 5000);
  delay(1000);

  bool bearerTypeSet = false;
  for (int attempt = 0; attempt < 3; attempt++) {
    if (sendAT("AT+SAPBR=3,1,\"CONTYPE\",\"GPRS\"", "OK", 5000)) {
      bearerTypeSet = true;
      break;
    }
    serviceAlarm();
    delay(500);
  }

  if (!bearerTypeSet) {
    lastCellularStatus = "Warning: bearer type command failed, trying APN anyway";
  }

  String apnCommand = "AT+SAPBR=3,1,\"APN\",\"";
  apnCommand += CELLULAR_APN;
  apnCommand += "\"";
  if (!sendAT(apnCommand, "OK", 5000)) {
    cellularDataReady = false;
    lastCellularStatus = "Failed to set APN";
    return false;
  }

  if (String(CELLULAR_APN_USER).length() > 0) {
    String userCommand = "AT+SAPBR=3,1,\"USER\",\"";
    userCommand += CELLULAR_APN_USER;
    userCommand += "\"";
    sendAT(userCommand, "OK", 5000);
  }

  if (String(CELLULAR_APN_PASSWORD).length() > 0) {
    String passCommand = "AT+SAPBR=3,1,\"PWD\",\"";
    passCommand += CELLULAR_APN_PASSWORD;
    passCommand += "\"";
    sendAT(passCommand, "OK", 5000);
  }

  if (!sendAT("AT+SAPBR=1,1", "OK", CELLULAR_CONNECT_TIMEOUT_MS)) {
    sendAT("AT+SAPBR=2,1", "OK", 5000);
  }

  if (!sendAT("AT+SAPBR=2,1", "+SAPBR: 1,1", 10000)) {
    cellularDataReady = false;
    lastCellularStatus = "Cellular bearer has no IP address";
    return false;
  }

  cellularDataReady = true;
  lastCellularStatus = "Cellular data ready";
  return true;
}

bool air780eHttpPost(const String &url, const String &payload, int &httpStatus, String &response) {
  httpStatus = 0;
  response = "";

  if (payload.length() > 3300) {
    response = "Payload too large for AIR780E AT+HTTPDATA";
    return false;
  }

  sendAT("AT+HTTPTERM", "OK", 3000);
  if (!sendAT("AT+HTTPINIT", "OK", 10000)) {
    response = "HTTPINIT failed";
    return false;
  }

  bool ok = true;
  ok = ok && sendAT("AT+HTTPSSL=1", "OK", 5000);
  ok = ok && sendAT("AT+HTTPPARA=\"CID\",1", "OK", 5000);
  ok = ok && sendAT("AT+HTTPPARA=\"CONTENT\",\"application/json\"", "OK", 5000);
  ok = ok && sendAT("AT+HTTPPARA=\"TIMEOUT\",90", "OK", 5000);

  String urlCommand = "AT+HTTPPARA=\"URL\",\"";
  urlCommand += url;
  urlCommand += "\"";
  ok = ok && sendAT(urlCommand, "OK", 10000);

  if (!ok) {
    sendAT("AT+HTTPTERM", "OK", 3000);
    response = "HTTP parameter setup failed";
    return false;
  }

  String dataCommand = "AT+HTTPDATA=";
  dataCommand += String(payload.length());
  dataCommand += ",15000";
  if (!sendAT(dataCommand, "DOWNLOAD", 10000)) {
    sendAT("AT+HTTPTERM", "OK", 3000);
    response = "HTTPDATA prompt failed";
    return false;
  }

  air780e.print(payload);
  String dataResponse = readAir780eUntil("OK", 20000);
  if (dataResponse.indexOf("OK") < 0) {
    sendAT("AT+HTTPTERM", "OK", 3000);
    response = "HTTPDATA body write failed: " + dataResponse;
    return false;
  }

  while (air780e.available()) {
    air780e.read();
  }
  air780e.print("AT+HTTPACTION=1\r");
  String actionResponse = readAir780eUntilHttpAction(CELLULAR_HTTP_TIMEOUT_MS);
  response = actionResponse;
  sendAT("AT+HTTPREAD", "OK", 10000);
  sendAT("AT+HTTPTERM", "OK", 3000);

  int marker = actionResponse.indexOf("+HTTPACTION:");
  if (marker >= 0) {
    int firstComma = actionResponse.indexOf(',', marker);
    int secondComma = actionResponse.indexOf(',', firstComma + 1);
    if (firstComma >= 0 && secondComma > firstComma) {
      httpStatus = actionResponse.substring(firstComma + 1, secondComma).toInt();
    }
  }

  return httpStatus >= 200 && httpStatus < 300;
}

bool checkFirebaseConnection(bool force) {
  if (!force && millis() - lastFirebaseCheckMs < FIREBASE_STATUS_CHECK_INTERVAL_MS) {
    return firebaseConnected;
  }

  lastFirebaseCheckMs = millis();

  if (WiFi.status() != WL_CONNECTED) {
    return checkFirebaseConnectionOverCellular();
  }

#if USE_FIRESTORE
  firebaseConnected = firestoreWriteTelemetry(false, lastFirebaseHttpStatus, lastFirebaseStatus);
  return firebaseConnected;
#else
  String payload = buildDeviceStatusJson("wifi");

  WiFiClientSecure client;
  client.setInsecure();  // Prototype only. For production, validate Firebase's CA certificate.

  HTTPClient http;
  http.begin(client, firebaseUrl("/deviceStatus/" + String(DEVICE_ID) + ".json"));
  http.addHeader("Content-Type", "application/json");
  http.setTimeout(FIREBASE_HTTP_TIMEOUT_MS);
  int status = http.PUT(payload);
  String response = http.getString();
  http.end();

  lastFirebaseHttpStatus = status;
  firebaseConnected = status >= 200 && status < 300;

  if (firebaseConnected) {
    lastFirebaseStatus = "Connected: status synced to Firebase";
  } else if (status == 401 || status == 403) {
    lastFirebaseStatus = "Disconnected: Firebase rules/auth denied HTTP " + String(status);
  } else if (status < 0) {
    lastFirebaseStatus = "Disconnected: HTTPS error " + String(status);
  } else {
    lastFirebaseStatus = "Disconnected: Firebase HTTP " + String(status);
  }

  if (!firebaseConnected && response.length() > 0) {
    Serial.println(response);
  }

  return firebaseConnected;
#endif
}

bool checkFirebaseConnectionOverCellular() {
  if (!ensureAir780eGprs(false)) {
    firebaseConnected = false;
    lastFirebaseHttpStatus = 0;
    if (lastCellularStatus.length() > 0) {
      lastFirebaseStatus = "Waiting for cellular Firebase: " + lastCellularStatus;
    } else {
      lastFirebaseStatus = "Waiting for cellular Firebase";
    }
    return false;
  }

#if USE_FIRESTORE
  firebaseConnected = firestoreWriteTelemetry(true, lastFirebaseHttpStatus, lastFirebaseStatus);
  if (firebaseConnected) {
    lastCellularStatus = "Cellular data and Firestore OK";
  }
  return firebaseConnected;
#else
  String payload = buildDeviceStatusJson("cellular");
  String statusUrl = firebaseUrlWithMethodOverride("/deviceStatus/" + String(DEVICE_ID) + ".json", "PUT");
  int status = 0;
  String response;

  bool ok = air780eHttpPost(statusUrl, payload, status, response);
  lastFirebaseHttpStatus = status;
  firebaseConnected = ok;

  if (ok) {
    lastFirebaseStatus = "Connected: status synced to Firebase over AIR780E cellular";
    lastCellularStatus = "Cellular data and Firebase OK";
  } else if (status == 401 || status == 403) {
    lastFirebaseStatus = "Cellular Firebase rules/auth denied HTTP " + String(status);
  } else if (status > 0) {
    lastFirebaseStatus = "Cellular Firebase HTTP " + String(status);
  } else {
    lastFirebaseStatus = "Cellular Firebase check failed";
  }

  if (!ok && response.length() > 0) {
    Serial.println(response);
  }

  return ok;
#endif
}

bool sendSmsLocation(const LocationFix &fix, const char *reason) {
  String recipientPhone = configuredRecipientPhone();
  if (recipientPhone.length() == 0 || recipientPhone == "+639XXXXXXXXX") {
    Serial.println("Recipient phone is empty. SMS skipped.");
    lastSmsStatus = "Skipped: recipient phone is not set";
    return false;
  }

  if (!checkAir780e(true)) {
    Serial.println("AIR780E not responding. SMS failed.");
    lastSmsStatus = "Failed: AIR780E not responding";
    return false;
  }

  sendAT("AT+CPIN?", "OK", 2500);
  sendAT("AT+CSQ", "OK", 2500);
  sendAT("AT+COPS?", "OK", 2500);
  sendAT("AT+CEREG?", "OK", 2500);
  sendAT("AT+CREG?", "OK", 2500);
  sendAT("AT+CGREG?", "OK", 2500);
  sendAT("AT+CSMS=1", "OK", 2500);
  sendAT("AT+CPMS=\"SM\",\"SM\",\"SM\"", "OK", 2500);
  sendAT("AT+CMGF=1", "OK", 2500);
  sendAT("AT+CSCS=\"GSM\"", "OK", 2500);
  sendAT("AT+CSMP=17,167,0,0", "OK", 2500);
  sendAT("AT+CSCA?", "OK", 2500);

  String command = "AT+CMGS=\"";
  command += recipientPhone;
  command += "\"";
  if (recipientPhone.startsWith("+")) {
    command += ",145";
  }
  if (!sendAT(command, ">", 5000)) {
    Serial.println("AIR780E did not accept SMS command.");
    lastSmsStatus = "Failed: AIR780E rejected SMS command";
    return false;
  }

  String message = customSmsMessage;
  message.trim();
  if (message.length() == 0) message = "Emergency! Rider safety alert.";
  message += "\nEvent: " + String(reason);
  message += "\nLocation: " + String(fix.lat, 6) + "," + String(fix.lng, 6);
  message += "\nMap: " + buildMapsUrl(fix);

  air780e.print(message);
  air780e.write(26);  // Ctrl+Z

  String response = readAir780eUntil("OK", SMS_RESPONSE_TIMEOUT_MS);
  Serial.println(response);

  if (response.indexOf("+CMGS:") >= 0 && response.indexOf("OK") >= 0) {
    Serial.println("SMS sent.");
    lastSmsStatus = "SMS sent to " + recipientPhone;
    return true;
  }

  if (response.indexOf("+CMS ERROR") >= 0 || response.indexOf("+CME ERROR") >= 0 || response.indexOf("ERROR") >= 0) {
    lastSmsStatus = "Failed: AIR780E returned SMS error";
    return false;
  }

  lastSmsStatus = "Failed: SMS send timeout";
  return false;
}

bool sendAT(const String &command, const String &expected, uint32_t timeoutMs) {
  while (air780e.available()) {
    air780e.read();
  }

  air780e.print(command);
  air780e.print("\r");
  String response = readAir780eUntil(expected, timeoutMs);

  if (response.indexOf(expected) >= 0) {
    return true;
  }

  if (response.indexOf("ERROR") >= 0) {
    Serial.println(response);
    return false;
  }

  Serial.print("AT timeout: ");
  Serial.println(command);
  Serial.println(response);
  return false;
}

String readAir780eUntil(const String &expected, uint32_t timeoutMs) {
  uint32_t startMs = millis();
  String response;

  while (millis() - startMs < timeoutMs) {
    while (air780e.available()) {
      response += char(air780e.read());
    }

    if (expected.length() > 0 && response.indexOf(expected) >= 0) {
      return response;
    }
    if (response.indexOf("+CMS ERROR") >= 0 || response.indexOf("+CME ERROR") >= 0 || response.indexOf("ERROR") >= 0) {
      return response;
    }
    serviceAlarm();
    delay(10);
  }

  if (response.length() == 0) {
    response = "(timeout, no response)";
  } else {
    response += "\n(timeout)";
  }
  return response;
}

String readAir780eUntilHttpAction(uint32_t timeoutMs) {
  uint32_t startMs = millis();
  String response;

  while (millis() - startMs < timeoutMs) {
    while (air780e.available()) {
      response += char(air780e.read());
    }

    int marker = response.indexOf("+HTTPACTION:");
    if (marker >= 0) {
      int lineEnd = response.indexOf('\n', marker);
      if (lineEnd >= 0) {
        return response;
      }
    }

    if (response.indexOf("+HTTP_ERROR") >= 0 || response.indexOf("ERROR") >= 0) {
      return response;
    }
    serviceAlarm();
    delay(20);
  }

  if (response.length() == 0) {
    response = "(timeout, no HTTPACTION response)";
  } else {
    response += "\n(timeout waiting for HTTPACTION)";
  }
  return response;
}

bool initializeAir780e() {
  for (int attempt = 0; attempt < 8; attempt++) {
    if (sendAT("AT", "OK", 1500)) {
      air780eReady = true;
      sendAT("ATE0", "OK", 3000);
      sendAT("AT+CMEE=2", "OK", 3000);
      sendAT("AT+CMGF=1", "OK", 3000);
      sendAT("AT+CSCS=\"GSM\"", "OK", 3000);
      sendAT("AT+CSMP=17,167,0,0", "OK", 3000);
      return true;
    }
    delay(500);
  }

  air780eReady = false;
  return false;
}

String buildMapsUrl(const LocationFix &fix) {
  return "https://maps.google.com/?q=" + String(fix.lat, 6) + "," + String(fix.lng, 6);
}

String firebaseUrl(const String &path) {
  String url = String(FIREBASE_DATABASE_URL);
  if (url.endsWith("/")) {
    url.remove(url.length() - 1);
  }
  url += path;

  if (String(FIREBASE_AUTH_TOKEN).length() > 0) {
    url += "?auth=";
    url += FIREBASE_AUTH_TOKEN;
  }

  return url;
}

String firebaseUrlWithMethodOverride(const String &path, const String &method) {
  return appendUrlParam(firebaseUrl(path), "x-http-method-override", method);
}

String appendUrlParam(const String &url, const String &key, const String &value) {
  String result = url;
  result += result.indexOf('?') >= 0 ? "&" : "?";
  result += key;
  result += "=";
  result += value;
  return result;
}

#if USE_FIRESTORE
// Firestore transport. One documents:commit write updates only the fields in
// its updateMask, so console-owned fields (assigned_rider_id, paired_at) are
// never touched. commit is used rather than PATCH because it is a plain POST
// (the AIR780E HTTP stack only does GET/POST) and because only commit can set
// last_update to the server's clock.
String firestoreCommitUrl() {
  return String("https://firestore.googleapis.com/v1/projects/") + FIREBASE_PROJECT_ID +
         "/databases/(default)/documents:commit";
}

// Appends one typed field and its mask entry together so the two cannot drift.
void addFirestoreField(String &fields, String &mask, const char *name, const String &typedValue) {
  if (fields.length() > 0) fields += ",";
  fields += "\"" + String(name) + "\":" + typedValue;
  if (mask.length() > 0) mask += ",";
  mask += "\"" + String(name) + "\"";
}

void addFirestoreDouble(String &fields, String &mask, const char *name, double value, int decimals) {
  if (!isfinite(value)) return;  // "nan" is not JSON; leave the stored value alone
  addFirestoreField(fields, mask, name, "{\"doubleValue\":" + String(value, decimals) + "}");
}

String buildFirestoreTelemetryCommit() {
  String fields;
  String mask;
  bool gpsFix = lastKnownFix.valid && gps.location.isValid() && gps.location.age() < 10000;

  addFirestoreField(fields, mask, "gps_fix", gpsFix ? "{\"booleanValue\":true}" : "{\"booleanValue\":false}");
  if (lastKnownFix.valid) {
    // Last known position; gps_fix says whether it is current.
    addFirestoreDouble(fields, mask, "latitude", lastKnownFix.lat, 6);
    addFirestoreDouble(fields, mask, "longitude", lastKnownFix.lng, 6);
  }
  if (gpsFix && gps.speed.isValid()) {
    addFirestoreDouble(fields, mask, "speed_kmh", lastKnownFix.speedKmph, 2);
  } else {
    mask += ",\"speed_kmh\"";  // masked with no value = deleted, so no stale speed is shown
  }
  if (adxl345Ready && latestAccel.valid) {
    addFirestoreDouble(fields, mask, "ax", latestAccel.xG, 3);
    addFirestoreDouble(fields, mask, "ay", latestAccel.yG, 3);
    addFirestoreDouble(fields, mask, "az", latestAccel.zG, 3);
    addFirestoreDouble(fields, mask, "vector_magnitude", latestAccel.magnitudeG, 3);
  }
  // Uncalibrated MQ-3 readings, not mg/L, so alcohol_level is deliberately not written.
  addFirestoreDouble(fields, mask, "alcohol_raw", mq3Raw, 0);
  addFirestoreDouble(fields, mask, "alcohol_voltage", mq3Voltage, 3);

  const char *state = crashAlertLatched ? "crash_alert" : (alcoholAlertActive ? "alcohol_alert" : "monitoring");
  addFirestoreField(fields, mask, "state", "{\"stringValue\":\"" + String(state) + "\"}");
  addFirestoreField(fields, mask, "firmware_version", "{\"stringValue\":\"" FIRMWARE_VERSION "\"}");

  String body = "{\"writes\":[{\"update\":{\"name\":\"projects/";
  body += FIREBASE_PROJECT_ID;
  body += "/databases/(default)/documents/devices/";
  body += DEVICE_ID;
  body += "\",\"fields\":{" + fields + "}},";
  body += "\"updateMask\":{\"fieldPaths\":[" + mask + "]},";
  body += "\"updateTransforms\":[{\"fieldPath\":\"last_update\",\"setToServerValue\":\"REQUEST_TIME\"}]}]}";
  return body;
}

bool firestoreWriteTelemetry(bool overCellular, int &httpStatus, String &statusText) {
  String body = buildFirestoreTelemetryCommit();
  String response;
  httpStatus = 0;

  if (overCellular) {
    air780eHttpPost(firestoreCommitUrl(), body, httpStatus, response);
  } else {
    WiFiClientSecure client;
    client.setInsecure();  // Prototype only. For production, validate Google's CA certificate.
    HTTPClient http;
    http.begin(client, firestoreCommitUrl());
    http.addHeader("Content-Type", "application/json");
    http.setTimeout(FIREBASE_HTTP_TIMEOUT_MS);
    httpStatus = http.POST(body);
    response = http.getString();
    http.end();
  }

  bool ok = httpStatus >= 200 && httpStatus < 300;
  const char *via = overCellular ? "cellular" : "wifi";
  Serial.printf("Firestore %s write devices/%s: HTTP %d\n", via, DEVICE_ID, httpStatus);

  if (ok) {
    statusText = "Connected: Firestore devices/" + String(DEVICE_ID) + " updated over " + via;
  } else {
    if (httpStatus == 401 || httpStatus == 403) {
      statusText = "Firestore rules denied HTTP " + String(httpStatus);
    } else if (httpStatus < 0) {
      statusText = "Firestore HTTPS error " + String(httpStatus);
    } else {
      statusText = "Firestore write failed: HTTP " + String(httpStatus);
    }
    Serial.println("Firestore request body:");
    Serial.println(body);
    Serial.println("Firestore response:");
    Serial.println(response);
  }
  return ok;
}
#endif

String buildDeviceStatusJson(const char *transport) {
  String payload = "{";
  payload += "\"deviceId\":\"" + String(DEVICE_ID) + "\",";
  payload += "\"online\":true,";
  payload += "\"transport\":\"" + String(transport) + "\",";
  if (WiFi.status() == WL_CONNECTED) {
    payload += "\"ip\":\"" + WiFi.localIP().toString() + "\",";
    payload += "\"rssi\":" + String(WiFi.RSSI()) + ",";
  } else {
    payload += "\"ip\":\"cellular\",";
    payload += "\"rssi\":0,";
  }
  payload += "\"gpsNmeaChars\":" + String(gpsCharsReceived) + ",";
  payload += "\"gpsValidSentences\":" + String(gps.passedChecksum()) + ",";
  payload += "\"accelerometerReady\":" + String(adxl345Ready ? "true" : "false") + ",";
  payload += "\"mq3Raw\":" + String(mq3Raw) + ",";
  payload += "\"mq3Voltage\":" + String(mq3Voltage, 3) + ",";
  payload += "\"alcoholRelativeIndex\":" + String(alcoholRelativeIndex, 1) + ",";
  payload += "\"alcoholAlert\":" + String(alcoholAlertActive ? "true" : "false") + ",";
  payload += "\"sw420Active\":" + String(sw420Active ? "true" : "false") + ",";
  payload += "\"tiltDegrees\":" + String(tiltDegrees, 1) + ",";
  payload += "\"orientation\":\"" + orientationText + "\",";

  payload += "\"cellularDataReady\":" + String(cellularDataReady ? "true" : "false") + ",";
  payload += "\"accelMagnitudeG\":" + String(latestAccel.magnitudeG, 3) + ",";
  payload += "\"lastSeen\":{ \".sv\":\"timestamp\" }";
  payload += "}";
  return payload;
}

String buildTrackingLocationJson(const LocationFix &fix) {
  String json = "{";
  json += "\"lat\":" + String(fix.lat, 6) + ",";
  json += "\"lng\":" + String(fix.lng, 6) + ",";
  json += "\"mq3Raw\":" + String(mq3Raw) + ",";
  json += "\"mq3Voltage\":" + String(mq3Voltage, 3) + ",";
  json += "\"alcoholRelativeIndex\":" + String(alcoholRelativeIndex, 1) + ",";
  json += "\"alcoholAlert\":" + String(alcoholAlertActive ? "true" : "false") + ",";
  json += "\"sw420Active\":" + String(sw420Active ? "true" : "false") + ",";
  json += "\"xG\":" + String(latestAccel.xG, 3) + ",";
  json += "\"yG\":" + String(latestAccel.yG, 3) + ",";
  json += "\"zG\":" + String(latestAccel.zG, 3) + ",";
  json += "\"tiltDegrees\":" + String(tiltDegrees, 1) + ",";
  json += "\"orientation\":\"" + orientationText + "\",";
  json += "\"serverTime\":{ \".sv\":\"timestamp\" }";
  json += "}";
  return json;
}

String buildLocationJson(const LocationFix &fix, const char *reason, const char *transport) {
  String json = "{";
  json += "\"deviceId\":\"" + String(DEVICE_ID) + "\",";
  json += "\"reason\":\"" + String(reason) + "\",";
  json += "\"transport\":\"" + String(transport) + "\",";
  json += "\"lat\":" + String(fix.lat, 6) + ",";
  json += "\"lng\":" + String(fix.lng, 6) + ",";
  json += "\"speedKmph\":" + String(fix.speedKmph, 2) + ",";
  json += "\"altitudeM\":" + String(fix.altitudeM, 2) + ",";
  json += "\"satellites\":" + String(fix.satellites) + ",";
  json += "\"mq3Raw\":" + String(mq3Raw) + ",";
  json += "\"mq3Voltage\":" + String(mq3Voltage, 3) + ",";
  json += "\"alcoholRelativeIndex\":" + String(alcoholRelativeIndex, 1) + ",";
  json += "\"alcoholAlert\":" + String(alcoholAlertActive ? "true" : "false") + ",";
  json += "\"sw420Active\":" + String(sw420Active ? "true" : "false") + ",";
  json += "\"tiltDegrees\":" + String(tiltDegrees, 1) + ",";
  json += "\"orientation\":\"" + orientationText + "\",";
  json += "\"safetyEvent\":\"" + safetyEventStatus + "\",";

  json += "\"gpsAgeMs\":" + String(fix.ageMs) + ",";
  json += "\"accelerometerReady\":" + String(adxl345Ready ? "true" : "false") + ",";
  json += "\"accelXG\":" + String(latestAccel.xG, 3) + ",";
  json += "\"accelYG\":" + String(latestAccel.yG, 3) + ",";
  json += "\"accelZG\":" + String(latestAccel.zG, 3) + ",";
  json += "\"accelMagnitudeG\":" + String(latestAccel.magnitudeG, 3) + ",";
  json += "\"mapsUrl\":\"" + buildMapsUrl(fix) + "\",";
  json += "\"serverTime\":{ \".sv\":\"timestamp\" }";
  json += "}";
  return json;
}

void setAlarm(bool enabled) {
  alarmActive = enabled;
  digitalWrite(LED_PIN, enabled ? HIGH : LOW);

  if (enabled) {
    morsePatternIndex = 0;
    morseToneActive = false;
    morseNextStepMs = 0;
    serviceAlarm();
  } else {
    buzzerOff();
    morseToneActive = false;
    morseNextStepMs = 0;
  }
}

void serviceAlarm() {
  if (!alarmActive) return;
  uint32_t t = millis();
  bool on = false;
  if (alertPattern == "slow") {
    on = (t % 1200UL) < 600UL;
  } else if (alertPattern == "pulse") {
    on = (t % 250UL) < 80UL;
  } else if (alertPattern == "sos") {
    uint32_t phase = t % 3000UL;
    on = (phase < 150UL) || (phase >= 300UL && phase < 450UL) ||
         (phase >= 600UL && phase < 1050UL) || (phase >= 1200UL && phase < 1650UL) ||
         (phase >= 1800UL && phase < 1950UL) || (phase >= 2100UL && phase < 2250UL);
  } else {
    on = (t % 350UL) < 175UL; // rapid
  }
  digitalWrite(LED_PIN, on ? HIGH : LOW);
  if (on) tone(BUZZER_PIN, alertToneHz);
  else noTone(BUZZER_PIN);
}

void keepAlarmActive(uint32_t durationMs) {
  uint32_t startMs = millis();
  while (millis() - startMs < durationMs) {
    serviceAlarm();
    feedGps(5);
    handleWebClients();
    delay(5);
  }
}

void playReadyMorseOk() {
  playMorsePatternBlocking("--- -.-");
}

void playMorsePatternBlocking(const char *pattern) {
  for (size_t i = 0; pattern[i] != '\0'; i++) {
    char symbol = pattern[i];
    if (symbol == '.') {
      buzzerOn();
      digitalWrite(LED_PIN, HIGH);
      delay(MORSE_DOT_MS);
      buzzerOff();
      digitalWrite(LED_PIN, LOW);
      delay(MORSE_SYMBOL_GAP_MS);
    } else if (symbol == '-') {
      buzzerOn();
      digitalWrite(LED_PIN, HIGH);
      delay(MORSE_DASH_MS);
      buzzerOff();
      digitalWrite(LED_PIN, LOW);
      delay(MORSE_SYMBOL_GAP_MS);
    } else if (symbol == ' ') {
      delay(MORSE_LETTER_GAP_MS);
    }
  }
}

void buzzerOn() {
  digitalWrite(BUZZER_PIN, HIGH);
}

void buzzerOff() {
  digitalWrite(BUZZER_PIN, LOW);
}

bool initializeAdxl345() {
  // MPU6050 I2C initialization; default address 0x68 (AD0 low).
  Wire.beginTransmission(MPU6050_ADDR);
  Wire.write(0x75); // WHO_AM_I
  if (Wire.endTransmission(false) != 0 || Wire.requestFrom(MPU6050_ADDR, uint8_t(1)) != 1) {
    adxl345Ready = false;
    lastAccelStatus = "MPU6050 not detected on I2C";
    return false;
  }
  uint8_t who = Wire.read();
  if (who != 0x68 && who != 0x69) {
    adxl345Ready = false;
    lastAccelStatus = "Unexpected I2C device ID: 0x" + String(who, HEX);
    return false;
  }
  if (!writeMpuRegister(MPU6050_REG_PWR_MGMT_1, 0x00)) {
    adxl345Ready = false;
    lastAccelStatus = "MPU6050 wake-up failed";
    return false;
  }
  delay(100);
  writeMpuRegister(0x1C, 0x00); // ±2g
  adxl345Ready = true;
  adxl345Address = MPU6050_ADDR;
  lastAccelStatus = "MPU6050 active";
  readAccelerometer(latestAccel);
  return true;
}

bool writeMpuRegister(uint8_t reg, uint8_t value) {
  Wire.beginTransmission(MPU6050_ADDR);
  Wire.write(reg);
  Wire.write(value);
  return Wire.endTransmission() == 0;
}
bool readMpuBytes(uint8_t reg, uint8_t *buffer, size_t length) {
  Wire.beginTransmission(MPU6050_ADDR);
  Wire.write(reg);
  if (Wire.endTransmission(false) != 0) return false;
  if (Wire.requestFrom(MPU6050_ADDR, uint8_t(length)) != length) return false;
  for (size_t i=0; i<length; ++i) buffer[i] = Wire.read();
  return true;
}
bool readAdxlRegister(uint8_t address, uint8_t reg, uint8_t &value) {
  (void)address; return readMpuBytes(reg, &value, 1);
}
bool writeAdxlRegister(uint8_t reg, uint8_t value) { return writeMpuRegister(reg, value); }
bool readAdxlBytes(uint8_t reg, uint8_t *buffer, size_t length) { return readMpuBytes(reg, buffer, length); }

bool readAccelerometer(AccelReading &reading) {
  uint8_t b[6] = {0};
  if (!adxl345Ready || !readMpuBytes(MPU6050_REG_ACCEL_XOUT_H, b, sizeof(b))) {
    reading.valid = false; lastAccelStatus = "MPU6050 read failed"; return false;
  }
  int16_t rx = int16_t((uint16_t(b[0])<<8) | b[1]);
  int16_t ry = int16_t((uint16_t(b[2])<<8) | b[3]);
  int16_t rz = int16_t((uint16_t(b[4])<<8) | b[5]);
  reading.valid = true;
  reading.xG = rx / 16384.0f; reading.yG = ry / 16384.0f; reading.zG = rz / 16384.0f;
  reading.magnitudeG = sqrtf(reading.xG*reading.xG + reading.yG*reading.yG + reading.zG*reading.zG);
  float xy = sqrtf(reading.xG*reading.xG + reading.yG*reading.yG);
  tiltDegrees = atan2f(xy, fabsf(reading.zG)) * 57.29578f;
  if (!baselineOrientationSet && reading.magnitudeG > 0.65f && reading.magnitudeG < 1.35f) {
    baselineXG=reading.xG; baselineYG=reading.yG; baselineZG=reading.zG; baselineOrientationSet=true;
  }
  float dot = reading.xG*baselineXG + reading.yG*baselineYG + reading.zG*baselineZG;
  float denom = reading.magnitudeG * sqrtf(baselineXG*baselineXG + baselineYG*baselineYG + baselineZG*baselineZG);
  float angle = denom > 0.01f ? acosf(constrain(dot/denom, -1.0f, 1.0f))*57.29578f : 0;
  if (angle < 35.0f) orientationText = "Default";
  else if (angle < 60.0f) orientationText = "Tilt";
  else orientationText = "Side/abnormal";
  lastAccelStatus = "MPU6050 active";
  return true;
}

void processFallDetector() {
  if (!adxl345Ready || alertInProgress) return;
  uint32_t now = millis();
  if (now-lastAccelSampleMs < ACCEL_SAMPLE_INTERVAL_MS) return;
  lastAccelSampleMs = now;
  if (!readAccelerometer(latestAccel)) return;

  sw420Active = digitalRead(SW420_PIN) == LOW; // typical module DO goes LOW on vibration
  if (sw420Active) lastVibrationMs = now;

  if (lastKnownFix.valid && gps.location.isValid() && gps.location.age() < 10000) {
    if (gpsStationarySinceMs == 0) {
      stationaryLat=lastKnownFix.lat; stationaryLng=lastKnownFix.lng; gpsStationarySinceMs=now;
    } else if (fabs(lastKnownFix.lat-stationaryLat)>0.00005 || fabs(lastKnownFix.lng-stationaryLng)>0.00005) {
      stationaryLat=lastKnownFix.lat; stationaryLng=lastKnownFix.lng; gpsStationarySinceMs=now;
    }
  }

  bool abnormal = orientationText == "Tilt" || orientationText == "Side/abnormal";
  if (abnormal) {
    if (tiltedSinceMs == 0) { tiltedSinceMs=now; lastRiderCheckMs=now-180000UL; safetyEventStatus="Tilt/side posture: monitoring"; }
    uint32_t duration=now-tiltedSinceMs;
    if (duration >= 120000UL && now-lastRiderCheckMs >= 180000UL) {
      lastRiderCheckMs=now;
      uint16_t pulse = alertPattern=="slow" ? 450 : (alertPattern=="pulse" ? 90 : 180);
      for (int i=0;i<3;i++) {
        uint16_t p = (alertPattern=="sos" && i==1) ? 450 : pulse;
        tone(BUZZER_PIN, alertToneHz, p); digitalWrite(LED_PIN,HIGH); delay(p);
        noTone(BUZZER_PIN); digitalWrite(LED_PIN,LOW); delay(p);
        handleWebClients();
      }
      safetyEventStatus="Rider check alert: posture unchanged";
    }
    if (duration >= 720000UL && !crashAlertLatched) {
      crashAlertLatched=true; safetyEventStatus="Crash alert: abnormal posture persisted 12 minutes";
      handleEmergencyAlert("suspected-crash", true); return;
    }
  } else {
    tiltedSinceMs=0; crashAlertLatched=false;
    if (!alcoholAlertActive) safetyEventStatus="Monitoring";
  }

  if (gpsStationarySinceMs && now-gpsStationarySinceMs>=720000UL && abnormal &&
      !sw420Active && lastVibrationMs && now-lastVibrationMs>=720000UL && !crashAlertLatched) {
    crashAlertLatched=true; safetyEventStatus="Crash alert: GPS stationary, no vibration, abnormal posture";
    handleEmergencyAlert("suspected-crash", true);
  }
}

void sampleAlcoholSensor() {
  static uint32_t lastSample=0;
  if (millis()-lastSample<500) return;
  lastSample=millis();
  mq3Raw=analogRead(MQ3_PIN);
  mq3Voltage=(float(mq3Raw)/4095.0f)*3.3f;
  // Relative index only; true ppm requires R0 calibration against known alcohol gas.
  alcoholRelativeIndex=float(mq3Raw);
  alcoholAlertActive=alcoholRelativeIndex>=alcoholThresholdPpm;
  if (alcoholAlertActive) {
    safetyEventStatus="Alcohol threshold exceeded";
    uint32_t t = millis();
    uint32_t period = alertPattern=="slow" ? 1200UL : (alertPattern=="pulse" ? 250UL : (alertPattern=="sos" ? 900UL : 350UL));
    bool ledOn = alertPattern=="sos" ? ((t%900UL)<150UL || ((t%900UL)>300UL && (t%900UL)<450UL)) : ((t%period)<(period/2));
    digitalWrite(LED_PIN, ledOn ? HIGH : LOW);
    if (ledOn) tone(BUZZER_PIN, alertToneHz); else noTone(BUZZER_PIN);
  } else if (!crashAlertLatched) noTone(BUZZER_PIN);
}

void updateBootIndicator() {
  bool ready=(gps.location.isValid() && gps.location.age() < 10000) && air780eReady && adxl345Ready;
  if (ready) {
    gpsStartupReady=true;
    if (!alcoholAlertActive && !crashAlertLatched) digitalWrite(LED_PIN,LOW);
    return;
  }
  if (millis()-bootBlinkMs>=350) {
    bootBlinkMs=millis(); bootLedState=!bootLedState;
    digitalWrite(LED_PIN,bootLedState?HIGH:LOW);
  }
}

void uploadSafetyTelemetryIfDue() {
  if (millis()-lastSafetyUploadMs<10000UL) return;
  lastSafetyUploadMs=millis();
#if USE_FIRESTORE
  int status=0; String statusText;
  bool ok = WiFi.status()==WL_CONNECTED && firestoreWriteTelemetry(false,status,statusText);
  if (!ok && ensureAir780eGprs(false)) ok=firestoreWriteTelemetry(true,status,statusText);
  if (ok) lastTrackingStatus="Safety telemetry uploaded";
#else
  String payload="{";
  payload += "\"deviceId\":\""+String(DEVICE_ID)+"\",";
  payload += "\"mq3Raw\":"+String(mq3Raw)+",";
  payload += "\"mq3Voltage\":"+String(mq3Voltage,3)+",";
  payload += "\"alcoholRelativeIndex\":"+String(alcoholRelativeIndex,1)+",";
  payload += "\"alcoholThreshold\":"+String(alcoholThresholdPpm)+",";
  payload += "\"alcoholAlert\":"+String(alcoholAlertActive?"true":"false")+",";
  payload += "\"sw420Active\":"+String(sw420Active?"true":"false")+",";
  payload += "\"mpuReady\":"+String(adxl345Ready?"true":"false")+",";
  payload += "\"xG\":"+String(latestAccel.xG,3)+",\"yG\":"+String(latestAccel.yG,3)+",\"zG\":"+String(latestAccel.zG,3)+",";
  payload += "\"tiltDegrees\":"+String(tiltDegrees,1)+",";
  payload += "\"orientation\":\""+orientationText+"\",";
  payload += "\"safetyEvent\":\""+safetyEventStatus+"\",";
  payload += "\"serverTime\":{ \".sv\":\"timestamp\" }}";
  bool ok=false;
  if (WiFi.status()==WL_CONNECTED) {
    WiFiClientSecure client; client.setInsecure(); HTTPClient http;
    http.begin(client,firebaseUrl("/devices/"+String(DEVICE_ID)+"/safety.json"));
    http.addHeader("Content-Type","application/json"); http.setTimeout(FIREBASE_HTTP_TIMEOUT_MS);
    int status=http.PUT(payload); http.end(); ok=status>=200 && status<300;
  }
  if (!ok && ensureAir780eGprs(false)) {
    int status=0; String response;
    String url=firebaseUrlWithMethodOverride("/devices/"+String(DEVICE_ID)+"/safety.json","PUT");
    ok=air780eHttpPost(url,payload,status,response);
  }
  if (ok) lastTrackingStatus="Safety telemetry uploaded";
#endif
}

void loadWifiSettings() {
  preferences.begin("tracker", false);
  savedWifiSsid = preferences.getString("wifi_ssid", "");
  savedWifiPassword = preferences.getString("wifi_pass", "");
  savedRecipientPhone = preferences.getString("sms_phone", "");
  alcoholThresholdPpm = preferences.getInt("alc_threshold", 300);
  customSmsMessage = preferences.getString("sms_message", "Emergency! Possible rider crash detected.");
  alertPattern = preferences.getString("alert_pattern", "rapid");
  alertToneHz = preferences.getUShort("tone_hz", 2200);
  preferences.end();
}

String configuredWifiSsid() {
  if (savedWifiSsid.length() > 0) {
    return savedWifiSsid;
  }
  return String(WIFI_SSID);
}

String configuredWifiPassword() {
  if (savedWifiSsid.length() > 0) {
    return savedWifiPassword;
  }
  return String(WIFI_PASSWORD);
}

String configuredRecipientPhone() {
  if (savedRecipientPhone.length() > 0) {
    return savedRecipientPhone;
  }
  return String(RECIPIENT_PHONE);
}

void startAccessPoint() {
  WiFi.mode(WIFI_AP_STA);
  WiFi.softAP(TRACKER_AP_SSID, TRACKER_AP_PASSWORD);
  dnsServer.start(DNS_PORT, "*", WiFi.softAPIP());

  Serial.print("Setup AP started: ");
  Serial.println(TRACKER_AP_SSID);
  Serial.print("Open browser: http://");
  Serial.println(WiFi.softAPIP());
}

void setupWebServer() {
  webServer.on("/", HTTP_GET, handleRoot);
  webServer.on("/save-wifi", HTTP_POST, handleSaveWifi);
  webServer.on("/save-recipient", HTTP_POST, handleSaveRecipient);
  webServer.on("/save-safety", HTTP_POST, handleSaveSafetySettings);
  webServer.on("/update", HTTP_POST, handleFirmwareUpdateComplete, handleFirmwareUpload);
  webServer.on("/api/status", HTTP_GET, handleApiStatus);
  webServer.on("/clear-wifi", HTTP_POST, handleClearWifi);
  webServer.onNotFound(handleNotFound);
  webServer.begin();
}

void handleWebClients() {
  dnsServer.processNextRequest();
  webServer.handleClient();
}

void handleRoot() {
  // Prevent a cached page from showing an old threshold after settings are saved.
  webServer.sendHeader("Cache-Control", "no-store, no-cache, must-revalidate, max-age=0");
  webServer.sendHeader("Pragma", "no-cache");
  webServer.sendHeader("Expires", "0");
  webServer.send(200, "text/html", buildStatusPage());
}

void handleSaveWifi() {
  String ssid = webServer.arg("ssid");
  String password = webServer.arg("password");
  ssid.trim();

  if (ssid.length() == 0) {
    webServer.send(400, "text/plain", "Wi-Fi SSID is required.");
    return;
  }

  if (password.length() == 0 && ssid == savedWifiSsid && savedWifiPassword.length() > 0) {
    password = savedWifiPassword;
  }

  preferences.begin("tracker", false);
  preferences.putString("wifi_ssid", ssid);
  preferences.putString("wifi_pass", password);
  preferences.end();

  savedWifiSsid = ssid;
  savedWifiPassword = password;
  lastWifiStatus = "Saved Wi-Fi credentials for " + ssid;
  WiFi.disconnect(false, false);

  webServer.sendHeader("Location", "/");
  webServer.send(303);
  connectWifi(WIFI_CONNECT_TIMEOUT_MS);
}

void handleSaveRecipient() {
  String phone = webServer.arg("phone");
  phone.trim();

  preferences.begin("tracker", false);
  preferences.putString("sms_phone", phone);
  preferences.end();

  savedRecipientPhone = phone;
  if (phone.length() == 0) {
    lastSmsStatus = "Recipient phone cleared";
  } else {
    lastSmsStatus = "Recipient phone saved";
  }

  webServer.sendHeader("Location", "/");
  webServer.send(303);
}

void handleSaveSafetySettings() {
  Serial.println("POST /save-safety received");
  Serial.printf("Form args: %d\n", webServer.args());
  for (int i = 0; i < webServer.args(); ++i) {
    Serial.printf("  %s = %s\n", webServer.argName(i).c_str(), webServer.arg(i).c_str());
  }

  if (!webServer.hasArg("threshold")) {
    webServer.send(400, "text/plain", "Missing form field 'threshold'. Check that the latest firmware is installed.");
    return;
  }

  String thresholdText = webServer.arg("threshold");
  thresholdText.trim();
  if (thresholdText.length() == 0) {
    webServer.send(400, "text/plain", "Alcohol threshold cannot be empty.");
    return;
  }
  char *endPtr = nullptr;
  long parsedThreshold = strtol(thresholdText.c_str(), &endPtr, 10);
  if (endPtr == thresholdText.c_str() || *endPtr != '\0' || parsedThreshold < 1 || parsedThreshold > 4095) {
    webServer.send(400, "text/plain", "Alcohol threshold must be a whole number from 1 to 4095 (raw ADC index, not ppm).");
    return;
  }
  const int threshold = (int)parsedThreshold;

  String message = webServer.arg("message");
  message.trim();
  if (message.length() > 150) message = message.substring(0, 150);
  String pattern = webServer.arg("pattern");
  if (pattern != "slow" && pattern != "rapid" && pattern != "pulse" && pattern != "sos") pattern = "rapid";
  int hz = constrain(webServer.arg("tone").toInt(), 300, 4000);

  if (!preferences.begin("tracker", false)) {
    webServer.send(500, "text/plain", "Could not open settings storage.");
    return;
  }
  size_t savedThresholdBytes = preferences.putInt("alc_threshold", threshold);
  preferences.putString("sms_message", message);
  preferences.putString("alert_pattern", pattern);
  preferences.putUShort("tone_hz", (uint16_t)hz);
  int verifiedThreshold = preferences.getInt("alc_threshold", -1);
  preferences.end();

  if (savedThresholdBytes != sizeof(int) || verifiedThreshold != threshold) {
    Serial.printf("ERROR saving alcohol threshold. Requested=%d, bytes=%u, read-back=%d\n", threshold, (unsigned)savedThresholdBytes, verifiedThreshold);
    webServer.send(500, "text/plain", "Could not save the alcohol threshold. Check Serial Monitor and try again.");
    return;
  }

  alcoholThresholdPpm = verifiedThreshold;
  customSmsMessage = message;
  alertPattern = pattern;
  alertToneHz = (uint16_t)hz;
  Serial.printf("THRESHOLD UPDATED: requested=%d, saved=%d, active=%d\n", threshold, verifiedThreshold, alcoholThresholdPpm);
  webServer.sendHeader("Cache-Control", "no-store, no-cache, must-revalidate, max-age=0");
  webServer.sendHeader("Pragma", "no-cache");
  webServer.sendHeader("Location", "/?settingsSaved=1&v=" + String(millis()));
  webServer.send(303, "text/plain", "Saved threshold " + String(alcoholThresholdPpm) + ". Reloading settings page.");
}

void handleFirmwareUpload() {
  HTTPUpload &upload = webServer.upload();
  if (upload.status == UPLOAD_FILE_START) {
    Serial.printf("OTA upload started: %s\n", upload.filename.c_str());
    if (!Update.begin(UPDATE_SIZE_UNKNOWN, U_FLASH)) {
      Update.printError(Serial);
    }
  } else if (upload.status == UPLOAD_FILE_WRITE) {
    if (Update.write(upload.buf, upload.currentSize) != upload.currentSize) {
      Update.printError(Serial);
    }
  } else if (upload.status == UPLOAD_FILE_END) {
    if (Update.end(true)) {
      Serial.printf("OTA upload complete: %u bytes\n", upload.totalSize);
    } else {
      Update.printError(Serial);
    }
  } else if (upload.status == UPLOAD_FILE_ABORTED) {
    Update.abort();
    Serial.println("OTA upload aborted");
  }
}

void handleFirmwareUpdateComplete() {
  if (Update.hasError()) {
    webServer.sendHeader("Cache-Control", "no-store");
    webServer.send(500, "text/plain", "Firmware update failed. Check Serial Monitor; the current firmware should remain active.");
    return;
  }
  webServer.sendHeader("Cache-Control", "no-store");
  webServer.send(200, "text/html", "<!doctype html><html><body><h2>Firmware uploaded successfully</h2><p>Device restarting. Reconnect to the setup Wi-Fi and reopen the tracker page in about 15 seconds.</p></body></html>");
  delay(1000);
  ESP.restart();
}
void handleApiStatus() {
  String json="{";
  json += "\"mq3Raw\":"+String(mq3Raw)+",\"mq3Voltage\":"+String(mq3Voltage,3)+",";
  json += "\"alcoholRelativeIndex\":"+String(alcoholRelativeIndex,1)+",\"threshold\":"+String(alcoholThresholdPpm)+",";
  json += "\"alcoholAlert\":"+String(alcoholAlertActive?"true":"false")+",";
  json += "\"sw420Active\":"+String(sw420Active?"true":"false")+",";
  json += "\"mpuReady\":"+String(adxl345Ready?"true":"false")+",";
  json += "\"xG\":"+String(latestAccel.xG,3)+",\"yG\":"+String(latestAccel.yG,3)+",\"zG\":"+String(latestAccel.zG,3)+",";
  json += "\"tiltDegrees\":"+String(tiltDegrees,1)+",\"orientation\":\""+orientationText+"\",";
  json += "\"event\":\""+safetyEventStatus+"\"}";
  webServer.send(200,"application/json",json);
}

void handleClearWifi() {
  preferences.begin("tracker", false);
  preferences.remove("wifi_ssid");
  preferences.remove("wifi_pass");
  preferences.end();

  savedWifiSsid = "";
  savedWifiPassword = "";
  lastWifiStatus = "Saved Wi-Fi credentials cleared";
  WiFi.disconnect(false, false);

  webServer.sendHeader("Location", "/");
  webServer.send(303);
}

void handleNotFound() {
  webServer.sendHeader("Location", "/");
  webServer.send(302, "text/plain", "");
}

String buildStatusPage() {
  String currentSsid = configuredWifiSsid();
  String currentRecipient = configuredRecipientPhone();
  if (currentRecipient == "+639XXXXXXXXX") {
    currentRecipient = "";
  }
  String html;
  html.reserve(9000);

  html += F("<!doctype html><html><head><meta name='viewport' content='width=device-width,initial-scale=1'>");
  html += F("<title>Smart GPS Tracker</title>");
  html += F("<style>");
  html += F(":root{font-family:Arial,Helvetica,sans-serif;color:#16202a;background:#f5f7f8}");
  html += F("body{margin:0}.wrap{max-width:760px;margin:0 auto;padding:18px}");
  html += F("h1{font-size:24px;margin:6px 0 18px}.grid{display:grid;gap:12px;grid-template-columns:repeat(auto-fit,minmax(210px,1fr))}");
  html += F(".card{background:#fff;border:1px solid #d9e0e5;border-radius:8px;padding:14px}.label{font-size:12px;text-transform:uppercase;color:#66717c;margin-bottom:7px}");
  html += F(".value{font-size:18px;font-weight:700;line-height:1.35}.sub{font-size:13px;color:#66717c;margin-top:6px;line-height:1.4}");
  html += F("code{display:block;white-space:pre-wrap;word-break:break-word;margin-top:4px;color:#16202a}");
  html += F(".ok{color:#137333}.warn{color:#b06000}.bad{color:#b3261e}");
  html += F("form{margin-top:16px;background:#fff;border:1px solid #d9e0e5;border-radius:8px;padding:14px}");
  html += F("input,select{box-sizing:border-box;width:100%;padding:11px;margin:6px 0 12px;border:1px solid #b8c2cc;border-radius:6px;font-size:16px}");
  html += F("button{border:0;border-radius:6px;background:#1769aa;color:#fff;padding:11px 14px;font-size:15px;font-weight:700}");
  html += F(".danger{background:#9b1c1c}.row{display:flex;gap:10px;flex-wrap:wrap}.note{font-size:13px;color:#59636e;line-height:1.45}");
  html += F("</style></head><body><main class='wrap'>");
  html += F("<h1>Smart GPS Tracker</h1>");
  if (webServer.hasArg("settingsSaved") && webServer.arg("settingsSaved") == "1") {
    html += F("<div class='card ok' style='margin-bottom:12px'>Settings saved successfully. Current alcohol threshold: ");
    html += String(alcoholThresholdPpm);
    html += F(" (raw ADC index, not ppm).</div>");
  }
  html += F("<section class='grid'>");
  html += F("<div class='card'><div class='label'>MQ-3 Alcohol Sensor</div><div class='value ");
  html += alcoholAlertActive ? F("bad'>ALERT") : F("ok'>Monitoring");
  html += F("</div><div class='sub'>Raw ADC: "); html += String(mq3Raw);
  html += F("<br>AO voltage: "); html += String(mq3Voltage,3); html += F(" V<br>Relative ADC index (not ppm): ");
  html += String(alcoholRelativeIndex,1); html += F("<br>Threshold: "); html += String(alcoholThresholdPpm);
  html += F("</div></div>");
  html += F("<div class='card'><div class='label'>SW-420 Movement</div><div class='value ");
  html += sw420Active ? F("ok'>Vibration detected") : F("warn'>No vibration now");
  html += F("</div><div class='sub'>Digital output sampled continuously.</div></div>");
  html += F("<div class='card'><div class='label'>MPU6050 Helmet Position</div><div class='value ");
  html += adxl345Ready ? F("ok'>") : F("bad'>");
  html += htmlEscape(orientationText);
  html += F("</div><div class='sub'>X: "); html += String(latestAccel.xG,3);
  html += F(" g<br>Y: "); html += String(latestAccel.yG,3);
  html += F(" g<br>Z: "); html += String(latestAccel.zG,3);
  html += F(" g<br>Relative tilt: "); html += String(tiltDegrees,1);
  html += F("&deg;<br>Safety event: "); html += htmlEscape(safetyEventStatus);
  html += F("</div></div>");


  html += F("<div class='card'><div class='label'>GPS Status</div><div class='value ");
  html += lastKnownFix.valid ? F("ok'>") : F("warn'>");
  html += gpsStatusText();
  html += F("</div>");
  if (lastKnownFix.valid) {
    html += F("<div class='sub'>Lat: ");
    html += String(lastKnownFix.lat, 6);
    html += F("<br>Lng: ");
    html += String(lastKnownFix.lng, 6);
    html += F("<br>Satellites: ");
    html += String(lastKnownFix.satellites);
    html += F("<br>NMEA chars: ");
    html += String(gpsCharsReceived);
    html += F("<br>Valid sentences: ");
    html += String(gps.passedChecksum());
    html += F("<br>Last NMEA age: ");
    if (lastNmeaMs > 0) {
      html += String(millis() - lastNmeaMs);
      html += F(" ms");
    } else {
      html += F("not received");
    }
    html += F("<br><strong>Latest NMEA</strong><br><code>");
    html += htmlEscape(latestNmeaSentence);
    html += F("</code>");
    html += F("<br><a href='");
    html += buildMapsUrl(lastKnownFix);
    html += F("'>Open map</a></div>");
  } else {
    html += F("<div class='sub'>Waiting for NEO-6M GPS fix.");
    html += F("<br>NMEA chars: ");
    html += String(gpsCharsReceived);
    html += F("<br>Valid sentences: ");
    html += String(gps.passedChecksum());
    html += F("<br>Failed checksum: ");
    html += String(gps.failedChecksum());
    html += F("<br>Last NMEA age: ");
    if (lastNmeaMs > 0) {
      html += String(millis() - lastNmeaMs);
      html += F(" ms");
    } else {
      html += F("not received");
    }
    html += F("<br><strong>Latest NMEA</strong><br><code>");
    html += htmlEscape(latestNmeaSentence);
    html += F("</code>");
    html += F("</div>");
  }
  html += F("</div>");

  html += F("<div class='card'><div class='label'>AIR780E Status</div><div class='value ");
  html += air780eReady ? F("ok'>") : F("bad'>");
  html += airStatusText();
  html += F("</div><div class='sub'>");
  html += recipientStatusText();
  html += F("<br>");
  html += htmlEscape(lastSmsStatus);
  html += F("</div></div>");

  html += F("<div class='card'><div class='label'>Cellular Data</div><div class='value ");
  html += cellularDataReady ? F("ok'>") : F("warn'>");
  html += cellularStatusText();
  html += F("</div><div class='sub'>");
  html += htmlEscape(lastCellularStatus);
  html += F("<br>APN: ");
  if (String(CELLULAR_APN).length() > 0) {
    html += htmlEscape(String(CELLULAR_APN));
  } else {
    html += F("auto");
  }
  html += F("<br>Wi-Fi fallback delay: ");
  html += String(WIFI_ALERT_CONNECT_TIMEOUT_MS / 1000);
  html += F(" seconds</div></div>");

  html += F("<div class='card'><div class='label'>Fall Detection</div><div class='value ");
  html += adxl345Ready ? F("ok'>") : F("bad'>");
  html += accelStatusText();
  html += F("</div><div class='sub'>");
  html += htmlEscape(lastAccelStatus);
  html += F("<br>X: ");
  html += String(latestAccel.xG, 3);
  html += F(" g<br>Y: ");
  html += String(latestAccel.yG, 3);
  html += F(" g<br>Z: ");
  html += String(latestAccel.zG, 3);
  html += F(" g<br>Magnitude: ");
  html += String(latestAccel.magnitudeG, 3);
  html += F(" g<br>Freefall threshold: ");
  html += String(FALL_FREEFALL_THRESHOLD_G, 2);
  html += F(" g<br>Impact threshold: ");
  html += String(FALL_IMPACT_THRESHOLD_G, 2);
  html += F(" g<br>Shake test: ");
  html += SHAKE_TEST_MODE ? F("enabled") : F("disabled");
  html += F("<br>Shake test threshold: ");
  html += String(SHAKE_TEST_THRESHOLD_G, 2);
  html += F(" g</div></div>");

  html += F("<div class='card'><div class='label'>Wi-Fi Status</div><div class='value ");
  html += WiFi.status() == WL_CONNECTED ? F("ok'>") : F("warn'>");
  html += wifiStatusText();
  html += F("</div><div class='sub'>");
  html += htmlEscape(lastWifiStatus);
  html += F("<br>");
  html += savedWifiPassword.length() > 0 ? F("Saved password: yes") : F("Saved password: no or open Wi-Fi");
  html += F("</div></div>");

  html += F("<div class='card'><div class='label'>Firebase Status</div><div class='value ");
  if (firebaseConnected) {
    html += F("ok'>");
  } else if (WiFi.status() == WL_CONNECTED) {
    html += F("bad'>");
  } else {
    html += F("warn'>");
  }
  html += firebaseStatusText();
  html += F("</div><div class='sub'>");
  html += htmlEscape(lastFirebaseStatus);
  html += F("<br>Database: ");
  html += htmlEscape(String(FIREBASE_DATABASE_URL));
  html += F("<br>Status path: /deviceStatus/");
  html += htmlEscape(String(DEVICE_ID));
  html += F("<br>5-minute tracking: ");
  html += htmlEscape(lastTrackingStatus);
  html += F("<br>Tracking path: /devices/");
  html += htmlEscape(String(DEVICE_ID));
  html += F("/tracking");
  if (lastFirebaseHttpStatus != 0) {
    html += F("<br>HTTP: ");
    html += String(lastFirebaseHttpStatus);
  }
  html += F("</div></div>");

  html += F("<div class='card'><div class='label'>Setup Access Point</div><div class='value ok'>");
  html += htmlEscape(String(TRACKER_AP_SSID));
  html += F("</div><div class='sub'>IP: ");
  html += WiFi.softAPIP().toString();
  html += F("</div></div></section>");

  html += F("<form method='post' action='/save-wifi'><h2>Wi-Fi Connection</h2>");
  html += F("<p class='note'>Save the Wi-Fi network the ESP32-C3 should use for Firebase uploads. The setup access point stays available after saving.</p>");
  html += F("<label>Wi-Fi Name</label><input name='ssid' maxlength='32' value='");
  html += htmlEscape(currentSsid);
  html += F("' required>");
  html += F("<label>Password</label><input name='password' maxlength='64' type='password' placeholder='Leave blank for open Wi-Fi or to save an empty password'>");
  html += F("<p class='note'>If this SSID is already saved, leaving password blank keeps the previous saved password.</p>");
  html += F("<button type='submit'>Save Wi-Fi</button></form>");

  html += F("<form method='post' action='/save-recipient'><h2>SMS Recipient</h2>");
  html += F("<p class='note'>This number receives the Google Maps link for fall alerts, and for button alerts when Firebase upload fails. Include the country code.</p>");
  html += F("<label>Mobile Number</label><input name='phone' maxlength='24' type='tel' value='");
  html += htmlEscape(currentRecipient);
  html += F("' placeholder='+639171234567'>");
  html += F("<button type='submit'>Save Recipient</button></form>");

  html += F("<form method='post' action='/save-safety'><h2>Rider Safety Settings</h2>");
  html += F("<label>Alcohol threshold (raw ADC index, 1-4095; not ppm)</label><input type='number' name='threshold' min='1' max='4095' value='");
  html += String(alcoholThresholdPpm);
  html += F("' required><label>Custom emergency SMS message</label><input name='message' maxlength='150' value='");
  html += htmlEscape(customSmsMessage);
  html += F("' required><label>Alert light pattern</label><select name='pattern'>");
  html += String("<option value='slow'")+(alertPattern=="slow"?" selected":"")+">Slow</option>";
  html += String("<option value='rapid'")+(alertPattern=="rapid"?" selected":"")+">Rapid</option>";
  html += String("<option value='pulse'")+(alertPattern=="pulse"?" selected":"")+">Pulse</option>";
  html += String("<option value='sos'")+(alertPattern=="sos"?" selected":"")+">SOS</option>";
  html += F("</select><label>Passive buzzer tone (Hz)</label><input type='number' name='tone' min='300' max='4000' value='");
  html += String(alertToneHz);
  html += F("' required><button type='submit'>Save Safety Settings</button>");
  html += F("<p class='note'>MQ-3 concentration is not ppm until calibrated with a known alcohol reference.</p></form>");

  html += F("<form method='post' action='/update' enctype='multipart/form-data'><h2>Firmware Update (OTA)</h2>");
  html += F("<p class='note'>Select an ESP32-C3 firmware .bin file compiled for this exact board. Keep the device powered and do not close this page until upload completes.</p>");
  html += F("<input type='file' name='firmware' accept='.bin,application/octet-stream' required>");
  html += F("<button type='submit' class='danger'>Upload Firmware</button></form>");
  html += F("<form method='post' action='/clear-wifi' style='margin-top:10px'><button class='danger' type='submit'>Clear Saved Wi-Fi</button></form>");
  html += F("<script>let settingsDirty=false;document.querySelectorAll('form').forEach(f=>f.addEventListener('input',()=>settingsDirty=true));setInterval(()=>{if(!settingsDirty && !['INPUT','SELECT','TEXTAREA'].includes(document.activeElement.tagName)){location.reload();}},8000);</script>");
  html += F("</main></body></html>");

  return html;
}

String htmlEscape(const String &value) {
  String escaped;
  escaped.reserve(value.length());
  for (size_t i = 0; i < value.length(); i++) {
    char c = value[i];
    if (c == '&') {
      escaped += F("&amp;");
    } else if (c == '<') {
      escaped += F("&lt;");
    } else if (c == '>') {
      escaped += F("&gt;");
    } else if (c == '"') {
      escaped += F("&quot;");
    } else if (c == '\'') {
      escaped += F("&#39;");
    } else {
      escaped += c;
    }
  }
  return escaped;
}

String gpsStatusText() {
  if (!lastKnownFix.valid) {
    return "No fix yet";
  }
  if (lastKnownFix.ageMs > 10000) {
    return "Last known fix";
  }
  return "Fix active";
}

String airStatusText() {
  return air780eReady ? "Ready" : "Not responding";
}

String wifiStatusText() {
  if (WiFi.status() == WL_CONNECTED) {
    return "Connected to " + WiFi.SSID();
  }
  if (configuredWifiSsid().length() == 0 || configuredWifiSsid() == "YOUR_WIFI_NAME") {
    return "No Wi-Fi saved";
  }
  return "Disconnected";
}

String firebaseStatusText() {
  if (firebaseConnected) {
    return "Connected";
  }
  if (WiFi.status() != WL_CONNECTED) {
    if (cellularDataReady) {
      return "Checking cellular";
    }
    return "Waiting for cellular";
  }
  return "Disconnected";
}

String wifiStatusCodeText(wl_status_t status) {
  switch (status) {
    case WL_IDLE_STATUS:
      return "idle";
    case WL_NO_SSID_AVAIL:
      return "network not found. Use 2.4 GHz Wi-Fi only";
    case WL_CONNECT_FAILED:
      return "connection failed. Check password";
    case WL_CONNECTION_LOST:
      return "connection lost";
    case WL_DISCONNECTED:
      return "disconnected. Check SSID/password and 2.4 GHz support";
    case WL_CONNECTED:
      return "connected";
    default:
      return "status code " + String((int)status);
  }
}

String recipientStatusText() {
  String recipientPhone = configuredRecipientPhone();
  if (recipientPhone.length() == 0 || recipientPhone == "+639XXXXXXXXX") {
    return "Recipient: not set";
  }
  return "Recipient: " + htmlEscape(recipientPhone);
}

String accelStatusText() {
  if (!adxl345Ready) {
    return "Not detected";
  }
  if (waitingForImpact) {
    return "Possible fall";
  }
  return "Active";
}

String cellularStatusText() {
  if (cellularDataReady) {
    return "Ready";
  }
  if (!air780eReady) {
    return "Waiting for AIR780E";
  }
  return "Not connected";
}

bool checkAir780e(bool force) {
  if (!force && millis() - lastAirStatusCheckMs < AIR_STATUS_CHECK_INTERVAL_MS) {
    return air780eReady;
  }

  lastAirStatusCheckMs = millis();
  air780eReady = sendAT("AT", "OK", 1500);
  return air780eReady;
}
