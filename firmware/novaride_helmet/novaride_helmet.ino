// NovaRide helmet firmware.
//
// What it writes to Firestore, as whom, and why each write is shaped the
// way it is: docs/FIRMWARE_CONTRACT.md. Wiring, libraries, bench tuning and
// sensor calibration: firmware/README.md. Tunables: config.h.
//
// Three threads of work:
//   detectorTask  core 1, 1 kHz. The MPU6050 and the two YL-99 switches.
//                 Decides crashes. It never touches the network, so a slow
//                 HTTPS call or a lost Wi-Fi link cannot make it miss one.
//   auxTask       core 0. NEO-6M parsing and MQ-3 sampling.
//   loop()        Wi-Fi, Firebase Auth, the alert queue, telemetry. It
//                 blocks on HTTP; nothing time-critical lives here.

#include <WiFi.h>
#include <HTTPClient.h>
#include <NetworkClientSecure.h>
#include <Wire.h>
#include <MPU6050.h>
#include <TinyGPSPlus.h>
#include <ArduinoJson.h>
#include <math.h>

#include "config.h"
#include "types.h"

#if __has_include("secrets.h")
#include "secrets.h"
#else
#error "Copy secrets.example.h to secrets.h and fill it in (firmware/README.md)."
#endif

#ifndef MQ3_BASELINE_RAW
#define MQ3_BASELINE_RAW 0  // a secrets.h from before 0.4.1: no alcohol verdict
#endif

// ------------------------------------------------------------ endpoints

#ifdef NR_EMULATOR_HOST
#define NR_PROJECT_ID "demo-novaride"
#define NR_AUTH_PREFIX "http://" NR_EMULATOR_HOST ":9099/"
#define NR_FIRESTORE_ORIGIN "http://" NR_EMULATOR_HOST ":8080"
#else
#define NR_PROJECT_ID "novaride-7a68c"
#define NR_AUTH_PREFIX "https://"
#define NR_FIRESTORE_ORIGIN "https://firestore.googleapis.com"
#endif

static const char SIGN_IN_URL[] =
  NR_AUTH_PREFIX "identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=" FIREBASE_API_KEY;
static const char REFRESH_URL[] =
  NR_AUTH_PREFIX "securetoken.googleapis.com/v1/token?key=" FIREBASE_API_KEY;
static const char COMMIT_URL[] =
  NR_FIRESTORE_ORIGIN "/v1/projects/" NR_PROJECT_ID "/databases/(default)/documents:commit";
static const char DOC_PREFIX[] =
  "projects/" NR_PROJECT_ID "/databases/(default)/documents/";

// --------------------------------------------------------- shared state

static inline uint32_t IRAM_ATTR nowMs() {
  return (uint32_t)(esp_timer_get_time() / 1000);
}

// true once `t` is at or past `deadline`; wraps correctly.
static inline bool reached(uint32_t t, uint32_t deadline) {
  return (int32_t)(t - deadline) >= 0;
}

// Guards everything below that more than one task touches, and the switch
// edges the ISR records. Held only for a few loads and stores at a time.
static portMUX_TYPE g_mux = portMUX_INITIALIZER_UNLOCKED;

// Written by the switch ISR, consumed by the detector.
static volatile uint32_t g_switchEdgeMs = 0;
static volatile uint8_t g_switchMask = 0;  // bit 0: switch 1, bit 1: switch 2

// Written by the detector.
static ImuReading g_imu = {};
static float g_tunePeakG = 0;  // highest A since the loop last read it
static uint32_t g_lastMotionMs = 0;
static bool g_everMoved = false;

// Written by auxTask.
static GpsState g_gps = {};
static AlcoholState g_alcohol = {};

// Detector → loop.
static QueueHandle_t g_crashQueue;

static MPU6050 mpu;
static TinyGPSPlus gps;
static HardwareSerial& gpsSerial = Serial2;

// ------------------------------------------------------- crash switches

static void IRAM_ATTR onSwitchClosed(void* arg) {
  const uint8_t bit = (uint8_t)(uintptr_t)arg;
  const uint32_t t = nowMs();
  portENTER_CRITICAL_ISR(&g_mux);
  // The first edge opens the window; bounce and the other switch only add
  // to the mask until the detector consumes it.
  if (g_switchMask == 0) g_switchEdgeMs = t;
  g_switchMask |= bit;
  portEXIT_CRITICAL_ISR(&g_mux);
}

// ------------------------------------------------------------------ IMU

static int readImuRegister(uint8_t reg) {
  Wire.beginTransmission(MPU_ADDRESS);
  Wire.write(reg);
  if (Wire.endTransmission(false) != 0) return -1;
  if (Wire.requestFrom(MPU_ADDRESS, (uint8_t)1) != 1) return -1;
  return Wire.read();
}

