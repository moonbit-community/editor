import { defineConfig } from 'vite';
import { resolve } from 'node:path';

const extraFsAllow = (process.env.READONLY_EDITOR_FS_ALLOW || '')
  .split(',')
  .map((path) => path.trim())
  .filter(Boolean)
  .map((path) => resolve(path));

export default defineConfig({
  root: 'app',
  server: {
    host: '127.0.0.1',
    port: 5173,
    fs: {
      allow: [resolve('.'), ...extraFsAllow]
    }
  },
  build: {
    outDir: '../dist',
    emptyOutDir: true,
    rollupOptions: {
      input: resolve('app/index.html')
    }
  }
});
