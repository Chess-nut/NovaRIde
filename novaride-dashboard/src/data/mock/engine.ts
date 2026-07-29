import type {
  Alert,
  AlertStatus,
  AlertType,
  FleetSnapshot,
  Rider,
  SimulateAction,
  TelemetrySnapshot,
  Unsubscribe,
} from '../types';
import { ALCOHOL_THRESHOLD, COUNTDOWN_MS, SEVERITY_BY_TYPE } from '../types';
import { labelFor } from './geo';
import { stepTelemetry } from './movement';
import { liveRng } from './rng';
import { buildAlertHistory, buildFleet } from './seed';

const TICK_MS = 2000;
/** A minor event roughly every 45s of wall clock. */
const MINOR_EVENT_CHANCE = TICK_MS / 45_000;
const CLOSED_STATUSES: readonly AlertStatus[] = ['canceled_by_rider', 'resolved'];

/**
 * The simulated helmet fleet. Owns all mutable demo state and the ticker;
 * nothing outside `src/data/mock` may import it.
 */
export class MockEngine {
  private fleet: FleetSnapshot = buildFleet();
  private alerts: Alert[] = buildAlertHistory(this.fleet);
  private readonly fleetListeners = new Set<(snapshot: FleetSnapshot) => void>();
  private readonly alertListeners = new Set<(alerts: Alert[]) => void>();
  private ticker: ReturnType<typeof setInterval> | null = null;
  private readonly countdownTimers = new Map<string, ReturnType<typeof setTimeout>>();
  private sequence = 0;

  subscribeFleet(cb: (snapshot: FleetSnapshot) => void): Unsubscribe {
    this.fleetListeners.add(cb);
    cb(this.fleet);
    this.ensureTicker();
    return () => {
      this.fleetListeners.delete(cb);
      this.stopIfIdle();
    };
  }

  subscribeAlerts(cb: (alerts: Alert[]) => void): Unsubscribe {
    this.alertListeners.add(cb);
    cb(this.alerts);
    this.ensureTicker();
    return () => {
      this.alertListeners.delete(cb);
      this.stopIfIdle();
    };
  }

  updateAlertStatus(id: string, status: AlertStatus): void {
    const alert = this.alerts.find((a) => a.id === id);
    if (!alert) return;
    if (status === 'canceled_by_rider' || CLOSED_STATUSES.includes(status)) {
      this.clearCountdown(id);
    }
    this.replaceAlert({
      ...alert,
      status,
      timeline: [...alert.timeline, { status, at: Date.now() }],
    });
    if (CLOSED_STATUSES.includes(status)) this.clearEmergency(alert.riderId);
    this.emitAlerts();
    this.emitFleet();
  }

  simulate(action: SimulateAction): void {
    switch (action) {
      case 'crash_countdown':
        this.startCountdown();
        break;
      case 'high_speed_crash':
        this.highSpeedCrash();
        break;
      case 'rider_cancel':
        this.riderCancel();
        break;
      case 'alcohol_warning':
        this.alcoholWarning();
        break;
      case 'reset':
        this.reset();
        break;
    }
  }

  /** Stop everything — used by the HMR dispose hook so tickers never stack. */
  dispose(): void {
    this.stopTicker();
    this.countdownTimers.forEach((timer) => clearTimeout(timer));
    this.countdownTimers.clear();
  }

  // ---------------------------------------------------------------- ticker

  private ensureTicker(): void {
    if (this.ticker !== null) return;
    this.ticker = setInterval(() => this.tick(), TICK_MS);
  }

  private stopIfIdle(): void {
    if (this.fleetListeners.size === 0 && this.alertListeners.size === 0) this.stopTicker();
  }

  private stopTicker(): void {
    if (this.ticker === null) return;
    clearInterval(this.ticker);
    this.ticker = null;
  }

