import { NavLink } from 'react-router-dom';
import { History, LayoutDashboard, MapPinned, ShieldHalf, Users } from 'lucide-react';
import { cn } from '../../lib/cn';

const NAV = [
  { to: '/', label: 'Rider Dashboard', icon: LayoutDashboard, end: true },
  { to: '/monitoring', label: 'Rider Monitoring', icon: MapPinned, end: false },
  { to: '/users', label: 'User Management', icon: Users, end: false },
] as const;

export function Sidebar() {
  return (
    <aside className="flex w-[232px] shrink-0 flex-col border-r border-line bg-panel">
      <div className="flex h-14 items-center gap-2 border-b border-line px-4">
        <ShieldHalf size={20} className="text-accent" aria-hidden="true" />
        <span className="text-[15px] font-bold tracking-tight text-txt">NovaRide</span>
      </div>

      <nav className="flex flex-col gap-1 p-2" aria-label="Main">
        {NAV.map(({ to, label, icon: Icon, end }) => (
          <NavLink
            key={to}
            to={to}
            end={end}
            className={({ isActive }) =>
              cn(
                'relative flex items-center gap-3 rounded-lg px-3 py-2 text-sm transition-colors',
                isActive
                  ? 'bg-panel2 font-semibold text-txt'
                  : 'text-txtdim hover:bg-panel2/60 hover:text-txt',
              )
            }
          >
            {({ isActive }) => (
              <>
                {isActive && (
                  <span
                    className="absolute left-0 top-1/2 h-5 w-[3px] -translate-y-1/2 rounded-r bg-accent"
                    aria-hidden="true"
                  />
                )}
                <Icon size={17} aria-hidden="true" />
                {label}
              </>
            )}
          </NavLink>
        ))}

        <div className="my-2 h-px bg-line" role="separator" />

        <span
          className="flex cursor-not-allowed items-center gap-3 rounded-lg px-3 py-2 text-sm text-txtdim/60"
          aria-disabled="true"
          title="Alerts History arrives in a later phase"
        >
          <History size={17} aria-hidden="true" />
          Alerts History
          <span className="telemetry ml-auto rounded border border-line px-1.5 py-px text-[10px] uppercase text-txtdim/70">
            soon
          </span>
        </span>
      </nav>

      <div className="mt-auto p-4">
        <p className="telemetry text-[10px] leading-relaxed text-txtdim/70">
          NovaRide H1 · Ops Console
          <br />
          build 0.1.0 · mock feed
        </p>
      </div>
    </aside>
  );
}
