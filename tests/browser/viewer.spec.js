import { expect, test } from '@playwright/test';
import { promises as fs } from 'node:fs';

test('renders highlighted readonly code and diagnostics', async ({ page }) => {
  await installTestRemoteProtocol(page);
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
  await expect(page.locator('.diagnostic-item')).toContainText('Fake semantic diagnostic');

  const hover = page.locator('.code span', { hasText: 'main' }).first();
  await hover.hover();
  await expect(hover).toHaveAttribute('data-hover', /Fake semantic hover for main/);
  await expect(page.locator('.hover-tooltip')).toContainText('Fake semantic hover for main');
  await hover.dblclick();
  await expect(hover).toHaveAttribute('data-definition-uri', 'memory://demo.mbt');
  await expect(hover).toHaveAttribute('data-definition-target', 'true');

  await page.locator('.code-viewer').evaluate((node) => {
    node.scrollTop = node.scrollHeight;
  });
  await expect(page.locator('.code-line').last()).toBeVisible();
  expect(events.some((event) => event.includes('moonbit:render'))).toBeTruthy();
  expect(events.some((event) => event.includes('dom:mounted'))).toBeTruthy();
  expect(events.some((event) => event.includes('language:diagnostics'))).toBeTruthy();
  expect(events.some((event) => event.includes('language:hover'))).toBeTruthy();
  expect(events.some((event) => event.includes('language:definition'))).toBeTruthy();
});

test('keeps code cells content-sized while rows span horizontal scroll width', async ({ page }) => {
  await installTestRemoteProtocol(page);
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

test('selects workspace sidebar files without changing the URL', async ({ page }) => {
  await installTestRemoteProtocol(page);
  await page.goto('/');
  const initialHref = await page.evaluate(() => window.location.href);

  await expect(page.locator('[data-workspace-id="docs/fixtures/demo.mbt"]')).toHaveAttribute('aria-selected', 'true');
  await page.locator('[data-workspace-id="docs/fixtures"]').click();
  await expect(page.locator('[data-workspace-id="docs/fixtures"]')).toHaveAttribute('aria-expanded', 'false');
  await expect(page.locator('[data-workspace-id="docs/fixtures/demo.mbt"]')).toHaveCount(0);
  await page.locator('[data-workspace-id="docs/fixtures"]').click();
  await expect(page.locator('[data-workspace-id="docs/fixtures/demo.mbt"]')).toHaveCount(1);

  await page.locator('[data-workspace-id="web/main.mbt"]').click();
  await expect(page.locator('[data-workspace-id="web/main.mbt"]')).toHaveAttribute('aria-selected', 'true');
  await expect(page.locator('[data-workspace-id="docs/fixtures/demo.mbt"]')).toHaveAttribute('aria-selected', 'false');
  expect(await page.evaluate(() => window.location.href)).toBe(initialHref);
});

test('renders a provider file and refreshes when content changes', async ({ page }) => {
  await installTestRemoteProtocol(page);
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
    return globalThis.__readonlyEditorRemoteProtocolMessages
      .filter((entry) => entry.type === 'request' && entry.packet.includes('"type":"Diagnostics"'))
      .length;
  })).toBeGreaterThan(1);
});

