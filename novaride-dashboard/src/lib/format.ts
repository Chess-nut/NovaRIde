import { format } from 'date-fns';
import type { AlertSeverity, AlertStatus, AlertType, RiderStatus } from '../data/types';

/** Status → hex. Mirrors the Tailwind tokens; charts and Leaflet need raw values. */
export const STATUS_COLOR: Record<RiderStatus, string> = {
  riding: '#34D399',
  idle: '#9CA3AF',
  emergency: '#F43F5E',
  offline: '#475569',
};

export const STATUS_LABEL: Record<RiderStatus, string> = {
  riding: 'Riding',
  idle: 'Idle',
  emergency: 'Emergency',
  offline: 'Offline',
};

/**
 * Severity → hex. Validated for CVD separation and 3:1 contrast against the
 * panel surface; every bar is also labelled on the category axis, so colour is
 * a redundant channel rather than the only one.
 */
export const SEVERITY_COLOR: Record<AlertSeverity, string> = {
  critical: '#F43F5E',
  high: '#F59E0B',
  medium: '#4C8DFF',
  low: '#34D399',
  info: '#9CA3AF',
};

export const SEVERITY_LABEL: Record<AlertSeverity, string> = {
  critical: 'Critical',
  high: 'High',
  medium: 'Medium',
  low: 'Low',
  info: 'Info',
};

export const ALERT_TYPE_LABEL: Record<AlertType, string> = {
  crash_sos: 'Crash — SOS',
  crash_countdown: 'Crash — Countdown',
  alcohol_warning: 'Alcohol Warning',
  low_battery: 'Low Battery',
  device_offline: 'Device Offline',
};

export const ALERT_TYPE_SHORT: Record<AlertType, string> = {
  crash_sos: 'SOS',
  crash_countdown: 'Countdown',
  alcohol_warning: 'Alcohol',
  low_battery: 'Battery',
  device_offline: 'Offline',
};

export const ALERT_STATUS_LABEL: Record<AlertStatus, string> = {
  active: 'Active',
  countdown: 'Countdown',
  canceled_by_rider: 'Canceled by rider',
  acknowledged: 'Acknowledged',
  dispatched: 'Dispatched',
  resolved: 'Resolved',
};

export const clockTime = (ms: number): string => format(ms, 'h:mm:ss a');

export const secondsSince = (ms: number, now: number): number =>
  Math.max(0, Math.round((now - ms) / 1000));

/** Compact "12s" / "4m" / "2h" relative label for table + map meta. */
export function relativeAge(ms: number, now: number): string {
  const seconds = secondsSince(ms, now);
  if (seconds < 60) return `${seconds}s`;
  if (seconds < 3600) return `${Math.floor(seconds / 60)}m`;
  return `${Math.floor(seconds / 3600)}h`;
}

export const oneDecimal = (value: number): string => value.toFixed(1);
export const twoDecimals = (value: number): string => value.toFixed(2);
