import './style.css';

const demoDocument = {
  uri: 'memory://demo.mbt',
  displayName: 'Demo',
  languageId: 'moonbit',
  version: 1,
  revision: 'demo',
  text: `pub fn main {
  let greeting = "hello"
  // TODO: replace demo provider with LSP-backed provider
  println(greeting)
}
`
};

const root = document.getElementById('app');
let activeSession = null;

installBrowserFileSystemBackend();
installBrowserLspBackend();

globalThis.__readonlyEditorEvent = (name, payload) => {
  let parsed = payload;
  try {
    parsed = JSON.parse(payload);
  } catch {
    // Keep the raw payload visible for debugging malformed events.
  }
  console.info('[readonly-editor]', name, parsed);
};

globalThis.__readonlyEditorMount = (payload) => {
  const model = JSON.parse(payload);
  activeSession?.mount(model);
};

function installBrowserFileSystemBackend() {
  const providers = globalThis.__readonlyEditorFileSystemProviders instanceof Map
    ? globalThis.__readonlyEditorFileSystemProviders
    : new Map();
  globalThis.__readonlyEditorFileSystemProviders = providers;
  globalThis.__readonlyEditorRegisterFileSystemProvider = (scheme, provider) => {
    providers.set(scheme, provider);
  };

  const injectedFileProvider = globalThis.__readonlyEditorFileSystemProvider;
  if (!providers.has('file')) {
    const provider = injectedFileProvider || createBrowserFileSystemProvider();
    providers.set('file', provider);
    globalThis.__readonlyEditorFileSystemProvider = provider;
  }

  globalThis.__readonlyEditorProviderReadFile = async (uri, signal) => {
    const provider = providerForUri(uri);
    if (!provider || typeof provider.readFile !== 'function') {
      return readError('Unavailable', `No filesystem provider is registered for ${uri}.`, uri);
    }

    try {
      const content = await provider.readFile(uri, { signal });
      return await normalizeReadResult(uri, content);
    } catch (error) {
      return readError(error.code || error.name || 'Unavailable', error.message, uri);
    }
  };

  globalThis.__readonlyEditorProviderWatchFile = (uri, listener) => {
    const provider = providerForUri(uri);
    if (!provider || typeof provider.watch !== 'function') {
      return { dispose() {} };
    }
    return provider.watch(uri, { recursive: false, excludes: [] }, (changes) => {
      listener(JSON.stringify(normalizeFileChanges(uri, changes)));
    }) || { dispose() {} };
  };
}

function createBrowserFileSystemProvider() {
  const entries = new Map();
  const watchers = new Set();

  const provider = {
    async openFile() {
      const entry = await chooseLocalFile();
      if (!entry) {
        return '';
      }
      return registerEntry(entry);
    },

    async readFile(uri, { signal } = {}) {
      if (signal?.aborted) {
        throw fileError('AbortError', 'File read was cancelled.');
      }
      const entry = entries.get(uri);
      if (!entry) {
        const localFile = await readViteLocalFile(uri, { signal });
        if (localFile) {
          return localFile;
        }
        throw fileError('FileNotFound', 'Choose a local file before opening this URI.');
      }
      const file = await entryFile(entry);
      if (signal?.aborted) {
        throw fileError('AbortError', 'File read was cancelled.');
      }
      const text = await file.text();
      if (text.includes('\0')) {
        throw fileError('InvalidData', 'Binary files cannot be viewed as source text.');
      }
      return {
        text,
        displayName: entry.displayName || file.name || uriDisplayName(uri),
        languageId: entry.languageId || '',
        revision: entry.revision || `${file.lastModified}:${file.size}`
      };
    },

    watch(uri, _options, listener) {
      const watcher = { uri, listener, revision: '' };
      watchers.add(watcher);
      pollWatcher(watcher);
      const interval = setInterval(() => pollWatcher(watcher), 1000);
      return {
        dispose() {
          clearInterval(interval);
          watchers.delete(watcher);
        }
      };
    },

    registerFile(uri, file, metadata = {}) {
      entries.set(uri, { file, ...metadata });
      notifyWatchers(uri, 'changed');
      return uri;
    }
  };

  function registerEntry(entry) {
    const uri = entry.uri || fileUriForName(entry.displayName || entry.file?.name || 'document');
    entries.set(uri, entry);
    notifyWatchers(uri, 'changed');
    return uri;
  }

  async function pollWatcher(watcher) {
    try {
      const content = await provider.readFile(watcher.uri);
      const revision = content.revision;
      if (watcher.revision && watcher.revision !== revision) {
        watcher.listener([{ uri: watcher.uri, type: 'changed' }]);
      }
      watcher.revision = revision;
    } catch {
      if (watcher.revision !== 'missing') {
        watcher.revision = 'missing';
        watcher.listener([{ uri: watcher.uri, type: 'deleted' }]);
      }
    }
  }

  function notifyWatchers(uri, type) {
    for (const watcher of watchers) {
      if (watcher.uri === uri) {
        watcher.listener([{ uri, type }]);
      }
    }
  }

  return provider;
}

