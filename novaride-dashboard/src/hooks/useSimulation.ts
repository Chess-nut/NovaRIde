/**
 * Demo-only control surface for the mock feed.
 * Phase 0 ships the shell wiring; the mock engine lands in phase 1 and
 * replaces the body of this hook without touching any component.
 */
export interface SimulationApi {
  crashCountdown: () => void;
  highSpeedCrash: () => void;
  riderCancel: () => void;
  alcoholWarning: () => void;
  reset: () => void;
}

const notWired = (action: string) => () => {
  console.warn(`[novaride] simulate "${action}" — mock engine arrives in phase 1`);
};

export function useSimulation(): SimulationApi {
  return {
    crashCountdown: notWired('crash_countdown'),
    highSpeedCrash: notWired('high_speed_crash'),
    riderCancel: notWired('rider_cancel'),
    alcoholWarning: notWired('alcohol_warning'),
    reset: notWired('reset'),
  };
}
