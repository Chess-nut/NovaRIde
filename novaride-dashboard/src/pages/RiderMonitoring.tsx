import { MapPinned } from 'lucide-react';
import { Panel } from '../components/ui/Panel';
import { EmptyState } from '../components/ui/EmptyState';

export function RiderMonitoring() {
  return (
    <Panel title="Rider Monitoring" className="h-full" bodyClassName="flex">
      <EmptyState
        icon={MapPinned}
        title="Per-rider monitoring is not wired yet"
        description="Full-screen fleet map, rider drill-down drawer, trip history and geofence tooling live on this screen."
        phase="Coming in Phase 3"
      />
    </Panel>
  );
}
