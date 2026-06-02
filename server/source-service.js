import { createHash } from 'node:crypto';
import { watch, realpathSync } from 'node:fs';
import { promises as fs } from 'node:fs';
import {
  basename,
  dirname,
  isAbsolute,
  normalize,
  relative,
  resolve,
  sep
} from 'node:path';
import { TextDecoder } from 'node:util';

const decoder = new TextDecoder('utf-8', { fatal: true });

export class SourceServiceError extends Error {
  constructor(code, message, status = 400) {
    super(message);
    this.name = 'SourceServiceError';
    this.code = code;
    this.status = status;
  }
}

export function createSourceService(options = {}) {
  return new SourceService(options);
}

export function sourceServicePlugin(options = {}) {
  const service = createSourceService(options);

  return {
    name: 'readonly-editor-source-service',
    configureServer(server) {
      server.middlewares.use(async (req, res, next) => {
        const url = new URL(req.url || '/', 'http://readonly-editor.local');

        if (url.pathname === '/api/source/read') {
          await handleRead(service, url, res);
          return;
        }

        if (url.pathname === '/api/source/events') {
          await handleEvents(service, url, req, res);
          return;
        }

        next();
      });
    }
  };
}

class SourceService {
  constructor(options = {}) {
    const roots = options.roots && options.roots.length > 0 ? options.roots : [process.cwd()];
    this.roots = roots.map((root) => {
      const absolute = resolve(root);
      return {
        absolute,
        real: realpathSync(absolute)
      };
    });
    this.debounceMs = options.debounceMs ?? 80;
    this.records = new Map();
  }

  async read(rawPath) {
    const resolved = await this.resolvePath(rawPath);
    return this.readResolved(resolved);
  }

  async subscribe(rawPath, listener) {
    const resolved = await this.resolvePath(rawPath, { allowMissing: true });
    const parent = dirname(resolved.absolutePath);
    const parentStat = await statOrError(parent, 'FileNotFound', 'Parent directory was not found', 404);
    if (!parentStat.isDirectory()) {
      throw new SourceServiceError('FileNotFound', 'Parent path is not a directory', 404);
    }

    let disposed = false;
    let timer = null;
    let lastSentRevision = this.records.get(resolved.key)?.revision ?? null;
    let lastSentState = 'ready';

    const sendCurrent = async () => {
      if (disposed) {
        return;
      }
      try {
        const doc = await this.readResolved(resolved);
        if (doc.revision !== lastSentRevision || lastSentState !== 'ready') {
          lastSentRevision = doc.revision;
          lastSentState = 'ready';
          listener({ type: 'document', data: doc });
        }
      } catch (error) {
        const payload = errorPayload(error, resolved);
        if (payload.code === 'FileNotFound') {
          if (lastSentState !== 'missing') {
            lastSentState = 'missing';
            lastSentRevision = null;
            listener({ type: 'missing', data: payload });
          }
          return;
        }
        lastSentState = 'error';
        listener({ type: 'error', data: payload });
      }
    };

    const scheduleRead = () => {
      clearTimeout(timer);
      timer = setTimeout(sendCurrent, this.debounceMs);
    };

    const watcher = watch(parent, { persistent: false }, (_eventType, filename) => {
      if (!filename || String(filename) === basename(resolved.absolutePath)) {
        scheduleRead();
      }
    });

    watcher.on('error', (error) => {
      if (!disposed) {
        listener({ type: 'error', data: errorPayload(error, resolved) });
      }
    });

    return {
      dispose() {
        disposed = true;
        clearTimeout(timer);
        watcher.close();
      }
    };
  }

  async resolvePath(rawPath, options = {}) {
    const relativePath = normalizeRequestPath(rawPath);

    for (const root of this.roots) {
      const absolutePath = resolve(root.absolute, relativePath);
      if (!isInside(absolutePath, root.absolute)) {
        continue;
      }

      if (options.allowMissing) {
        const closest = await closestExistingPath(absolutePath);
        if (!closest || !isInside(closest.real, root.real)) {
          throw new SourceServiceError('OutsideRoot', 'Path escapes the configured source root', 403);
        }
      } else {
        const real = await realpathOrError(absolutePath);
        if (!isInside(real, root.real)) {
          throw new SourceServiceError('OutsideRoot', 'Path escapes the configured source root', 403);
        }
      }

      return {
        root,
        absolutePath,
        relativePath,
        displayName: relativePath,
        uri: `file://server/${encodeURI(relativePath)}`,
        key: `${root.real}:${relativePath}`
      };
    }

    throw new SourceServiceError('OutsideRoot', 'Path escapes the configured source root', 403);
  }

  async readResolved(resolved) {
    const stat = await statOrError(
      resolved.absolutePath,
      'FileNotFound',
      'File was not found',
      404
    );

    if (stat.isDirectory()) {
      throw new SourceServiceError('IsDirectory', 'Directories cannot be viewed as source files');
    }
    if (!stat.isFile()) {
      throw new SourceServiceError('NotFile', 'Only regular files can be viewed as source files');
    }

    const real = await realpathOrError(resolved.absolutePath);
    if (!isInside(real, resolved.root.real)) {
      throw new SourceServiceError('OutsideRoot', 'Path escapes the configured source root', 403);
    }

    const buffer = await fs.readFile(resolved.absolutePath);
    const text = decodeText(buffer);
    const revision = createHash('sha256').update(buffer).digest('hex');
    const previous = this.records.get(resolved.key);
    const version = previous ? (previous.revision === revision ? previous.version : previous.version + 1) : 1;
    const document = {
      uri: resolved.uri,
      displayName: resolved.displayName,
      languageId: inferLanguageId(resolved.relativePath),
      version,
      revision,
      text
    };

    this.records.set(resolved.key, {
      revision,
      version
    });

    return document;
  }
}

