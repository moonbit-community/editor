import { defineConfig } from 'vite';
import { resolve } from 'node:path';

export default defineConfig({
  root: 'app',
  server: {
    host: '127.0.0.1',
    port: 5173
  },
  build: {
    outDir: '../dist',
    emptyOutDir: true,
    rollupOptions: {
      input: resolve('app/index.html')
    }
  }
});
