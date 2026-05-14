import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

export default defineConfig({
  plugins: [react()],
  // Build output goes to backend/frontend_dist so Python can serve it
  build: {
    outDir: '../../backend/frontend_dist',
    emptyOutDir: true,
  },
  server: {
    port: 3000,
    proxy: {
      '/customer': {
        target: 'http://localhost:8000',
        changeOrigin: true,
      },
    },
  },
})
