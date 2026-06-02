import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";

export default defineConfig({
  plugins: [react()],
  base: process.env.VITE_BASE_PATH || "/",
  server: {
    host: true,
    port: 5174,
    proxy: {
      // Only used when VITE_API_BASE_URL is NOT set (relative URL mode).
      // When VITE_API_BASE_URL=https://quickbytes.buzz, these are bypassed.
      "/platform": {
        target: "https://quickbytes.buzz",
        changeOrigin: true,
      },
      "/health": {
        target: "https://quickbytes.buzz",
        changeOrigin: true,
      },
    },
  },
  preview: {
    host: true,
    port: 5174,
  },
});
