import {
  Bar,
  BarChart,
  CartesianGrid,
  ResponsiveContainer,
  Tooltip,
  XAxis,
  YAxis,
} from 'recharts';
import type { AlertType } from '../../data/types';
import { ALERT_TYPE_SHORT } from '../../lib/format';
import { Panel } from '../ui/Panel';
import { ChartTooltip } from './ChartTooltip';
import { axisStyle, gridStroke, tooltipCursor } from './chartTheme';

const ORDER: AlertType[] = [
  'crash_sos',
  'crash_countdown',
  'alcohol_warning',
  'low_battery',
  'device_offline',
];

interface AlertTypesChartProps {
  counts: Record<AlertType, number>;
}

export function AlertTypesChart({ counts }: AlertTypesChartProps) {
  const data = ORDER.map((type) => ({ name: ALERT_TYPE_SHORT[type], value: counts[type] }));

  return (
    <Panel
      title="Alert Types"
      meta={<span className="telemetry text-[11px] text-txtdim">24h</span>}
      bodyClassName="min-h-0"
    >
      <div className="h-full min-h-[180px]">
        <ResponsiveContainer width="100%" height="100%">
          <BarChart data={data} margin={{ top: 8, right: 4, bottom: 0, left: -24 }} barSize={22}>
            <CartesianGrid stroke={gridStroke} strokeDasharray="2 4" vertical={false} />
            <XAxis dataKey="name" {...axisStyle} interval={0} />
            <YAxis allowDecimals={false} {...axisStyle} />
            <Tooltip cursor={tooltipCursor} content={<ChartTooltip unit="alerts" />} />
            <Bar dataKey="value" fill="#4C8DFF" radius={[4, 4, 0, 0]} isAnimationActive={false} />
          </BarChart>
        </ResponsiveContainer>
      </div>
    </Panel>
  );
}
