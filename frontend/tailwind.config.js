/** @type {import('tailwindcss').Config} */
export default {
  content: ['./index.html', './src/**/*.{js,jsx}'],
  theme: {
    extend: {
      fontFamily: {
        heading: ['Archivo', 'sans-serif'],
        body: ['Space Grotesk', 'sans-serif'],
        mono: ['JetBrains Mono', 'monospace'],
      },
      colors: {
        brutal: {
          bg: '#FAFAFA',
          text: '#09090B',
          primary: '#18181B',
          muted: '#3F3F46',
          accent: '#2563EB',
        },
      },
      boxShadow: {
        brutal: '4px 4px 0 #18181B',
        'brutal-lg': '8px 8px 0 #18181B',
      },
      borderRadius: {
        none: '0px',
      },
    },
  },
  plugins: [],
}
