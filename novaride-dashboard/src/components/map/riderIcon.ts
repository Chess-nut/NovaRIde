import { divIcon } from 'leaflet';
import type { DivIcon } from 'leaflet';
import type { RiderStatus } from '../../data/types';
import { STATUS_COLOR } from '../../lib/format';

/**
 * divIcon dots instead of Leaflet's default PNG markers — the bundled marker
 * images resolve to broken paths under Vite.
 *
 * Icons are cached per (status, focused) pair: handing Leaflet a fresh icon on
 * every 2s tick would rebuild the marker DOM and restart the emergency pulse.
 */
const cache = new Map<string, DivIcon>();

export function riderIcon(status: RiderStatus, focused: boolean): DivIcon {
  const key = `${status}:${focused}`;
  const cached = cache.get(key);
  if (cached) return cached;

  const emergency = status === 'emergency';
  const size = emergency ? 16 : 12;
  const ring = focused ? 'box-shadow:0 0 0 3px rgba(76,141,255,0.55);' : '';
  const className = emergency ? 'nr-dot nr-dot-emergency' : 'nr-dot';

  const icon = divIcon({
    className: '',
    iconSize: [size, size],
    iconAnchor: [size / 2, size / 2],
    html: `<span class="${className}" style="display:block;width:${size}px;height:${size}px;background:${STATUS_COLOR[status]};${ring}"></span>`,
  });

  cache.set(key, icon);
  return icon;
}
