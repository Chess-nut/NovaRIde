import { useEffect } from 'react';
import { useAlertStore } from '../store/useAlertStore';
import { useFleetStore } from '../store/useFleetStore';

/** Opens the fleet + alert subscriptions once, at app mount. */
export function useLiveFeed(): void {
  useEffect(() => {
    const fleet = useFleetStore.getState();
    const alerts = useAlertStore.getState();
    fleet.connect();
    alerts.connect();
    return () => {
      useFleetStore.getState().disconnect();
      useAlertStore.getState().disconnect();
    };
  }, []);
}