// Read straight off the bus rather than through the library, whose getters
// return a stale buffer when the device stops answering.
static bool imuConfigured() {
  const int accelConfig = readImuRegister(0x1C);  // ACCEL_CONFIG
  const int power = readImuRegister(0x6B);        // PWR_MGMT_1
  return accelConfig >= 0 && power >= 0
      && ((accelConfig >> 3) & 0x03) == MPU6050_ACCEL_FS_16
      && (power & 0x40) == 0;  // not asleep
}

static bool configureImu() {
  mpu.initialize();  // wakes it, at ±2 g
  mpu.setFullScaleAccelRange(MPU6050_ACCEL_FS_16);
  mpu.setDLPFMode(MPU6050_DLPF_BW_256);
  const bool ok = imuConfigured();
  Serial.printf("[imu] %s (WHO_AM_I 0x%02X)\n",
                ok ? "ready at +/-16 g" : "NOT RESPONDING, crash detection is off",
                readImuRegister(0x75));
  return ok;
}

static inline bool clippedAxis(int16_t raw) {
  return raw == INT16_MAX || raw == INT16_MIN;
}

// ------------------------------------------------------------- detector

static Sample g_ring[SAMPLE_RING_SIZE] = {};  // detectorTask only
static size_t g_ringNext = 0;

// The highest A sampled in [from, to], whether any sample there clipped,
// and when the first one at or over the threshold was taken.
static float peakBetween(uint32_t from, uint32_t to, bool* clipped, uint32_t* firstOverMs) {
  float peak = 0;
  *clipped = false;
  bool over = false;
  for (size_t i = 0; i < SAMPLE_RING_SIZE; i++) {
    const Sample& s = g_ring[i];
    if (!reached(s.ms, from) || !reached(to, s.ms)) continue;
    if (s.g > peak) peak = s.g;
    if (s.clipped) *clipped = true;
    if (s.g >= IMPACT_THRESHOLD_G && (!over || (int32_t)(s.ms - *firstOverMs) < 0)) {
      *firstOverMs = s.ms;
      over = true;
    }
  }
  return peak;
}

