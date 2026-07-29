import { useEffect, useRef } from 'react';
import { MapContainer, TileLayer, useMap } from 'react-leaflet';
import 'leaflet/dist/leaflet.css';
import { RiderMarkers } from './RiderMarkers';
import type { MapCanvasProps } from './types';

const CENTER: [number, number] = [14.6, 121.02];
const ZOOM = 12;

/**
 * Flies to a rider when the *selection* changes — never when that rider simply
 * moves, so the operator's own panning is left alone between selections.
 */
function FocusController({ riderId, lat, lng }: { riderId: string; lat: number; lng: number }) {
  const map = useMap();
  const position = useRef({ lat, lng });
  position.current = { lat, lng };

  useEffect(() => {
    const { lat: targetLat, lng: targetLng } = position.current;
    map.flyTo([targetLat, targetLng], Math.max(map.getZoom(), 14), { duration: 0.6 });
  }, [map, riderId]);

  return null;
}

/** Leaflet caches its pixel size — re-measure when the panel resizes. */
function ResizeWatcher() {
  const map = useMap();

  useEffect(() => {
    const container = map.getContainer();
    const observer = new ResizeObserver(() => map.invalidateSize({ animate: false }));
    observer.observe(container);
    return () => observer.disconnect();
  }, [map]);

  return null;
}

/**
 * The only component in the app that touches Leaflet. Everything it needs
 * arrives as plain props, so the Google Maps swap is contained here.
 */
export function MapCanvas({ riders, focusRiderId, onRiderClick }: MapCanvasProps) {
  const focused = riders.find((rider) => rider.id === focusRiderId);

  return (
    <MapContainer
      center={CENTER}
      zoom={ZOOM}
      className="h-full w-full rounded-lg"
      zoomControl
      attributionControl
      preferCanvas
    >
      <TileLayer
        url="https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png"
        attribution='&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a> contributors &copy; <a href="https://carto.com/attributions">CARTO</a>'
        subdomains={['a', 'b', 'c', 'd']}
        maxZoom={19}
      />
      <ResizeWatcher />
      <RiderMarkers riders={riders} focusRiderId={focusRiderId} onRiderClick={onRiderClick} />
      {focused && <FocusController riderId={focused.id} lat={focused.lat} lng={focused.lng} />}
    </MapContainer>
  );
}
