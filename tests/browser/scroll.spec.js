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
  await expect(page.locator('.code-line[data-line="1"]')).toBeVisible();
  await expect(page.locator('.code-line[data-line="10000"]')).toHaveCount(0);

  await page
    .locator('.code-viewer')
    .evaluate((viewer) => (viewer.scrollTop = viewer.scrollHeight));

  await expect(page.locator('.code-line[data-line="10000"]')).toBeVisible();
  await expect(page.locator('.code-line[data-line="1"]')).toHaveCount(0);
});

test('resolves hover for the token under the mouse after scrolling', async ({ page }) => {
  test.setTimeout(120_000);
  await page.goto('/');
  await openWorkspaceFile(page, 'src/generated_scroll.mbt');

  await page
    .locator('.code-viewer')
    .evaluate((viewer) => (viewer.scrollTop = viewer.scrollHeight));
  const target = page.locator('.code span', { hasText: 'generated_value_1999' }).first();
  await expect(target).toBeVisible();

  // The language server may still be indexing the generated file on first
  // hover; retry the gesture until the hover widget resolves.
  await expect(async () => {
    await page.mouse.move(5, 5);
    await target.hover();
    await expect(page.locator('.hover-widget')).toContainText('generated_value_1999', {
      timeout: 3_000,
    });
  }).toPass({ timeout: 60_000 });
});

async function openWorkspaceFile(page, workspaceId) {
  await expect(page.locator(`[data-workspace-id="${workspaceId}"]`)).toBeVisible();
  await page.locator(`[data-workspace-id="${workspaceId}"]`).click();
  await expect(page.locator('.editor-shell')).toHaveAttribute('data-status', 'ready', {
    timeout: 60_000,
  });
  await expect(page.locator('.editor-shell')).toHaveAttribute(
    'data-source-uri',
    `readonly-remote://workspace/${workspaceId}`,
  );
}