static void detectorTask(void*) {
  bool imuOk = configureImu();
  uint32_t nextHealthCheck = nowMs() + IMU_HEALTH_CHECK_MS;
  uint32_t refractoryUntil = 0;
  bool refractory = false;

  // An IMU excursion over the threshold, tracked only to log the ones no
  // switch confirms.
  bool episodeOpen = false, episodePaired = false;
  uint32_t episodeLastMs = 0;
  float episodePeak = 0;

  TickType_t wake = xTaskGetTickCount();
  for (;;) {
    vTaskDelayUntil(&wake, pdMS_TO_TICKS(SAMPLE_PERIOD_MS));
    const uint32_t now = nowMs();

    if (reached(now, nextHealthCheck)) {
      nextHealthCheck = now + IMU_HEALTH_CHECK_MS;
      const bool healthy = imuConfigured();
      if (!healthy) {
        if (imuOk) Serial.println("[imu] lost or reset");
        imuOk = configureImu();
      } else if (!imuOk) {
        imuOk = true;
        Serial.println("[imu] back");
      }
    }

    if (imuOk) {
      int16_t rx, ry, rz;
      mpu.getAcceleration(&rx, &ry, &rz);
      const float xg = rx / ACCEL_LSB_PER_G;
      const float yg = ry / ACCEL_LSB_PER_G;
      const float zg = rz / ACCEL_LSB_PER_G;
      const float a = sqrtf(xg * xg + yg * yg + zg * zg);
      const bool clipped = clippedAxis(rx) || clippedAxis(ry) || clippedAxis(rz);

      g_ring[g_ringNext] = {now, a, clipped};
      g_ringNext = (g_ringNext + 1) % SAMPLE_RING_SIZE;

      portENTER_CRITICAL(&g_mux);
      g_imu = {true, xg * STANDARD_GRAVITY, yg * STANDARD_GRAVITY, zg * STANDARD_GRAVITY,
               a * STANDARD_GRAVITY};
      if (a > g_tunePeakG) g_tunePeakG = a;
      if (fabsf(a - 1.0f) > MOTION_DEADBAND_G) {
        g_lastMotionMs = now;
        g_everMoved = true;
      }
      portEXIT_CRITICAL(&g_mux);

      if (a >= IMPACT_THRESHOLD_G) {
        if (!episodeOpen) {
          episodeOpen = true;
          episodePaired = false;
          episodePeak = 0;
        }
        episodeLastMs = now;
        if (a > episodePeak) episodePeak = a;
      }
    } else {
      portENTER_CRITICAL(&g_mux);
      g_imu.ok = false;
      portEXIT_CRITICAL(&g_mux);
    }

    // A switch edge is judged once its window has fully passed, so the
    // peak is taken over the whole of it: up to COINCIDENCE_WINDOW_MS
    // before the switch and as long after.
    uint8_t switches = 0;
    uint32_t switchMs = 0;
    portENTER_CRITICAL(&g_mux);
    if (g_switchMask != 0 && reached(now, g_switchEdgeMs + COINCIDENCE_WINDOW_MS)) {
      switches = g_switchMask;
      switchMs = g_switchEdgeMs;
      g_switchMask = 0;
    }
    portEXIT_CRITICAL(&g_mux);

    if (switches != 0) {
      if (!imuOk) {
        Serial.printf("[detect] switch %u closed, IMU down: cannot confirm, no alert\n", switches);
      } else {
        bool clipped = false;
        uint32_t firstOverMs = 0;
        const float peak = peakBetween(switchMs - COINCIDENCE_WINDOW_MS,
                                       switchMs + COINCIDENCE_WINDOW_MS, &clipped, &firstOverMs);
        const bool coincident = peak >= IMPACT_THRESHOLD_G;
        if (coincident) episodePaired = true;

        if (coincident && refractory && !reached(now, refractoryUntil)) {
          Serial.printf("[detect] crash candidate %.2f g during refractory, ignored\n", peak);
        } else if (coincident) {
          const CrashEvent ev = {switchMs, peak, clipped, switches,
                                 (int32_t)(firstOverMs - switchMs)};
          Serial.printf("[detect] CRASH peak=%.2f g%s switches=%u lag=%ld ms\n", peak,
                        clipped ? " (clipped)" : "", switches, (long)ev.lagMs);
          if (xQueueSend(g_crashQueue, &ev, 0) != pdTRUE) {
            Serial.println("[detect] crash queue full, event lost");
          }
          refractory = true;
          refractoryUntil = now + CRASH_REFRACTORY_MS;
        } else {
          Serial.printf("[detect] rejected: switch %u without impact (peak %.2f g < %.2f g)\n",
                        switches, peak, IMPACT_THRESHOLD_G);
        }
      }
    }

    if (episodeOpen && reached(now, episodeLastMs + 2 * COINCIDENCE_WINDOW_MS + 1)) {
      if (!episodePaired) {
        Serial.printf("[detect] rejected: impact %.2f g without switch\n", episodePeak);
      }
      episodeOpen = false;
    }
  }
}

// ------------------------------------------------------ GPS and alcohol

static void auxTask(void*) {
  uint32_t nextAlcoholSample = 0;
  uint8_t alcoholOverCount = 0;
  bool alcoholDetected = false;
  bool warnedNoGps = false;
  const uint32_t started = nowMs();

  for (;;) {
    while (gpsSerial.available() > 0) gps.encode(gpsSerial.read());
    const uint32_t now = nowMs();

    // TinyGPSPlus commits a location only from a sentence that reports a
    // fix, so isUpdated() means a fresh valid fix.
    if (gps.location.isUpdated()) {
      const double lat = gps.location.lat();
      const double lng = gps.location.lng();
      const bool plausible = lat >= -90 && lat <= 90 && lng >= -180 && lng <= 180
                          && !(lat == 0 && lng == 0);
      if (plausible) {
        portENTER_CRITICAL(&g_mux);
        g_gps.everFixed = true;
        g_gps.lat = lat;
        g_gps.lng = lng;
        g_gps.fixMs = now;
        portEXIT_CRITICAL(&g_mux);
      }
    }
    if (gps.speed.isUpdated()) {
      const float kmh = (float)gps.speed.kmph();
      portENTER_CRITICAL(&g_mux);
      g_gps.speedKmh = kmh;
      if (kmh >= RIDING_SPEED_KMH) {
        g_gps.ridingMs = now;
        g_gps.everRode = true;
      }
      portEXIT_CRITICAL(&g_mux);
    }
    if (gps.satellites.isUpdated()) {
      const uint32_t sats = gps.satellites.value();
      portENTER_CRITICAL(&g_mux);
      g_gps.satellites = sats;
      portEXIT_CRITICAL(&g_mux);
    }
    const uint32_t chars = gps.charsProcessed();
    portENTER_CRITICAL(&g_mux);
    g_gps.charsSeen = chars;
    portEXIT_CRITICAL(&g_mux);
    if (!warnedNoGps && chars == 0 && reached(now, started + 5000)) {
      Serial.println("[gps] no NMEA from the NEO-6M after 5 s: check TX->GPIO16 and baud");
      warnedNoGps = true;
    }

    if (reached(now, nextAlcoholSample)) {
      nextAlcoholSample = now + MQ3_SAMPLE_PERIOD_MS;
      uint32_t sum = 0;
      for (int i = 0; i < MQ3_SAMPLES_PER_READING; i++) sum += analogRead(MQ3_PIN);
      const uint16_t raw = sum / MQ3_SAMPLES_PER_READING;
      const bool ready = reached(now, MQ3_WARMUP_MS);
      const bool hasVerdict = ready && MQ3_BASELINE_RAW > 0;
      if (hasVerdict) {
        if (raw >= MQ3_BASELINE_RAW + MQ3_DETECT_MARGIN_RAW) {
          if (alcoholOverCount < MQ3_DETECT_READINGS) alcoholOverCount++;
        } else {
          alcoholOverCount = 0;
        }
        if (!alcoholDetected && alcoholOverCount >= MQ3_DETECT_READINGS) {
          alcoholDetected = true;
        } else if (alcoholDetected && raw < MQ3_BASELINE_RAW + MQ3_DETECT_MARGIN_RAW / 2) {
          alcoholDetected = false;
        }
      }
      portENTER_CRITICAL(&g_mux);
      g_alcohol = {ready, raw, hasVerdict, alcoholDetected};
      portEXIT_CRITICAL(&g_mux);
    }

    vTaskDelay(pdMS_TO_TICKS(20));
  }
}

