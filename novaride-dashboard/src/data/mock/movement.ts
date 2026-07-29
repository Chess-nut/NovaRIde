import type { RiderStatus, TelemetrySnapshot } from '../types';
import { advance, bounce } from './geo';
import { liveRng } from './rng';

/**
 * One 2s step of simulated helmet telemetry. Pure with respect to engine
 * state — it only reads the previous snapshot.
 */
export function stepTelemetry(
  status: RiderStatus,
  prev: TelemetrySnapshot,
  now: number,
): TelemetrySnapshot {
  /* Alcohol always decays back toward the baseline. */
  const alcoholLevel = Math.max(0, prev.alcoholLevel - liveRng.range(0, 0.02));

  if (status !== 'riding') {
    /* Idle and post-crash riders jitter in place. */
    return {
      ...prev,
      lat: prev.lat + liveRng.range(-0.00004, 0.00004),
      lng: prev.lng + liveRng.range(-0.00004, 0.00004),
      speedKph: 0,
      alcoholLevel: Number(alcoholLevel.toFixed(3)),
      accelMagG: Number(liveRng.range(0.96, 1.04).toFixed(2)),
      updatedAt: now,
    };
  }

  const speedKph = Math.min(75, Math.max(0, prev.speedKph + liveRng.range(-9, 9)));
  const heading = prev.headingDeg + liveRng.range(-14, 14);
  const meters = liveRng.range(80, 250);
  const moved = bounce(advance({ lat: prev.lat, lng: prev.lng }, heading, meters), heading);

  return {
    ...prev,
    lat: moved.point.lat,
    lng: moved.point.lng,
    headingDeg: moved.headingDeg,
    speedKph: Number(speedKph.toFixed(1)),
    alcoholLevel: Number(alcoholLevel.toFixed(3)),
    batteryPct: Math.max(3, prev.batteryPct - (liveRng.next() < 0.12 ? 1 : 0)),
    accelMagG: Number(liveRng.range(0.9, 1.35).toFixed(2)),
    gpsFix: true,
    updatedAt: now,
  };
}
