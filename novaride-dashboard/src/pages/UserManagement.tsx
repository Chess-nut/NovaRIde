import { Users } from 'lucide-react';
import { Panel } from '../components/ui/Panel';
import { EmptyState } from '../components/ui/EmptyState';

export function UserManagement() {
  return (
    <Panel title="User Management" className="h-full" bodyClassName="flex">
      <EmptyState
        icon={Users}
        title="Rider and operator accounts are not wired yet"
        description="Rider onboarding, helmet-to-rider assignment, emergency contacts and operator roles live on this screen."
        phase="Coming in Phase 4"
      />
    </Panel>
  );
}