static bool fixIsCurrent(const GpsState& s, uint32_t now) {
  return s.everFixed && !reached(now, s.fixMs + GPS_FIX_STALE_MS);
}

// ----------------------------------------------------------------- Wi-Fi

// Never blocks. The old connectWiFi() waited up to 20 s on every pass of
// loop() while out of range.
static void maintainWiFi() {
  static bool wasConnected = false;
  static bool attempted = false;
  static uint32_t lastAttempt = 0;
  const uint32_t now = nowMs();

  if (WiFi.status() == WL_CONNECTED) {
    if (!wasConnected) {
      Serial.printf("[wifi] connected, %s\n", WiFi.localIP().toString().c_str());
      wasConnected = true;
    }
    return;
  }
  if (wasConnected) {
    Serial.println("[wifi] lost");
    wasConnected = false;
  }
  if (attempted && !reached(now, lastAttempt + WIFI_RETRY_MS)) return;
  attempted = true;
  lastAttempt = now;
  Serial.printf("[wifi] connecting to %s\n", WIFI_SSID);
  WiFi.disconnect();
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);
}

// ------------------------------------------------------------------ HTTP

#ifdef NR_EMULATOR_HOST
static WiFiClient g_client;
#else
static NetworkClientSecure g_client;  // verified against the built-in CA bundle
#endif

static String g_idToken;

// The HTTP status, or a negative HTTPClient error for no response at all.
static int httpPost(const char* url, const char* contentType, const String& body,
                    String* response, bool withToken) {
  HTTPClient http;
  http.setConnectTimeout(HTTP_CONNECT_TIMEOUT_MS);
  http.setTimeout(HTTP_TIMEOUT_MS);
  if (!http.begin(g_client, url)) return HTTPC_ERROR_CONNECTION_REFUSED;
  http.addHeader("Content-Type", contentType);
  if (withToken) http.addHeader("Authorization", String("Bearer ") + g_idToken);
  const int code = http.POST(body);
  if (response != nullptr) *response = code > 0 ? http.getString() : String();
  http.end();
  return code;
}

// ------------------------------------------------------------------ Auth

static String g_refreshToken;
static uint32_t g_tokenRenewAt = 0;
static uint32_t g_nextAuthAttempt = 0;
static uint32_t g_lastForcedRenew = 0;
static bool g_forcedRenewEver = false;
static bool g_authRevoked = false;

static void keepTokens(const char* idToken, const char* refreshToken, const char* expiresIn) {
  g_idToken = idToken;
  g_refreshToken = refreshToken;
  long seconds = atol(expiresIn);
  if (seconds <= 0) seconds = 3600;
  long renewIn = seconds - TOKEN_RENEW_MARGIN_S;
  if (renewIn < 60) renewIn = 60;
  g_tokenRenewAt = nowMs() + (uint32_t)renewIn * 1000;
}

static void noteAuthError(const char* step, int code, const char* message) {
  Serial.printf("[auth] %s failed: HTTP %d %s\n", step, code, message);
  if (strncmp(message, "USER_DISABLED", 13) == 0) {
    // Revoked on purpose (contract §7). Retrying cannot help.
    g_authRevoked = true;
    Serial.println("[auth] ACCOUNT DISABLED: this helmet's access was revoked. Not retrying.");
  }
}

