import { expect, test } from '@playwright/test';

test('renders highlighted readonly code and diagnostics', async ({ page }) => {
  const events = [];
  page.on('console', (message) => {
    if (message.text().includes('[readonly-editor]')) {
      events.push(message.text());
    }
  });

  await page.goto('/');
  await expect(page.locator('.editor-shell')).toBeVisible();
  await expect(page.locator('.code-line')).toHaveCount(6);
  await expect(page.locator('.code').first()).toContainText('pub fn main');
  await expect(page.locator('.tok-keyword').first()).toHaveText('pub');
  await expect(page.locator('.tok-string')).toContainText('"hello"');
  await expect(page.locator('.diag-warning')).toContainText('TODO');
  await expect(page.locator('.diagnostic-item')).toContainText('Demo diagnostic');

  const hover = page.locator('[data-hover]').first();
  await expect(hover).toHaveAttribute('data-hover', /entry point symbol/);
  await hover.hover();

  await page.locator('.code-viewer').evaluate((node) => {
    node.scrollTop = node.scrollHeight;
  });
  await expect(page.locator('.code-line').last()).toBeVisible();
  expect(events.some((event) => event.includes('moonbit:render'))).toBeTruthy();
  expect(events.some((event) => event.includes('dom:mounted'))).toBeTruthy();
});

test('keeps code cells content-sized while rows span horizontal scroll width', async ({ page }) => {
  await page.setViewportSize({ width: 432, height: 987 });
  await page.goto('/');
  await expect(page.locator('.code-lines')).toBeVisible();

  const metrics = await page.evaluate(() => {
    const viewer = document.querySelector('.code-viewer');
    const lines = document.querySelector('.code-lines');
    const rows = [...document.querySelectorAll('.code-line')];
    const codes = [...document.querySelectorAll('.code')];

    viewer.scrollLeft = viewer.scrollWidth;

    return {
      codeWidth: codes[1].getBoundingClientRect().width,
      linesRight: Math.round(lines.getBoundingClientRect().right),
      rowRight: Math.round(rows[1].getBoundingClientRect().right),
      viewerRight: Math.round(viewer.getBoundingClientRect().right),
      viewerWidth: viewer.clientWidth,
      viewerScrollLeft: viewer.scrollLeft,
      viewerScrollWidth: viewer.scrollWidth
    };
  });

  expect(metrics.viewerScrollWidth).toBeGreaterThan(metrics.viewerWidth);
  expect(metrics.viewerScrollLeft).toBeGreaterThan(0);
  expect(metrics.codeWidth).toBeLessThan(metrics.viewerWidth);
  expect(metrics.linesRight).toBe(metrics.viewerRight);
  expect(metrics.rowRight).toBe(metrics.viewerRight);
});
