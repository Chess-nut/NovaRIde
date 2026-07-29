import { useEffect, useRef, useState } from 'react';
import type { Alert, Rider } from '../../data/types';
import { Panel } from '../ui/Panel';
import { AlertCard } from './AlertCard';

interface AlertsFeedProps {
  alerts: Alert[];
  ridersById: Map<string, Rider>;
  now: number;
  onSelect: (riderId: string) => void;
}

/** Cards that appeared since the previous render animate in once. */
function useFreshIds(alerts: Alert[]): Set<string> {
  const seen = useRef<Set<string> | null>(null);
  const [fresh, setFresh] = useState<Set<string>>(() => new Set());

  useEffect(() => {
    const ids = new Set(alerts.map((alert) => alert.id));
    if (seen.current === null) {
      seen.current = ids;
      return;
    }
    const added = alerts.filter((alert) => !seen.current?.has(alert.id)).map((alert) => alert.id);
    seen.current = ids;
    if (added.length === 0) return;

    setFresh(new Set(added));
    const timer = setTimeout(() => setFresh(new Set()), 400);
    return () => clearTimeout(timer);
  }, [alerts]);

  return fresh;
}

export function AlertsFeed({ alerts, ridersById, now, onSelect }: AlertsFeedProps) {
  const fresh = useFreshIds(alerts);

  return (
    <Panel
      title="Recent Alerts"
      className="min-h-0 flex-1"
      meta={
        <span className="telemetry text-[11px] text-txtdim">
          {alerts.length} in 24h
        </span>
      }
      bodyClassName="min-h-0 overflow-y-auto pr-1"
    >
      {alerts.length === 0 ? (
        <p className="py-8 text-center text-xs text-txtdim">No alerts in the last 24 hours.</p>
      ) : (
        <ul className="flex flex-col gap-2">
          {alerts.map((alert) => (
            <AlertCard
              key={alert.id}
              alert={alert}
              rider={ridersById.get(alert.riderId)}
              now={now}
              isNew={fresh.has(alert.id)}
              onSelect={onSelect}
            />
          ))}
        </ul>
      )}
    </Panel>
  );
}