function installBrowserLspBackend() {
  if (globalThis.__readonlyEditorLspTransport) {
    return;
  }

  const listeners = new Set();
  const documents = new Map();
  const messages = [];
  globalThis.__readonlyEditorLspMessages = messages;

  globalThis.__readonlyEditorLspTransport = {
    async request(message, { signal } = {}) {
      messages.push({ type: 'request', message });
      if (signal?.aborted) {
        throw fileError('AbortError', 'LSP request was cancelled.');
      }
      const request = parseLspMessage(message);
      if (request.method === 'initialize') {
        return lspResponse(request.id, {
          capabilities: {
            textDocumentSync: 1,
            hoverProvider: true
          }
        });
      }
      if (request.method === 'textDocument/hover') {
        const uri = request.params?.textDocument?.uri;
        const document = documents.get(uri);
        return lspResponse(request.id, hoverForDocument(document, request.params?.position));
      }
      return lspError(request.id, -32601, `Unsupported LSP request ${request.method || ''}.`);
    },

    async notify(message, { signal } = {}) {
      messages.push({ type: 'notify', message });
      if (signal?.aborted) {
        throw fileError('AbortError', 'LSP notification was cancelled.');
      }
      const notification = parseLspMessage(message);
      if (notification.method === 'textDocument/didOpen') {
        const item = notification.params?.textDocument;
        if (item?.uri) {
          documents.set(item.uri, {
            uri: item.uri,
            languageId: item.languageId || '',
            version: item.version || 1,
            text: item.text || ''
          });
          publishDiagnostics(item.uri);
        }
      } else if (notification.method === 'textDocument/didChange') {
        const item = notification.params?.textDocument;
        const text = notification.params?.contentChanges?.[0]?.text;
        if (item?.uri && typeof text === 'string') {
          const previous = documents.get(item.uri) || { uri: item.uri };
          documents.set(item.uri, {
            ...previous,
            version: item.version || previous.version || 1,
            text
          });
          publishDiagnostics(item.uri);
        }
      } else if (notification.method === 'textDocument/didClose') {
        const uri = notification.params?.textDocument?.uri;
        if (uri) {
          documents.delete(uri);
        }
      }
    },

    subscribe(listener) {
      listeners.add(listener);
      return {
        dispose() {
          listeners.delete(listener);
        }
      };
    }
  };

  function publishDiagnostics(uri) {
    const document = documents.get(uri);
    if (!document) {
      return;
    }
    const diagnostics = diagnosticsForDocument(document);
    const message = {
      jsonrpc: '2.0',
      method: 'textDocument/publishDiagnostics',
      params: {
        uri,
        version: document.version,
        diagnostics
      }
    };
    for (const listener of listeners) {
      listener(JSON.stringify(message));
    }
  }
}

function parseLspMessage(message) {
  try {
    return JSON.parse(message);
  } catch {
    return {};
  }
}

function lspResponse(id, result) {
  return JSON.stringify({
    jsonrpc: '2.0',
    id: id ?? null,
    result
  });
}

function lspError(id, code, message) {
  return JSON.stringify({
    jsonrpc: '2.0',
    id: id ?? null,
    error: { code, message }
  });
}

function diagnosticsForDocument(document) {
  const todo = document.text.indexOf('TODO');
  if (todo < 0) {
    return [];
  }
  return [{
    range: {
      start: offsetToPosition(document.text, todo),
      end: offsetToPosition(document.text, todo + 4)
    },
    severity: 2,
    message: 'Fake LSP diagnostic from readonly transport'
  }];
}

