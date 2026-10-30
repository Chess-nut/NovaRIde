# NovaRide — Helmet Firmware Contract

What the ESP32 helmet writes to the cloud, as whom, and what happens when a
write is wrong. It is written for someone who has never opened this
repository. You need nothing else from it except the files named in §1.

**The whole system in one paragraph.** The helmet talks to **Cloud Firestore**,
a Google-hosted document database. An operator console (a web app) watches
that database live. When the helmet detects a crash, it creates a document
in `alerts/`, and a dispatcher sees it on the board within a second or two.
The rest of the time it keeps its own document in `devices/` up to date with
readings, and the console shows those on a map. The helmet signs in to
Firebase with an email and password, like any other client. A set of
**security rules** decides whether each write is accepted, and those rules
are what this document describes.

The helmet makes exactly three kinds of write, and it reads nothing:

| Write | When | Section |
|---|---|---|
| Create `alerts/{id}` | A crash, an SOS, alcohol detected (§3.7), a low battery | §3 |
| Set `riders/{riderId}.status` to `"emergency"` | Right after a `crash` or `sos` alert | §3.5 |
| Update `devices/{deviceId}` | Periodically, with the latest readings | §4 |

All three go to one HTTPS endpoint, Firestore's `documents:commit`. It is
the only REST call that lets the database stamp the time itself, and every
time in this contract is stamped by the database. **The helmet needs no clock.**

---

## 1. Where to develop: the local emulator

**Develop against the emulator first, not the live project.** On the live
project the helmet's account and the rules in §3 are provisioned separately
(§7). Until then every write you make there comes back `403
PERMISSION_DENIED`, and you can't tell a wrong payload from a missing account.
The Firebase emulators run the same rules, from the same file, on your laptop.
The emulator also tells you *which rule line* refused a write, and the live
project never does.

The emulator project is called `demo-novaride`. The `demo-` prefix means it
does not exist anywhere: nothing you do can reach the real database, and you
need no Google account.

### One-time setup

1. Install **Node.js** 20 or newer and a **JDK 21** (Temurin 21 works). The
   Firestore emulator is a Java program.
2. `npm install -g firebase-tools`
3. Clone this repository, then `cd tool` and `npm install`.

### Every session

From the repository root:

```
firebase emulators:start --config firebase.firmware.json --only auth,firestore --project demo-novaride
```

`firebase.firmware.json` is the repo's normal emulator setup, with one
difference: it listens on every network interface rather than only on
`localhost`. That is what lets an ESP32 on the same Wi-Fi reach it. The
first time, your OS firewall will ask whether Java and Node may accept
connections. Allow it on **private** networks. Campus Wi-Fi often blocks
device-to-device traffic, and a phone hotspot that both the laptop and the
ESP32 join avoids that. Stop the emulators when you are done, because
anyone on that network can reach them while they run.

In a second terminal, create the helmet's account and give it its role:

```
cd tool
node provision_helmet_service.mjs helmet-nr-h1-001@novaride.invalid --emulator --create dev-only-helmet-pw
```

Then open <http://localhost:4000/firestore> (the Emulator UI) and create the
two documents the console would already have made on the live project:

- `riders/R-001` with `fullName` (string) and `status` = `riding` (string).
  Without it, the rider-status write in §3.5 is refused, because the helmet
  can change a rider's status but can't create a rider.
- `devices/NR-H1-001` with `assigned_rider_id` = `R-001` (string). This is
  the pairing the console writes. Keep it, so you can see that your
  telemetry writes leave it alone (§4.3).

Writes made from the Emulator UI bypass the rules, so they are for fixtures
only. **Everything is wiped when the emulators stop.** To keep state between
sessions, add `--import=../novaride-emulator-data --export-on-exit` to the
start command. Keep that folder outside the repository.

### Pointing the helmet at it

Find the laptop's LAN address (`ipconfig` on Windows, `ip addr` on Linux,
for example `192.168.100.23`). The firmware then uses plain HTTP to:

