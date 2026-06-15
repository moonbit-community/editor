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

  // The harness scroll control drives the synthetic scroll model; the
  // request clamps to the bottom of the document.
  await page.evaluate(() => globalThis.__readonlyEditorScrollTo(1e9));

  await expect(page.locator('.view-line[data-line="10000"]')).toBeVisible();
  await expect(page.locator('.view-line[data-line="1"]')).toHaveCount(0);
});

test('reveals editor scrollbar for wheel input then fades it after idle', async ({ page }) => {
  const events = readonlyEvents(page);
  await page.goto('/');
  await openWorkspaceFile(page, 'src/generated_scroll.mbt');

  const editorScrollable = page.locator('.monaco-scrollable-element.editor-scrollable');
  const verticalBar = editorScrollable.locator('> .scrollbar.vertical');
  await expect(verticalBar).toHaveClass(/(^|\s)invisible(\s|$)/);
  await editorScrollable.hover();
  await expect(verticalBar).toHaveClass(/(^|\s)visible(\s|$)/);

  const scrollEventsBefore = events.count('view:scroll');
  await page.mouse.wheel(0, 720);
  await expect
    .poll(() => lastScrollTop(events), { timeout: 3_000 })
    .toBeGreaterThan(0);
  expect(events.count('view:scroll')).toBeGreaterThan(scrollEventsBefore);
  await expect(verticalBar).toHaveClass(/(^|\s)visible(\s|$)/);

  await page.mouse.move(4, 4);
  await expect(verticalBar).toHaveClass(/(^|\s)invisible(\s|$).*($|\s)fade(\s|$)/, { timeout: 1_500 });
});

test('drags editor scrollbar thumb after auto reveal', async ({ page }) => {
  await page.goto('/');
  await openWorkspaceFile(page, 'src/generated_scroll.mbt');

  const editorScrollable = page.locator('.monaco-scrollable-element.editor-scrollable');
  const verticalBar = editorScrollable.locator('> .scrollbar.vertical');
  await expect(verticalBar).toHaveClass(/(^|\s)invisible(\s|$)/);
  await editorScrollable.hover();
  await expect(verticalBar).toHaveClass(/(^|\s)visible(\s|$)/);

  const before = await page.evaluate(() => {
    const slider = document.querySelector(
      '.monaco-scrollable-element.editor-scrollable > .scrollbar.vertical > .slider',
    );
    const rect = slider.getBoundingClientRect();
    return {
      x: rect.left + rect.width / 2,
      y: rect.top + Math.min(20, rect.height / 2),
      top: rect.top,
    };
  });
  await page.mouse.move(before.x, before.y);
  await page.mouse.down();
  await page.mouse.move(before.x, before.y + 160, { steps: 4 });
  await page.mouse.up();

  await expect
    .poll(() => firstVisibleLine(page), { timeout: 3_000 })
    .toBeGreaterThan(1);
  await expect
    .poll(() =>
      page.evaluate(() => {
        const slider = document.querySelector(
          '.monaco-scrollable-element.editor-scrollable > .scrollbar.vertical > .slider',
        );
        return slider.getBoundingClientRect().top;
      }),
    )
    .toBeGreaterThan(before.top);
  await expect(verticalBar.locator('> .slider')).not.toHaveClass(/active/);
});

test('resolves hover for the token under the mouse after scrolling', async ({ page }) => {
  test.setTimeout(120_000);
  await page.goto('/');
  await setHoverFixture(page, 'plaintext', 'generated_value_1999');
  await openWorkspaceFile(page, 'src/generated_scroll.mbt');

  await page.evaluate(() => globalThis.__readonlyEditorScrollTo(1e9));
  const target = page.locator('.view-line span', { hasText: 'generated_value_1999' }).first();
  await expect(target).toBeVisible();

  // Use the deterministic harness hover provider here; this spec verifies
  // scroll-adjusted hit testing and hover placement, not LSP indexing.
  await expect(async () => {
    await page.mouse.move(5, 5);
    await target.hover();
    await expect(page.locator('[data-content-widget="hover"] .monaco-hover')).toContainText(
      'generated_value_1999',
      { timeout: 3_000 },
    );
  }).toPass({ timeout: 60_000 });
});

async function setHoverFixture(page, kind, contents) {
  await expect
    .poll(() => page.evaluate(() => typeof globalThis.__readonlyEditorSetHover), {
      timeout: 5_000,
    })
    .toBe('function');
  await page.evaluate(
    ([fixtureKind, fixtureContents]) =>
      globalThis.__readonlyEditorSetHover(fixtureKind, fixtureContents),
    [kind, contents],
  );
}

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

function readonlyEvents(page) {
  const messages = [];
  page.on('console', (message) => {
    if (message.text().includes('[readonly-editor]')) {
      messages.push(message.text());
    }
  });
  return {
    count(name) {
      return messages.filter((event) => event.includes(name)).length;
    },
    messages,
  };
}

function lastScrollTop(events) {
  const latest = events.messages
    .filter((event) => event.includes('view:scroll'))
    .at(-1);
  if (!latest) {
    return 0;
  }
  const match = latest.match(/"scrollTop":([0-9.]+)/);
  return match ? Number(match[1]) : 0;
}

async function firstVisibleLine(page) {
  return page.evaluate(() => {
    const root = document.querySelector('.moonbit-viewer.readonly-editor');
    const rootRect = root?.getBoundingClientRect();
    if (!rootRect) {
      return 0;
    }
    for (const line of document.querySelectorAll('.view-line[data-line]')) {
      const rect = line.getBoundingClientRect();
      if (rect.bottom >= rootRect.top && rect.top <= rootRect.bottom) {
        return Number(line.getAttribute('data-line') || 0);
      }
    }
    return 0;
  });
}
