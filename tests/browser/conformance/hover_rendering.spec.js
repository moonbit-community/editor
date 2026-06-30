import { expect, test } from '../support/test.js';
import {
  collectReadonlyEvents,
  hoverMainSymbol,
  openMainFixture,
  setHoverFixture,
} from '../support/app.js';

test('renders markdown hover content as safe HTML', async ({ page }) => {
  await page.goto('/');
  await setHoverFixture(
    page,
    'markdown',
    [
      '**bold** and `inline`',
      '',
      '```moonbit',
      'fn rendered() -> Unit {}',
      '```',
      '',
      '- first',
      '- second',
    ].join('\n'),
  );
  await openMainFixture(page);

  await hoverMainSymbol(page);
  const widget = page.locator('[data-content-widget="hover"]');
  const hover = widget.locator('.monaco-hover');
  const content = widget.locator('.monaco-hover-content');
  await expect(widget).toHaveClass(/monaco-resizable-hover/);
  await expect(hover).toBeVisible();
  await expect(widget.locator('.monaco-scrollable-element')).toBeVisible();
  await expect(content.locator('.hover-row > .hover-row-contents > .markdown-hover > .hover-contents')).toHaveCount(1);
  // Each rendered hover part is its own row, a direct child of the scrollable
  // content, and an independent focus stop (Monaco
  // `_registerListenersOnRenderedParts` sets `tabIndex = 0` on every part).
  await expect(content.locator('> .hover-row')).toHaveCount(1);
  await expect(content.locator('> .hover-row[tabindex="0"]')).toHaveCount(1);
  await expect(hover.locator('strong')).toHaveText('bold');
  await expect(hover.locator('code', { hasText: 'inline' })).toBeVisible();
  await expect(hover.locator('pre code')).toHaveCount(0);
  await expect(hover.locator('.monaco-tokenized-source')).toContainText('fn rendered');
  await expect(hover.locator('.monaco-tokenized-source .mtk3').first()).toContainText('fn');
  await expect(
    hover.locator('.monaco-tokenized-source .mtk4').filter({ hasText: 'rendered' }).first(),
  ).toBeVisible();
  await expect(hover.locator('li')).toHaveCount(2);
  await expect(hover).not.toContainText('**bold**');
});

test('escapes plaintext hover content', async ({ page }) => {
  await page.goto('/');
  await setHoverFixture(
    page,
    'plaintext',
    '<img src=x onerror="globalThis.__hoverUnsafe = 1"> plain',
  );
  await openMainFixture(page);

  await hoverMainSymbol(page);
  const hover = page.locator('[data-content-widget="hover"] .monaco-hover');
  await expect(hover).toContainText('<img src=x');
  await expect(hover.locator('img')).toHaveCount(0);
  expect(await page.evaluate(() => globalThis.__hoverUnsafe)).toBeUndefined();
});

test('sanitizes unsafe markdown hover payloads', async ({ page }) => {
  await page.goto('/');
  await page.evaluate(() => {
    globalThis.__hoverUnsafe = 0;
  });
  await setHoverFixture(
    page,
    'markdown',
    '<img src=x onerror="globalThis.__hoverUnsafe = 1"> [bad](javascript:globalThis.__hoverUnsafe=1)',
  );
  await openMainFixture(page);

  await hoverMainSymbol(page);
  const hover = page.locator('[data-content-widget="hover"] .monaco-hover');
  await expect(hover.locator('img')).toHaveCount(0);
  const hrefs = await hover.locator('a').evaluateAll((links) =>
    links.map((link) => link.getAttribute('href') || ''),
  );
  expect(hrefs.some((href) => href.trim().toLowerCase().startsWith('javascript:'))).toBeFalsy();
  expect(await page.evaluate(() => globalThis.__hoverUnsafe)).toBe(0);
});

test('keeps hover inspectable with pointer, wheel, focus, and Escape', async ({ page }) => {
  const events = readonlyEvents(page);
  await page.goto('/');
  await setHoverFixture(
    page,
    'markdown',
    Array.from({ length: 120 }, (_, index) => `- hover item ${index}`).join('\n'),
  );
  await openMainFixture(page);

  await hoverMainSymbol(page);
  const widget = page.locator('[data-content-widget="hover"]');
  const hover = widget.locator('.monaco-hover');
  const content = widget.locator('.monaco-hover-content');
  const verticalBar = widget.locator('.scrollbar.vertical');
  await expect(hover).toBeVisible();
  await expect(verticalBar).toHaveClass(/(^|\s)invisible(\s|$)/);

  await content.hover();
  await expect(verticalBar).toHaveClass(/(^|\s)visible(\s|$)/);
  await page.waitForTimeout(400);
  await expect(hover).toBeVisible();

  const scrollEventsBefore = events.count('view:scroll');
  await page.mouse.wheel(0, 600);
  await expect
    .poll(() => content.evaluate((node) => node.scrollTop), { timeout: 2_000 })
    .toBeGreaterThan(0);
  await page.waitForTimeout(100);
  expect(events.count('view:scroll')).toBe(scrollEventsBefore);

  await hover.focus();
  await page.keyboard.press('Home');
  await expect
    .poll(() => content.evaluate((node) => node.scrollTop), { timeout: 2_000 })
    .toBe(0);
  await page.keyboard.press('Escape');
  await expect(hover).toHaveCount(0);
});

