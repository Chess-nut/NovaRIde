# NovaRide helmet firmware

ESP32 sketch for the helmet: dual-sensor crash detection (MPU6050 + two
YL-99 switches), NEO-6M position, MQ-3 alcohol reading, and the Firestore
writes described in [docs/FIRMWARE_CONTRACT.md](../docs/FIRMWARE_CONTRACT.md).
The contract says what goes over the wire. This file covers the hardware,
the bench work, and what the firmware deliberately does not do yet.

| File | What |
|---|---|
| `novaride_helmet/novaride_helmet.ino` | The sketch |
| `novaride_helmet/config.h` | Pins, thresholds, timings, each with why it is set where it is |
| `novaride_helmet/types.h` | Structs shared between tasks |
| `novaride_helmet/secrets.example.h` | Copy to `secrets.h` (gitignored), one per helmet |

## Build

- Board package **esp32 by Espressif, 3.3.x** (built against 3.3.12),
  board **ESP32 Dev Module**.
- Libraries, from the Library Manager: **MPU6050** by Electronic Cats (1.4.x),
  **TinyGPSPlus** by Mikal Hart (1.0.x), **ArduinoJson** by Benoit Blanchon (7.x).
- Copy `secrets.example.h` to `secrets.h` and fill it in. `RIDER_ID` is the
  console's `riders/` document id (`R-001`), not a Firebase Auth uid.

To try it against the emulator first (contract §1), uncomment
`NR_EMULATOR_HOST` in `secrets.h` and set it to the laptop's LAN address.

## Wiring

| Part | Pin | ESP32 | Notes |
|---|---|---|---|
| YL-99 #1 | OUT | GPIO 13 | Active LOW, on an interrupt. **Power from 3.3 V**: the output is the supply rail. |
| YL-99 #2 | OUT | GPIO 27 | As above. |
| MPU6050 | SDA / SCL | GPIO 21 / 22 | AD0 to GND (address 0x68). 400 kHz. |
| NEO-6M | TX / RX | GPIO 16 / 17 | UART2, 9600 baud. GPS TX goes to ESP32 GPIO 16. |
| MQ-3 | AO | GPIO 34 | **Through a divider**, e.g. 10 kΩ over 15 kΩ: the heater runs at 5 V and AO can reach 5 V, and the ESP32 ADC tops out near 3.1 V. Must be an ADC1 pin; ADC2 is unusable with Wi-Fi on. |

GPIO 16/17 are taken by PSRAM on WROVER modules. On one of those, move
the GPS to another pair in `config.h`.

## How detection works

The detector runs on its own FreeRTOS task at 1 kHz, above `loop()`'s
priority, and never touches the network. Each sample computes
A = √(X² + Y² + Z²) in g, at ±16 g (2048 LSB/g), into a 256 ms ring.

Each switch closure is caught by an interrupt and timestamped. Once
`COINCIDENCE_WINDOW_MS` has passed, the detector looks at the ring from
that long before the closure to that long after it:

- **Peak ≥ `IMPACT_THRESHOLD_G`**: a crash. One alert is queued, with
  the peak, GPS and alcohol snapshot taken then, and further candidates are
  ignored for `CRASH_REFRACTORY_MS`.
- **Peak below threshold**: logged as `rejected: switch without impact`.
- **The IMU crosses the threshold with no switch**: logged as
  `rejected: impact without switch`.

The two `rejected` lines are the dual-sensor rule doing its job. Count them
during testing: they are the evidence for the false-positive claim. One
caveat when counting: a lever held down longer than the window can bounce
on release and log a second `switch without impact`. Count presses, not
lines.

## Tuning

`IMPACT_THRESHOLD_G` (4 g), `COINCIDENCE_WINDOW_MS` (50 ms) and
`SEVERITY_HIGH_G` (10 g) are reasoned starting values, not measurements
(the comments in `config.h` give the reasoning). Replace them with numbers
from this helmet before the defence. Open the serial monitor at 115200:

