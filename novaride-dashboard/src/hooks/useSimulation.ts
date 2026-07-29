import { useMemo } from 'react';
import { useAlertStore } from '../store/useAlertStore';

/** Demo-only control surface for the feed. Goes through the store, never the provider. */
export interface SimulationApi {
  crashCountdown: () => void;
  highSpeedCrash: () => void;
  riderCancel: () => void;
  alcoholWarning: () => void;
  reset: () => void;
}

export function useSimulation(): SimulationApi {
  const simulate = useAlertStore((state) => state.simulate);

  return useMemo(
    () => ({
      crashCountdown: () => simulate('crash_countdown'),
      highSpeedCrash: () => simulate('high_speed_crash'),
      riderCancel: () => simulate('rider_cancel'),
      alcoholWarning: () => simulate('alcohol_warning'),
      reset: () => simulate('reset'),
    }),
    [simulate],
  );
}