function hoverForDocument(document, position) {
  if (!document || !position) {
    return null;
  }
  const offset = offsetFromPosition(document.text, position);
  const main = document.text.indexOf('main');
  if (main < 0 || offset < main || offset > main + 4) {
    return null;
  }
  return {
    contents: {
      kind: 'plaintext',
      value: 'Fake LSP hover for main'
    },
    range: {
      start: offsetToPosition(document.text, main),
      end: offsetToPosition(document.text, main + 4)
    }
  };
}

function offsetToPosition(text, offset) {
  const safeOffset = Math.max(0, Math.min(offset, text.length));
  let line = 0;
  let character = 0;
  for (let index = 0; index < safeOffset; index += 1) {
    if (text.charCodeAt(index) === 10) {
      line += 1;
      character = 0;
    } else {
      character += 1;
    }
  }
  return { line, character };
}

function offsetFromPosition(text, position) {
  let line = 0;
  let character = 0;
  for (let index = 0; index < text.length; index += 1) {
    if (line === position.line && character === position.character) {
      return index;
    }
    if (text.charCodeAt(index) === 10) {
      line += 1;
      character = 0;
    } else {
      character += 1;
    }
  }
  return text.length;
}

async function chooseLocalFile() {
  if (typeof window.showOpenFilePicker === 'function') {
    const handles = await window.showOpenFilePicker({ multiple: false });
    const handle = handles[0];
    if (!handle) {
      return null;
    }
    const file = await handle.getFile();
    return { handle, displayName: file.name };
  }

  return new Promise((resolve) => {
    const input = document.createElement('input');
    input.type = 'file';
    input.style.display = 'none';
    input.addEventListener('change', () => {
      resolve(input.files?.[0] ? { file: input.files[0], displayName: input.files[0].name } : null);
      input.remove();
    }, { once: true });
    document.body.appendChild(input);
    input.click();
  });
}

async function entryFile(entry) {
  if (entry.handle && typeof entry.handle.getFile === 'function') {
    return entry.handle.getFile();
  }
  if (entry.file) {
    return entry.file;
  }
  throw fileError('FileNotFound', 'The local file is no longer available.');
}

async function normalizeReadResult(uri, content) {
  if (typeof content === 'string') {
    return { ok: true, text: content, displayName: uriDisplayName(uri), languageId: '', revision: String(content.length) };
  }
  if (content instanceof Uint8Array) {
    const text = new TextDecoder('utf-8', { fatal: true }).decode(content);
    return { ok: true, text, displayName: uriDisplayName(uri), languageId: '', revision: String(content.byteLength) };
  }
  if (content instanceof ArrayBuffer) {
    return normalizeReadResult(uri, new Uint8Array(content));
  }
  if (content instanceof Blob) {
    const text = await content.text();
    return { ok: true, text, displayName: content.name || uriDisplayName(uri), languageId: '', revision: `${content.lastModified || 0}:${content.size}` };
  }
  if (content && content.content) {
    const normalized = await normalizeReadResult(uri, content.content);
    return { ...normalized, ...content, ok: true, text: normalized.text };
  }
  if (content && typeof content.text === 'string') {
    return {
      ok: true,
      text: content.text,
      displayName: content.displayName || uriDisplayName(uri),
      languageId: content.languageId || '',
      revision: content.revision || String(content.text.length)
    };
  }
  throw fileError('InvalidData', 'Filesystem provider returned unsupported file content.');
}

function normalizeFileChanges(uri, changes) {
  const list = Array.isArray(changes) ? changes : [{ uri, type: 'changed' }];
  return list.map((change) => ({
    uri: change.uri || uri,
    type: change.type || 'changed'
  }));
}

function readError(code, message, uri) {
  return {
    ok: false,
    code,
    message: message || code,
    uri
  };
}

function fileError(code, message) {
  const error = new Error(message || code);
  error.code = code;
  return error;
}

function providerForUri(uri) {
  return providerForScheme(uriScheme(uri));
}

function providerForScheme(scheme) {
  return globalThis.__readonlyEditorFileSystemProviders?.get(scheme);
}

function uriScheme(uri) {
  const index = uri.indexOf('://');
  return index > 0 ? uri.slice(0, index) : '';
}

