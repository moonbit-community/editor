import { expect, test } from '@playwright/test';
import { promises as fs } from 'node:fs';

test('renders highlighted readonly code and diagnostics', async ({ page }) => {
  await installTestLsp(page);
  const events = [];
  page.on('console', (message) => {
    if (message.text().includes('[readonly-editor]')) {
      events.push(message.text());
    }
  });

  await page.goto('/');
  await expect(page.locator('.editor-shell')).toBeVisible();
  await expect(page.locator('.code-line')).toHaveCount(6);
  await expect(page.locator('.code').first()).toContainText('pub fn main');
  await expect(page.locator('.tok-keyword').first()).toHaveText('pub');
  await expect(page.locator('.tok-string')).toContainText('"hello"');
  await expect(page.locator('.diag-warning')).toContainText('TODO');
  await expect(page.locator('.diagnostic-item')).toContainText('Fake LSP diagnostic');

  const hover = page.locator('.code span', { hasText: 'main' }).first();
  await hover.hover();
  await expect(hover).toHaveAttribute('data-hover', /Fake LSP hover for main/);
  await expect(page.locator('.hover-tooltip')).toContainText('Fake LSP hover for main');
  await hover.dblclick();
  await expect(hover).toHaveAttribute('data-definition-uri', 'memory://demo.mbt');
  await expect(hover).toHaveAttribute('data-definition-target', 'true');

  await page.locator('.code-viewer').evaluate((node) => {
    node.scrollTop = node.scrollHeight;
  });
  await expect(page.locator('.code-line').last()).toBeVisible();
  expect(events.some((event) => event.includes('moonbit:render'))).toBeTruthy();
  expect(events.some((event) => event.includes('dom:mounted'))).toBeTruthy();
  expect(events.some((event) => event.includes('lsp:initialize'))).toBeTruthy();
  expect(events.some((event) => event.includes('lsp:diagnostics'))).toBeTruthy();
  expect(events.some((event) => event.includes('lsp:hover'))).toBeTruthy();
  expect(events.some((event) => event.includes('lsp:definition'))).toBeTruthy();
});

test('keeps code cells content-sized while rows span horizontal scroll width', async ({ page }) => {
  await installTestLsp(page);
  await page.setViewportSize({ width: 432, height: 987 });
  await page.goto('/');
  await expect(page.locator('.code-lines')).toBeVisible();

  const metrics = await page.evaluate(() => {
    const viewer = document.querySelector('.code-viewer');
    const lines = document.querySelector('.code-lines');
    const rows = [...document.querySelectorAll('.code-line')];
    const codes = [...document.querySelectorAll('.code')];

    viewer.scrollLeft = viewer.scrollWidth;

    return {
      codeWidth: codes[1].getBoundingClientRect().width,
      linesRight: Math.round(lines.getBoundingClientRect().right),
      rowRight: Math.round(rows[1].getBoundingClientRect().right),
      viewerRight: Math.round(viewer.getBoundingClientRect().right),
      viewerWidth: viewer.clientWidth,
      viewerScrollLeft: viewer.scrollLeft,
      viewerScrollWidth: viewer.scrollWidth
    };
  });

  expect(metrics.viewerScrollWidth).toBeGreaterThan(metrics.viewerWidth);
  expect(metrics.viewerScrollLeft).toBeGreaterThan(0);
  expect(metrics.codeWidth).toBeLessThan(metrics.viewerWidth);
  expect(metrics.linesRight).toBe(metrics.viewerRight);
  expect(metrics.rowRight).toBe(metrics.viewerRight);
});