| Purpose | Emulator URL |
|---|---|
| Sign in | `http://<laptop-ip>:9099/identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=anything` |
| Refresh the token | `http://<laptop-ip>:9099/securetoken.googleapis.com/v1/token?key=anything` |
| Write | `http://<laptop-ip>:8080/v1/projects/demo-novaride/databases/(default)/documents:commit` |

The emulator accepts any API key. If your HTTP library rejects the
parentheses in `(default)`, send them as `%28default%29`.

Before touching the ESP32, you can run each call in this document from the
laptop with `curl` (on Windows PowerShell type `curl.exe`, because plain
`curl` is a different command there). Save a body to a file and send it:

```
curl.exe -X POST "http://localhost:8080/v1/projects/demo-novaride/databases/(default)/documents:commit" -H "Authorization: Bearer <idToken>" -H "Content-Type: application/json" --data-binary @alert.json
```

### Seeing what happened

- **Emulator UI → Firestore → Data** shows the documents as the console
  would see them.
- **Emulator UI → Firestore → Requests** lists every request with the rule
  evaluation beside it. When a write is refused, this shows which condition
  failed.
- The 403 body names the refusing rule line too, for example
  `false for 'create' @ L221`. The line numbers refer to `firestore.rules` in
  this repository.

---

## 2. How the helmet authenticates

The helmet is a normal Firebase Auth email/password user. The only thing
special about it is a **custom claim** on the account, `role: helmetService`,
which the project owner sets with `tool/provision_helmet_service.mjs` (§7).
Firebase copies the claim into every sign-in token, and the rules check for
it. The rules recognise the helmet by that claim and nothing else.

### What that identity can do

| | |
|---|---|
| **May** | create `alerts/` documents that satisfy §3 · create and update `devices/` documents · change `riders/{id}.status` and nothing else on a rider |
| **May not** | read anything, including its own `devices/` document · edit or delete an alert once created · write any other collection |

The password lives in the helmet's flash, and anyone holding a helmet can
read flash. The rules are built around that fact: stolen helmet credentials
let someone write junk telemetry, but not read one rider's position.

### The token lifecycle

**1. Sign in** once, at boot:

```
POST https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=<WEB_API_KEY>
Content-Type: application/json

{ "email": "helmet-nr-h1-001@novaride.invalid", "password": "<password>", "returnSecureToken": true }
```

The response carries `idToken`, `refreshToken` and `expiresIn` (`"3600"`
seconds). Keep both tokens in RAM.

**2. Use** the ID token on every Firestore request:

```
Authorization: Bearer <idToken>
```

**3. Refresh** before the hour is up. Around 55 minutes is a good margin.
Refreshing is cheaper than signing in again and doesn't send the password:

```
POST https://securetoken.googleapis.com/v1/token?key=<WEB_API_KEY>
Content-Type: application/x-www-form-urlencoded

grant_type=refresh_token&refresh_token=<refreshToken>
```

The response uses snake_case: `id_token`, `refresh_token`, `expires_in`.
Replace both stored tokens with the new ones.

**4. If refresh fails**, sign in again with the password. If signing in
fails with `USER_DISABLED`, the account has been revoked on purpose (§7.4).
Stop retrying and show an error on the helmet.

A token minted **before** the claim was set carries no claim, and every
write made with it is refused. After the owner runs the provisioning script,
the helmet has to sign in again or refresh.

