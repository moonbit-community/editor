import { promises as fs } from 'node:fs';
import { expect, test } from '../support/test.js';
import {
  collectReadonlyEvents,
  firstVisibleLine,
  lastScrollTop,
  openWorkspaceFile,
} from '../support/app.js';

const largeFixture = 'tests/fixtures/workspace/src/generated_scroll.mbt';

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

test('reveals editor scrollbar for wheel input then fades it after idle', async ({ page }) => {
  const events = collectReadonlyEvents(page);
  await page.goto('/');
  await openWorkspaceFile(page, 'src/generated_scroll.mbt', { waitForActiveReveal: false });

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
  await expect(verticalBar).toHaveClass(/(^|\s)invisible(\s|$).*($|\s)fade(\s|$)/, {
    timeout: 1_500,
  });
});

test('scrolls wheel input through the Monaco delta pipeline at integer positions', async ({ page }) => {
  const events = collectReadonlyEvents(page);
  await page.goto('/');
  await openWorkspaceFile(page, 'src/generated_scroll.mbt', { waitForActiveReveal: false });

  const editorScrollable = page.locator('.monaco-scrollable-element.editor-scrollable');
  await editorScrollable.hover();
  // `StandardWheelEvent` (`deltaY / 40`) x `SCROLL_WHEEL_SENSITIVITY` (50):
  // a 72px pixel-mode wheel delta scrolls 90px, 1.25x, like Monaco.
  await page.mouse.wheel(0, 72);
  await expect.poll(() => lastScrollTop(events), { timeout: 3_000 }).toBe(90);

  // Fractional trackpad deltas round away from zero (2.37 x 1.25 = 2.9625
  // -> 3px) and the scroll truth stays whole pixels (`forceIntegerValues`),
  // so Monaco's shared lines-content rail never sits at a subpixel offset.
  await page.evaluate(() => {
    document.querySelector('.overflow-guard').dispatchEvent(
      new WheelEvent('wheel', { deltaY: 2.37, deltaMode: 0, bubbles: true, cancelable: true }),
    );
  });
  await expect.poll(() => lastScrollTop(events), { timeout: 3_000 }).toBe(93);
  const rail = await page.evaluate(() => {
    const linesContent = document.querySelector('.lines-content');
    return {
      top: linesContent.style.top,
      left: linesContent.style.left,
      viewLinesTransform: document.querySelector('.view-lines').style.transform,
      zonesTransform: document.querySelector('.view-zones').style.transform,
      widgetsTransform: document.querySelector('.contentWidgets').style.transform,
      cursorsTransform: document.querySelector('.cursors-layer').style.transform,
    };
  });
  expect(rail.top).toMatch(/^-?\d+px$/);
  expect(rail.left).toMatch(/^-?\d+px$/);
  expect(rail.viewLinesTransform).toBe('');
  expect(rail.zonesTransform).toBe('');
  expect(rail.widgetsTransform).toBe('');
  expect(rail.cursorsTransform).toBe('');
});

test('moves only the shared rail during a steady retained-row scroll', async ({ page }) => {
  await page.addInitScript(() => {
    globalThis.__moonbitViewerScrollMetrics = {};
  });
  await page.goto('/');
  await openWorkspaceFile(page, 'src/generated_scroll.mbt', { waitForActiveReveal: false });

  // First same-window movement seeds the FastDomNode caches on rows that were
  // initially bound from batched HTML.
  await page.evaluate(() => {
    document.querySelector('.overflow-guard').dispatchEvent(
      new WheelEvent('wheel', { deltaY: 0.2, deltaMode: 0, bubbles: true, cancelable: true }),
    );
  });
  await expect.poll(() => firstVisibleLine(page)).toBe(1);
  await page.waitForTimeout(50);

  await page.evaluate(() => {
    globalThis.__moonbitViewerScrollMetrics = {};
    globalThis.__moonbitViewerRetainedRows = Array.from(
      document.querySelectorAll('.view-line'),
    ).map((node) => ({
      node,
      style: node.getAttribute('style'),
      html: node.innerHTML,
    }));
  });
  await page.evaluate(() => {
    document.querySelector('.overflow-guard').dispatchEvent(
      new WheelEvent('wheel', { deltaY: 0.2, deltaMode: 0, bubbles: true, cancelable: true }),
    );
  });
  await page.waitForTimeout(50);

  const evidence = await page.evaluate(() => {
    const before = globalThis.__moonbitViewerRetainedRows;
    const after = Array.from(document.querySelectorAll('.view-line'));
    return {
      sameRows: before.every((entry, index) => entry.node === after[index]),
      sameStyles: before.every(
        (entry, index) => entry.style === after[index]?.getAttribute('style'),
      ),
      sameHtml: before.every((entry, index) => entry.html === after[index]?.innerHTML),
      metrics: globalThis.__moonbitViewerScrollMetrics,
    };
  });
  expect(evidence.sameRows).toBeTruthy();
  expect(evidence.sameStyles).toBeTruthy();
  expect(evidence.sameHtml).toBeTruthy();
  expect(evidence.metrics.viewLayer ?? {}).toEqual({});
  expect(evidence.metrics.styleWritesByKey).toEqual({
    'lines-content:top': 1,
  });
});

test('drags editor scrollbar thumb after auto reveal', async ({ page }) => {
  await page.goto('/');
  await openWorkspaceFile(page, 'src/generated_scroll.mbt', { waitForActiveReveal: false });

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
