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