On the live project the URLs are `https://`, and the TLS certificate must be
verified. Use the ESP-IDF certificate bundle (or your library's) rather
than turning verification off. `<WEB_API_KEY>` is the project's Web API key,
which the project owner gives you. It identifies the project and is not a
secret.

---

## 3. `alerts/{alertId}`: one document per incident

Every alert is **created** by the helmet and never touched by it again.
Dispatchers then move it through `open → acknowledged → dispatched →
resolved` from the console. A crash starts one step earlier, `pending`,
while its rider can call it off (§3.8).

### 3.1 Fields

Field names are **camelCase** in this collection.

| Field | Type (REST value) | Required | Units / values | Notes |
|---|---|---|---|---|
| `riderId` | string (`stringValue`) | **yes**, non-empty | e.g. `R-001` | The rider this helmet is paired with. See §3.6 for where the helmet gets it. |
| `deviceId` | string (`stringValue`) | **yes**, non-empty | e.g. `NR-H1-001` | This helmet's serial, the same as its `devices/` document id. |
| `type` | string (`stringValue`) | **yes** | exactly `crash` · `sos` · `alcoholWarning` · `lowBattery` | Case-sensitive. The reports filter on this field. |
| `severity` | string (`stringValue`) | **yes** | exactly `low` · `moderate` · `high` | **Lowercase, and only these three.** `High`, `medium` and `critical` are all refused. How a reading maps to a severity is the firmware's decision. |
| `status` | string (`stringValue`) | **yes** | `pending` for a `crash`; `open` for everything else | A crash may also be sent `open`, and must be when the rules refuse `pending` (§3.8). Only the console, and the rider during the countdown, move it on. |
| `timestamp` | timestamp | **yes** | server time | **Never put this in `fields`.** It is written by a server transform (§3.2). A time from the helmet's clock is refused. |
| `location` | GeoPoint (`geoPointValue`) | no, but send it whenever you have one | degrees, WGS-84 | **The canonical position.** Latitude −90…90, longitude −180…180. Send the last known good fix. |
| `lat`, `lng` | number, number | no | degrees | Accepted **instead of** `location`, never alongside it. If you send one, send both. |
| `alcoholLevel` | number (`doubleValue` or `integerValue`) | no | **mg/L**, MQ-3 | A calibrated concentration, for if the study ever needs one. Firmware 0.4 does not send it (§3.7), and the console does not read it. |
| `alcoholRaw` | number (`integerValue`) | no | ADC counts, 0–4095 | The uncalibrated MQ-3 output at the moment of the alert, sent instead of a converted mg/L figure that would be invented. **Not mg/L**. Stored, not displayed. See §3.7. |
| `impactMagnitude` | number (`doubleValue` or `integerValue`) | no | **m/s²** | Peak of √(ax² + ay² + az²) from the MPU6050, the same formula and unit as `vector_magnitude` in `devices/`. About 9.8 at rest. |

**Snake_case aliases.** `alcohol_level` and `impact_magnitude` are accepted in
place of `alcoholLevel` and `impactMagnitude`, and they're held to the same
type (a number). They exist so that a firmware still writing the `devices/`
spelling degrades gracefully. **Write the camelCase names**, and never both
spellings in one document.

**Don't write** `riderName` or `address` (the console fills both in from its
own records), `acknowledgedAt`, `dispatchedAt` or `resolvedAt` (the console
stamps those, and an alert that arrives with any of them is refused). Any
other field is stored but ignored.

**No GPS fix?** Leave `location` out entirely and send the alert anyway. A
crash with no position must still reach the board, so the rules
deliberately don't require a position. Never send `0, 0` as "no fix": that
is a real point in the Atlantic, and the board would plot the rider there.

### 3.2 Worked example

The document as it will appear in the database:

```
alerts/k3F9qTz2VbX8mLw4NcR7
  riderId:         "R-001"
  deviceId:        "NR-H1-001"
  type:            "crash"
  severity:        "high"
  status:          "pending"
  location:        GeoPoint(14.5995, 120.9842)
  alcoholRaw:      1210
  impactMagnitude: 31.4
  timestamp:       2026-09-30 04:33:35 UTC+8     ← stamped by the server
```

The request that creates it, `POST …/documents:commit`, is copyable as is
against the emulator (§1):