function pathToLocalFileUri(path) {
  if (!path) {
    return '';
  }
  return `file://local/${path.replaceAll('\\', '/')}`;
}

function fileUriForName(name) {
  return `file://local/${encodeURIComponent(name || 'document')}`;
}

function uriDisplayName(uri) {
  const path = uri.split('://')[1]?.split('/').slice(1).join('/') || uri;
  const name = path.split('/').filter(Boolean).at(-1) || uri;
  try {
    return decodeURIComponent(name);
  } catch {
    return name;
  }
}

async function readViteLocalFile(uri, { signal } = {}) {
  const path = localPathFromFileUri(uri);
  if (!path) {
    return null;
  }
  const response = await fetch(`/@fs${path}`, { signal });
  if (!response.ok) {
    return null;
  }
  const text = await response.text();
  if (text.includes('\0')) {
    throw fileError('InvalidData', 'Binary files cannot be viewed as source text.');
  }
  return {
    text,
    displayName: path.split('/').filter(Boolean).at(-1) || uriDisplayName(uri),
    languageId: '',
    revision: `${response.headers.get('last-modified') || ''}:${text.length}`
  };
}

function localPathFromFileUri(uri) {
  if (!uri.startsWith('file://local/')) {
    return '';
  }
  const encoded = uri.slice('file://local'.length);
  if (!encoded.startsWith('/')) {
    return '';
  }
  const normalized = encoded.startsWith('//') ? encoded.slice(1) : encoded;
  try {
    return decodeURIComponent(normalized);
  } catch {
    return normalized;
  }
}

class DocumentSession {
  constructor(container) {
    const params = new URL(window.location.href).searchParams;
    this.container = container;
    this.uri = params.get('uri') || pathToLocalFileUri(params.get('path') || '');
    this.document = null;
    this.status = 'loading';
    this.error = null;
    this.watchDisposable = null;
    this.rendererPromise = null;
    this.rendererLoaded = false;
    this.model = null;
  }

  async start() {
    this.renderStatus();
    await this.loadRenderer();

    if (!this.uri) {
      this.applyDocument(demoDocument);
      this.status = 'ready';
      await this.renderCurrentDocument();
      return;
    }

    await this.loadDocument({ watch: true });
  }

  async openFile() {
    const provider = providerForScheme('file');
    if (!provider || typeof provider.openFile !== 'function') {
      this.status = 'error';
      this.error = { message: 'No browser file opener is available.' };
      this.renderStatus();
      return;
    }

    try {
      const uri = await provider.openFile();
      if (!uri) {
        return;
      }
      this.uri = uri;
      this.status = 'loading';
      this.error = null;
      this.model = null;
      this.renderStatus();
      await this.loadDocument({ watch: true });
    } catch (error) {
      this.status = error.code === 'FileNotFound' ? 'missing' : 'error';
      this.error = error;
      this.renderStatus();
    }
  }

  async loadDocument({ watch = false } = {}) {
    try {
      const document = await this.readDocument();
      this.applyDocument(document);
      this.status = 'ready';
      this.error = null;
      await this.renderCurrentDocument();
      if (watch) {
        this.connectEvents();
      }
    } catch (error) {
      this.status = error.code === 'FileNotFound' ? 'missing' : 'error';
      this.error = error;
      this.renderStatus();
    }
  }

  async readDocument() {
    if (typeof globalThis.__readonlyEditorLoadSource !== 'function') {
      throw Object.assign(new Error('MoonBit filesystem loader is not registered.'), {
        code: 'Unavailable',
        status: 503
      });
    }
    const payload = await globalThis.__readonlyEditorLoadSource(this.uri);
    const result = JSON.parse(payload);
    if (!result.ok) {
      const error = new Error(result.error?.message || 'Failed to read source file');
      error.code = result.error?.code || 'Unavailable';
      error.status = result.error?.status || 503;
      error.uri = result.error?.uri;
      error.displayName = result.error?.displayName;
      throw error;
    }
    return result.document;
  }

  connectEvents() {
    this.watchDisposable?.dispose?.();
    this.watchDisposable = null;
    if (!this.uri || typeof globalThis.__readonlyEditorWatchSource !== 'function') {
      return;
    }

    this.watchDisposable = globalThis.__readonlyEditorWatchSource(this.uri, async () => {
      await this.loadDocument();
    });
  }

