import type {
  Alert,
  AlertType,
  FleetSnapshot,
  HelmetDevice,
  Platform,
  Rider,
  RiderStatus,
  TelemetrySnapshot,
} from '../types';
import { SEVERITY_BY_TYPE } from '../types';
import { labelFor, spawnInCity } from './geo';
import { createRng } from './rng';

interface RiderSpec {
  name: string;
  city: string;
  platform: Platform;
}

/** 24 riders: QC 8 · Manila 5 · Makati 3 · Pasig 3 · Caloocan 2 · Marikina 2 · Mandaluyong 1. */
const RIDER_SPECS: readonly RiderSpec[] = [
  { name: 'Renato Villanueva', city: 'Quezon City', platform: 'Angkas' },
  { name: 'Maricel Bautista', city: 'Quezon City', platform: 'JoyRide' },
  { name: 'Joselito Ramos', city: 'Quezon City', platform: 'Angkas' },
  { name: 'Divina Salazar', city: 'Quezon City', platform: 'Move It' },
  { name: 'Arnel Dela Cruz', city: 'Quezon City', platform: 'JoyRide' },
  { name: 'Rowena Manalo', city: 'Quezon City', platform: 'Angkas' },
  { name: 'Ferdinand Aquino', city: 'Quezon City', platform: 'Move It' },
  { name: 'Cristina Pangilinan', city: 'Quezon City', platform: 'JoyRide' },
  { name: 'Edgardo Mercado', city: 'Manila', platform: 'Angkas' },
  { name: 'Lorna Gatchalian', city: 'Manila', platform: 'JoyRide' },
  { name: 'Nestor Bacani', city: 'Manila', platform: 'Angkas' },
  { name: 'Imelda Ocampo', city: 'Manila', platform: 'Move It' },
  { name: 'Rodolfo Tolentino', city: 'Manila', platform: 'JoyRide' },
  { name: 'Antonio Sarmiento', city: 'Makati', platform: 'Angkas' },
  { name: 'Jocelyn Fajardo', city: 'Makati', platform: 'Move It' },
  { name: 'Wilfredo Lazaro', city: 'Makati', platform: 'JoyRide' },
  { name: 'Melinda Corpuz', city: 'Pasig', platform: 'Angkas' },
  { name: 'Ricardo Naval', city: 'Pasig', platform: 'JoyRide' },
  { name: 'Susan Legaspi', city: 'Pasig', platform: 'Move It' },
  { name: 'Danilo Estrada', city: 'Caloocan', platform: 'Angkas' },
  { name: 'Teresita Alcantara', city: 'Caloocan', platform: 'JoyRide' },
  { name: 'Benjamin Quiambao', city: 'Marikina', platform: 'Move It' },
  { name: 'Gloria Sandoval', city: 'Marikina', platform: 'Angkas' },
  { name: 'Alfredo Buenaventura', city: 'Mandaluyong', platform: 'JoyRide' },
];

/**
 * Boot statuses: 16 riding, 4 idle, 3 offline, plus one rider who is back on
 * the road after the pre-seeded resolved crash that sits in alert history.
 */
const BOOT_STATUS: readonly RiderStatus[] = [
  ...Array<RiderStatus>(16).fill('riding'),
  ...Array<RiderStatus>(4).fill('idle'),
  ...Array<RiderStatus>(3).fill('offline'),
  'riding',
];

const AVATAR_COLORS = ['#4C8DFF', '#34D399', '#F59E0B', '#A78BFA', '#22D3EE', '#FB7185'];

/** Rider index that owns the pre-seeded resolved crash. */
const RECOVERED_RIDER_INDEX = 23;

function phone(rng: ReturnType<typeof createRng>): string {
  return `+639${rng.int(100000000, 999999999)}`;
}

function plate(rng: ReturnType<typeof createRng>): string {
  const letters = 'ABCDEFGHJKLMNPRSTUVWXYZ';
  const l = () => letters.charAt(rng.int(0, letters.length - 1));
  return `${l()}${l()}${l()} ${rng.int(1000, 9999)}`;
}