<!-- contract-example: alert expect=200 -->
```json
{
  "writes": [
    {
      "update": {
        "name": "projects/demo-novaride/databases/(default)/documents/alerts/k3F9qTz2VbX8mLw4NcR7",
        "fields": {
          "riderId":         { "stringValue": "R-001" },
          "deviceId":        { "stringValue": "NR-H1-001" },
          "type":            { "stringValue": "crash" },
          "severity":        { "stringValue": "high" },
          "status":          { "stringValue": "pending" },
          "location":        { "geoPointValue": { "latitude": 14.5995, "longitude": 120.9842 } },
          "alcoholRaw":      { "integerValue": "1210" },
          "impactMagnitude": { "doubleValue": 31.4 }
        }
      },
      "updateTransforms": [
        { "fieldPath": "timestamp", "setToServerValue": "REQUEST_TIME" }
      ],
      "currentDocument": { "exists": false }
    }
  ]
}
```

The three parts that matter:

- **`updateTransforms`** is how `timestamp` gets the server's time. The
  database writes its own clock into the field, and the rules check that the
  value equals the moment of the request. It is the only way to satisfy
  them, which is why every write here uses `documents:commit` rather than
  the simpler create or patch calls: those can't carry a transform.
- **`currentDocument: { exists: false }`** makes this a create that can
  never overwrite an existing document.
- **The document id** (`k3F9qTz2VbX8mLw4NcR7` above) is chosen by the
  helmet: **20 random characters from `A–Z a–z 0–9`**, from `esp_random()`.
  That's the same shape Firebase's own SDKs generate. On the live project,
  replace `demo-novaride` in `name` with `novaride-7a68c`.

A successful response is `200` with a `writeResults[0].transformResults[0]
.timestampValue`, which is the time the server stamped.

### 3.3 Retrying is safe

Generate the id **once per alert** and keep it until the alert is
confirmed. If a request times out, send the identical body again:

| Response | Meaning | Do |
|---|---|---|
| `200` | Created | Done. |
| `409 ALREADY_EXISTS` | An earlier attempt landed and you never saw the reply | Done. This is not an error. |
| timeout / connection error | Unknown | Resend the same body. |

Because the id doesn't change, a retry can never produce a second alert.
If the helmet is offline, queue the alert with its id and send it on
reconnection. Note that `timestamp` will then record when the alert
*arrived*, not when the crash happened (§8).

### 3.4 What a malformed alert does

**A malformed alert is refused with `403 PERMISSION_DENIED`, never silently
stored.** This is deliberate. The dispatcher board lists alerts ordered by
`timestamp`, and the database leaves any document without that field out of
such a query. An alert without a timestamp would sit in the database where
no dispatcher could see it. For a crash, that is the worst possible outcome.
A refusal is at least visible to you on the bench, before a helmet ships.

Everything the rules require is a constant or a server transform, so the
helmet can always supply it, whatever its sensors are doing. A `403` on an
alert therefore always means a firmware bug, never a bad GPS day. Checked
against the emulator:

| You send | Response |
|---|---|
| No `updateTransforms` (no `timestamp`) | `403 PERMISSION_DENIED` |
| `timestamp` in `fields`, from the helmet clock | `403 PERMISSION_DENIED` |
| `severity` of `"High"`, `"medium"`, `"critical"`, or missing | `403 PERMISSION_DENIED` |
| `type` of `"Crash"`, `"fall"`, `"alcohol_warning"`, or missing | `403 PERMISSION_DENIED` |
| `riderId` or `deviceId` missing or `""` | `403 PERMISSION_DENIED` |
| `status` missing, `"pending"` on anything but a `crash`, anything but `"open"` or `"pending"`, or any `…At` lifecycle field (including `cancelledAt`) | `403 PERMISSION_DENIED` |
| `lat` without `lng`, or either as a string, or latitude out of range (swapped?) | `403 PERMISSION_DENIED` |
| `location` as a map `{latitude, longitude}` instead of a GeoPoint | `403 PERMISSION_DENIED` |
| `alcoholLevel` or `impactMagnitude` as a string (`"0.08"`) or null | `403 PERMISSION_DENIED` |
| `geoPointValue` with latitude outside −90…90 | `400 INVALID_ARGUMENT`, refused by the database before the rules see it |
| The same id twice | `409 ALREADY_EXISTS` (§3.3) |
| No `Authorization` header | `403 PERMISSION_DENIED` |
| An expired or garbled token | `401 UNAUTHENTICATED` on the live project (the emulator says `400 invalid jwt`). Refresh and resend. |

