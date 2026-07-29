import { LayoutDashboard } from 'lucide-react';
import { Panel } from '../components/ui/Panel';
import { EmptyState } from '../components/ui/EmptyState';

export function RiderDashboard() {
  return (
    <Panel title="Rider Dashboard" className="h-full" bodyClassName="flex">
      <EmptyState
        icon={LayoutDashboard}
        title="Live fleet overview"
        description="KPIs, fleet status donut, live map, telemetry table and alert charts land here."
        phase="Building in Phase 2"
      />
    </Panel>
  );
}