test('scrolls long fenced code horizontally with Monaco hover scrollbar', async ({ page }) => {
  const events = readonlyEvents(page);
  const longName = `rendered_${'x'.repeat(320)}`;
  await page.goto('/');
  await setHoverFixture(
    page,
    'markdown',
    ['```moonbit', `fn ${longName}() -> Unit {}`, '```'].join('\n'),
  );
  await openMainFixture(page);

  await hoverMainSymbol(page);
  const widget = page.locator('[data-content-widget="hover"]');
  const content = widget.locator('.monaco-hover-content');
  const horizontalBar = widget.locator('.scrollbar.horizontal');
  await expect(widget.locator('.monaco-tokenized-source .mtk3').first()).toContainText('fn');
  await expect(horizontalBar).toHaveClass(/(^|\s)invisible(\s|$)/);

  await content.hover();
  await expect(horizontalBar).toHaveClass(/(^|\s)visible(\s|$)/);
  const scrollEventsBefore = events.count('view:scroll');
  await page.mouse.wheel(600, 0);
  await expect
    .poll(() => content.evaluate((node) => node.scrollLeft), { timeout: 2_000 })
    .toBeGreaterThan(0);
  await page.waitForTimeout(100);
  expect(events.count('view:scroll')).toBe(scrollEventsBefore);
});

test('wraps spaced signature code blocks instead of clipping hover content', async ({ page }) => {
  await page.goto('/');
  await setHoverFixture(
    page,
    'markdown',
    [
      '```moonbit',
      'fn inspect(obj : &Show, content~ : String, loc~ : SourceLoc = _, args_loc~ : ArgsLoc = _) -> Unit raise InspectError',
      '```',
      '',
      'Tests if the string representation of an object matches the expected content.',
    ].join('\n'),
  );
  await openMainFixture(page);

  await hoverMainSymbol(page);
  const widget = page.locator('[data-content-widget="hover"]');
  const content = widget.locator('.monaco-hover-content');
  await expect(widget.locator('.monaco-tokenized-source')).toContainText('InspectError');
  await expect
    .poll(() =>
      content.evaluate((node) => Math.ceil(node.scrollWidth - node.clientWidth)),
    )
    .toBeLessThanOrEqual(1);
  await expect(widget.locator('.scrollbar.horizontal.visible .slider')).toHaveCount(0);
});

test('anchors the hover at the hovered word in exact pixels', async ({ page }) => {
  await page.goto('/');
  await setHoverFixture(page, 'plaintext', 'anchored at the word start');
  await openMainFixture(page);

  await hoverMainSymbol(page);
  const widget = page.locator('[data-content-widget="hover"]');
  await expect(widget.locator('.monaco-hover')).toBeVisible();

  const wordBox = await page
    .locator('.view-line span', { hasText: /^main$/ })
    .first()
    .boundingBox();
  const widgetBox = await widget.boundingBox();
  // The hover anchors at the word's start column. Positioning it with CSS `ch`
  // (which resolves against the wrapper's proportional UI font, not the editor
  // glyph advance) drifts it right by column*(ch - charWidth); exact-pixel
  // placement keeps the widget's left edge on the word.
  expect(Math.abs(widgetBox.x - wordBox.x)).toBeLessThan(3);
});

test('keeps the hover open while the pointer travels onto the widget', async ({ page }) => {
  await page.goto('/');
  await setHoverFixture(page, 'plaintext', 'grace period hover');
  await openMainFixture(page);

  await hoverMainSymbol(page);
  const widget = page.locator('[data-content-widget="hover"]');
  const hover = widget.locator('.monaco-hover');
  await expect(hover).toBeVisible();

  const geom = await page.evaluate(() => {
    const span = [...document.querySelectorAll('.view-line span')].find(
      (node) => node.textContent === 'main',
    );
    const wordRect = span.getBoundingClientRect();
    const root =
      document.querySelector('.readonly-editor') ||
      document.querySelector('.moonbit-viewer');
    const rootRect = root.getBoundingClientRect();
    return { right: wordRect.right, top: wordRect.top, rootRight: rootRect.right };
  });

  // Move into empty content space off the word but still inside the editor: the
  // hover must survive the hidingDelay grace instead of closing immediately
  // (the bug was an instant `cleared()` on any move off the anchored span).
  const emptyX = Math.min(geom.right + 140, geom.rootRight - 30);
  await page.mouse.move(emptyX, geom.top + 7);
  await page.waitForTimeout(150);
  await expect(hover).toBeVisible();

  // Reaching the widget within the grace keeps it open past the delay.
  const widgetBox = await widget.boundingBox();
  await page.mouse.move(widgetBox.x + widgetBox.width / 2, widgetBox.y + widgetBox.height / 2);
  await page.waitForTimeout(450);
  await expect(hover).toBeVisible();

  // Leaving the editor entirely hides it.
  await page.mouse.move(10, 10);
  await expect(widget).toHaveCount(0);
});

function readonlyEvents(page) {
  return collectReadonlyEvents(page);
}