The live project's 403 says only `Missing or insufficient permissions.` It
never says which field was wrong, which is one more reason to develop on the
emulator (§1).

### 3.5 Critical alerts: set the rider's status

After a `crash` or `sos` alert returns `200` or `409`, set the rider's
status so their dot turns red on the map. The console clears it back to
`idle` when a dispatcher resolves the alert. Skip this for `alcoholWarning`
and `lowBattery`.

<!-- contract-example: rider-status expect=200 -->
```json
{
  "writes": [
    {
      "update": {
        "name": "projects/demo-novaride/databases/(default)/documents/riders/R-001",
        "fields": { "status": { "stringValue": "emergency" } }
      },
      "updateMask": { "fieldPaths": ["status"] },
      "currentDocument": { "exists": true }
    }
  ]
}
```

`updateMask` restricts the write to `status`, and the rules refuse anything
more. **Send it as a separate request after the alert, never in the same
commit.** A commit is all-or-nothing: if `riderId` were ever wrong, the rider
update would be refused (`403`, because the helmet may not create riders), and
it would take the alert down with it.

### 3.6 Where `riderId` comes from

The helmet can't read anything, so it can't look up which rider it is paired
with. For now, `riderId` is part of the helmet's configuration, set when it
is flashed, and it must match the pairing a Super Admin made in the console.
If a helmet is re-paired to another rider in the console, reflash it. See §8.

### 3.7 Alcohol: what the helmet measures, and what it claims

**A sensor inside a helmet measures the vapour in the helmet, not breath.**
The air is diluted by ventilation and by however the rider happens to be
breathing. Nothing the MQ-3 reports there is a breath alcohol concentration
(BrAC) or a blood alcohol figure, calibrated or not, and nothing in this
system may present it as one.

So the helmet makes **detection above a measured clean-air baseline**, not
a legal-limit comparison. Each helmet's MQ-3 is measured in clean air on
the bench, and that baseline is flashed with it. The helmet reports
`alcohol_detected: true` while the reading stays a margin above that
baseline. A legal limit would be the wrong comparison anyway. Under RA 10586
the limit for motorcycle and public-utility drivers is zero tolerance; the
0.05 % BAC figure the console once used is the private-vehicle limit.

| | |
|---|---|
| `devices/.alcohol_detected` | The current verdict. **Absent when there is none**: no baseline flashed, or the heater still warming. The console shows absent as "Not measured", never as sober. |
| `devices/.alcohol_raw`, `alerts/.alcoholRaw` | The raw ADC count, for the study's records. Not a concentration. |
| `alerts/` with `type: alcoholWarning` | Raised once when detection starts, `severity: moderate`, then not again for 10 minutes. |

The baseline procedure, and what converting to mg/L would take, are in
[firmware/README.md](../firmware/README.md).

---

### 3.8 The false-positive countdown

A crash arrives `pending`. For **15 seconds of server time** after its
`timestamp`, the rider's own app account, once a Super Admin has linked it
to the rider (`riders/{id}.authUid`), may cancel it. The rider sees a
countdown and an *I'm OK* button. Cancelling sets `status: cancelled` and a
server-clock `cancelledAt`, and stands the rider down from `emergency` to
`riding`.

**The countdown can only suppress an alert, never be needed to send one.**
Nothing has to happen for a crash to escalate: once the 15 s pass, the rules
refuse a cancel and the console treats the alert as open. A phone that is
broken, flat, offline or in a pocket changes nothing. A dispatcher may also
acknowledge a `pending` alert at any time, which ends the countdown.

What this asks of the helmet:

- Send a crash with `status: "pending"`. `sos`, `alcoholWarning` and
  `lowBattery` stay `open`: they are deliberate or informational.
