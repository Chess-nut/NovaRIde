import { Outlet, useLocation } from 'react-router-dom';
import { useLiveFeed } from '../../hooks/useLiveFeed';
import { Sidebar } from './Sidebar';
import { Topbar } from './Topbar';

const TITLES: Record<string, string> = {
  '/': 'Rider Dashboard',
  '/monitoring': 'Rider Monitoring',
  '/users': 'User Management',
};

export function AppLayout() {
  const { pathname } = useLocation();
  const title = TITLES[pathname] ?? 'NovaRide';
  useLiveFeed();

  return (
    <div className="flex h-full min-h-screen bg-ink">
      <Sidebar />
      <div className="flex min-w-0 flex-1 flex-col">
        <Topbar title={title} />
        <main className="min-h-0 flex-1 overflow-auto p-4">
          <Outlet />
        </main>
      </div>
    </div>
  );
}