static bool signIn() {
  JsonDocument req;
  req["email"] = HELMET_EMAIL;
  req["password"] = HELMET_PASSWORD;
  req["returnSecureToken"] = true;
  String body, resp;
  serializeJson(req, body);
  const int code = httpPost(SIGN_IN_URL, "application/json", body, &resp, false);

  JsonDocument doc;
  deserializeJson(doc, resp);
  if (code == 200 && doc["idToken"].is<const char*>()) {
    keepTokens(doc["idToken"], doc["refreshToken"] | "", doc["expiresIn"] | "3600");
    Serial.println("[auth] signed in");
    return true;
  }
  noteAuthError("sign-in", code, doc["error"]["message"] | "");
  return false;
}

static bool refreshIdToken() {
  String resp;
  const int code = httpPost(REFRESH_URL, "application/x-www-form-urlencoded",
                            "grant_type=refresh_token&refresh_token=" + g_refreshToken, &resp, false);
  JsonDocument doc;
  deserializeJson(doc, resp);
  if (code == 200 && doc["id_token"].is<const char*>()) {
    keepTokens(doc["id_token"], doc["refresh_token"] | "", doc["expires_in"] | "3600");
    Serial.println("[auth] token refreshed");
    return true;
  }
  noteAuthError("refresh", code, doc["error"]["message"] | "");
  g_refreshToken = "";  // fall back to signing in with the password
  return false;
}

// A usable ID token, renewing it if it is due. False while it cannot get
// one; it retries on its own schedule, so callers just try again later.
static bool haveToken() {
  if (g_authRevoked) return false;
  const uint32_t now = nowMs();
  if (g_idToken.length() > 0 && !reached(now, g_tokenRenewAt)) return true;
  if (!reached(now, g_nextAuthAttempt)) return false;

  bool ok = g_refreshToken.length() > 0 && refreshIdToken();
  if (!ok && !g_authRevoked) ok = signIn();
  if (!ok) {
    g_idToken = "";
    g_nextAuthAttempt = now + AUTH_RETRY_MS;
  }
  return ok;
}

// A token minted before the helmetService claim was set carries no claim,
// and every write made with it is a 403 (contract §2). Renewing picks the
// claim up. Rate-limited, because a 403 is far more often a payload bug.
static void renewTokenAfterDenial() {
  const uint32_t now = nowMs();
  if (g_forcedRenewEver && !reached(now, g_lastForcedRenew + 300000)) return;
  g_forcedRenewEver = true;
  g_lastForcedRenew = now;
  g_tokenRenewAt = now;
  Serial.println("[auth] renewing the token in case it predates the helmetService claim");
}

// --------------------------------------------------------------- Firestore

static int commit(const String& body, String* resp) {
  if (!haveToken()) return HTTPC_ERROR_NOT_CONNECTED;
  const int code = httpPost(COMMIT_URL, "application/json", body, resp, true);
  if (code == 401) g_tokenRenewAt = nowMs();  // expired or garbled: renew, then resend
  return code;
}

static void putString(JsonObject fields, const char* key, const char* value) {
  fields[key]["stringValue"] = value;
}
static void putDouble(JsonObject fields, JsonArray mask, const char* key, double value) {
  fields[key]["doubleValue"] = value;
  mask.add(key);  // a null array, for creates, ignores this
}
static void putInteger(JsonObject fields, JsonArray mask, const char* key, long value) {
  fields[key]["integerValue"] = String(value);  // a string: contract §5
  mask.add(key);
}
static void putBool(JsonObject fields, JsonArray mask, const char* key, bool value) {
  fields[key]["booleanValue"] = value;
  mask.add(key);
}
static void stampServerTime(JsonObject write, const char* field) {
  JsonObject t = write["updateTransforms"].add<JsonObject>();
  t["fieldPath"] = field;
  t["setToServerValue"] = "REQUEST_TIME";
}

// ---------------------------------------------------------------- alerts

static PendingAlert g_alerts[ALERT_QUEUE_LEN];
static size_t g_alertHead = 0, g_alertCount = 0;

// 20 characters from A-Z a-z 0-9, like the Firebase SDKs' auto-ids. Made
// once per alert and kept, so a resend can never create a second one.
static void newAlertId(char out[21]) {
  static const char ALPHABET[] =
    "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789";
  for (int i = 0; i < 20;) {
    const uint8_t b = esp_random() & 0xFF;
    if (b < 248) out[i++] = ALPHABET[b % 62];  // 248 = 4 × 62: no modulo bias
  }
  out[20] = '\0';
}

static bool needsRiderStatus(const PendingAlert& a) {
  return strcmp(a.type, "crash") == 0 || strcmp(a.type, "sos") == 0;
}