- **If the alert is refused with 403**, resend the same id with
  `status: "open"`. That is the live project still running rules from
  before the countdown. A crash that can't be cancelled is a nuisance; one
  that is refused is lost. Firmware 0.5 does this, and keeps sending `open`
  until it reboots.
- Set `riders/{id}.status = "emergency"` as before (§3.5). If the rider
  cancels, the app clears it, even when the helmet's write lands after the
  cancel.

**Limitation, plainly:** the countdown is shown only while the rider app is
open, in the foreground. A backgrounded or killed app shows nothing, so the
alert escalates when the 15 s run out. That is the safe direction, but it
means a false positive goes to the dispatcher. Keeping the app listening in
the background needs an Android foreground service, which is future work.

---

## 4. `devices/{deviceId}`: the helmet's live readings

One document per helmet. The document id is the helmet serial,
`NR-H1-001`. The console shows these readings on the map and in the rider
table.

### 4.1 Fields

Field names are **snake_case** in this collection. That's the firmware's own
convention, kept on purpose.

| Field | Type (REST value) | Units / values | If missing, the console shows |
|---|---|---|---|
| `alcohol_detected` | boolean | The helmet's verdict: vapour above its own clean-air baseline (§3.7). **Leave it out when there is no verdict** | "Not measured". Never "not detected", and never 0 |
| `alcohol_level` | number | mg/L, if the study ever calibrates the sensor. Not sent by firmware 0.4 | stored, not displayed |
| `alcohol_raw` | number (`integerValue`) | ADC counts, 0–4095, uncalibrated; **not mg/L** | stored, not displayed |
| `imu_ok` | boolean | `false` while the MPU6050 is not answering at ±16 g. Crash detection needs both sensors, so it is **off** while this is false | stored, not displayed |
| `ax`, `ay`, `az` | number | **m/s²**, MPU6050 axes | stored, not displayed |
| `vector_magnitude` | number | **m/s²**, √(ax² + ay² + az²) | stored, not displayed |
| `latitude`, `longitude` | number, number | degrees, NEO-6M fix | 0, 0 |
| `speed_kmh` | number | km/h | 0 |
| `battery_pct` | number (`integerValue`) | 0–100 | 0 |
| `gps_fix` | boolean | `true` when the fix is current | `true` if lat/lng are non-zero |
| `last_update` | timestamp | server time, **by transform, like `timestamp` in §3** | the moment the console received the change, which overstates freshness |
| `severity` | string | the firmware's own running classification | stored, not displayed |
| `firmware_version` | string | free text, e.g. `0.3.1` | stored, not displayed |

**Don't write** `assigned_rider_id` or `paired_at`. They are the console's
record of which rider wears this helmet (§4.3).

Unlike alerts, **the rules don't check field types in `devices/`**: any
write from the helmet identity is accepted. A wrong type is stored, and the
console shows the default from the table above. Check your payload against
this table, because the database won't do it for you.

The console also accepts camelCase spellings of every field above
(`speedKmh`, `batteryPct` and so on). Pick snake_case and stay on it.

### 4.2 Worked example

<!-- contract-example: telemetry expect=200 -->
```json
{
  "writes": [
    {
      "update": {
        "name": "projects/demo-novaride/databases/(default)/documents/devices/NR-H1-001",
        "fields": {
          "alcohol_detected": { "booleanValue": false },
          "ax":               { "doubleValue": 0.12 },
          "ay":               { "doubleValue": -0.34 },
          "az":               { "doubleValue": 9.79 },
          "vector_magnitude": { "doubleValue": 9.80 },
          "latitude":         { "doubleValue": 14.5995 },
          "longitude":        { "doubleValue": 120.9842 },
          "speed_kmh":        { "doubleValue": 23.5 },
          "battery_pct":      { "integerValue": "87" },
          "gps_fix":          { "booleanValue": true },
          "firmware_version": { "stringValue": "0.3.1" }
        }
      },
      "updateMask": {
        "fieldPaths": [
          "alcohol_detected", "ax", "ay", "az", "vector_magnitude",
          "latitude", "longitude", "speed_kmh", "battery_pct", "gps_fix",
          "firmware_version"
        ]
      },
      "updateTransforms": [
        { "fieldPath": "last_update", "setToServerValue": "REQUEST_TIME" }
      ]
    }
  ]
}
```