export function buildFleet(): FleetSnapshot {
  const rng = createRng(20260729);
  const riders: Rider[] = [];
  const telemetry: Record<string, TelemetrySnapshot> = {};
  const now = Date.now();

  RIDER_SPECS.forEach((spec, index) => {
    const id = `rider-${String(index + 1).padStart(2, '0')}`;
    const helmetId = `NR-H1-${String(index + 1).padStart(3, '0')}`;
    const status = BOOT_STATUS[index] ?? 'idle';

    riders.push({
      id,
      name: spec.name,
      phone: phone(rng),
      platform: spec.platform,
      plateNo: plate(rng),
      helmetId,
      city: spec.city,
      status,
      emergencyContacts: [
        {
          name: rng.pick(['Marites', 'Jun', 'Aileen', 'Boyet', 'Nenita', 'Rico']),
          phone: phone(rng),
          relation: rng.pick(['Spouse', 'Sibling', 'Parent', 'Child']),
        },
      ],
      avatarColor: rng.pick(AVATAR_COLORS),
    });

    const at = spawnInCity(spec.city, rng);
    telemetry[id] = {
      riderId: id,
      lat: at.lat,
      lng: at.lng,
      headingDeg: rng.range(0, 360),
      speedKph: status === 'riding' ? Number(rng.range(12, 62).toFixed(1)) : 0,
      alcoholLevel: Number(rng.range(0, 0.12).toFixed(3)),
      batteryPct: rng.int(35, 100),
      accelMagG: Number(rng.range(0.9, 1.2).toFixed(2)),
      gpsFix: status !== 'offline',
      updatedAt: status === 'offline' ? now - rng.int(240, 900) * 1000 : now,
    };
  });

  /** 26 helmets: one per rider plus 2 spares in the depot. */
  const devices: HelmetDevice[] = riders.map((rider, index) => ({
    id: rider.helmetId,
    model: 'NovaRide H1',
    assignedRiderId: rider.id,
    firmware: index % 3 === 0 ? '1.4.2' : '1.4.1',
  }));
  devices.push(
    { id: 'NR-H1-025', model: 'NovaRide H1', assignedRiderId: null, firmware: '1.4.2' },
    { id: 'NR-H1-026', model: 'NovaRide H1', assignedRiderId: null, firmware: '1.3.9' },
  );

  return { riders, devices, telemetry };
}

/** Types that make up a plausible 24h history so the charts are never empty. */
const HISTORY_MIX: readonly AlertType[] = [
  'low_battery',
  'low_battery',
  'low_battery',
  'alcohol_warning',
  'alcohol_warning',
  'device_offline',
  'device_offline',
  'device_offline',
  'crash_countdown',
  'crash_countdown',
  'alcohol_warning',
  'low_battery',
];

export function buildAlertHistory(fleet: FleetSnapshot): Alert[] {
  const rng = createRng(770126);
  const now = Date.now();
  const alerts: Alert[] = [];

  HISTORY_MIX.forEach((type, index) => {
    const rider = rng.pick(fleet.riders);
    const snapshot = fleet.telemetry[rider.id];
    /* Spread across the last 23 hours, newest last. */
    const createdAt = now - Math.round(((index + 1) / (HISTORY_MIX.length + 1)) * 23 * 3600_000);
    alerts.push({
      id: `alert-h${index + 1}`,
      riderId: rider.id,
      type,
      severity: SEVERITY_BY_TYPE[type],
      status: type === 'crash_countdown' ? 'canceled_by_rider' : 'resolved',
      createdAt,
      location: {
        lat: snapshot?.lat ?? 14.6,
        lng: snapshot?.lng ?? 121.02,
        label: labelFor(rider.city, rng),
      },
      timeline: [
        { status: type === 'crash_countdown' ? 'countdown' : 'active', at: createdAt },
        {
          status: type === 'crash_countdown' ? 'canceled_by_rider' : 'resolved',
          at: createdAt + rng.int(45, 600) * 1000,
        },
      ],
    });
  });

  /* The pre-seeded resolved crash: full dispatch timeline, rider is back riding. */
  const recovered = fleet.riders[RECOVERED_RIDER_INDEX];
  if (recovered) {
    const snapshot = fleet.telemetry[recovered.id];
    const createdAt = now - 5 * 3600_000;
    alerts.push({
      id: 'alert-h0',
      riderId: recovered.id,
      type: 'crash_sos',
      severity: SEVERITY_BY_TYPE.crash_sos,
      status: 'resolved',
      createdAt,
      location: {
        lat: snapshot?.lat ?? 14.6,
        lng: snapshot?.lng ?? 121.02,
        label: labelFor(recovered.city, rng),
      },
      timeline: [
        { status: 'countdown', at: createdAt - 15_000 },
        { status: 'active', at: createdAt },
        { status: 'acknowledged', at: createdAt + 42_000 },
        { status: 'dispatched', at: createdAt + 96_000 },
        { status: 'resolved', at: createdAt + 1_920_000 },
      ],
    });
  }

  return alerts.sort((a, b) => b.createdAt - a.createdAt);
}
