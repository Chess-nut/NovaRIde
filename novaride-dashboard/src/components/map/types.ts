import type { RiderStatus } from '../../data/types';

/**
 * Plain props the map understands. Screens pass these — they never pass
 * Leaflet objects, so swapping to the Google Maps JS API touches only
 * `src/components/map`.
 */
export interface MapRider {
  id: string;
  name: string;
  lat: number;
  lng: number;
  speedKph: number;
  status: RiderStatus;
}

export interface MapCanvasProps {
  riders: MapRider[];
  focusRiderId?: string | null;
  onRiderClick?: (riderId: string) => void;
}