  private tick(): void {
    const now = Date.now();
    const telemetry: Record<string, TelemetrySnapshot> = {};

    for (const rider of this.fleet.riders) {
      const prev = this.fleet.telemetry[rider.id];
      if (!prev) continue;
      /* Offline helmets report nothing — their last snapshot freezes. */
      telemetry[rider.id] =
        rider.status === 'offline' ? prev : stepTelemetry(rider.status, prev, now);
    }

    this.fleet = { ...this.fleet, telemetry };
    this.emitFleet();

    if (liveRng.next() < MINOR_EVENT_CHANCE) this.minorEvent();
  }

  /** Low battery below 20%, or a brief sub-threshold alcohol blip. */
  private minorEvent(): void {
    const drained = this.fleet.riders.find(
      (rider) =>
        rider.status !== 'offline' &&
        (this.fleet.telemetry[rider.id]?.batteryPct ?? 100) < 20 &&
        !this.hasOpenAlert(rider.id, 'low_battery'),
    );
    if (drained) {
      this.raise(drained, 'low_battery', 'active');
      return;
    }

    const riding = this.fleet.riders.filter((rider) => rider.status === 'riding');
    if (riding.length === 0) return;
    const rider = liveRng.pick(riding);
    this.patchTelemetry(rider.id, { alcoholLevel: Number(liveRng.range(0.08, 0.2).toFixed(3)) });
    this.emitFleet();
  }

  // ------------------------------------------------------------ crash flow

  private startCountdown(): void {
    const rider = this.pickAvailable('riding');
    if (!rider) return;

    const alert = this.raise(rider, 'crash_countdown', 'countdown', {
      countdownEndsAt: Date.now() + COUNTDOWN_MS,
    });
    this.patchTelemetry(rider.id, { accelMagG: Number(liveRng.range(4.2, 7.5).toFixed(2)) });
    this.emitFleet();

    /* Escalates to SOS unless the rider cancels inside the window. */
    this.countdownTimers.set(
      alert.id,
      setTimeout(() => this.escalate(alert.id), COUNTDOWN_MS),
    );
  }

  private escalate(alertId: string): void {
    this.countdownTimers.delete(alertId);
    const alert = this.alerts.find((a) => a.id === alertId);
    if (!alert || alert.status !== 'countdown') return;

    this.replaceAlert({
      ...alert,
      type: 'crash_sos',
      severity: SEVERITY_BY_TYPE.crash_sos,
      status: 'active',
      countdownEndsAt: undefined,
      timeline: [...alert.timeline, { status: 'active', at: Date.now() }],
    });
    this.setEmergency(alert.riderId);
    this.emitAlerts();
    this.emitFleet();
  }

  private highSpeedCrash(): void {
    const rider =
      this.fleet.riders.find(
        (r) =>
          r.status === 'riding' &&
          (this.fleet.telemetry[r.id]?.speedKph ?? 0) > 60 &&
          !this.hasOpenCrash(r.id),
      ) ?? this.pickAvailable('riding');
    if (!rider) return;

    /* Impact above 60 kph skips the cancelable window entirely. */
    this.patchTelemetry(rider.id, { accelMagG: Number(liveRng.range(9.5, 14).toFixed(2)) });
    this.raise(rider, 'crash_sos', 'active');
    this.setEmergency(rider.id);
    this.emitFleet();
  }

  private riderCancel(): void {
    const pending = this.alerts.find((a) => a.status === 'countdown');
    if (!pending) return;
    this.clearCountdown(pending.id);
    this.replaceAlert({
      ...pending,
      status: 'canceled_by_rider',
      countdownEndsAt: undefined,
      timeline: [...pending.timeline, { status: 'canceled_by_rider', at: Date.now() }],
    });
    this.clearEmergency(pending.riderId);
    this.emitAlerts();
    this.emitFleet();
  }

