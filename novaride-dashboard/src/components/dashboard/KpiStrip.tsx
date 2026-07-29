import { AlarmClock, Bell, Radio, Siren } from 'lucide-react';
import type { LucideIcon } from 'lucide-react';
import { cn } from '../../lib/cn';

interface KpiCardProps {
  label: string;
  value: string;
  hint: string;
  icon: LucideIcon;
  alarmed?: boolean;
}

function KpiCard({ label, value, hint, icon: Icon, alarmed }: KpiCardProps) {
  return (
    <div
      className={cn(
        'panel flex items-start justify-between gap-3 p-4',
        alarmed && 'border-danger/50 bg-danger/10',
      )}
    >
      <div className="min-w-0">
        <p className="panel-title">{label}</p>
        <p
          className={cn(
            'telemetry mt-2 text-[30px] font-semibold leading-none',
            alarmed ? 'text-danger' : 'text-txt',
          )}
        >
          {value}
        </p>
        <p className="mt-1.5 truncate text-[11px] text-txtdim">{hint}</p>
      </div>
      <Icon
        size={18}
        className={cn('shrink-0', alarmed ? 'text-danger' : 'text-txtdim/60')}
        aria-hidden="true"
      />
    </div>
  );
}

interface KpiStripProps {
  ridersOnline: number;
  fleetSize: number;
  activeEmergencies: number;
  alertsToday: number;
  avgResponse: string;
}

export function KpiStrip({
  ridersOnline,
  fleetSize,
  activeEmergencies,
  alertsToday,
  avgResponse,
}: KpiStripProps) {
  return (
    <div className="grid grid-cols-2 gap-4 xl:grid-cols-4">
      <KpiCard
        label="Riders Online"
        value={String(ridersOnline)}
        hint={`of ${fleetSize} helmets in fleet`}
        icon={Radio}
      />
      <KpiCard
        label="Active Emergencies"
        value={String(activeEmergencies)}
        hint={activeEmergencies > 0 ? 'SOS awaiting dispatch' : 'no open SOS'}
        icon={Siren}
        alarmed={activeEmergencies > 0}
      />
      <KpiCard
        label="Alerts Today"
        value={String(alertsToday)}
        hint="rolling 24 hours"
        icon={Bell}
      />
      <KpiCard
        label="Avg Response Time"
        value={avgResponse}
        hint="acknowledge to dispatch"
        icon={AlarmClock}
      />
    </div>
  );
}
