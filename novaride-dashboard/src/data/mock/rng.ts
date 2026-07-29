/** Deterministic PRNG so every boot of the demo looks the same. */
export function mulberry32(seed: number): () => number {
  let a = seed >>> 0;
  return () => {
    a = (a + 0x6d2b79f5) >>> 0;
    let t = a;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

export interface Rng {
  next: () => number;
  range: (min: number, max: number) => number;
  int: (min: number, max: number) => number;
  pick: <T>(items: readonly T[]) => T;
}

export function createRng(seed: number): Rng {
  const next = mulberry32(seed);
  const range = (min: number, max: number) => min + next() * (max - min);
  const int = (min: number, max: number) => Math.floor(range(min, max + 1));
  const pick = <T,>(items: readonly T[]): T => {
    const item = items[int(0, items.length - 1)];
    if (item === undefined) throw new Error('pick() called on an empty list');
    return item;
  };
  return { next, range, int, pick };
}

/** Boot state uses a fixed seed; the live ticker uses an unseeded stream. */
export const seedRng = createRng(20260729);
export const liveRng = createRng(Math.floor(Math.random() * 1e9));
