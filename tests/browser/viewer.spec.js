import { expect, test } from '@playwright/test';
import { promises as fs } from 'node:fs';

test('renders highlighted readonly code and diagnostics', async ({ page }) => {
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

  await page.locator('.code-viewer').evaluate((node) => {
    node.scrollTop = node.scrollHeight;
  });
  await expect(page.locator('.code-line').last()).toBeVisible();
  expect(events.some((event) => event.includes('moonbit:render'))).toBeTruthy();
  expect(events.some((event) => event.includes('dom:mounted'))).toBeTruthy();
  expect(events.some((event) => event.includes('lsp:initialize'))).toBeTruthy();
  expect(events.some((event) => event.includes('lsp:diagnostics'))).toBeTruthy();
  expect(events.some((event) => event.includes('lsp:hover'))).toBeTruthy();
});

test('keeps code cells content-sized while rows span horizontal scroll width', async ({ page }) => {
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

test('shows missing state and resumes when watched file reappears', async ({ page }) => {
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
