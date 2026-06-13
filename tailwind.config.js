/** @type {import('tailwindcss').Config} */
export default {
  content: [
    './index.html',
    './src/**/*.{vue,ts,tsx}',
  ],
  theme: {
    extend: {
      colors: {
        gold:  '#C9A84C',
        dark:  '#111111',
        dark2: '#1C1C1C',
        dark3: '#242424',
      },
      fontFamily: {
        display: ['"Playfair Display"', 'serif'],
        body:    ['Lato', 'sans-serif'],
      },
    },
  },
  plugins: [],
}
