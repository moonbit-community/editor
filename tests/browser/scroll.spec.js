import { expect, test } from '@playwright/test';
import { promises as fs } from 'node:fs';

const largeFixture = 'docs/fixtures/project/src/generated_scroll.mbt';

test.beforeAll(async () => {
  const chunks = [];
  for (let i = 0; i < 2000; i++) {
    chunks.push(`///|\npub fn generated_value_${i}() -> Int {\n  ${i}\n}\n`);
  }
  await fs.writeFile(largeFixture, chunks.join('\n'), 'utf8');
});

test.afterAll(async () => {
  await fs.rm(largeFixture, { force: true });
});

test('windows the rendered lines while keeping the document height', async ({ page }) => {
  await page.goto('/');
  await openWorkspaceFile(page, 'src/generated_scroll.mbt');

  await expect(page.locator('.editor-shell')).toHaveAttribute('data-line-count', '10000');
  await expect(page.locator('.view-line[data-line="1"]')).toBeVisible();
  await expect(page.locator('.view-line[data-line="10000"]')).toHaveCount(0);

  // The harness scroll control drives the synthetic scroll model; the
  // request clamps to the bottom of the document.
  await page.evaluate(() => globalThis.__readonlyEditorScrollTo(1e9));

  await expect(page.locator('.view-line[data-line="10000"]')).toBeVisible();
  await expect(page.locator('.view-line[data-line="1"]')).toHaveCount(0);
});

test('resolves hover for the token under the mouse after scrolling', async ({ page }) => {
  test.setTimeout(120_000);
  await page.goto('/');
  await openWorkspaceFile(page, 'src/generated_scroll.mbt');

  await page.evaluate(() => globalThis.__readonlyEditorScrollTo(1e9));
  const target = page.locator('.view-line span', { hasText: 'generated_value_1999' }).first();
  await expect(target).toBeVisible();

  // The language server may still be indexing the generated file on first
  // hover; retry the gesture until the hover widget resolves.
  await expect(async () => {
    await page.mouse.move(5, 5);
    await target.hover();
    await expect(page.locator('.contentWidgets .hover-widget')).toContainText(
      'generated_value_1999',
      { timeout: 3_000 },
    );
  }).toPass({ timeout: 60_000 });
});

function workspaceItem(path) {
  return `[data-workspace-id="readonly-remote://workspace/${path}"]`;
}

async function openWorkspaceFile(page, workspacePath) {
  // Let the startup auto-open settle so its document switch cannot race
  // the one this helper performs.
  await expect(page.locator('.editor-shell')).toHaveAttribute('data-status', 'ready', {
    timeout: 60_000,
  });
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
  await expect(page.locator('.editor-shell')).toHaveAttribute('data-status', 'ready', {
    timeout: 60_000,
  });
  await expect(page.locator('.editor-shell')).toHaveAttribute(
    'data-source-uri',
    `readonly-remote://workspace/${workspacePath}`,
  );
}
