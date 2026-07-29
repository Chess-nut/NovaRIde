/** @type {import('tailwindcss').Config} */
export default {
  content: ['./index.html', './src/**/*.{js,ts,jsx,tsx}'],
  theme: {
    extend: {
      colors: {
        ink: '#0B0F17',
        panel: '#121826',
        panel2: '#182136',
        line: '#232D42',
        txt: '#E6EAF2',
        txtdim: '#8A94A8',
        accent: '#4C8DFF',
        ok: '#34D399',
        idle: '#9CA3AF',
        warn: '#F59E0B',
        danger: '#F43F5E',
        offline: '#475569',
      },
      fontFamily: {
        sans: ['Inter', 'system-ui', 'sans-serif'],
        mono: ['"IBM Plex Mono"', 'ui-monospace', 'monospace'],
      },
      keyframes: {
        'ring-pulse': {
          '0%, 100%': { boxShadow: '0 0 0 1px rgba(244,63,94,0.9), 0 0 0 0 rgba(244,63,94,0.30)' },
          '50%': { boxShadow: '0 0 0 1px rgba(244,63,94,0.9), 0 0 0 10px rgba(244,63,94,0)' },
        },
        'row-pulse': {
          '0%, 100%': { backgroundColor: 'rgba(244,63,94,0.07)' },
          '50%': { backgroundColor: 'rgba(244,63,94,0.17)' },
        },
        'slide-fade': {
          from: { opacity: '0', transform: 'translateY(-10px)' },
          to: { opacity: '1', transform: 'translateY(0)' },
        },
      },
      animation: {
        'ring-pulse': 'ring-pulse 2s ease-in-out infinite',
        'row-pulse': 'row-pulse 2.4s ease-in-out infinite',
        'slide-fade': 'slide-fade 200ms ease-out',
      },
    },
  },
  plugins: [],
};