static String alertBody(const PendingAlert& a) {
  JsonDocument doc;
  JsonObject write = doc["writes"].add<JsonObject>();
  write["update"]["name"] = String(DOC_PREFIX) + "alerts/" + a.id;
  JsonObject f = write["update"]["fields"].to<JsonObject>();
  JsonArray noMask;
  putString(f, "riderId", RIDER_ID);
  putString(f, "deviceId", DEVICE_ID);
  putString(f, "type", a.type);
  putString(f, "severity", a.severity);
  putString(f, "status", "open");
  if (a.hasLocation) {
    // A GeoPoint, never a map, and never 0,0 for "no fix" (contract §3.1).
    f["location"]["geoPointValue"]["latitude"] = a.lat;
    f["location"]["geoPointValue"]["longitude"] = a.lng;
  }
  if (a.hasImpact) putDouble(f, noMask, "impactMagnitude", a.impactMs2);
  if (a.hasAlcoholRaw) putInteger(f, noMask, "alcoholRaw", a.alcoholRaw);
  stampServerTime(write, "timestamp");
  write["currentDocument"]["exists"] = false;
  String body;
  serializeJson(doc, body);
  return body;
}

static String riderStatusBody() {
  JsonDocument doc;
  JsonObject write = doc["writes"].add<JsonObject>();
  write["update"]["name"] = String(DOC_PREFIX) + "riders/" + RIDER_ID;
  write["update"]["fields"]["status"]["stringValue"] = "emergency";
  write["updateMask"]["fieldPaths"].add("status");
  write["currentDocument"]["exists"] = true;
  String body;
  serializeJson(doc, body);
  return body;
}

// A new alert at the tail of the queue, with the position and alcohol
// snapshot taken now, at detection, not when it finally gets through.
static PendingAlert& queueAlert(const char* type, const char* severity) {
  if (g_alertCount == ALERT_QUEUE_LEN) {
    Serial.printf("[alert] queue full, dropping unsent %s\n", g_alerts[g_alertHead].id);
    g_alertHead = (g_alertHead + 1) % ALERT_QUEUE_LEN;
    g_alertCount--;
  }
  PendingAlert& a = g_alerts[(g_alertHead + g_alertCount) % ALERT_QUEUE_LEN];
  a = {};
  newAlertId(a.id);
  a.type = type;
  a.severity = severity;

  portENTER_CRITICAL(&g_mux);
  const GpsState gpsNow = g_gps;
  const AlcoholState alcoholNow = g_alcohol;
  portEXIT_CRITICAL(&g_mux);
  a.hasLocation = gpsNow.everFixed;  // the last good fix, however old
  a.lat = gpsNow.lat;
  a.lng = gpsNow.lng;
  a.hasAlcoholRaw = alcoholNow.ready;
  a.alcoholRaw = alcoholNow.raw;
  a.nextAttempt = nowMs();
  g_alertCount++;

  if (a.hasLocation) {
    Serial.printf("[alert] %s queued: %s, %s, at %.6f,%.6f (fix %lus old)\n", a.id, type, severity,
                  a.lat, a.lng, (unsigned long)((nowMs() - gpsNow.fixMs) / 1000));
  } else {
    Serial.printf("[alert] %s queued: %s, %s, no fix since boot\n", a.id, type, severity);
  }
  return a;
}

static void queueCrash(const CrashEvent& ev) {
  PendingAlert& a =
    queueAlert("crash", (ev.clipped || ev.peakG >= SEVERITY_HIGH_G) ? "high" : "moderate");
  a.hasImpact = true;
  a.impactMs2 = ev.peakG * STANDARD_GRAVITY;
}

// One alcoholWarning when detection starts, then none for the refractory
// period however long it lasts or however often it flickers.
static void watchAlcohol() {
  static bool wasDetected = false;
  static bool alerted = false;
  static uint32_t lastAlert = 0;
  portENTER_CRITICAL(&g_mux);
  const bool detected = g_alcohol.hasVerdict && g_alcohol.detected;
  portEXIT_CRITICAL(&g_mux);
  const uint32_t now = nowMs();
  if (detected && !wasDetected
      && (!alerted || reached(now, lastAlert + ALCOHOL_ALERT_REFRACTORY_MS))) {
    queueAlert("alcoholWarning", "moderate");
    alerted = true;
    lastAlert = now;
  }
  wasDetected = detected;
}

static uint32_t backoff(uint8_t attempts) {
  const uint32_t ms = 2000u << (attempts < 5 ? attempts : 5);
  return ms < ALERT_RETRY_MAX_MS ? ms : ALERT_RETRY_MAX_MS;
}