  private alcoholWarning(): void {
    const rider = this.pickAvailable('riding') ?? this.pickAvailable('idle');
    if (!rider) return;
    this.patchTelemetry(rider.id, {
      alcoholLevel: Number(liveRng.range(ALCOHOL_THRESHOLD + 0.04, 0.62).toFixed(3)),
    });
    this.raise(rider, 'alcohol_warning', 'active');
    this.emitFleet();
  }

  private reset(): void {
    this.dispose();
    this.sequence = 0;
    this.fleet = buildFleet();
    this.alerts = buildAlertHistory(this.fleet);
    this.emitFleet();
    this.emitAlerts();
    if (this.fleetListeners.size > 0 || this.alertListeners.size > 0) this.ensureTicker();
  }

  // ---------------------------------------------------------------- helpers

  private raise(
    rider: Rider,
    type: AlertType,
    status: AlertStatus,
    extra: Partial<Alert> = {},
  ): Alert {
    const now = Date.now();
    const snapshot = this.fleet.telemetry[rider.id];
    this.sequence += 1;
    const alert: Alert = {
      id: `alert-${now}-${this.sequence}`,
      riderId: rider.id,
      type,
      severity: SEVERITY_BY_TYPE[type],
      status,
      createdAt: now,
      location: {
        lat: snapshot?.lat ?? 14.6,
        lng: snapshot?.lng ?? 121.02,
        label: labelFor(rider.city, liveRng),
      },
      timeline: [{ status, at: now }],
      ...extra,
    };
    this.alerts = [alert, ...this.alerts];
    this.emitAlerts();
    return alert;
  }

  private pickAvailable(status: Rider['status']): Rider | null {
    const pool = this.fleet.riders.filter((r) => r.status === status && !this.hasOpenCrash(r.id));
    return pool.length > 0 ? liveRng.pick(pool) : null;
  }

  private hasOpenCrash(riderId: string): boolean {
    return this.alerts.some(
      (a) =>
        a.riderId === riderId &&
        (a.type === 'crash_sos' || a.type === 'crash_countdown') &&
        !CLOSED_STATUSES.includes(a.status),
    );
  }

  private hasOpenAlert(riderId: string, type: AlertType): boolean {
    return this.alerts.some(
      (a) => a.riderId === riderId && a.type === type && !CLOSED_STATUSES.includes(a.status),
    );
  }

  private replaceAlert(next: Alert): void {
    this.alerts = this.alerts.map((a) => (a.id === next.id ? next : a));
  }

  private clearCountdown(alertId: string): void {
    const timer = this.countdownTimers.get(alertId);
    if (timer === undefined) return;
    clearTimeout(timer);
    this.countdownTimers.delete(alertId);
  }

  private setEmergency(riderId: string): void {
    this.setRiderStatus(riderId, 'emergency');
    this.patchTelemetry(riderId, { speedKph: 0 });
  }

  private clearEmergency(riderId: string): void {
    if (this.hasOpenCrash(riderId)) return;
    const rider = this.fleet.riders.find((r) => r.id === riderId);
    if (rider && rider.status === 'emergency') this.setRiderStatus(riderId, 'riding');
  }

  private setRiderStatus(riderId: string, status: Rider['status']): void {
    this.fleet = {
      ...this.fleet,
      riders: this.fleet.riders.map((r) => (r.id === riderId ? { ...r, status } : r)),
    };
  }

  private patchTelemetry(riderId: string, patch: Partial<TelemetrySnapshot>): void {
    const prev = this.fleet.telemetry[riderId];
    if (!prev) return;
    this.fleet = {
      ...this.fleet,
      telemetry: { ...this.fleet.telemetry, [riderId]: { ...prev, ...patch, updatedAt: Date.now() } },
    };
  }

  private emitFleet(): void {
    this.fleetListeners.forEach((cb) => cb(this.fleet));
  }

  private emitAlerts(): void {
    const sorted = [...this.alerts].sort((a, b) => b.createdAt - a.createdAt);
    this.alertListeners.forEach((cb) => cb(sorted));
  }
}
