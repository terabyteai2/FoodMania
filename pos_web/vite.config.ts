import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

// Served by nginx directly from backend/pos_dist/ at the site root (see
// deploy/nginx/quickbytes.conf) — assets resolve under /.
// Build output goes straight into backend/pos_dist/.
export default defineConfig({
  base: '/',
  plugins: [react()],
  build: {
    outDir: '../backend/pos_dist',
    emptyOutDir: true,
  },
  server: {
    port: 5174,
  },
});
