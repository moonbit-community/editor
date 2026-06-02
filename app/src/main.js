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

class DocumentSession {
  constructor(container) {
    const params = new URL(window.location.href).searchParams;
    this.container = container;
    this.path = params.get('path') || '';
    this.document = null;
    this.status = 'loading';
    this.error = null;
    this.eventSource = null;
    this.rendererPromise = null;
    this.rendererLoaded = false;
    this.model = null;
  }

  async start() {
    if (!this.path) {
      this.applyDocument(demoDocument);
      this.status = 'ready';
      await this.renderCurrentDocument();
      return;
    }

    this.renderStatus();
    try {
      const document = await this.fetchDocument();
      this.applyDocument(document);
      this.status = 'ready';
      this.error = null;
      await this.renderCurrentDocument();
      this.connectEvents();
    } catch (error) {
      this.status = error.code === 'FileNotFound' ? 'missing' : 'error';
      this.error = error;
      this.renderStatus();
    }
  }

  async fetchDocument() {
    const url = new URL('/api/source/read', window.location.origin);
    url.searchParams.set('path', this.path);
    const response = await fetch(url);
    const payload = await response.json();
    if (!response.ok) {
      const error = new Error(payload.message || 'Failed to read source file');
      error.code = payload.code;
      error.status = payload.status;
      throw error;
    }
    return payload;
  }

  connectEvents() {
    this.eventSource?.close();
    const url = new URL('/api/source/events', window.location.origin);
    url.searchParams.set('path', this.path);
    const source = new EventSource(url);
    this.eventSource = source;

    source.addEventListener('ready', () => {
      if (this.status === 'stale') {
        this.status = 'ready';
        this.error = null;
        this.renderStatus();
      }
    });

    source.addEventListener('document', async (event) => {
      const document = JSON.parse(event.data);
      this.applyDocument(document);
      this.status = 'ready';
      this.error = null;
      await this.renderCurrentDocument();
    });

    source.addEventListener('missing', (event) => {
      this.status = 'missing';
      this.error = JSON.parse(event.data);
      this.renderStatus();
    });

    source.addEventListener('error', (event) => {
      if (event.data) {
        this.status = 'error';
        this.error = JSON.parse(event.data);
        this.renderStatus();
      }
    });

    source.onerror = () => {
      if (this.status === 'ready') {
        this.status = 'stale';
        this.renderStatus();
      }
    };
  }

  applyDocument(document) {
    this.document = document;
    globalThis.__readonlyEditorDocument = document;
    globalThis.__readonlyEditorSource = document.text;
  }

  async renderCurrentDocument() {
    const alreadyLoaded = this.rendererLoaded;
    await this.loadRenderer();
    if (alreadyLoaded && typeof globalThis.__readonlyEditorRender === 'function') {
      globalThis.__readonlyEditorRender();
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
      path: this.path
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
      path: this.path
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
  name.textContent = session.document?.displayName || session.path || 'Readonly MoonBit Editor';

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
