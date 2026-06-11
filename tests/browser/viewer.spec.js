import { expect, test } from '@playwright/test';
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
  await expect(page.locator('.code-viewer')).toContainText('fn main');
  await expect(page.locator('.code-viewer')).toContainText('startup_event');
  await expect(page.locator('.editor-shell')).not.toContainText('readonly provider');

  const mainSymbol = page.locator('.code span', { hasText: 'main' }).first();
  await mainSymbol.hover();
  await mainSymbol.dblclick();

  expect(await events.some('moonbit:render')).toBeTruthy();
  expect(await events.some('dom:mounted')).toBeTruthy();
});

test('renders workspace sidebar entries without changing the URL', async ({ page }) => {
  await page.goto('/');
  const initialHref = await page.evaluate(() => window.location.href);

  await expect(page.locator('[data-workspace-id="moon.mod"]')).toHaveAttribute(
    'data-workspace-kind',
    'file',
  );
  await expect(page.locator('[data-workspace-id="src"]')).toHaveAttribute(
    'aria-expanded',
    'true',
  );
  await expect(page.locator('[data-workspace-id="src/events.mbt"]')).toHaveAttribute(
    'data-workspace-kind',
    'file',
  );
  await expect(page.locator('[data-workspace-id="src/main.mbt"]')).toHaveAttribute(
    'data-workspace-kind',
    'file',
  );

  await page.locator('[data-workspace-id="src"]').click();
  await expect(page.locator('[data-workspace-id="src"]')).toHaveAttribute(
    'aria-expanded',
    'false',
  );
  await expect(page.locator('[data-workspace-id="src/main.mbt"]')).toHaveCount(0);

  await page.locator('[data-workspace-id="src"]').click();
  await page.locator('[data-workspace-id="src/main.mbt"]').click();
  await expect(page.locator('[data-workspace-id="src/main.mbt"]')).toHaveAttribute(
    'aria-selected',
    'true',
  );
  expect(await page.evaluate(() => window.location.href)).toBe(initialHref);
});

test('overlays semantic token classes onto rendered spans', async ({ page }) => {
  await page.goto('/');
  await openWorkspaceFile(page, 'src/errors.mbt');

  const semanticSpan = page.locator('.code span[class*="sem-"]').first();
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

async function openWorkspaceFile(page, workspaceId) {
  await expect(page.locator(`[data-workspace-id="${workspaceId}"]`)).toBeVisible();
  await page.locator(`[data-workspace-id="${workspaceId}"]`).click();
  await expect(page.locator('.editor-shell')).toHaveAttribute('data-status', 'ready');
  await expect(page.locator('.editor-shell')).toHaveAttribute(
    'data-source-uri',
    `readonly-remote://workspace/${workspaceId}`,
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
