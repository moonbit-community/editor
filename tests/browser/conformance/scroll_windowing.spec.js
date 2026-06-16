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

test('retains visible line nodes and limits html rewrites on decoration updates', async ({
  page,
}) => {
  await page.goto('/');
  await setHoverFixture(page, 'plaintext', 'main hover');
  await openWorkspaceFile(page, 'src/main.mbt');

  await installViewLineHtmlWriteCounter(page);
  const before = await snapshotVisibleLines(page);
  expect(before.length).toBeGreaterThan(1);

  const target = page.locator('.view-line span', { hasText: 'main' }).first();
  await expect(target).toBeVisible();
  await target.hover();
  await expect(page.locator('[data-content-widget="hover"] .monaco-hover')).toContainText(
    'main hover',
    { timeout: 5_000 },
  );

  const after = await snapshotVisibleLines(page);
  const beforeByLine = new Map(before.map((line) => [line.line, line.probe]));
  for (const line of after) {
    expect(line.probe).toBe(beforeByLine.get(line.line));
  }
  const writes = await page.evaluate(() => globalThis.__readonlyEditorLineHtmlWrites ?? 0);
  expect(writes).toBeGreaterThan(0);
  expect(writes).toBeLessThan(before.length);
  await expect(page.locator('.view-line[data-line]').first()).toHaveAttribute('style', /top:/);
  await expect(page.locator('.line-number[data-line]').first()).toBeVisible();
});

async function installViewLineHtmlWriteCounter(page) {
  await page.evaluate(() => {
    if (globalThis.__readonlyEditorLineHtmlCounterInstalled) {
      globalThis.__readonlyEditorLineHtmlWrites = 0;
      return;
    }
    const descriptor =
      Object.getOwnPropertyDescriptor(Element.prototype, 'innerHTML') ??
      Object.getOwnPropertyDescriptor(HTMLElement.prototype, 'innerHTML');
    globalThis.__readonlyEditorLineHtmlWrites = 0;
    Object.defineProperty(Element.prototype, 'innerHTML', {
      configurable: true,
      get() {
        return descriptor.get.call(this);
      },
      set(value) {
        if (this.classList?.contains('view-line')) {
          globalThis.__readonlyEditorLineHtmlWrites += 1;
        }
        return descriptor.set.call(this, value);
      },
    });
    globalThis.__readonlyEditorLineHtmlCounterInstalled = true;
  });
}

async function snapshotVisibleLines(page) {
  return page.evaluate(() =>
    Array.from(document.querySelectorAll('.view-line[data-line]')).map((node, index) => {
      if (!node.dataset.retainProbe) {
        node.dataset.retainProbe = `line-${index}-${node.getAttribute('data-line')}`;
      }
      return {
        line: node.getAttribute('data-line'),
        probe: node.dataset.retainProbe,
      };
    }),
  );
}