// One request for the alert at the head of the queue, if one is due.
// Returns true if it made a request.
static bool serviceAlertQueue() {
  if (g_alertCount == 0) return false;
  PendingAlert& a = g_alerts[g_alertHead];
  const uint32_t now = nowMs();
  if (!reached(now, a.nextAttempt) || !haveToken()) return false;

  String resp;
  if (!a.created) {
    const int code = commit(alertBody(a), &resp);
    if (code == 200 || code == 409) {
      // 409: an earlier attempt landed and its reply was lost (§3.3).
      a.created = true;
      Serial.printf("[alert] %s %s\n", a.id, code == 200 ? "created" : "already there");
    } else {
      a.attempts++;
      a.nextAttempt = now + backoff(a.attempts);
      Serial.printf("[alert] %s HTTP %d, retry %u in %lus\n", a.id, code, a.attempts,
                    (unsigned long)(backoff(a.attempts) / 1000));
      if (code == 403) {
        // Always a firmware bug or a pre-claim token (§3.4). Never drop a
        // crash for it: keep retrying, and say so loudly.
        Serial.printf("[alert] PERMISSION_DENIED: %s\n", resp.c_str());
        renewTokenAfterDenial();
      }
      return true;
    }
  } else if (needsRiderStatus(a) && !a.riderStatusDone) {
    // Separately from the alert, never in the same commit (§3.5).
    const int code = commit(riderStatusBody(), &resp);
    a.riderStatusAttempts++;
    if (code == 200) {
      a.riderStatusDone = true;
      Serial.printf("[alert] riders/%s set to emergency\n", RIDER_ID);
    } else if (code == 403) {
      // The alert itself just got through with this token, so this is not
      // the claim: the rules refuse a rider that does not exist.
      a.riderStatusDone = true;
      Serial.printf("[alert] riders/%s refused: does it exist? is RIDER_ID right?\n", RIDER_ID);
    } else if (a.riderStatusAttempts >= RIDER_STATUS_MAX_ATTEMPTS) {
      a.riderStatusDone = true;
      Serial.printf("[alert] gave up on rider status: HTTP %d %s\n", code, resp.c_str());
    } else {
      a.nextAttempt = now + backoff(a.riderStatusAttempts);
      return true;
    }
  }

  if (a.created && (!needsRiderStatus(a) || a.riderStatusDone)) {
    g_alertHead = (g_alertHead + 1) % ALERT_QUEUE_LEN;
    g_alertCount--;
  }
  return true;
}

// ------------------------------------------------------------- telemetry

static uint32_t g_nextTelemetry = 0;

static bool helmetActive(uint32_t now) {
  portENTER_CRITICAL(&g_mux);
  const bool rode = g_gps.everRode && !reached(now, g_gps.ridingMs + ACTIVE_HOLD_MS);
  const bool moved = g_everMoved && !reached(now, g_lastMotionMs + ACTIVE_HOLD_MS);
  portEXIT_CRITICAL(&g_mux);
  return rode || moved;
}

static void sendTelemetry() {
  const uint32_t now = nowMs();
  portENTER_CRITICAL(&g_mux);
  const ImuReading imu = g_imu;
  const GpsState gpsNow = g_gps;
  const AlcoholState alcoholNow = g_alcohol;
  portEXIT_CRITICAL(&g_mux);
  const bool fix = fixIsCurrent(gpsNow, now);

  JsonDocument doc;
  JsonObject write = doc["writes"].add<JsonObject>();
  write["update"]["name"] = String(DOC_PREFIX) + "devices/" + DEVICE_ID;
  JsonObject f = write["update"]["fields"].to<JsonObject>();
  // Built field by field with the mask, so the two always match. Without
  // the mask this write would delete the console's pairing (§4.3).
  JsonArray mask = write["updateMask"]["fieldPaths"].to<JsonArray>();

  if (imu.ok) {
    putDouble(f, mask, "ax", imu.ax);
    putDouble(f, mask, "ay", imu.ay);
    putDouble(f, mask, "az", imu.az);
    putDouble(f, mask, "vector_magnitude", imu.magnitude);
  }
  putBool(f, mask, "imu_ok", imu.ok);
  // With no current fix the stored position is left alone and gps_fix says
  // it is stale; nothing is overwritten with zeros.
  putBool(f, mask, "gps_fix", fix);
  if (fix) {
    putDouble(f, mask, "latitude", gpsNow.lat);
    putDouble(f, mask, "longitude", gpsNow.lng);
    putDouble(f, mask, "speed_kmh", gpsNow.speedKmh);
  }
  if (alcoholNow.ready) putInteger(f, mask, "alcohol_raw", alcoholNow.raw);
  // With no verdict the field is left out, so the console says "Not
  // measured"; a stored verdict from before a reboot would otherwise
  // linger, so it is cleared by listing it in the mask with no value.
  if (alcoholNow.hasVerdict) {
    putBool(f, mask, "alcohol_detected", alcoholNow.detected);
  } else {
    mask.add("alcohol_detected");
  }
  f["firmware_version"]["stringValue"] = FIRMWARE_VERSION;
  mask.add("firmware_version");
  stampServerTime(write, "last_update");

  String body, resp;
  serializeJson(doc, body);
  const int code = commit(body, &resp);
  if (code != 200) Serial.printf("[telemetry] HTTP %d %s\n", code, resp.c_str());
}

