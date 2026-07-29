import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

// https://vite.dev/config/
export default defineConfig({
  plugins: [react()],
  build: {
    rollupOptions: {
      output: {
        /* Keep the map and chart libraries out of the app chunk. */
        codeSplitting: {
          groups: [
            { name: 'leaflet', test: /node_modules[\\/](leaflet|react-leaflet|@react-leaflet)/ },
            { name: 'charts', test: /node_modules[\\/](recharts|d3-|victory-)/ },
            { name: 'react', test: /node_modules[\\/](react|react-dom|react-router|scheduler)/ },
          ],
        },
      },
    },
  },
});
