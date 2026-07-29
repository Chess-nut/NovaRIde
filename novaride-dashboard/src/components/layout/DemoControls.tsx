import { useEffect, useRef, useState } from 'react';
import { FlaskConical, Gauge, RotateCcw, ShieldAlert, Timer, Wine } from 'lucide-react';
import type { LucideIcon } from 'lucide-react';
import { useSimulation } from '../../hooks/useSimulation';
import { cn } from '../../lib/cn';

export function DemoControls() {
  const [open, setOpen] = useState(false);
  const wrapRef = useRef<HTMLDivElement>(null);
  const sim = useSimulation();

  useEffect(() => {
    if (!open) return;
    const onPointerDown = (event: MouseEvent) => {
      if (!wrapRef.current?.contains(event.target as Node)) setOpen(false);
    };
    const onKeyDown = (event: KeyboardEvent) => {
      if (event.key === 'Escape') setOpen(false);
    };
    document.addEventListener('mousedown', onPointerDown);
    document.addEventListener('keydown', onKeyDown);
    return () => {
      document.removeEventListener('mousedown', onPointerDown);
      document.removeEventListener('keydown', onKeyDown);
    };
  }, [open]);

  const actions: { label: string; hint: string; icon: LucideIcon; tone: string; run: () => void }[] =
    [
      {
        label: 'Simulate crash (countdown)',
        hint: '15s rider-cancelable window, then auto-SOS',
        icon: Timer,
        tone: 'text-warn',
        run: sim.crashCountdown,
      },
      {
        label: 'Simulate high-speed crash',
        hint: 'Impact above 60 kph — instant SOS, no countdown',
        icon: ShieldAlert,
        tone: 'text-danger',
        run: sim.highSpeedCrash,
      },
      {
        label: 'Simulate rider cancel',
        hint: 'Rider clears the newest active countdown',
        icon: Gauge,
        tone: 'text-ok',
        run: sim.riderCancel,
      },
      {
        label: 'Simulate alcohol warning',
        hint: 'MQ-3 reading above 0.25 mg/L threshold',
        icon: Wine,
        tone: 'text-warn',
        run: sim.alcoholWarning,
      },
      {
        label: 'Reset simulation',
        hint: 'Restore the fleet to its boot state',
        icon: RotateCcw,
        tone: 'text-txtdim',
        run: sim.reset,
      },
    ];

  return (
    <div className="relative" ref={wrapRef}>
      <button
        type="button"
        onClick={() => setOpen((v) => !v)}
        aria-label="Demo controls"
        aria-expanded={open}
        aria-haspopup="dialog"
        className={cn(
          'flex items-center gap-2 rounded-lg border border-line px-3 py-1.5 text-xs transition-colors',
          open ? 'bg-panel text-txt' : 'bg-panel text-txtdim hover:text-txt',
        )}
      >
        <FlaskConical size={14} aria-hidden="true" />
        Demo Controls
      </button>

      {open && (
        <div
          role="dialog"
          aria-label="Demo controls"
          className="absolute right-0 top-[calc(100%+8px)] z-[1200] w-[300px] rounded-xl border border-line bg-panel p-2"
        >
          <p className="panel-title px-2 pb-2 pt-1">Simulation</p>
          <ul className="flex flex-col gap-0.5">
            {actions.map(({ label, hint, icon: Icon, tone, run }) => (
              <li key={label}>
                <button
                  type="button"
                  onClick={() => {
                    run();
                    setOpen(false);
                  }}
                  className="flex w-full items-start gap-2.5 rounded-lg px-2 py-2 text-left transition-colors hover:bg-panel2"
                >
                  <Icon size={15} className={cn('mt-0.5 shrink-0', tone)} aria-hidden="true" />
                  <span>
                    <span className="block text-xs font-medium text-txt">{label}</span>
                    <span className="block text-[11px] leading-snug text-txtdim">{hint}</span>
                  </span>
                </button>
              </li>
            ))}
          </ul>
        </div>
      )}
    </div>
  );
}