There's no `currentDocument` precondition. The same body creates the
document the first time a helmet reports and updates it after that.
`last_update` is set by the transform, so it is **not** listed in
`updateMask`.

### 4.3 Always send `updateMask`

**Without `updateMask`, a write replaces the whole document.** Every field
you didn't send is deleted, including `assigned_rider_id` and `paired_at`,
the pairing a Super Admin set up in the console. The rules can't tell this
apart from a legitimate update, so it returns `200` and the pairing is gone
(checked against the emulator). List exactly the fields you are sending.
Fields in the mask but missing from `fields` are deleted too, so the mask
and the body must match.

### 4.4 How often

The project is on Firebase's free plan: **20,000 document writes per day**
across the whole project, with every console that has the map open reading
each change. One helmet writing every 5 seconds uses 17,280 writes a day on
its own. Something like every **15 seconds while riding** and every few
minutes while parked keeps a small fleet inside the quota. Alerts go out
immediately, whatever the telemetry interval.

---

## 5. Value encoding cheat sheet

The REST API wraps every value in a typed object:

| Firestore type | JSON |
|---|---|
| string | `{ "stringValue": "R-001" }` |
| number, fractional | `{ "doubleValue": 0.02 }` |
| number, whole | `{ "integerValue": "87" }`, **as a string**: 64-bit integers don't fit a JSON number |
| boolean | `{ "booleanValue": true }` |
| GeoPoint | `{ "geoPointValue": { "latitude": 14.5995, "longitude": 120.9842 } }` |
| server timestamp | not a value: an entry in `updateTransforms`, `{ "fieldPath": "…", "setToServerValue": "REQUEST_TIME" }` |

Anywhere this contract says "number", either `doubleValue` or
`integerValue` is accepted. A reading that happens to be whole
(`alcoholLevel` of `0`) may go as either.

---

## 6. Going from the emulator to the live project

Only configuration changes, not payloads:

| | Emulator | Live |
|---|---|---|
| Sign-in / refresh host | `http://<laptop-ip>:9099/identitytoolkit.googleapis.com/…`, `…:9099/securetoken.googleapis.com/…` | `https://identitytoolkit.googleapis.com/…`, `https://securetoken.googleapis.com/…` |
| Firestore host | `http://<laptop-ip>:8080` | `https://firestore.googleapis.com` |
| Project id (in the URL **and** in every `name`) | `demo-novaride` | `novaride-7a68c` |
| API key | anything | the project's Web API key |
| Account | `helmet-nr-h1-001@novaride.invalid` / `dev-only-helmet-pw` | the real account and password from the project owner |

Keep the live password out of the firmware repository, in a gitignored
secrets header or in NVS. If the live project refuses writes that the
emulator accepted, check two things first. Did the owner deploy the rules
(§7, step 4)? Did the helmet sign in again after the claim was set (§2)?

---

## 7. For the project owner: provisioning the helmet identity

Done once per physical helmet. One account per helmet costs nothing, and
it means a lost or dumped helmet can be revoked without touching the rest
of the fleet.

**1. Create the account.** Firebase console → project `novaride-7a68c` →
**Authentication → Users → Add user**:

- Email: `helmet-nr-h1-001@novaride.invalid`, named after the helmet
  serial. `.invalid` is a reserved domain that can never receive mail, so
  nobody can take the account over through a password-reset email. If the
  console refuses it, any address will do, because the mailbox is never
  used.
- Password: 24 or more random characters from your password manager, stored
  there.

**Do not** create an `admins/{uid}` document for it, and don't sign in with
it in the phone app. Either one makes the script in step 3 refuse the
account, and it would be right to refuse. An `admins/` document would give
the helmet's credentials an operator's read access to every rider.

