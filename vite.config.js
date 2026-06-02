import { defineConfig } from 'vite';
import { resolve } from 'node:path';
import { sourceServicePlugin } from './server/source-service.js';

export default defineConfig({
  root: 'app',
  plugins: [
    sourceServicePlugin({
      roots: [process.cwd()]
    })
  ],
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
