import type { TooltipContentProps } from 'recharts';

interface ChartTooltipProps extends Partial<TooltipContentProps<number, string>> {
  unit?: string;
}

export function ChartTooltip({ active, payload, label, unit }: ChartTooltipProps) {
  if (!active || !payload || payload.length === 0) return null;
  const entry = payload[0];
  if (!entry) return null;

  return (
    <div className="rounded-lg border border-line bg-panel2 px-2.5 py-1.5">
      <p className="text-[11px] text-txt">{String(label)}</p>
      <p className="telemetry text-[12px] font-semibold text-txt">
        {entry.value}
        {unit ? <span className="ml-1 font-normal text-txtdim">{unit}</span> : null}
      </p>
    </div>
  );
}
