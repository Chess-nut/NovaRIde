import type { Rng } from './rng';

export interface Bounds {
  minLat: number;
  maxLat: number;
  minLng: number;
  maxLng: number;
}

/** Rough operating bounds per city/district, centred on Metro Manila. */
export const CITY_BOUNDS: Record<string, Bounds> = {
  'Quezon City': { minLat: 14.62, maxLat: 14.72, minLng: 121.02, maxLng: 121.09 },
  Manila: { minLat: 14.565, maxLat: 14.62, minLng: 120.97, maxLng: 121.01 },
  Makati: { minLat: 14.545, maxLat: 14.575, minLng: 121.0, maxLng: 121.04 },
  Pasig: { minLat: 14.555, maxLat: 14.6, minLng: 121.06, maxLng: 121.1 },
  Caloocan: { minLat: 14.645, maxLat: 14.72, minLng: 120.97, maxLng: 121.02 },
  Marikina: { minLat: 14.62, maxLat: 14.675, minLng: 121.09, maxLng: 121.13 },
  Mandaluyong: { minLat: 14.572, maxLat: 14.6, minLng: 121.02, maxLng: 121.05 },
};

/** Riders never wander outside this box. */
export const METRO_BOUNDS: Bounds = {
  minLat: 14.48,
  maxLat: 14.78,
  minLng: 120.93,
  maxLng: 121.16,
};

export const METRO_CENTER = { lat: 14.6, lng: 121.02 };

const M_PER_DEG_LAT = 110_574;
const M_PER_DEG_LNG = 111_320 * Math.cos((14.6 * Math.PI) / 180);

export interface LatLng {
  lat: number;
  lng: number;
}

export function spawnInCity(city: string, rng: Rng): LatLng {
  const b = CITY_BOUNDS[city];
  if (!b) return { ...METRO_CENTER };
  return { lat: rng.range(b.minLat, b.maxLat), lng: rng.range(b.minLng, b.maxLng) };
}

/** Advance a point `meters` along `headingDeg` (0 = north, clockwise). */
export function advance(point: LatLng, headingDeg: number, meters: number): LatLng {
  const rad = (headingDeg * Math.PI) / 180;
  return {
    lat: point.lat + (Math.cos(rad) * meters) / M_PER_DEG_LAT,
    lng: point.lng + (Math.sin(rad) * meters) / M_PER_DEG_LNG,
  };
}

/**
 * Keep a rider inside Metro Manila by reflecting the heading at the edges
 * rather than teleporting them.
 */
export function bounce(point: LatLng, headingDeg: number): { point: LatLng; headingDeg: number } {
  let { lat, lng } = point;
  let heading = headingDeg;

  if (lat > METRO_BOUNDS.maxLat || lat < METRO_BOUNDS.minLat) {
    heading = 180 - heading;
    lat = Math.min(Math.max(lat, METRO_BOUNDS.minLat), METRO_BOUNDS.maxLat);
  }
  if (lng > METRO_BOUNDS.maxLng || lng < METRO_BOUNDS.minLng) {
    heading = 360 - heading;
    lng = Math.min(Math.max(lng, METRO_BOUNDS.minLng), METRO_BOUNDS.maxLng);
  }

  return { point: { lat, lng }, headingDeg: ((heading % 360) + 360) % 360 };
}

const LANDMARKS: Record<string, string[]> = {
  'Quezon City': ['Commonwealth Ave', 'Katipunan Ave', 'EDSA–Quezon Ave', 'Timog Ave'],
  Manila: ['Taft Ave', 'España Blvd', 'Roxas Blvd', 'Recto Ave'],
  Makati: ['Ayala Ave', 'Chino Roces Ave', 'Gil Puyat Ave', 'EDSA–Magallanes'],
  Pasig: ['Ortigas Ave', 'C-5 Road', 'Shaw Blvd', 'Julia Vargas Ave'],
  Caloocan: ['A. Mabini St', 'MacArthur Highway', 'Samson Road', 'EDSA–Monumento'],
  Marikina: ['Marcos Highway', 'Sumulong Highway', 'Gil Fernando Ave', 'A. Bonifacio Ave'],
  Mandaluyong: ['Boni Ave', 'EDSA–Guadalupe', 'Pioneer St', 'Shaw Blvd'],
};

/** Human-readable location label for an alert. */
export function labelFor(city: string, rng: Rng): string {
  const streets = LANDMARKS[city] ?? ['EDSA'];
  return `${rng.pick(streets)}, ${city}`;
}
