import { defineConfig } from 'vite';
import { resolve } from 'node:path';
import { spawn } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { WebSocketServer } from 'ws';

const extraFsAllow = (process.env.READONLY_EDITOR_FS_ALLOW || '')
  .split(',')
  .map((path) => path.trim())
  .filter(Boolean)
  .map((path) => resolve(path));

const lspEndpoint = '/__readonly_editor_lsp';

export default defineConfig({
  root: 'app',
  plugins: [readonlyEditorLspPlugin()],
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

function readonlyEditorLspPlugin() {
  return {
    name: 'readonly-editor-lsp',
    configureServer(server) {
      const wss = new WebSocketServer({ noServer: true });

      server.httpServer?.on('upgrade', (request, socket, head) => {
        const url = new URL(request.url || '/', 'http://127.0.0.1');
        if (url.pathname !== lspEndpoint) {
          return;
        }
        wss.handleUpgrade(request, socket, head, (ws) => {
          wss.emit('connection', ws, request);
        });
      });

      wss.on('connection', (ws) => {
        const connection = new MoonLspConnection(ws, server.config.logger);
        ws.on('message', (data) => connection.receive(data));
        ws.on('close', () => connection.dispose());
        ws.on('error', () => connection.dispose());
      });

      server.httpServer?.on('close', () => {
        wss.close();
      });
    }
  };
}

class MoonLspConnection {
  constructor(ws, logger) {
    this.ws = ws;
    this.logger = logger;
    this.process = null;
    this.stdout = Buffer.alloc(0);
  }

  receive(data) {
    let packet;
    try {
      packet = JSON.parse(data.toString());
    } catch {
      this.sendError('Invalid LSP transport packet.');
      return;
    }
    if (packet.type !== 'message' || typeof packet.message !== 'string') {
      this.sendError('Unsupported LSP transport packet.');
      return;
    }
    this.ensureProcess(packet.message);
    if (!this.process || this.process.stdin.destroyed) {
      this.sendError('moon-lsp is unavailable.');
      return;
    }
    writeJsonRpc(this.process.stdin, packet.message);
  }

  ensureProcess(firstMessage) {
    if (this.process) {
      return;
    }
    const cwd = lspWorkingDirectory(firstMessage);
    const command = process.env.READONLY_EDITOR_LSP_COMMAND || 'moon-lsp';
    const args = lspCommandArgs();
    this.process = spawn(command, args, {
      cwd,
      stdio: ['pipe', 'pipe', 'pipe']
    });
    this.process.stdout.on('data', (chunk) => this.receiveStdout(chunk));
    this.process.stderr.on('data', (chunk) => {
      const message = chunk.toString().trim();
      if (message) {
        this.logger.info(`[readonly-editor:lsp] ${message}`);
      }
    });
    this.process.on('error', (error) => {
      this.sendError(error.message || 'Failed to start moon-lsp.');
    });
    this.process.on('exit', (code, signal) => {
      this.sendError(`moon-lsp exited${signal ? ` by ${signal}` : ` with ${code ?? 0}`}.`);
      this.process = null;
    });
  }

  receiveStdout(chunk) {
    this.stdout = Buffer.concat([this.stdout, chunk]);
    while (true) {
      const headerEnd = this.stdout.indexOf('\r\n\r\n');
      if (headerEnd < 0) {
        return;
      }
      const header = this.stdout.slice(0, headerEnd).toString('ascii');
      const match = /Content-Length:\s*(\d+)/i.exec(header);
      if (!match) {
        this.sendError('moon-lsp emitted an invalid JSON-RPC header.');
        this.stdout = Buffer.alloc(0);
        return;
      }
      const length = Number(match[1]);
      const bodyStart = headerEnd + 4;
      const bodyEnd = bodyStart + length;
      if (this.stdout.length < bodyEnd) {
        return;
      }
      const message = this.stdout.slice(bodyStart, bodyEnd).toString('utf8');
      this.stdout = this.stdout.slice(bodyEnd);
      this.send({ type: 'message', message });
    }
  }

  send(packet) {
    if (this.ws.readyState === 1) {
      this.ws.send(JSON.stringify(packet));
    }
  }

  sendError(message) {
    this.send({ type: 'error', message });
  }

  dispose() {
    if (this.process) {
      this.process.kill();
      this.process = null;
    }
  }
}

function writeJsonRpc(stream, raw) {
  stream.write(`Content-Length: ${Buffer.byteLength(raw, 'utf8')}\r\n\r\n${raw}`);
}

function lspCommandArgs() {
  const raw = process.env.READONLY_EDITOR_LSP_ARGS;
  if (!raw) {
    return ['--stdio'];
  }
  return raw.split(' ').map((part) => part.trim()).filter(Boolean);
}

function lspWorkingDirectory(firstMessage) {
  const configured = process.env.READONLY_EDITOR_LSP_ROOT;
  if (configured) {
    return resolve(configured);
  }
  const rootUri = lspRootUri(firstMessage);
  if (rootUri) {
    try {
      return fileURLToPath(rootUri);
    } catch {
      // Fall through to the repository root.
    }
  }
  return extraFsAllow[0] || resolve('.');
}

function lspRootUri(firstMessage) {
  try {
    const message = JSON.parse(firstMessage);
    const rootUri = message.params?.rootUri;
    return typeof rootUri === 'string' && rootUri.startsWith('file://')
      ? rootUri
      : '';
  } catch {
    return '';
  }
}
