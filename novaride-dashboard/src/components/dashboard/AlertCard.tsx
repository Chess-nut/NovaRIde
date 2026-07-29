import type { Alert, Rider } from '../../data/types';
import { cn } from '../../lib/cn';
import {
  ALERT_STATUS_LABEL,
  ALERT_TYPE_LABEL,
  SEVERITY_COLOR,
  clockTime,
} from '../../lib/format';
import { CountdownRing } from './CountdownRing';

interface AlertCardProps {
  alert: Alert;
  rider: Rider | undefined;
  now: number;
  isNew: boolean;
  onSelect: (riderId: string) => void;
}

const STATUS_CHIP: Record<string, string> = {
  active: 'border-danger/40 bg-danger/15 text-danger',
  countdown: 'border-warn/40 bg-warn/15 text-warn',
  acknowledged: 'border-accent/40 bg-accent/15 text-accent',
  dispatched: 'border-accent/40 bg-accent/15 text-accent',
  canceled_by_rider: 'border-line bg-panel2 text-txtdim',
  resolved: 'border-line bg-panel2 text-txtdim',
};

export function AlertCard({ alert, rider, now, isNew, onSelect }: AlertCardProps) {
  const countdown = alert.status === 'countdown' && alert.countdownEndsAt !== undefined;

  return (
    <li>
      <button
        type="button"
        onClick={() => onSelect(alert.riderId)}
        className={cn(
          'flex w-full items-start gap-3 rounded-lg border border-line bg-panel2/50 p-3 pl-0 text-left transition-colors hover:bg-panel2',
          isNew && 'animate-slide-fade',
        )}
      >
        <span
          className="mt-0.5 w-[3px] shrink-0 self-stretch rounded-r"
          style={{ background: SEVERITY_COLOR[alert.severity] }}
          aria-hidden="true"
        />

        <span className="min-w-0 flex-1">
          <span className="flex items-center justify-between gap-2">
            <span className="truncate text-[13px] font-semibold text-txt">
              {ALERT_TYPE_LABEL[alert.type]}
            </span>
            <span className="telemetry shrink-0 text-[11px] text-txtdim">
              {clockTime(alert.createdAt)}
            </span>
          </span>

          <span className="mt-0.5 block truncate text-[12px] text-txtdim">
            {rider?.name ?? 'Unknown rider'} · {rider?.city ?? alert.location.label}
          </span>

          <span
            className={cn(
              'mt-2 inline-block rounded-full border px-2 py-0.5 text-[10px] uppercase tracking-wide',
              STATUS_CHIP[alert.status] ?? 'border-line bg-panel2 text-txtdim',
            )}
          >
            {ALERT_STATUS_LABEL[alert.status]}
          </span>
        </span>

        {countdown && alert.countdownEndsAt !== undefined && (
          <CountdownRing endsAt={alert.countdownEndsAt} now={now} />
        )}
      </button>
    </li>
  );
}
