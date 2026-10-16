// Pins, thresholds and timings. Everything you might change on the bench
// is in this file; nothing in it is secret. Per-helmet identity and
// credentials are in secrets.h.
#pragma once

#include <stdint.h>

static const char FIRMWARE_VERSION[] = "0.4.0";

// ---------------------------------------------------------------- pins

// YL-99 collision switches. Active LOW: the module pulls the line low
// while the lever is pressed. Power the modules from 3.3 V, not 5 V; their
// output is the supply rail and the ESP32 is not 5 V tolerant.
static const int CRASH_SWITCH_1_PIN = 13;
static const int CRASH_SWITCH_2_PIN = 27;

// MPU6050 on I2C, AD0 tied low.
static const int I2C_SDA_PIN = 21;
static const int I2C_SCL_PIN = 22;
static const uint32_t I2C_CLOCK_HZ = 400000;
static const uint8_t MPU_ADDRESS = 0x68;

// NEO-6M on UART2. The module's TX goes to GPS_RX_PIN.
static const int GPS_RX_PIN = 16;
static const int GPS_TX_PIN = 17;
static const uint32_t GPS_BAUD = 9600;

// MQ-3 analogue out. Must be an ADC1 pin (GPIO 32-39): ADC2 is unusable
// while Wi-Fi is on. The module's AO swings to its 5 V heater supply, so it
// goes through a divider to stay under 3.3 V (firmware/README.md).
static const int MQ3_PIN = 34;

// ------------------------------------------------- crash detection

// The dual-sensor rule (paper, Chapter 2, Algorithm Discussion): a crash is
// A = sqrt(X² + Y² + Z²) over IMPACT_THRESHOLD_G *and* a crash switch
// closing, within COINCIDENCE_WINDOW_MS of each other. Either one alone is
// logged as a rejected candidate and raises nothing.

// ±16 g full scale; at the default ±2 g every axis clips at 2 g and the
// magnitude of a real impact is unmeasurable. 2048 LSB per g at ±16 g
// (MPU6050 register map, ACCEL_CONFIG).
static const float ACCEL_LSB_PER_G = 2048.0f;

// Impact threshold, in g, on the magnitude A.
//
// A starting value, not yet measured on this helmet. At rest A is 1 g;
// riding vibration and head movement add a few g at most; a head impact in
// a fall is tens of g. 4 g sits well clear of the first two and far below
// the third. The switch already ignores vibration, so the threshold's main
// job is to reject a switch knocked by a hand, a bag or a helmet hook,
// which barely moves the IMU.
//
// To tune it, use the serial log (firmware/README.md, "Tuning"): `[tune]`
// prints the highest A each second and `[detect]` prints every rejected
// candidate with its peak. Ride normally and handle the helmet normally;
// the threshold goes above the highest peak seen with margin, and every
// drop test must still clear it.
static const float IMPACT_THRESHOLD_G = 4.0f;

// How far apart the switch closing and the IMU crossing the threshold may
// be, either way round, and still count as one event.
//
// The collision pulse lasts milliseconds. The window does not need to
// cover the pulse; it covers the offset between the two sensors seeing it:
// lever travel before the switch closes, contact bounce, and the 1 ms
// sample period. 50 ms covers that with room, and is still far shorter
// than the seconds between a knock on the switch and some unrelated jolt.
// Each confirmed crash logs the measured offset as `lag`; narrow the window
// once you have those numbers.
static const uint32_t COINCIDENCE_WINDOW_MS = 50;

// After a crash, further candidates are logged and ignored for this long,
// so one tumbling fall raises one alert rather than five.
static const uint32_t CRASH_REFRACTORY_MS = 10000;

// IMU sampling. 1 kHz is the accelerometer's own output rate, and the DLPF
// is at its widest (260 Hz) so a short pulse is not smoothed away.
static const uint32_t SAMPLE_PERIOD_MS = 1;

// Samples kept for looking back across the window. Must cover
// 2 × COINCIDENCE_WINDOW_MS plus slack.
static const size_t SAMPLE_RING_SIZE = 256;
static_assert(SAMPLE_RING_SIZE * SAMPLE_PERIOD_MS > 2 * COINCIDENCE_WINDOW_MS + 20,
              "SAMPLE_RING_SIZE too small for COINCIDENCE_WINDOW_MS");

// How often the detector checks that the IMU is still there and still at
// ±16 g. A brown-out resets the MPU6050 to ±2 g, which would silently put
// every reading 8× too high.
static const uint32_t IMU_HEALTH_CHECK_MS = 1000;

// --------------------------------------------------------- severity
//
// Contract §8.4 leaves this to the firmware. A confirmed crash is never
// `low`. It is `high` when the peak reaches SEVERITY_HIGH_G, or when any
// axis clipped (the true peak is then unknown and above what was
// measured); otherwise `moderate`. 10 g is a placeholder, to be set from
// the same bench data as IMPACT_THRESHOLD_G.
static const float SEVERITY_HIGH_G = 10.0f;

static const float STANDARD_GRAVITY = 9.80665f;  // g → m/s², the contract's unit

// ------------------------------------------------------------- GPS

// A fix older than this is not "current": gps_fix goes false and the
// position is left out of telemetry. Alerts still carry the last good fix,
// however old (contract §3.1).
static const uint32_t GPS_FIX_STALE_MS = 3000;

// ----------------------------------------------------------- MQ-3

// Readings before this are not reported at all. The heater needs minutes
// to settle after power-on (and 24-48 h burn-in when the sensor is new).
static const uint32_t MQ3_WARMUP_MS = 180000;
static const uint32_t MQ3_SAMPLE_PERIOD_MS = 500;
static const int MQ3_SAMPLES_PER_READING = 16;

// ------------------------------------------------------- telemetry

// Contract §4.4: 20,000 writes a day for the whole project.
static const uint32_t TELEMETRY_ACTIVE_MS = 15000;    // 5,760 writes/day
static const uint32_t TELEMETRY_PARKED_MS = 180000;   //   480 writes/day

// "Active" means the GPS saw riding speed, or the IMU saw the helmet move
// (A more than MOTION_DEADBAND_G away from 1 g), within ACTIVE_HOLD_MS.
static const float MOTION_DEADBAND_G = 0.3f;
static const float RIDING_SPEED_KMH = 5.0f;
static const uint32_t ACTIVE_HOLD_MS = 60000;

// -------------------------------------------------------- network

static const uint32_t WIFI_RETRY_MS = 10000;
static const uint32_t HTTP_CONNECT_TIMEOUT_MS = 8000;
static const uint16_t HTTP_TIMEOUT_MS = 10000;

static const uint32_t AUTH_RETRY_MS = 15000;
static const long TOKEN_RENEW_MARGIN_S = 300;  // refresh at 55 of 60 minutes

static const size_t ALERT_QUEUE_LEN = 8;
static const uint32_t ALERT_RETRY_MAX_MS = 60000;
static const uint8_t RIDER_STATUS_MAX_ATTEMPTS = 5;

static const uint32_t TUNE_LOG_EVERY_MS = 1000;
