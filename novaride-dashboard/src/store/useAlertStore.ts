import { create } from 'zustand';
import { dataProvider } from '../data';
import type {
  Alert,
  AlertSeverity,
  AlertStatus,
  AlertType,
  SimulateAction,
  Unsubscribe,
} from '../data/types';

const OPEN_STATUSES: readonly AlertStatus[] = ['active', 'countdown', 'acknowledged', 'dispatched'];

interface AlertState {
  alerts: Alert[];
  ready: boolean;
  subscribers: number;
  unsubscribe: Unsubscribe | null;
  connect: () => void;
  disconnect: () => void;
  updateStatus: (id: string, status: AlertStatus) => void;
  /** Demo tooling — the only write path the Demo Controls popover uses. */
  simulate: (action: SimulateAction) => void;
}

export const useAlertStore = create<AlertState>((set, get) => ({
  alerts: [],
  ready: false,
  subscribers: 0,
  unsubscribe: null,

  connect: () => {
    const { subscribers, unsubscribe } = get();
    set({ subscribers: subscribers + 1 });
    if (unsubscribe) return;
    const stop = dataProvider.subscribeAlerts((alerts) => {
      /* Provider already sorts newest-first; keep the guarantee local too. */
      set({ alerts: [...alerts].sort((a, b) => b.createdAt - a.createdAt), ready: true });
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

  updateStatus: (id, status) => dataProvider.updateAlertStatus(id, status),

  simulate: (action) => dataProvider.simulate(action),
}));

// ------------------------------------------------------------- selectors

export const isOpen = (alert: Alert): boolean => OPEN_STATUSES.includes(alert.status);

export const selectActiveCritical = (alerts: Alert[]): Alert[] =>
  alerts.filter((a) => isOpen(a) && (a.severity === 'critical' || a.severity === 'high'));

export const selectCountdowns = (alerts: Alert[]): Alert[] =>
  alerts.filter((a) => a.status === 'countdown');

export const selectEmergencies = (alerts: Alert[]): Alert[] =>
  alerts.filter((a) => a.type === 'crash_sos' && isOpen(a));

export const selectToday = (alerts: Alert[]): Alert[] => {
  const since = Date.now() - 24 * 3600_000;
  return alerts.filter((a) => a.createdAt >= since);
};

export const countBySeverity = (alerts: Alert[]): Record<AlertSeverity, number> => {
  const counts: Record<AlertSeverity, number> = {
    critical: 0,
    high: 0,
    medium: 0,
    low: 0,
    info: 0,
  };
  for (const alert of alerts) counts[alert.severity] += 1;
  return counts;
};

export const countByType = (alerts: Alert[]): Record<AlertType, number> => {
  const counts: Record<AlertType, number> = {
    crash_sos: 0,
    crash_countdown: 0,
    alcohol_warning: 0,
    low_battery: 0,
    device_offline: 0,
  };
  for (const alert of alerts) counts[alert.type] += 1;
  return counts;
};