test('renders a provider file and refreshes when content changes', async ({ page }) => {
  await installTestLsp(page);
  const fixtureUri = 'file://local/docs/fixtures/demo.mbt';
  const original = await fs.readFile('docs/fixtures/demo.mbt', 'utf8');
  await installTestFileSystem(page, {
    [fixtureUri]: {
      text: original,
      displayName: 'docs/fixtures/demo.mbt',
      revision: 'rev-1'
    }
  });

  await page.goto(`/?uri=${encodeURIComponent(fixtureUri)}`);
  await expect(page.locator('.editor-shell')).toHaveAttribute('data-status', 'ready');
  await expect(page.locator('.editor-shell')).toHaveAttribute('data-source-uri', /docs\/fixtures\/demo\.mbt/);
  await expect(page.locator('.code').first()).toContainText('pub fn main');

  await page.evaluate(({ uri, text }) => {
    globalThis.__readonlyEditorFileSystemProvider.__setFile(uri, {
      text,
      displayName: 'docs/fixtures/demo.mbt',
      revision: 'rev-2'
    });
  }, { uri: fixtureUri, text: original.replace('"hello"', '"synced"') });
  await expect(page.locator('.tok-string')).toContainText('"synced"', { timeout: 5_000 });
  await expect.poll(() => page.evaluate(() => {
    return globalThis.__readonlyEditorLspMessages
      .filter((entry) => entry.type === 'notify' && entry.message.includes('textDocument/didChange'))
      .length;
  })).toBeGreaterThan(0);
});

test('opens readonly remote workspace files through the protocol provider', async ({ page }) => {
  await installTestLsp(page);
  const localUri = 'file://local/docs/fixtures/demo.mbt';
  const remoteUri = 'readonly-remote://workspace/docs/fixtures/demo.mbt';
  const original = await fs.readFile('docs/fixtures/demo.mbt', 'utf8');
  await installTestFileSystem(page, {
    [localUri]: {
      text: original,
      displayName: 'docs/fixtures/demo.mbt',
      revision: 'remote-rev-1'
    }
  });

  await page.goto(`/?uri=${encodeURIComponent(remoteUri)}`);
  await expect(page.locator('.editor-shell')).toHaveAttribute('data-status', 'ready');
  await expect(page.locator('.editor-shell')).toHaveAttribute('data-source-uri', remoteUri);
  await expect(page.locator('.code').first()).toContainText('pub fn main');
  await expect.poll(() => page.evaluate(() => {
    return globalThis.__readonlyEditorRemoteProtocolMessages
      .filter((entry) => entry.type === 'request' || entry.type === 'watch')
      .length;
  })).toBeGreaterThan(0);

  await page.evaluate(({ uri, text }) => {
    globalThis.__readonlyEditorFileSystemProvider.__setFile(uri, {
      text,
      displayName: 'docs/fixtures/demo.mbt',
      revision: 'remote-rev-2'
    });
  }, { uri: localUri, text: original.replace('"hello"', '"remote"') });
  await expect(page.locator('.tok-string')).toContainText('"remote"', { timeout: 5_000 });
});

test('shows missing state and resumes when watched file reappears', async ({ page }) => {
  await installTestLsp(page);
  const fixtureUri = 'file://local/docs/fixtures/auto-sync-temp.mbt';
  await installTestFileSystem(page, {
    [fixtureUri]: {
      text: 'pub fn watched { "one" }\n',
      displayName: 'auto-sync-temp.mbt',
      revision: 'rev-1'
    }
  });

  await page.goto(`/?uri=${encodeURIComponent(fixtureUri)}`);
  await expect(page.locator('.editor-shell')).toHaveAttribute('data-status', 'ready');
  await expect(page.locator('.tok-string')).toContainText('"one"');

  await page.evaluate((uri) => {
    globalThis.__readonlyEditorFileSystemProvider.__deleteFile(uri);
  }, fixtureUri);
  await expect(page.locator('.editor-shell')).toHaveAttribute('data-status', 'missing', { timeout: 5_000 });
  await expect(page.locator('.source-message')).toContainText('Source file is missing.');

  await page.evaluate((uri) => {
    globalThis.__readonlyEditorFileSystemProvider.__setFile(uri, {
      text: 'pub fn watched { "two" }\n',
      displayName: 'auto-sync-temp.mbt',
      revision: 'rev-2'
    });
  }, fixtureUri);
  await expect(page.locator('.editor-shell')).toHaveAttribute('data-status', 'ready', { timeout: 5_000 });
  await expect(page.locator('.tok-string')).toContainText('"two"');
});

