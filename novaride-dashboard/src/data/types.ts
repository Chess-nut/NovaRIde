/** Domain model. Module names mirror the capstone manuscript. */

export type RiderStatus = 'riding' | 'idle' | 'emergency' | 'offline';

export type AlertType =
  | 'crash_countdown'
  | 'crash_sos'
  | 'alcohol_warning'
  | 'low_battery'
  | 'device_offline';

export type AlertSeverity = 'critical' | 'high' | 'medium' | 'low' | 'info';

export type AlertStatus =
  | 'active'
  | 'countdown'
  | 'canceled_by_rider'
  | 'acknowledged'
  | 'dispatched'
  | 'resolved';

export type Platform = 'Angkas' | 'JoyRide' | 'Move It';

export interface EmergencyContact {
  name: string;
  phone: string;
  relation: string;
}

export interface Rider {
  id: string;
  name: string;
  phone: string;
  platform: Platform;
  plateNo: string;
  helmetId: string;
  city: string;
  status: RiderStatus;
  emergencyContacts: EmergencyContact[];
  avatarColor: string;
}

export interface HelmetDevice {
  id: string;
  model: 'NovaRide H1';
  assignedRiderId: string | null;
  firmware: string;
}

export interface TelemetrySnapshot {
  riderId: string;
  lat: number;
  lng: number;
  headingDeg: number;
  speedKph: number;
  /** MQ-3 reading in mg/L. */
  alcoholLevel: number;
  batteryPct: number;
  accelMagG: number;
  gpsFix: boolean;
  updatedAt: number;
}

export interface AlertLocation {
  lat: number;
  lng: number;
  label: string;
}

export interface AlertTimelineEntry {
  status: AlertStatus;
  at: number;
}

export interface Alert {
  id: string;
  riderId: string;
  type: AlertType;
  severity: AlertSeverity;
  status: AlertStatus;
  createdAt: number;
  countdownEndsAt?: number;
  location: AlertLocation;
  timeline: AlertTimelineEntry[];
}

/** Fixed severity mapping — never derive severity anywhere else. */
export const SEVERITY_BY_TYPE: Record<AlertType, AlertSeverity> = {
  crash_sos: 'critical',
  crash_countdown: 'high',
  alcohol_warning: 'medium',
  low_battery: 'low',
  device_offline: 'info',
};

/** MQ-3 breach threshold in mg/L. */
export const ALCOHOL_THRESHOLD = 0.25;

/** Rider-cancelable window before an SOS fires, in milliseconds. */
export const COUNTDOWN_MS = 15_000;

export type SimulateAction =
  | 'crash_countdown'
  | 'high_speed_crash'
  | 'rider_cancel'
  | 'alcohol_warning'
  | 'reset';

export interface FleetSnapshot {
  riders: Rider[];
  devices: HelmetDevice[];
  telemetry: Record<string, TelemetrySnapshot>;
}

export type Unsubscribe = () => void;
