// Types shared between the tasks. In a header, not the .ino, because the
// Arduino builder hoists function prototypes above anything in the sketch.
#pragma once

#include <stdint.h>

struct ImuReading {
  bool ok;
  float ax, ay, az, magnitude;  // m/s²
};

struct GpsState {
  bool everFixed;
  double lat, lng;  // last good fix
  uint32_t fixMs;
  float speedKmh;
  uint32_t ridingMs;
  bool everRode;
  uint32_t satellites;
  uint32_t charsSeen;
};

struct AlcoholState {
  bool ready;
  uint16_t raw;     // ADC counts, 0-4095. Uncalibrated: not mg/L.
  bool hasVerdict;  // warmed up and a baseline is configured
  bool detected;    // above baseline + margin (config.h)
};

// Detector → loop.
struct CrashEvent {
  uint32_t switchMs;
  float peakG;
  bool clipped;
  uint8_t switches;  // bit 0: switch 1, bit 1: switch 2
  int32_t lagMs;     // first sample over threshold, relative to the switch
};

struct Sample {
  uint32_t ms;
  float g;
  bool clipped;
};

struct PendingAlert {
  char id[21];
  const char* type;
  const char* severity;
  const char* status;  // "pending" (a crash, in its countdown) or "open"
  bool hasLocation;
  double lat, lng;
  bool hasImpact;
  float impactMs2;
  bool hasAlcoholRaw;
  uint16_t alcoholRaw;
  bool created;
  bool riderStatusDone;
  uint8_t attempts;
  uint8_t riderStatusAttempts;
  uint32_t nextAttempt;
};
