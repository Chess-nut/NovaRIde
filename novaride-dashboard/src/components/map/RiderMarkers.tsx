import { Marker, Tooltip } from 'react-leaflet';
import { STATUS_LABEL } from '../../lib/format';
import { riderIcon } from './riderIcon';
import type { MapRider } from './types';

interface RiderMarkersProps {
  riders: MapRider[];
  focusRiderId?: string | null;
  onRiderClick?: (riderId: string) => void;
}

export function RiderMarkers({ riders, focusRiderId, onRiderClick }: RiderMarkersProps) {
  return (
    <>
      {riders.map((rider) => (
        <Marker
          key={rider.id}
          position={[rider.lat, rider.lng]}
          icon={riderIcon(rider.status, rider.id === focusRiderId)}
          zIndexOffset={rider.status === 'emergency' ? 1000 : 0}
          eventHandlers={{ click: () => onRiderClick?.(rider.id) }}
        >
          <Tooltip direction="top" offset={[0, -10]} className="nr-tooltip">
            <span className="block font-semibold">{rider.name}</span>
            <span className="telemetry block text-[11px]">
              {rider.speedKph.toFixed(1)} kph · {STATUS_LABEL[rider.status]}
            </span>
          </Tooltip>
        </Marker>
      ))}
    </>
  );
}
