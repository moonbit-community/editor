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

test('opens and closes the references peek widget', async ({ page }) => {
  await page.goto('/');
  await openMainFixture(page);

  const identifier = page.locator('.definition-candidate').first();
  await identifier.click({ button: 'right' });

  await expect(page.locator('.peek-widget')).toBeVisible();
  await expect(page.locator('.peek-title')).toHaveText('References');

  await page.keyboard.press('Escape');
  await expect(page.locator('.peek-widget')).toHaveCount(0);

  await identifier.click({ button: 'right' });
  await expect(page.locator('.peek-widget')).toBeVisible();
  await page.locator('.peek-close').click();
  await expect(page.locator('.peek-widget')).toHaveCount(0);
});

async function openMainFixture(page) {
  await expect(page.locator('[data-workspace-id="src/main.mbt"]')).toBeVisible();
  await page.locator('[data-workspace-id="src/main.mbt"]').click();
  await expect(page.locator('.editor-shell')).toHaveAttribute('data-status', 'ready');
}