static void serviceTelemetry() {
  const uint32_t now = nowMs();
  if (!reached(now, g_nextTelemetry) || !haveToken()) return;
  g_nextTelemetry = now + (helmetActive(now) ? TELEMETRY_ACTIVE_MS : TELEMETRY_PARKED_MS);
  sendTelemetry();
}

// ------------------------------------------------------------ tuning log

static void logTuning() {
  static uint32_t next = 0;
  const uint32_t now = nowMs();
  if (!reached(now, next)) return;
  next = now + TUNE_LOG_EVERY_MS;

  portENTER_CRITICAL(&g_mux);
  const float peak = g_tunePeakG;
  g_tunePeakG = 0;
  const bool imuOk = g_imu.ok;
  const GpsState gpsNow = g_gps;
  const AlcoholState alcoholNow = g_alcohol;
  portEXIT_CRITICAL(&g_mux);

  Serial.printf("[tune] peak=%.2fg imu=%s gps=%s sats=%lu mq3=%u%s wifi=%s auth=%s queue=%u\n",
                peak, imuOk ? "ok" : "DOWN",
                fixIsCurrent(gpsNow, now) ? "fix" : (gpsNow.charsSeen ? "nofix" : "silent"),
                (unsigned long)gpsNow.satellites, alcoholNow.raw,
                alcoholNow.ready ? "" : "(warming)",
                WiFi.status() == WL_CONNECTED ? "up" : "down",
                g_authRevoked ? "REVOKED" : (g_idToken.length() ? "ok" : "none"),
                (unsigned)g_alertCount);
}

// ------------------------------------------------------------ setup/loop

void setup() {
  Serial.begin(115200);
  Serial.printf("\nNovaRide helmet %s, device %s, rider %s, %s\n", FIRMWARE_VERSION, DEVICE_ID,
                RIDER_ID,
#ifdef NR_EMULATOR_HOST
                "EMULATOR at " NR_EMULATOR_HOST
#else
                "LIVE " NR_PROJECT_ID
#endif
  );

  Wire.begin(I2C_SDA_PIN, I2C_SCL_PIN);
  Wire.setClock(I2C_CLOCK_HZ);

  analogReadResolution(12);
  analogSetPinAttenuation(MQ3_PIN, ADC_11db);
  gpsSerial.begin(GPS_BAUD, SERIAL_8N1, GPS_RX_PIN, GPS_TX_PIN);

#ifndef NR_EMULATOR_HOST
  g_client.useBuiltinCACertBundle();
#endif
  WiFi.mode(WIFI_STA);
  WiFi.setSleep(false);
  maintainWiFi();  // starts the first attempt; does not wait for it

  g_crashQueue = xQueueCreate(4, sizeof(CrashEvent));

  pinMode(CRASH_SWITCH_1_PIN, INPUT_PULLUP);
  pinMode(CRASH_SWITCH_2_PIN, INPUT_PULLUP);
  attachInterruptArg(digitalPinToInterrupt(CRASH_SWITCH_1_PIN), onSwitchClosed, (void*)1, FALLING);
  attachInterruptArg(digitalPinToInterrupt(CRASH_SWITCH_2_PIN), onSwitchClosed, (void*)2, FALLING);

  // The detector outranks loop() on the same core, so a TLS handshake in
  // loop() cannot delay a sample.
  xTaskCreatePinnedToCore(detectorTask, "detector", 4096, nullptr, 5, nullptr, 1);
  xTaskCreatePinnedToCore(auxTask, "aux", 4096, nullptr, 1, nullptr, 0);
}

void loop() {
  maintainWiFi();

  CrashEvent ev;
  while (xQueueReceive(g_crashQueue, &ev, 0) == pdTRUE) queueCrash(ev);
  watchAlcohol();

  if (WiFi.status() == WL_CONNECTED) {
    // Alerts first. Telemetry only goes out when no alert is due.
    if (!serviceAlertQueue()) serviceTelemetry();
  }

  logTuning();
  delay(10);
}