async function handleRead(service, url, res) {
  try {
    const document = await service.read(url.searchParams.get('path'));
    sendJson(res, 200, document);
  } catch (error) {
    const payload = errorPayload(error);
    sendJson(res, payload.status, payload);
  }
}

async function handleEvents(service, url, req, res) {
  let subscription;
  let streamOpen = false;
  const pendingEvents = [];
  const emit = (event) => {
    if (streamOpen) {
      writeSse(res, event.type, event.data);
    } else {
      pendingEvents.push(event);
    }
  };

  try {
    subscription = await service.subscribe(url.searchParams.get('path'), emit);
  } catch (error) {
    const payload = errorPayload(error);
    sendJson(res, payload.status, payload);
    return;
  }

  res.writeHead(200, {
    'Content-Type': 'text/event-stream',
    'Cache-Control': 'no-cache, no-store, must-revalidate',
    Connection: 'keep-alive',
    'X-Accel-Buffering': 'no'
  });
  streamOpen = true;
  writeSse(res, 'ready', { ok: true });
  for (const event of pendingEvents) {
    writeSse(res, event.type, event.data);
  }

  req.on('close', () => {
    subscription.dispose();
  });
}

function sendJson(res, status, payload) {
  res.statusCode = status;
  res.setHeader('Content-Type', 'application/json; charset=utf-8');
  res.end(JSON.stringify(payload));
}

function writeSse(res, event, payload) {
  res.write(`event: ${event}\n`);
  res.write(`data: ${JSON.stringify(payload)}\n\n`);
}

function normalizeRequestPath(rawPath) {
  if (typeof rawPath !== 'string' || rawPath.length === 0) {
    throw new SourceServiceError('MissingPath', 'A root-relative path is required');
  }
  if (rawPath.includes('\0')) {
    throw new SourceServiceError('InvalidPath', 'Path cannot contain null bytes');
  }

  const slashPath = rawPath.replaceAll('\\', '/');
  if (
    slashPath.startsWith('/') ||
    slashPath.startsWith('//') ||
    isAbsolute(slashPath) ||
    /^[A-Za-z]:\//.test(slashPath)
  ) {
    throw new SourceServiceError('InvalidPath', 'Path must be relative to the source root');
  }

  const segments = slashPath.split('/');
  if (segments.some((segment) => segment === '..')) {
    throw new SourceServiceError('InvalidPath', 'Path cannot contain parent traversal');
  }

  const normalized = normalize(slashPath).split(sep).join('/');
  if (normalized === '.' || normalized.startsWith('../') || normalized === '..') {
    throw new SourceServiceError('InvalidPath', 'Path must identify a file below the source root');
  }

  return normalized;
}

async function statOrError(filePath, code, message, status) {
  try {
    return await fs.stat(filePath);
  } catch (error) {
    if (error?.code === 'ENOENT') {
      throw new SourceServiceError(code, message, status);
    }
    throw error;
  }
}

async function realpathOrError(filePath) {
  try {
    return await fs.realpath(filePath);
  } catch (error) {
    if (error?.code === 'ENOENT') {
      throw new SourceServiceError('FileNotFound', 'File was not found', 404);
    }
    throw error;
  }
}

async function closestExistingPath(filePath) {
  let current = filePath;

  while (current !== dirname(current)) {
    try {
      return {
        path: current,
        real: await fs.realpath(current)
      };
    } catch (error) {
      if (error?.code !== 'ENOENT') {
        throw error;
      }
      current = dirname(current);
    }
  }

  return null;
}

function isInside(candidate, root) {
  const rel = relative(root, candidate);
  return rel === '' || (!rel.startsWith('..') && !isAbsolute(rel));
}

function decodeText(buffer) {
  if (buffer.includes(0)) {
    throw new SourceServiceError('BinaryFile', 'Binary files cannot be viewed as source text', 415);
  }

  try {
    return decoder.decode(buffer);
  } catch {
    throw new SourceServiceError('InvalidUtf8', 'File is not valid UTF-8 text', 415);
  }
}

function inferLanguageId(relativePath) {
  if (relativePath.endsWith('.mbt') || relativePath.endsWith('.mbt.md')) {
    return 'moonbit';
  }
  if (relativePath.endsWith('.js') || relativePath.endsWith('.mjs')) {
    return 'javascript';
  }
  if (relativePath.endsWith('.ts')) {
    return 'typescript';
  }
  if (relativePath.endsWith('.json')) {
    return 'json';
  }
  if (relativePath.endsWith('.md')) {
    return 'markdown';
  }
  if (relativePath.endsWith('.css')) {
    return 'css';
  }
  if (relativePath.endsWith('.html')) {
    return 'html';
  }
  if (relativePath.endsWith('.txt')) {
    return 'plaintext';
  }
  return 'moonbit';
}

function errorPayload(error, resolved) {
  if (error instanceof SourceServiceError) {
    return {
      code: error.code,
      message: error.message,
      status: error.status,
      uri: resolved?.uri,
      displayName: resolved?.displayName
    };
  }

  return {
    code: error?.code || 'SourceError',
    message: error?.message || 'Unexpected source service error',
    status: 500,
    uri: resolved?.uri,
    displayName: resolved?.displayName
  };
}
