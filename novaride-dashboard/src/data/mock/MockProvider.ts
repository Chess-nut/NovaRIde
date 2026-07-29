import type { DataProvider } from '../provider';
import type { Alert, AlertStatus, FleetSnapshot, SimulateAction, Unsubscribe } from '../types';
import { MockEngine } from './engine';

/**
 * DataProvider backed by the simulated helmet fleet.
 * The engine instance is kept on globalThis so Vite HMR reuses it instead of
 * stacking a second ticker on every hot reload.
 */
const GLOBAL_KEY = '__novaride_mock_engine__';

type EngineHost = typeof globalThis & { [GLOBAL_KEY]?: MockEngine };

function getEngine(): MockEngine {
  const host = globalThis as EngineHost;
  if (!host[GLOBAL_KEY]) host[GLOBAL_KEY] = new MockEngine();
  return host[GLOBAL_KEY];
}

if (import.meta.hot) {
  import.meta.hot.dispose(() => {
    const host = globalThis as EngineHost;
    host[GLOBAL_KEY]?.dispose();
    delete host[GLOBAL_KEY];
  });
}

export class MockProvider implements DataProvider {
  private readonly engine = getEngine();

  subscribeFleet(cb: (snapshot: FleetSnapshot) => void): Unsubscribe {
    return this.engine.subscribeFleet(cb);
  }

  subscribeAlerts(cb: (alerts: Alert[]) => void): Unsubscribe {
    return this.engine.subscribeAlerts(cb);
  }

  updateAlertStatus(id: string, status: AlertStatus): void {
    this.engine.updateAlertStatus(id, status);
  }

  simulate(action: SimulateAction): void {
    this.engine.simulate(action);
  }
}