  applyDocument(document) {
    const previous = this.document;
    const next = { ...document };
    if (previous?.uri === next.uri) {
      next.version = previous.revision === next.revision
        ? previous.version
        : previous.version + 1;
    } else if (!Number.isFinite(next.version) || next.version < 1) {
      next.version = 1;
    }
    this.document = next;
    globalThis.__readonlyEditorDocument = next;
    globalThis.__readonlyEditorSource = next.text;
  }

  async renderCurrentDocument() {
    await this.loadRenderer();
    if (typeof globalThis.__readonlyEditorRender === 'function') {
      await globalThis.__readonlyEditorRender();
    }
  }

  async loadRenderer() {
    if (!this.rendererPromise) {
      this.rendererPromise = import('../../web/generated/editor.mjs').catch((error) => {
        console.error('[readonly-editor]', 'moonbit:load-error', error);
        throw error;
      });
    }
    await this.rendererPromise;
    this.rendererLoaded = true;
  }

  mount(model) {
    this.model = model;
    const scroll = captureScroll(this.container);
    renderEditor(this.container, model, {
      document: this.document,
      status: this.status,
      error: this.error,
      uri: this.uri
    });
    restoreScroll(this.container, scroll);
  }

  renderStatus() {
    const scroll = captureScroll(this.container);
    const model = this.status === 'stale' ? this.model : null;
    renderEditor(this.container, model, {
      document: this.document,
      status: this.status,
      error: this.error,
      uri: this.uri
    });
    restoreScroll(this.container, scroll);
  }
}

activeSession = new DocumentSession(root);
activeSession.start();

function renderEditor(container, model, session) {
  container.innerHTML = '';
  const shell = document.createElement('main');
  shell.className = 'editor-shell';
  shell.dataset.status = session.status;
  shell.dataset.lineCount = model ? String(model.lineCount) : '0';
  if (session.document?.uri) {
    shell.dataset.sourceUri = session.document.uri;
  }

  const topbar = document.createElement('div');
  topbar.className = 'topbar';
  topbar.append(createTitleBlock(model, session), createStatusBlock(model, session));
  shell.appendChild(topbar);

  if (model) {
    shell.append(createCodeViewer(model), createDiagnostics(model));
  } else {
    shell.append(createEmptyViewer(session), createDiagnostics({ diagnostics: [] }));
  }

  container.appendChild(shell);
  console.info('[readonly-editor]', 'dom:mounted', {
    renderedLines: model ? model.lines.length : 0,
    diagnostics: model ? model.diagnostics.length : 0,
    status: session.status
  });
}

function createTitleBlock(model, session) {
  const title = document.createElement('div');
  title.className = 'source-title';

  const name = document.createElement('strong');
  name.textContent = session.document?.displayName || session.uri || 'Readonly MoonBit Editor';

  const meta = document.createElement('span');
  const language = model?.languageId || session.document?.languageId || 'moonbit';
  const version = session.document?.version ? `v${session.document.version}` : 'v-';
  meta.textContent = `${language} ${version}`;

  title.append(name, meta);
  return title;
}

function createStatusBlock(model, session) {
  const status = document.createElement('div');
  status.className = `source-status source-status-${session.status}`;
  const lineCount = model ? `${model.lineCount} lines` : session.statusLabel || '';
  status.textContent = `${statusLabel(session.status)}${lineCount ? ` - ${lineCount}` : ''}`;
  return status;
}

function createCodeViewer(model) {
  const editor = document.createElement('section');
  editor.className = 'code-viewer';
  editor.setAttribute('aria-label', 'Readonly code viewer');

  const lines = document.createElement('div');
  lines.className = 'code-lines';

  for (const line of model.lines) {
    const row = document.createElement('div');
    row.className = 'code-line';
    row.dataset.line = String(line.lineNumber);

    const gutter = document.createElement('div');
    gutter.className = 'gutter';
    gutter.textContent = String(line.lineNumber);

    const code = document.createElement('pre');
    code.className = 'code';

    if (line.spans.length === 0) {
      code.textContent = line.text || ' ';
    } else {
      for (const span of line.spans) {
        const node = document.createElement('span');
        node.className = span.className;
        node.textContent = span.text;
        const hover = hoverForRange(model.hovers, line.offset + span.start, line.offset + span.end);
        if (hover) {
          node.classList.add('has-hover');
          node.title = hover.contents;
          node.dataset.hover = hover.contents;
        }
        node.dataset.start = String(line.offset + span.start);
        node.dataset.end = String(line.offset + span.end);
        node.addEventListener('mouseenter', () => requestHoverForSpan(node, model));
        node.addEventListener('focus', () => requestHoverForSpan(node, model));
        code.appendChild(node);
      }
    }

    row.append(gutter, code);
    lines.appendChild(row);
  }

  editor.appendChild(lines);
  return editor;
}

