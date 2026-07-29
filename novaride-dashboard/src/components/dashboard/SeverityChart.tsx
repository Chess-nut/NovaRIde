import {
  Bar,
  BarChart,
  CartesianGrid,
  Cell,
  ResponsiveContainer,
  Tooltip,
  XAxis,
  YAxis,
} from 'recharts';
import type { AlertSeverity } from '../../data/types';
import { SEVERITY_COLOR, SEVERITY_LABEL } from '../../lib/format';
import { Panel } from '../ui/Panel';
import { ChartTooltip } from './ChartTooltip';
import { axisStyle, gridStroke, tooltipCursor } from './chartTheme';

const ORDER: AlertSeverity[] = ['critical', 'high', 'medium', 'low', 'info'];

interface SeverityChartProps {
  counts: Record<AlertSeverity, number>;
}

export function SeverityChart({ counts }: SeverityChartProps) {
  const data = ORDER.map((severity) => ({
    key: severity,
    name: SEVERITY_LABEL[severity],
    value: counts[severity],
  }));

  return (
    <Panel
      title="Alert Severity"
      meta={<span className="telemetry text-[11px] text-txtdim">24h</span>}
      bodyClassName="min-h-0"
    >
      <div className="h-full min-h-[180px]">
        <ResponsiveContainer width="100%" height="100%">
          <BarChart data={data} margin={{ top: 8, right: 4, bottom: 0, left: -24 }} barSize={22}>
            <CartesianGrid stroke={gridStroke} strokeDasharray="2 4" vertical={false} />
            <XAxis dataKey="name" {...axisStyle} />
            <YAxis allowDecimals={false} {...axisStyle} />
            <Tooltip cursor={tooltipCursor} content={<ChartTooltip unit="alerts" />} />
            <Bar dataKey="value" radius={[4, 4, 0, 0]} isAnimationActive={false}>
              {data.map((entry) => (
                <Cell key={entry.key} fill={SEVERITY_COLOR[entry.key]} />
              ))}
            </Bar>
          </BarChart>
        </ResponsiveContainer>
      </div>
    </Panel>
  );
}
