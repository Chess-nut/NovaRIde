import { useMemo } from 'react';
import { AlertTypesChart } from '../components/dashboard/AlertTypesChart';
import { AlertsFeed } from '../components/dashboard/AlertsFeed';
import { FleetDonut } from '../components/dashboard/FleetDonut';
import { KpiStrip } from '../components/dashboard/KpiStrip';
import { MapPanel } from '../components/dashboard/MapPanel';
import { SeverityChart } from '../components/dashboard/SeverityChart';
import { TelemetryTable } from '../components/dashboard/TelemetryTable';
import type { MapRider } from '../components/map/types';
import { useNow } from '../hooks/useNow';
import {
  countBySeverity,
  countByType,
  selectActiveCritical,
  selectEmergencies,
  selectToday,
  useAlertStore,
} from '../store/useAlertStore';
import { countByStatus, selectRidersOnline, useFleetStore } from '../store/useFleetStore';
import { useUiStore } from '../store/useUiStore';

/** Placeholder until dispatch timings are recorded — mock for the defense demo. */
const AVG_RESPONSE = '4m 32s';

export function RiderDashboard() {
  const now = useNow(1000);

  const riders = useFleetStore((state) => state.riders);
  const telemetry = useFleetStore((state) => state.telemetry);
  const lastUpdateAt = useFleetStore((state) => state.lastUpdateAt);
  const alerts = useAlertStore((state) => state.alerts);

  const selectedRiderId = useUiStore((state) => state.selectedRiderId);
  const selectRider = useUiStore((state) => state.selectRider);

  const statusCounts = useMemo(() => countByStatus(riders), [riders]);
  const ridersById = useMemo(() => new Map(riders.map((rider) => [rider.id, rider])), [riders]);

  const todaysAlerts = useMemo(() => selectToday(alerts), [alerts]);
  const severityCounts = useMemo(() => countBySeverity(todaysAlerts), [todaysAlerts]);
  const typeCounts = useMemo(() => countByType(todaysAlerts), [todaysAlerts]);
  const activeEmergencies = useMemo(() => selectEmergencies(alerts).length, [alerts]);
  const takeover = useMemo(() => selectActiveCritical(alerts).length > 0, [alerts]);

  const mapRiders = useMemo<MapRider[]>(
    () =>
      riders.flatMap((rider) => {
        const snapshot = telemetry[rider.id];
        if (!snapshot) return [];
        return [
          {
            id: rider.id,
            name: rider.name,
            lat: snapshot.lat,
            lng: snapshot.lng,
            speedKph: snapshot.speedKph,
            status: rider.status,
          },
        ];
      }),
    [riders, telemetry],
  );

  return (
    <div className="flex flex-col gap-4">
      <KpiStrip
        ridersOnline={selectRidersOnline(riders)}
        fleetSize={riders.length}
        activeEmergencies={activeEmergencies}
        alertsToday={todaysAlerts.length}
        avgResponse={AVG_RESPONSE}
      />

      <div className="grid grid-cols-1 gap-4 xl:grid-cols-[320px_minmax(0,1fr)]">
        {/* Below 1280px the left column drops beneath the map. */}
        <div className="order-2 flex min-h-0 flex-col gap-4 xl:order-1 xl:h-[560px]">
          <FleetDonut counts={statusCounts} />
          <AlertsFeed
            alerts={todaysAlerts}
            ridersById={ridersById}
            now={now}
            onSelect={selectRider}
          />
        </div>

        <div className="order-1 min-h-0 xl:order-2 xl:h-[560px]">
          <MapPanel
            riders={mapRiders}
            focusRiderId={selectedRiderId}
            lastUpdateAt={lastUpdateAt}
            now={now}
            alarmed={takeover}
            onRiderClick={selectRider}
          />
        </div>
      </div>

      <div className="grid grid-cols-1 gap-4 xl:grid-cols-[55%_minmax(0,1fr)_minmax(0,1fr)]">
        <div className="h-[320px] min-h-0">
          <TelemetryTable
            riders={riders}
            telemetry={telemetry}
            now={now}
            selectedRiderId={selectedRiderId}
            onSelect={selectRider}
          />
        </div>
        <SeverityChart counts={severityCounts} />
        <AlertTypesChart counts={typeCounts} />
      </div>
    </div>
  );
}
