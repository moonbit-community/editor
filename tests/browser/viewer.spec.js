import { expect, test } from './base.js';
import { promises as fs } from 'node:fs';

const mainFixture = 'docs/fixtures/project/src/main.mbt';

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
  const events = readonlyEvents(page);

  await page.goto('/');
  await openMainFixture(page);

  await expect(page.locator('.editor-shell')).toHaveAttribute('data-status', 'ready');
  await expect(page.locator('.editor-shell')).toHaveAttribute(
    'data-source-uri',
    'readonly-remote://workspace/src/main.mbt',
  );
  await expect(page.locator('.moonbit-viewer.readonly-editor')).toContainText('fn main');
  await expect(page.locator('.moonbit-viewer.readonly-editor')).toContainText('startup_event');
  await expect(page.locator('.editor-shell')).not.toContainText('readonly provider');

  const mainSymbol = page.locator('.view-line span', { hasText: 'main' }).first();
  await mainSymbol.hover();
  await mainSymbol.dblclick();

  expect(await events.some('moonbit:render')).toBeTruthy();
  expect(await events.some('dom:mounted')).toBeTruthy();
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

test('falls back to plain tokenization for unregistered languages', async ({ page }) => {
  await page.goto('/');
  await openWorkspaceFile(page, 'notes.txt');

  await expect(page.locator('.moonbit-viewer.readonly-editor')).toContainText('Fixture notes');
  await expect(page.locator('.tok-identifier', { hasText: 'value' }).first()).toBeVisible();
  // The plain fallback never classifies types or operators, even for the
  // capitalized FixtureError word the MoonBit lexer would tag.
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

async function openMainFixture(page) {
  await openWorkspaceFile(page, 'src/main.mbt');
}

function workspaceItem(path) {
  return `[data-workspace-id="readonly-remote://workspace/${path}"]`;
}

async function openWorkspaceFile(page, workspacePath) {
  // Let the startup auto-open settle so its document switch cannot race
  // the one this helper performs.
  await expect(page.locator('.editor-shell')).toHaveAttribute('data-status', 'ready');
  // Also let the explorer auto-reveal finish: it inserts rows while
  // expanding the active file's ancestors, and a click during that
  // re-render can land on the wrong row.
  const activeUri = await page.locator('.editor-shell').getAttribute('data-source-uri');
  if (activeUri) {
    await expect(page.locator(`[data-workspace-id="${activeUri}"]`)).toHaveAttribute(
      'aria-selected',
      'true',
    );
  }
  const segments = workspacePath.split('/');
  let prefix = '';
  for (const segment of segments.slice(0, -1)) {
    prefix = prefix ? `${prefix}/${segment}` : segment;
    const folder = page.locator(workspaceItem(prefix));
    await expect(folder).toBeVisible();
    if ((await folder.getAttribute('aria-expanded')) !== 'true') {
      await folder.click();
    }
  }
  const item = page.locator(workspaceItem(workspacePath));
  await expect(item).toBeVisible();
  await item.click();
  await expect(page.locator('.editor-shell')).toHaveAttribute('data-status', 'ready');
  await expect(page.locator('.editor-shell')).toHaveAttribute(
    'data-source-uri',
    `readonly-remote://workspace/${workspacePath}`,
  );
}

function readonlyEvents(page) {
  const messages = [];
  page.on('console', (message) => {
    if (message.text().includes('[readonly-editor]')) {
      messages.push(message.text());
    }
  });
  return {
    async some(name) {
      return expect
        .poll(() => messages.some((event) => event.includes(name)), {
          timeout: 5_000,
        })
        .toBeTruthy()
        .then(() => true);
    },
  };
}
