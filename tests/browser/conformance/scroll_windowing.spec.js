import { promises as fs } from 'node:fs';
import { expect, test } from '../support/test.js';
import { openWorkspaceFile, setHoverFixture } from '../support/app.js';

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
  await openWorkspaceFile(page, 'src/generated_scroll.mbt', { waitForActiveReveal: false });

  await expect(page.locator('.editor-shell')).toHaveAttribute('data-line-count', '10000');
  const editorScrollable = page.locator(
    '.overflow-guard > .monaco-scrollable-element.editor-scrollable',
  );
  const verticalBar = editorScrollable.locator('> .scrollbar.vertical');
  await expect(editorScrollable).toBeVisible();
  await expect(editorScrollable.locator('> .lines-content .view-lines')).toHaveCount(1);
  await expect(verticalBar).toHaveClass(/(^|\s)invisible(\s|$)/);
  await expect(verticalBar.locator('> .slider')).toHaveCount(1);
  await expect(page.locator('.view-line[data-line="1"]')).toBeVisible();
  await expect(page.locator('.view-line[data-line="10000"]')).toHaveCount(0);

  await page.evaluate(() => globalThis.__readonlyEditorScrollTo(1e9));

  await expect(page.locator('.view-line[data-line="10000"]')).toBeVisible();
  await expect(page.locator('.view-line[data-line="1"]')).toHaveCount(0);
});

test('resolves hover for the token under the mouse after deterministic scrolling', async ({
  page,
}) => {
  test.setTimeout(120_000);
  await page.goto('/');
  await setHoverFixture(page, 'plaintext', 'generated_value_1999');
  await openWorkspaceFile(page, 'src/generated_scroll.mbt', { waitForActiveReveal: false });

  await page.evaluate(() => globalThis.__readonlyEditorScrollTo(1e9));
  const target = page.locator('.view-line span', { hasText: 'generated_value_1999' }).first();
  await expect(target).toBeVisible();

  await expect(async () => {
    await page.mouse.move(5, 5);
    await target.hover();
    await expect(page.locator('[data-content-widget="hover"] .monaco-hover')).toContainText(
      'generated_value_1999',
      { timeout: 3_000 },
    );
  }).toPass({ timeout: 60_000 });
});
