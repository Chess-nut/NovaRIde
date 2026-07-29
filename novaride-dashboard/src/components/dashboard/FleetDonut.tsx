import { Cell, Pie, PieChart, ResponsiveContainer } from 'recharts';
import type { RiderStatus } from '../../data/types';
import { STATUS_COLOR, STATUS_LABEL } from '../../lib/format';
import { Panel } from '../ui/Panel';

const ORDER: RiderStatus[] = ['riding', 'idle', 'emergency', 'offline'];

interface FleetDonutProps {
  counts: Record<RiderStatus, number>;
}

export function FleetDonut({ counts }: FleetDonutProps) {
  const total = ORDER.reduce((sum, status) => sum + counts[status], 0);
  const data = ORDER.map((status) => ({
    status,
    name: STATUS_LABEL[status],
    value: counts[status],
  })).filter((slice) => slice.value > 0);

  return (
    <Panel title="Fleet Status">
      <div className="relative h-[168px]">
        <ResponsiveContainer width="100%" height="100%">
          <PieChart>
            <Pie
              data={data}
              dataKey="value"
              nameKey="name"
              innerRadius={54}
              outerRadius={78}
              startAngle={90}
              endAngle={-270}
              paddingAngle={2}
              stroke="#121826"
              strokeWidth={2}
              isAnimationActive={false}
            >
              {data.map((slice) => (
                <Cell key={slice.status} fill={STATUS_COLOR[slice.status]} />
              ))}
            </Pie>
          </PieChart>
        </ResponsiveContainer>

        <div className="pointer-events-none absolute inset-0 flex flex-col items-center justify-center">
          <span className="telemetry text-[30px] font-semibold leading-none text-txt">{total}</span>
          <span className="mt-1 text-[11px] uppercase tracking-wider text-txtdim">riders</span>
        </div>
      </div>

      <ul className="mt-3 grid grid-cols-2 gap-1.5">
        {ORDER.map((status) => (
          <li
            key={status}
            className="flex items-center gap-2 rounded-lg border border-line bg-panel2/60 px-2 py-1.5"
          >
            <span
              className="h-2 w-2 shrink-0 rounded-full"
              style={{ background: STATUS_COLOR[status] }}
              aria-hidden="true"
            />
            <span className="truncate text-[11px] text-txtdim">{STATUS_LABEL[status]}</span>
            <span className="telemetry ml-auto text-[12px] font-semibold text-txt">
              {counts[status]}
            </span>
          </li>
        ))}
      </ul>
    </Panel>
  );
}
