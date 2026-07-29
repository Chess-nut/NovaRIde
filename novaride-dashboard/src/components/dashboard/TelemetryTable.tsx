import { useMemo } from 'react';
import { ALCOHOL_THRESHOLD } from '../../data/types';
import type { Rider, TelemetrySnapshot } from '../../data/types';
import { cn } from '../../lib/cn';
import { STATUS_COLOR, STATUS_LABEL, oneDecimal, relativeAge, twoDecimals } from '../../lib/format';
import { Panel } from '../ui/Panel';

interface TelemetryTableProps {
  riders: Rider[];
  telemetry: Record<string, TelemetrySnapshot>;
  now: number;
  selectedRiderId: string | null;
  onSelect: (riderId: string) => void;
}

const HEAD = 'sticky top-0 z-10 bg-panel2 px-3 py-2 text-left text-[11px] uppercase tracking-wider text-txtdim';

export function TelemetryTable({
  riders,
  telemetry,
  now,
  selectedRiderId,
  onSelect,
}: TelemetryTableProps) {
  /* Emergencies pin to the top; everyone else sorts by name. */
  const rows = useMemo(
    () =>
      [...riders].sort((a, b) => {
        const emergency = Number(b.status === 'emergency') - Number(a.status === 'emergency');
        return emergency !== 0 ? emergency : a.name.localeCompare(b.name);
      }),
    [riders],
  );

  return (
    <Panel
      title="Live Telemetry"
      meta={<span className="telemetry text-[11px] text-txtdim">{rows.length} helmets</span>}
      bodyClassName="min-h-0 overflow-auto"
      className="min-h-0"
    >
      <table className="w-full border-collapse text-[12px]">
        <thead>
          <tr>
            <th scope="col" className={HEAD}>Rider</th>
            <th scope="col" className={HEAD}>City</th>
            <th scope="col" className={cn(HEAD, 'text-right')}>Speed</th>
            <th scope="col" className={cn(HEAD, 'text-right')}>Alcohol</th>
            <th scope="col" className={cn(HEAD, 'text-right')}>Battery</th>
            <th scope="col" className={HEAD}>GPS</th>
            <th scope="col" className={HEAD}>Status</th>
            <th scope="col" className={cn(HEAD, 'text-right')}>Last Update</th>
          </tr>
        </thead>
        <tbody>
          {rows.map((rider) => {
            const snapshot = telemetry[rider.id];
            const emergency = rider.status === 'emergency';
            const overLimit = (snapshot?.alcoholLevel ?? 0) > ALCOHOL_THRESHOLD;
            const lowBattery = (snapshot?.batteryPct ?? 100) < 20;

            return (
              <tr
                key={rider.id}
                tabIndex={0}
                onClick={() => onSelect(rider.id)}
                onKeyDown={(event) => {
                  if (event.key === 'Enter' || event.key === ' ') {
                    event.preventDefault();
                    onSelect(rider.id);
                  }
                }}
                className={cn(
                  'cursor-pointer border-t border-line/70 transition-colors',
                  emergency ? 'animate-row-pulse' : 'hover:bg-panel2/70',
                  selectedRiderId === rider.id && !emergency && 'bg-panel2',
                )}
              >
                <td className="px-3 py-2">
                  <span className="flex items-center gap-2">
                    <span
                      className="h-1.5 w-1.5 shrink-0 rounded-full"
                      style={{ background: rider.avatarColor }}
                      aria-hidden="true"
                    />
                    <span className="truncate font-medium text-txt">{rider.name}</span>
                  </span>
                </td>
                <td className="px-3 py-2 text-txtdim">{rider.city}</td>
                <td className="telemetry px-3 py-2 text-right text-txt">
                  {oneDecimal(snapshot?.speedKph ?? 0)}
                </td>
                <td
                  className={cn(
                    'telemetry px-3 py-2 text-right',
                    overLimit ? 'font-semibold text-warn' : 'text-txt',
                  )}
                >
                  {twoDecimals(snapshot?.alcoholLevel ?? 0)}
                </td>
                <td
                  className={cn(
                    'telemetry px-3 py-2 text-right',
                    lowBattery ? 'text-warn' : 'text-txt',
                  )}
                >
                  {snapshot?.batteryPct ?? 0}%
                </td>
                <td className="telemetry px-3 py-2 text-txtdim">
                  {snapshot?.gpsFix ? 'FIX' : 'NO FIX'}
                </td>
                <td className="px-3 py-2">
                  <span className="flex items-center gap-1.5">
                    <span
                      className="h-2 w-2 shrink-0 rounded-full"
                      style={{ background: STATUS_COLOR[rider.status] }}
                      aria-hidden="true"
                    />
                    <span className={cn(emergency ? 'font-semibold text-danger' : 'text-txtdim')}>
                      {STATUS_LABEL[rider.status]}
                    </span>
                  </span>
                </td>
                <td className="telemetry px-3 py-2 text-right text-txtdim">
                  {relativeAge(snapshot?.updatedAt ?? now, now)} ago
                </td>
              </tr>
            );
          })}
        </tbody>
      </table>
    </Panel>
  );
}
