import { getSession, initials } from '../../lib/auth';
import { DemoControls } from './DemoControls';

interface TopbarProps {
  title: string;
}

export function Topbar({ title }: TopbarProps) {
  const session = getSession();
  const name = session?.displayName ?? 'Ops Admin';

  return (
    <header className="flex h-14 shrink-0 items-center justify-between border-b border-line bg-panel2 px-5">
      <h1 className="text-[15px] font-semibold text-txt">{title}</h1>

      <div className="flex items-center gap-3">
        <span className="telemetry flex items-center gap-2 rounded-full border border-line bg-panel px-3 py-1 text-[11px] uppercase tracking-wide text-txtdim">
          <span className="h-1.5 w-1.5 rounded-full bg-ok" aria-hidden="true" />
          Mock feed · Live
        </span>

        <DemoControls />

        <div className="flex items-center gap-2 rounded-full border border-line bg-panel py-1 pl-1 pr-3">
          <span
            className="flex h-6 w-6 items-center justify-center rounded-full bg-accent/20 text-[10px] font-semibold text-accent"
            aria-hidden="true"
          >
            {initials(name)}
          </span>
          <span className="text-xs text-txt">{name}</span>
        </div>
      </div>
    </header>
  );
}
