import type { Config } from 'tailwindcss';

const config: Config = {
  content: ['./app/**/*.{ts,tsx}', './components/**/*.{ts,tsx}'],
  theme: {
    extend: {
      colors: {
        ink: {
          DEFAULT: '#F7F0E8',
          muted: 'rgba(247,240,232,0.5)',
        },
        surface: {
          DEFAULT: '#0F1E2D',
          alt:     '#0A1520',
        },
        accent: {
          DEFAULT: '#D84727',
          soft:    'rgba(216,71,39,0.15)',
        },
        molt: {
          shell: '#D84727',
          ocean: '#0B4F6C',
          sand:  '#F7F0E8',
          coral: '#F9B5A4',
          kelp:  '#4A7C59',
        },
        bg: {
          deep:    '#0A1520',
          surface: '#0F1E2D',
        },
      },
      fontFamily: {
        sans:     ['var(--font-inter)', 'system-ui', 'sans-serif'],
        fraunces: ['var(--font-fraunces)', 'Georgia', 'serif'],
        mono:     ['Space Mono', 'ui-monospace', 'monospace'],
      },
      borderRadius: {
        card: '22px',
      },
      backdropBlur: {
        xs: '4px',
      },
      boxShadow: {
        glow:       '0 0 32px var(--glow-shell)',
        'glow-sm':  '0 0 12px var(--glow-shell)',
        'glow-ocean': '0 0 24px var(--glow-ocean)',
      },
    },
  },
  plugins: [],
};

export default config;
