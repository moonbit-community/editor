import './style.css';

const source = `pub fn main {
  let greeting = "hello"
  // TODO: replace demo provider with LSP-backed provider
  println(greeting)
}
`;

const root = document.getElementById('app');

globalThis.__readonlyEditorSource = source;
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
  renderEditor(root, model);
};

import('../../web/generated/editor.mjs').catch((error) => {
  console.error('[readonly-editor]', 'moonbit:load-error', error);
});

function renderEditor(container, model) {
  container.innerHTML = '';
  const shell = document.createElement('main');
  shell.className = 'editor-shell';
  shell.dataset.lineCount = String(model.lineCount);

  const topbar = document.createElement('div');
  topbar.className = 'topbar';
  topbar.innerHTML = `
    <div>
      <strong>Readonly MoonBit Editor</strong>
      <span>${model.languageId}</span>
    </div>
    <div>${model.lineCount} lines</div>
  `;

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

  shell.append(topbar, editor, diagnostics);
  container.appendChild(shell);
  console.info('[readonly-editor]', 'dom:mounted', {
    renderedLines: model.lines.length,
    diagnostics: model.diagnostics.length
  });
}

function hoverForRange(hovers, start, end) {
  return hovers.find((hover) => hover.range.start < end && start < hover.range.end);
}
