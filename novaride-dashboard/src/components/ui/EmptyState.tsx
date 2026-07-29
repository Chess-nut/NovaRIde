import type { LucideIcon } from 'lucide-react';

interface EmptyStateProps {
  icon: LucideIcon;
  title: string;
  description: string;
  phase?: string;
}

export function EmptyState({ icon: Icon, title, description, phase }: EmptyStateProps) {
  return (
    <div className="flex h-full flex-col items-center justify-center gap-3 px-6 py-16 text-center">
      <div className="flex h-12 w-12 items-center justify-center rounded-xl border border-line bg-panel2">
        <Icon size={22} className="text-txtdim" aria-hidden="true" />
      </div>
      <h3 className="text-base font-semibold text-txt">{title}</h3>
      <p className="max-w-sm text-sm text-txtdim">{description}</p>
      {phase && (
        <span className="telemetry mt-1 rounded-full border border-line bg-panel2 px-3 py-1 text-[11px] uppercase tracking-wider text-txtdim">
          {phase}
        </span>
      )}
    </div>
  );
}
