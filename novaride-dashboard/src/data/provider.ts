import type { Alert, AlertStatus, FleetSnapshot, SimulateAction, Unsubscribe } from './types';

/**
 * The single seam between the UI and its data source.
 *
 * Subscription-shaped on purpose: it mirrors Firebase `onValue`, so a
 * FirebaseProvider can drop in by changing one line in `src/data/index.ts`.
 * Screens and components never touch a provider directly — only stores do.
 */
export interface DataProvider {
  subscribeFleet(cb: (snapshot: FleetSnapshot) => void): Unsubscribe;
  subscribeAlerts(cb: (alerts: Alert[]) => void): Unsubscribe;
  updateAlertStatus(id: string, status: AlertStatus): void;
  simulate(action: SimulateAction): void;
}