test('opens readonly remote workspace files through the protocol provider', async ({ page }) => {
  await installTestRemoteProtocol(page);
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
  await installTestRemoteProtocol(page);
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

async function installTestRemoteProtocol(page) {
  await page.addInitScript(() => {
    const messages = [];
    globalThis.__readonlyEditorRemoteProtocolMessages = messages;
    globalThis.__readonlyEditorRemoteProtocolTransport = {
      async request(packet, { signal } = {}) {
        messages.push({ type: 'request', packet });
        const request = parse(packet);
        if (request.type === 'OpenDocument') {
          return readRemoteDocument(request, { signal, responseType: 'DocumentLoaded' });
        }
        if (request.type === 'Diagnostics') {
          return diagnosticsPacket(request);
        }
        if (request.type === 'Hover') {
          return hoverPacket(request);
        }
        if (request.type === 'Definition') {
          return definitionPacket(request);
        }
        if (request.type === 'DocumentSymbols') {
          return symbolsPacket(request);
        }
        if (request.type === 'SemanticTokens') {
          return semanticTokensPacket(request);
        }
        return protocolErrorPacket(request, 'InvalidPacket', `Unsupported remote protocol request ${request.type || 'unknown'}.`);
      },

      watch(packet, listener) {
        messages.push({ type: 'watch', packet });
        const request = parse(packet);
        if (request.type !== 'WatchDocument') {
          queueMicrotask(() => {
            listener(protocolErrorPacket(request, 'InvalidPacket', 'Unsupported remote watch request.'));
          });
          return { dispose() {} };
        }
        const localUri = remoteUriToLocalFileUri(request.uri);
        return globalThis.__readonlyEditorProviderWatchFile(localUri, async (payload) => {
          const changes = parseFileChanges(payload);
          if (changes.some((change) => change.type === 'deleted')) {
            listener(providerErrorPacket(request, 'FileNotFound', 'Watched source file was deleted.'));
            return;
          }
          listener(await readRemoteDocument(request, { responseType: 'DocumentChanged' }));
        }) || { dispose() {} };
      }
    };

    async function readRemoteDocument(request, { signal, responseType }) {
      const localUri = remoteUriToLocalFileUri(request.uri);
      const result = await globalThis.__readonlyEditorProviderReadFile(localUri, signal);
      if (!result?.ok) {
        return providerErrorPacket(request, result?.code || 'Unavailable', result?.message || 'Unable to read remote source document.');
      }
      return JSON.stringify({
        version: 1,
        type: responseType,
        id: request.id || '',
        document: {
          uri: request.uri,
          displayName: result.displayName || 'demo.mbt',
          languageId: result.languageId || '',
          version: 1,
          revision: result.revision || String(result.text?.length || 0),
          text: result.text || ''
        }
      });
    }

    function diagnosticsPacket(request) {
      const document = documentForRequest(request);
      if (!document) {
        return protocolErrorPacket(request, 'InvalidPacket', 'No matching loaded document is available for diagnostics.');
      }
      const todo = document.text.indexOf('TODO');
      const diagnostics = todo < 0 ? [] : [{
        range: { start: todo, end: todo + 4 },
        severity: 'Warning',
        message: 'Fake semantic diagnostic from remote protocol'
      }];
      return languagePacket(request, 'Diagnostics', document, { diagnostics });
    }

    function hoverPacket(request) {
      const document = documentForRequest(request);
      if (!document) {
        return protocolErrorPacket(request, 'InvalidPacket', 'No matching loaded document is available for hover.');
      }
      const range = identifierRange(document, request.offset);
      const hover = range ? {
        range,
        contents: `Fake semantic hover for ${document.text.slice(range.start, range.end)}`
      } : null;
      return languagePacket(request, 'HoverResult', document, { hover });
    }

    function definitionPacket(request) {
      const document = documentForRequest(request);
      if (!document) {
        return protocolErrorPacket(request, 'InvalidPacket', 'No matching loaded document is available for definition.');
      }
      const range = identifierRange(document, request.offset);
      let location = null;
      if (!range) {
        return languagePacket(request, 'DefinitionResult', document, { location });
      }
      const word = document.text.slice(range.start, range.end);
      const start = document.text.indexOf(word);
      if (start >= 0) {
        location = {
          uri: document.uri,
          range: { start, end: start + word.length }
        };
      }
      return languagePacket(request, 'DefinitionResult', document, { location });
    }

    function symbolsPacket(request) {
      const document = documentForRequest(request);
      if (!document) {
        return protocolErrorPacket(request, 'InvalidPacket', 'No matching loaded document is available for document symbols.');
      }
      const main = document.text.indexOf('main');
      const symbols = main < 0 ? [] : [{ name: 'main', kind: 'function', range: { start: main, end: main + 4 } }];
      return languagePacket(request, 'DocumentSymbolsResult', document, { symbols });
    }

    function semanticTokensPacket(request) {
      const document = documentForRequest(request);
      if (!document) {
        return protocolErrorPacket(request, 'InvalidPacket', 'No matching loaded document is available for semantic tokens.');
      }
      const main = document.text.indexOf('main');
      const semanticTokens = main < 0 ? [] : [{ range: { start: main, end: main + 4 }, tokenType: 'function' }];
      return languagePacket(request, 'SemanticTokensResult', document, { semanticTokens });
    }

    function documentForRequest(request) {
      const document = globalThis.__readonlyEditorDocument;
      if (!document || document.uri !== request.uri) {
        return null;
      }
      if (request.documentVersion > 0 && document.version !== request.documentVersion) {
        return null;
      }
      return document;
    }

    function identifierRange(document, offset) {
      if (!document || !Number.isFinite(offset)) {
        return null;
      }
      let index = Math.max(0, Math.min(document.text.length, Math.trunc(offset)));
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

    function languagePacket(request, type, document, fields) {
      return JSON.stringify({
        version: 1,
        type,
        id: request.id || '',
        uri: request.uri,
        documentVersion: document.version,
        ...fields
      });
    }

    function protocolErrorPacket(request, code, message) {
      return JSON.stringify({
        version: 1,
        type: 'Error',
        id: request.id || '',
        error: { code, message, requestId: request.id || '' }
      });
    }

    function providerErrorPacket(request, providerCode, message) {
      return JSON.stringify({
        version: 1,
        type: 'Error',
        id: request.id || '',
        error: {
          code: 'ProviderError',
          message,
          requestId: request.id || '',
          providerCode
        }
      });
    }

    function remoteUriToLocalFileUri(uri) {
      const prefix = 'readonly-remote://workspace/';
      return typeof uri === 'string' && uri.startsWith(prefix)
        ? `file://local/${uri.slice(prefix.length)}`
        : '';
    }

    function parseFileChanges(payload) {
      try {
        return JSON.parse(payload);
      } catch {
        return [{ type: 'changed' }];
      }
    }

    function parse(message) {
      try {
        return JSON.parse(message);
      } catch {
        return {};
      }
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
