import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";

// /api/* is proxied to the MangoTime API server (see server/, PORT=8787)
export default defineConfig({
  plugins: [react()],
  server: {
    port: 5173,
    proxy: {
      "/api": {
        target: "http://localhost:8787",
        changeOrigin: true,
        rewrite: (p) => p.replace(/^\/api/, ""),
      },
    },
  },
});
