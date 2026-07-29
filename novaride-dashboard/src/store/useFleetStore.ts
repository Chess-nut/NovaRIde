import { create } from 'zustand';
import { dataProvider } from '../data';
import type { HelmetDevice, Rider, RiderStatus, TelemetrySnapshot, Unsubscribe } from '../data/types';

interface FleetState {
  riders: Rider[];
  devices: HelmetDevice[];
  telemetry: Record<string, TelemetrySnapshot>;
  lastUpdateAt: number;
  ready: boolean;
  subscribers: number;
  unsubscribe: Unsubscribe | null;
  connect: () => void;
  disconnect: () => void;
}

export const useFleetStore = create<FleetState>((set, get) => ({
  riders: [],
  devices: [],
  telemetry: {},
  lastUpdateAt: 0,
  ready: false,
  subscribers: 0,
  unsubscribe: null,

  /** Ref-counted so React StrictMode's double-mount can't drop the feed. */
  connect: () => {
    const { subscribers, unsubscribe } = get();
    set({ subscribers: subscribers + 1 });
    if (unsubscribe) return;
    const stop = dataProvider.subscribeFleet((snapshot) => {
      set({
        riders: snapshot.riders,
        devices: snapshot.devices,
        telemetry: snapshot.telemetry,
        lastUpdateAt: Date.now(),
        ready: true,
      });
    });
    set({ unsubscribe: stop });
  },

  disconnect: () => {
    const { subscribers, unsubscribe } = get();
    const next = Math.max(0, subscribers - 1);
    set({ subscribers: next });
    if (next === 0 && unsubscribe) {
      unsubscribe();
      set({ unsubscribe: null });
    }
  },
}));

export const countByStatus = (riders: Rider[]): Record<RiderStatus, number> => {
  const counts: Record<RiderStatus, number> = { riding: 0, idle: 0, emergency: 0, offline: 0 };
  for (const rider of riders) counts[rider.status] += 1;
  return counts;
};

export const selectRidersOnline = (riders: Rider[]): number =>
  riders.filter((r) => r.status === 'riding' || r.status === 'idle').length;
