// Copy to secrets.h (gitignored) and fill in. One secrets.h per physical
// helmet: the account, DEVICE_ID and RIDER_ID all belong to it.
#pragma once

#define WIFI_SSID "your-ssid"
#define WIFI_PASSWORD "your-wifi-password"

// Project settings -> General -> Web API key. Not a secret, but kept here
// with the rest of the configuration. Any value works on the emulator.
#define FIREBASE_API_KEY "anything"

// The helmet's own Firebase account (contract §2, §7). On the emulator,
// tool/provision_helmet_service.mjs creates this one.
#define HELMET_EMAIL "helmet-nr-h1-001@novaride.invalid"
#define HELMET_PASSWORD "dev-only-helmet-pw"

// This helmet's serial, which is its devices/ document id.
#define DEVICE_ID "NR-H1-001"

// The riders/ document id this helmet is paired with in the console, for
// example R-001. Not a Firebase Auth uid. Contract §3.6.
#define RIDER_ID "R-001"

// Uncomment to talk to the local emulators on this laptop address instead
// of the live project (contract §1). Plain HTTP, project demo-novaride.
// #define NR_EMULATOR_HOST "192.168.100.23"