**2. Have the service-account key ready**: the same one
`tool/set_admin_claims.mjs` uses, kept outside the repository at
`$HOME\novaride-admin-key.json`. If you don't have one: Project settings →
Service accounts → Generate new private key.

**3. Grant the role**, in PowerShell from the repository root:

```powershell
cd tool
npm install
$env:GOOGLE_APPLICATION_CREDENTIALS="$HOME\novaride-admin-key.json"
node provision_helmet_service.mjs helmet-nr-h1-001@novaride.invalid
node provision_helmet_service.mjs helmet-nr-h1-001@novaride.invalid --show
```

The first command prints `Set role=helmetService on …`. `--show` should
report the role claim `helmetService`, password login `yes`, and **no**
`admins/` or `users/` document.

**4. Deploy the rules.** The alert checks in §3.4 are in `firestore.rules`
in this repository, and the live project has them only after a deploy. Run
the rules tests first:

```powershell
cd rules_test; npm test; cd ..
firebase deploy --only firestore:rules
```

The deploy publishes the whole file, so anything else in it that is not live
yet goes live too.

**5. Hand over** to the firmware developer: the account email and password
(through the password manager's sharing or another private channel, never
chat or a commit), the project id `novaride-7a68c`, and the **Web API key**
(Project settings → General → Web API key). If sign-in from the helmet fails
with a referer or API-restriction error, the key has restrictions in Google
Cloud → APIs & Services → Credentials that block non-browser clients.

**If a helmet's credentials leak**, or a helmet is lost:

```powershell
node provision_helmet_service.mjs helmet-nr-h1-001@novaride.invalid --revoke
```

This removes the claim, revokes the refresh token and disables the account.
A token the helmet already holds keeps working against Firestore until it
expires, which is at most an hour. Change the password before re-enabling
the account, then run step 3 again.

**Why a separate script from `set_admin_claims.mjs`:** that one is for
operators and checks nothing about what else an account is. This one
refuses an account that has an `admins/` or `users/` document or a console
role, requires email/password sign-in, and can target the emulator
(`--emulator`) without a key.

---

## 8. Known gaps

What this contract does not settle yet:

1. **The console does not display `severity`, `alcoholRaw` or
   `impactMagnitude` yet.** The rules check them and the database stores
   them, so write them now. The console's alert reader, including the
   snake_case aliases, is a pending change on the app side. Until then the
   console reads `severity` only as a fallback when `type` is missing, which
   can't happen for a helmet alert because `type` is required.
2. **`riderId` is flashed, not looked up** (§3.6). Re-pairing a helmet in
   the console means reflashing it. The fix is for the console to resolve
   the rider from `deviceId` through `devices/{id}.assigned_rider_id`, which
   it already keeps. When that lands, `riderId` becomes optional for the
   helmet.
3. **`timestamp` is arrival time.** An alert queued while offline is stamped
   when it reaches the database, not when the crash happened. If the study
   needs detection time too, agree a separate field before the firmware
   writes one.
4. **Severity thresholds** (which `impactMagnitude` counts as `moderate`,
   and so on) are the firmware's decision. They are in
   `firmware/novaride_helmet/config.h`, with how each was chosen, and are
   placeholders until the bench tests in
   [firmware/README.md](../firmware/README.md) have been run.
5. **The helmet identity is not bound to its serial.** Any helmet account
   may write any `devices/` document or name any `deviceId`. Binding them
   (a `deviceId` claim per account, checked by the rules) is possible once
   there is one account per helmet, which §7 already recommends.
6. **`devices/` payloads are not validated** (§4.1), unlike alerts.

---

*The rules are `firestore.rules`. `rules_test/alerts.test.js` pins every row
of §3.4, and `rules_test/firmware_contract.test.js` replays the three JSON
bodies marked in this file against the emulator, so this document and the
rules cannot silently drift apart. The wider schema, including the
console-owned collections, is in [FIRESTORE_SCHEMA.md](FIRESTORE_SCHEMA.md).*
