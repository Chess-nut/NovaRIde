import type { RiderStatus } from '../../data/types';
import { STATUS_COLOR, STATUS_LABEL, relativeAge } from '../../lib/format';
import { MapCanvas } from '../map/MapCanvas';
import type { MapRider } from '../map/types';
import { Panel } from '../ui/Panel';

const LEGEND: RiderStatus[] = ['riding', 'idle', 'emergency', 'offline'];

interface MapPanelProps {
  riders: MapRider[];
  focusRiderId: string | null;
  lastUpdateAt: number;
  now: number;
  alarmed: boolean;
  onRiderClick: (riderId: string) => void;
}

export function MapPanel({
  riders,
  focusRiderId,
  lastUpdateAt,
  now,
  alarmed,
  onRiderClick,
}: MapPanelProps) {
  return (
    <Panel
      title="Live Fleet Map"
      alarmed={alarmed}
      className="min-h-[420px]"
      bodyClassName="min-h-0"
      meta={
        <>
          <ul className="hidden items-center gap-3 lg:flex">
            {LEGEND.map((status) => (
              <li key={status} className="flex items-center gap-1.5">
                <span
                  className="h-2 w-2 rounded-full"
                  style={{ background: STATUS_COLOR[status] }}
                  aria-hidden="true"
                />
                <span className="text-[11px] text-txtdim">{STATUS_LABEL[status]}</span>
              </li>
            ))}
          </ul>
          <span className="telemetry text-[11px] text-txtdim">
            updated {lastUpdateAt > 0 ? relativeAge(lastUpdateAt, now) : '0s'} ago
          </span>
        </>
      }
    >
      <MapCanvas riders={riders} focusRiderId={focusRiderId} onRiderClick={onRiderClick} />
    </Panel>
  );
}
