import { promises as fs } from 'node:fs';
import { expect, test } from '../support/test.js';
import {
  collectReadonlyEvents,
  openMainFixture,
  openWorkspaceFile,
  workspaceItem,
} from '../support/app.js';

const mainFixture = 'tests/fixtures/workspace/src/main.mbt';

test('starts from native-served static assets', async ({ page }) => {
  const requestedPaths = [];
  page.on('request', (request) => {
    requestedPaths.push(new URL(request.url()).pathname);
  });

  await page.goto('/');
  await expect(page.locator('.editor-shell')).toBeVisible();

  expect(requestedPaths).toContain('/style.css');
  expect(requestedPaths).toContain('/editor.mjs');
  expect(requestedPaths.some((path) => path.endsWith('/src/bootstrap.js'))).toBeFalsy();
  expect(requestedPaths.some((path) => path.includes('/web/generated/'))).toBeFalsy();
  expect(requestedPaths.some((path) => path.includes('/@vite/'))).toBeFalsy();
});

test('renders fixture workspace through the native protocol', async ({ page }) => {
  const events = collectReadonlyEvents(page);

  await page.goto('/');
  await openMainFixture(page);

  await expect(page.locator('.editor-shell')).toHaveAttribute('data-status', 'ready');
  await expect(page.locator('.editor-shell')).toHaveAttribute(
    'data-source-uri',
    'readonly-remote://workspace/src/main.mbt',
  );
  await expect(page.locator('.monaco-editor.readonly-editor')).toContainText('fn main');
  await expect(page.locator('.monaco-editor.readonly-editor')).toContainText('startup_event');
  await expect(page.locator('.editor-shell')).not.toContainText('readonly provider');

  const mainSymbol = page.locator('.view-line span', { hasText: 'main' }).first();
  await mainSymbol.hover();
  await mainSymbol.dblclick();

  expect(await events.some('moonbit:render')).toBeTruthy();
  expect(await events.some('dom:mounted')).toBeTruthy();
});

test('shows hover through pointer interaction', async ({ page }) => {
  await page.goto('/');
  await openMainFixture(page);

  const symbol = page.locator('.view-line span', { hasText: 'startup_event' }).first();
  await expect(symbol).toBeVisible();
  await expect(async () => {
    await symbol.hover();
    const hover = page.locator('[data-content-widget="hover"] .monaco-hover');
    await expect(hover).toBeVisible({ timeout: 3_000 });
    await expect
      .poll(() => hover.textContent().then((text) => text.trim().length), {
        timeout: 3_000,
      })
      .toBeGreaterThan(0);
  }).toPass({ timeout: 60_000 });
});

test('lazily expands explorer folders and auto-reveals the active file', async ({ page }) => {
  await page.goto('/');
  const initialHref = await page.evaluate(() => window.location.href);

  // Startup auto-opens the first MoonBit file; auto-reveal expands its
  // ancestor chain and selects its row.
  await expect(page.locator('.editor-shell')).toHaveAttribute('data-status', 'ready');
  await expect(page.locator(workspaceItem('moon.mod'))).toHaveAttribute(
    'data-workspace-kind',
    'file',
  );
  await expect(page.locator(workspaceItem('src'))).toHaveAttribute('aria-expanded', 'true');
  await expect(page.locator(workspaceItem('src/main.mbt'))).toHaveAttribute(
    'aria-selected',
    'true',
  );
  await expect(page.locator(workspaceItem('src/errors.mbt'))).toHaveAttribute(
    'data-workspace-kind',
    'file',
  );

  // Collapsing hides children without forgetting the resolved level.
  await page.locator(workspaceItem('src')).click();
  await expect(page.locator(workspaceItem('src'))).toHaveAttribute('aria-expanded', 'false');
  await expect(page.locator(workspaceItem('src/main.mbt'))).toHaveCount(0);

  await page.locator(workspaceItem('src')).click();
  await page.locator(workspaceItem('src/events.mbt')).click();
  await expect(page.locator(workspaceItem('src/events.mbt'))).toHaveAttribute(
    'aria-selected',
    'true',
  );
  await expect(page.locator(workspaceItem('src/main.mbt'))).toHaveAttribute(
    'aria-selected',
    'false',
  );
  expect(await page.evaluate(() => window.location.href)).toBe(initialHref);
});

test('highlights MoonBit sources through the registered language tokenizer', async ({ page }) => {
  await page.goto('/');
  await openWorkspaceFile(page, 'src/errors.mbt');

  // tok-type only comes from the MoonBit lexer (capitalized identifier);
  // the plain fallback never emits it.
  await expect(page.locator('.tok-type', { hasText: 'FixtureError' }).first()).toBeVisible();
  await expect(page.locator('.tok-keyword', { hasText: 'suberror' }).first()).toBeVisible();
});

test('renders unregistered languages with default/plain spans', async ({ page }) => {
  await page.goto('/');
  await openWorkspaceFile(page, 'notes.txt');

  await expect(page.locator('.monaco-editor.readonly-editor')).toContainText('Fixture notes');
  await expect(page.locator('.tok-plain', { hasText: 'value' }).first()).toBeVisible();
  // Registry misses intentionally do not run the generic fallback lexer; the
  // line renderer fills the content with default/plain spans instead.
  await expect(page.locator('.view-line span[class*="tok-identifier"]')).toHaveCount(0);
  await expect(page.locator('.view-line span[class*="tok-type"]')).toHaveCount(0);
  await expect(page.locator('.view-line span[class*="tok-operator"]')).toHaveCount(0);
});

test('overlays semantic token classes onto rendered spans', async ({ page }) => {
  await page.goto('/');
  await openWorkspaceFile(page, 'src/errors.mbt');

  const semanticSpan = page.locator('.view-line span[class*="sem-"]').first();
  // Semantic tokens resolve once per document version; while the language
  // server is still indexing, re-open the document to request them again.
  await expect(async () => {
    if ((await semanticSpan.count()) === 0) {
      await openWorkspaceFile(page, 'src/main.mbt');
      await openWorkspaceFile(page, 'src/errors.mbt');
    }
    await expect(semanticSpan).toBeVisible({ timeout: 2_000 });
  }).toPass({ timeout: 30_000 });
  await expect(semanticSpan).toHaveClass(/tok-/);
});

test('updates and recovers watched fixture files from disk changes', async ({ page }) => {
  const original = await fs.readFile(mainFixture, 'utf8');

  try {
    await page.goto('/');
    await openMainFixture(page);
    await expect(page.locator('.editor-shell')).toHaveAttribute('data-status', 'ready');

    await fs.writeFile(
      mainFixture,
      original.replace('println(event.message)', 'println("synced from disk")'),
      'utf8',
    );
    await expect(page.locator('.tok-string')).toContainText('"synced from disk"', {
      timeout: 7_000,
    });

    await fs.rm(mainFixture);
    await expect(page.locator('.editor-shell')).toHaveAttribute('data-status', 'missing', {
      timeout: 7_000,
    });
    await expect(page.locator('.source-message')).toContainText('Source file is missing.');

    await fs.writeFile(
      mainFixture,
      original.replace('println(event.message)', 'println("restored from disk")'),
      'utf8',
    );
    await expect(page.locator('.editor-shell')).toHaveAttribute('data-status', 'ready', {
      timeout: 7_000,
    });
    await expect(page.locator('.tok-string')).toContainText('"restored from disk"', {
      timeout: 7_000,
    });
  } finally {
    await fs.writeFile(mainFixture, original, 'utf8');
  }
});