function createEmptyViewer(session) {
  const editor = document.createElement('section');
  editor.className = 'code-viewer source-empty';
  editor.setAttribute('aria-label', 'Readonly code viewer');

  const message = document.createElement('div');
  message.className = 'source-message';
  message.textContent = sourceMessage(session);
  editor.appendChild(message);
  if (session.status !== 'loading') {
    const actions = document.createElement('div');
    actions.className = 'source-actions';
    const openButton = document.createElement('button');
    openButton.className = 'source-open-button';
    openButton.type = 'button';
    openButton.textContent = 'Open file';
    openButton.addEventListener('click', () => activeSession?.openFile());
    actions.appendChild(openButton);
    editor.appendChild(actions);
  }
  return editor;
}

function createDiagnostics(model) {
  const diagnostics = document.createElement('aside');
  diagnostics.className = 'diagnostics';
  diagnostics.setAttribute('aria-label', 'Diagnostics');
  diagnostics.innerHTML = '<strong>Diagnostics</strong>';
  for (const diagnostic of model.diagnostics) {
    const item = document.createElement('div');
    item.className = 'diagnostic-item';
    item.textContent = `${diagnostic.severity}: ${diagnostic.message}`;
    diagnostics.appendChild(item);
  }
  return diagnostics;
}

function captureScroll(container) {
  const viewer = container.querySelector('.code-viewer');
  return viewer ? { top: viewer.scrollTop, left: viewer.scrollLeft } : null;
}

function restoreScroll(container, scroll) {
  if (!scroll) {
    return;
  }
  const viewer = container.querySelector('.code-viewer');
  if (viewer) {
    viewer.scrollTop = scroll.top;
    viewer.scrollLeft = scroll.left;
  }
}

function sourceMessage(session) {
  if (session.status === 'loading') {
    return 'Loading source...';
  }
  if (session.status === 'missing') {
    return 'Source file is missing.';
  }
  if (session.status === 'error') {
    return session.error?.message || 'Unable to load source.';
  }
  if (session.status === 'stale') {
    return 'Connection lost. Reconnecting...';
  }
  return '';
}

function statusLabel(status) {
  if (status === 'ready') {
    return 'Ready';
  }
  if (status === 'loading') {
    return 'Loading';
  }
  if (status === 'missing') {
    return 'Missing';
  }
  if (status === 'stale') {
    return 'Reconnecting';
  }
  return 'Error';
}

function hoverForRange(hovers, start, end) {
  return hovers.find((hover) => hover.range.start < end && start < hover.range.end);
}

async function requestHoverForSpan(node, model) {
  if (node.dataset.hoverState === 'loading' || !globalThis.__readonlyEditorHover) {
    return;
  }
  const start = Number(node.dataset.start);
  const end = Number(node.dataset.end);
  if (!Number.isFinite(start) || !Number.isFinite(end)) {
    return;
  }

  const cached = hoverForRange(model.hovers || [], start, end);
  if (cached) {
    applyHover(node, cached);
    return;
  }

  node.dataset.hoverState = 'loading';
  const offset = Math.floor((start + end) / 2);
  const requestedVersion = model.version;
  try {
    const payload = await globalThis.__readonlyEditorHover(offset, requestedVersion);
    const result = JSON.parse(payload);
    if (!result.ok || result.version !== activeSession?.document?.version || requestedVersion !== result.version) {
      return;
    }
    const hover = result.hover;
    if (hover && hover.range?.start < end && start < hover.range?.end) {
      applyHover(node, hover);
    }
  } finally {
    delete node.dataset.hoverState;
  }
}

function applyHover(node, hover) {
  node.classList.add('has-hover');
  node.title = hover.contents;
  node.dataset.hover = hover.contents;
}