```
[tune] peak=1.03g imu=ok gps=fix sats=7 mq3=1210 wifi=up auth=ok queue=0
[detect] rejected: switch 1 without impact (peak 1.21 g < 4.00 g)
[detect] CRASH peak=14.80 g switches=3 lag=-6 ms
```

`[tune]` prints once a second with the highest A in that second. Then:

1. **At rest.** The peak should read about 1.0 g. If it reads 8 g, the
   range did not take. The boot line must say `ready at +/-16 g`.
2. **Normal use.** Wear it and ride, or at least walk, nod, turn, set the
   helmet down and hang it up. Keep the `[tune]` log. Its highest peak is
   your noise ceiling.
3. **Switch only.** Press each lever by hand. Every press should log
   `rejected: switch without impact`.
4. **Drops.** Drop the helmet, with a mass inside, from fixed heights onto
   the switch side. Each one should log `CRASH`. Record `peak` and `lag`.
5. **Choose.**
   - The threshold goes between the noise ceiling (step 2) and the
     smallest drop peak (step 4), with margin on both sides.
   - The window should be comfortably above the largest |lag| from step 4.
   - Write the data and the date into the comments in `config.h`.

At ±16 g an axis clips, and a hard impact can exceed that. A clipped
crash logs `(clipped)`, `impactMagnitude` is then a lower bound, and the
alert is sent as `high`. Measuring the true peak needs a high-g part such
as the ADXL375 (±200 g).

## MQ-3: what calibration it needs

The firmware reports the MQ-3 as **raw ADC counts** (`alcoholRaw` on alerts,
`alcohol_raw` on `devices/`) and writes nothing to `alcoholLevel` /
`alcohol_level`. Readings are withheld for the first 3 minutes while the
heater settles. Turning counts into mg/L takes:

1. **Burn-in.** A new sensor needs 24–48 h powered before its readings
   settle.
2. **Circuit constants.**
   - The module's load resistor RL: read it off the board, or measure it
     unpowered.
   - Your divider ratio.
   - The ADC's own non-linearity: use `analogReadMilliVolts()` rather than
     counts.
3. **R0.** Rs = RL × (5 V − Vout) / Vout. Measure Rs in clean air, then
   take R0 from the clean-air ratio on the datasheet curve.
4. **A curve, checked against a reference.** The datasheet's Rs/R0
   against mg/L curve is a starting point only. It has to be checked at
   known concentrations: a calibrated breathalyser alongside, or a
   wet-bath simulator. It also has to be checked across temperature and
   humidity, which both move the reading.

Even calibrated, a sensor inside a helmet measures ethanol vapour in the
helmet air, diluted by ventilation and breathing. That is **not** breath
alcohol (BrAC) and not BAC. Without a fixed sampling procedure (the rider
breathes toward the sensor for a set time), describe it in the paper as an
alcohol-vapour indicator.

Check the console's limit too. It flags **0.05 mg/L**, which looks like the
**0.05 % BAC** figure. 0.05 % BAC is about **0.24 mg/L** BrAC at the
standard 2100:1 ratio, nearly five times higher. Confirm which number the
paper means, and which legal limit applies to motorcycle riders, before
this goes live.

Until the MQ-3 is calibrated the firmware sends no `alcoholWarning`
alerts: their threshold is in mg/L.

## Not done yet

- **No SOS button and no battery measurement** in this hardware, so no
  `sos` or `lowBattery` alerts.
- **No false-positive countdown.** Crash alerts go out at once as `open`.
  The 15 s countdown changes the alert flow across firmware, rules,
  console and rider app, and waits on the app-architecture decision.
- **The alert queue is in RAM.** An alert raised offline survives a lost
  connection, but not a reboot or power loss before it is sent.
- **The IMU is required.** With the MPU6050 down there is no crash
  detection at all, by the dual-sensor rule. The firmware says so in
  `[detect]` lines and reports `imu_ok: false` to `devices/`, but the
  console does not show it yet.
