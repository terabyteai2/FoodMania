import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

// Served by FastAPI at https://<host>/pos/* — assets resolve under /pos/.
// Build output goes straight into backend/pos_dist/ (see backend/main.py mounts).
export default defineConfig({
  base: '/pos/',
  plugins: [react()],
  build: {
    outDir: '../backend/pos_dist',
    emptyOutDir: true,
  },
  server: {
    port: 5174,
  },
});
