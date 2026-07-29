import { COUNTDOWN_MS } from '../../data/types';

interface CountdownRingProps {
  endsAt: number;
  now: number;
}

const SIZE = 34;
const RADIUS = 14;
const CIRCUMFERENCE = 2 * Math.PI * RADIUS;

/** Live seconds ring for a rider-cancelable crash countdown. */
export function CountdownRing({ endsAt, now }: CountdownRingProps) {
  const remainingMs = Math.max(0, endsAt - now);
  const seconds = Math.ceil(remainingMs / 1000);
  const progress = Math.min(1, Math.max(0, remainingMs / COUNTDOWN_MS));

  return (
    <span
      className="relative inline-flex shrink-0 items-center justify-center"
      style={{ width: SIZE, height: SIZE }}
      role="timer"
      aria-live="off"
      aria-label={`${seconds} seconds until SOS`}
    >
      <svg width={SIZE} height={SIZE} className="-rotate-90" aria-hidden="true">
        <circle cx={SIZE / 2} cy={SIZE / 2} r={RADIUS} fill="none" stroke="#232D42" strokeWidth="2.5" />
        <circle
          cx={SIZE / 2}
          cy={SIZE / 2}
          r={RADIUS}
          fill="none"
          stroke="#F59E0B"
          strokeWidth="2.5"
          strokeLinecap="round"
          strokeDasharray={CIRCUMFERENCE}
          strokeDashoffset={CIRCUMFERENCE * (1 - progress)}
        />
      </svg>
      <span className="telemetry absolute text-[11px] font-semibold text-warn">{seconds}</span>
    </span>
  );
}
