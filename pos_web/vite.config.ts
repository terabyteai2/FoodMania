import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';
import { VitePWA } from 'vite-plugin-pwa';

// Served by nginx directly from backend/pos_dist/ at the site root (see
// deploy/nginx/quickbytes.conf) — assets resolve under /.
// Build output goes straight into backend/pos_dist/.
export default defineConfig({
  base: '/',
  plugins: [
    react(),
    VitePWA({
      registerType: 'autoUpdate',
      includeAssets: ['fonts/*.ttf'],
      manifest: {
        name: 'QuickBytes POS',
        short_name: 'QuickBytes',
        description: 'Restaurant billing station',
        theme_color: '#2F4FE0',
        background_color: '#F3F4F6',
        display: 'standalone',
        start_url: '/',
        icons: [
          { src: '/pwa-192x192.png', sizes: '192x192', type: 'image/png' },
          { src: '/pwa-512x512.png', sizes: '512x512', type: 'image/png' },
        ],
      },
      workbox: {
        globPatterns: ['**/*.{js,css,html,ttf,png}'],
        navigateFallback: '/index.html',
      },
    }),
  ],
  build: {
    outDir: '../backend/pos_dist',
    emptyOutDir: true,
  },
  server: {
    port: 5174,
  },
});
