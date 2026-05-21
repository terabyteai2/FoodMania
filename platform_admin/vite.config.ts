import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";

export default defineConfig({
  plugins: [react()],
  server: {
    host: true,
    port: 5174,
    proxy: {
      // Only used when VITE_API_BASE_URL is NOT set (relative URL mode).
      // When VITE_API_BASE_URL=http://160.187.130.80, these are bypassed.
      "/platform": {
        target: "http://160.187.130.80",
        changeOrigin: true,
      },
      "/health": {
        target: "http://160.187.130.80",
        changeOrigin: true,
      },
    },
  },
  preview: {
    host: true,
    port: 5174,
  },
});