async function installTestLsp(page) {
  await page.addInitScript(() => {
    const listeners = new Set();
    const documents = new Map();
    const messages = [];
    globalThis.__readonlyEditorLspMessages = messages;
    globalThis.__readonlyEditorLspTransport = {
      async request(message) {
        messages.push({ type: 'request', message });
        const request = parse(message);
        if (request.method === 'initialize') {
          return response(request.id, {
            capabilities: {
              textDocumentSync: 1,
              hoverProvider: true,
              definitionProvider: true
            }
          });
        }
        if (request.method === 'textDocument/hover') {
          const document = documents.get(request.params?.textDocument?.uri);
          return response(request.id, hoverFor(document, request.params?.position));
        }
        if (request.method === 'textDocument/definition') {
          const document = documents.get(request.params?.textDocument?.uri);
          return response(request.id, definitionFor(document, request.params?.position));
        }
        return JSON.stringify({
          jsonrpc: '2.0',
          id: request.id ?? null,
          error: { code: -32601, message: 'Unsupported test LSP request.' }
        });
      },

      async notify(message) {
        messages.push({ type: 'notify', message });
        const notification = parse(message);
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
          documents.delete(notification.params?.textDocument?.uri);
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
      const todo = document?.text.indexOf('TODO') ?? -1;
      const diagnostics = todo < 0 ? [] : [{
        range: {
          start: offsetToPosition(document.text, todo),
          end: offsetToPosition(document.text, todo + 4)
        },
        severity: 2,
        message: 'Fake LSP diagnostic from readonly transport'
      }];
      const message = JSON.stringify({
        jsonrpc: '2.0',
        method: 'textDocument/publishDiagnostics',
        params: { uri, version: document?.version || 1, diagnostics }
      });
      for (const listener of listeners) {
        listener(message);
      }
    }

    function hoverFor(document, position) {
      const range = identifierRange(document, position);
      if (!range) {
        return null;
      }
      const word = document.text.slice(range.start, range.end);
      return {
        contents: { kind: 'plaintext', value: `Fake LSP hover for ${word}` },
        range: {
          start: offsetToPosition(document.text, range.start),
          end: offsetToPosition(document.text, range.end)
        }
      };
    }

    function definitionFor(document, position) {
      const range = identifierRange(document, position);
      if (!range) {
        return null;
      }
      const word = document.text.slice(range.start, range.end);
      const start = document.text.indexOf(word);
      return {
        uri: document.uri,
        range: {
          start: offsetToPosition(document.text, start),
          end: offsetToPosition(document.text, start + word.length)
        }
      };
    }

    function identifierRange(document, position) {
      if (!document || !position) {
        return null;
      }
      let index = offsetFromPosition(document.text, position);
      if (index === document.text.length || !/[A-Za-z0-9_]/.test(document.text[index])) {
        index -= 1;
      }
      if (index < 0 || !/[A-Za-z0-9_]/.test(document.text[index])) {
        return null;
      }
      let start = index;
      while (start > 0 && /[A-Za-z0-9_]/.test(document.text[start - 1])) {
        start -= 1;
      }
      let end = index + 1;
      while (end < document.text.length && /[A-Za-z0-9_]/.test(document.text[end])) {
        end += 1;
      }
      return { start, end };
    }

    function offsetToPosition(text, offset) {
      let line = 0;
      let character = 0;
      for (let index = 0; index < offset; index += 1) {
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

    function parse(message) {
      try {
        return JSON.parse(message);
      } catch {
        return {};
      }
    }

    function response(id, result) {
      return JSON.stringify({ jsonrpc: '2.0', id: id ?? null, result });
    }
  });
}

async function installTestFileSystem(page, initialFiles) {
  await page.addInitScript((files) => {
    const records = new Map(Object.entries(files));
    const watchers = new Map();

    function listenersFor(uri) {
      let listeners = watchers.get(uri);
      if (!listeners) {
        listeners = new Set();
        watchers.set(uri, listeners);
      }
      return listeners;
    }

    function emit(uri, type) {
      for (const listener of listenersFor(uri)) {
        listener([{ uri, type }]);
      }
    }

    globalThis.__readonlyEditorFileSystemProvider = {
      async readFile(uri) {
        const record = records.get(uri);
        if (!record) {
          const error = new Error('File not found.');
          error.code = 'FileNotFound';
          throw error;
        }
        return record;
      },

      watch(uri, _options, listener) {
        const listeners = listenersFor(uri);
        listeners.add(listener);
        return {
          dispose() {
            listeners.delete(listener);
          }
        };
      },

      __setFile(uri, record) {
        records.set(uri, record);
        emit(uri, 'changed');
      },

      __deleteFile(uri) {
        records.delete(uri);
        emit(uri, 'deleted');
      }
    };
  }, initialFiles);
}
