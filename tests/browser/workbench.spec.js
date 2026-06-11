import { expect, test } from '@playwright/test';

test('defaults to the dark theme and persists the toggled choice', async ({ page }) => {
  await page.goto('/');
  await expect(page.locator('.editor-shell')).toHaveAttribute('data-theme', 'dark');

  await page.locator('[data-action="toggle-theme"]').click();
  await expect(page.locator('.editor-shell')).toHaveAttribute('data-theme', 'light');

  await page.reload();
  await expect(page.locator('.editor-shell')).toHaveAttribute('data-theme', 'light');

  await page.locator('[data-action="toggle-theme"]').click();
  await expect(page.locator('.editor-shell')).toHaveAttribute('data-theme', 'dark');
});

test('renders explorer rows with twisties and file icons', async ({ page }) => {
  await page.goto('/');

  await expect(page.locator('[data-workspace-id="src"] .workspace-twistie svg')).toBeVisible();
  await expect(
    page.locator('[data-workspace-id="src/main.mbt"] .workspace-file-icon svg'),
  ).toBeVisible();
});

