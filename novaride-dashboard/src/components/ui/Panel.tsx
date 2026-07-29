import type { ReactNode } from 'react';
import { cn } from '../../lib/cn';

interface PanelProps {
  title?: string;
  meta?: ReactNode;
  children: ReactNode;
  className?: string;
  bodyClassName?: string;
  /** Emergency takeover: slow-pulsing danger outer ring (static under reduced motion). */
  alarmed?: boolean;
}

export function Panel({ title, meta, children, className, bodyClassName, alarmed }: PanelProps) {
  return (
    <section
      className={cn(
        'panel flex min-h-0 flex-col p-4',
        alarmed && 'animate-ring-pulse border-danger/60',
        className,
      )}
    >
      {(title || meta) && (
        <header className="mb-3 flex min-h-[20px] items-center justify-between gap-3">
          {title ? <h2 className="panel-title">{title}</h2> : <span />}
          {meta ? <div className="flex items-center gap-2">{meta}</div> : null}
        </header>
      )}
      <div className={cn('min-h-0 flex-1', bodyClassName)}>{children}</div>
    </section>
  );
}
