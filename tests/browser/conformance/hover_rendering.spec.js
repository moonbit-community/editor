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
  await expect(hover.locator('strong')).toHaveText('bold');
  await expect(hover.locator('code', { hasText: 'inline' })).toBeVisible();
  await expect(hover.locator('pre code')).toHaveCount(0);
  await expect(hover.locator('.monaco-tokenized-source')).toContainText('fn rendered');
  await expect(hover.locator('.monaco-tokenized-source .tok-keyword').first()).toContainText('fn');
  await expect(
    hover.locator('.monaco-tokenized-source .tok-identifier').filter({ hasText: 'rendered' }).first(),
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
  await expect(widget.locator('.monaco-tokenized-source .tok-keyword').first()).toContainText('fn');
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

function readonlyEvents(page) {
  return collectReadonlyEvents(page);
}
