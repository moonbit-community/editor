import { expect, test } from '@playwright/test';

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
  const hover = page.locator('.contentWidgets .hover-widget');
  await expect(hover.locator('strong')).toHaveText('bold');
  await expect(hover.locator('code', { hasText: 'inline' })).toBeVisible();
  await expect(hover.locator('pre code')).toContainText('fn rendered');
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
  const hover = page.locator('.contentWidgets .hover-widget');
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
  const hover = page.locator('.contentWidgets .hover-widget');
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
  const hover = page.locator('.contentWidgets .hover-widget');
  const content = hover.locator('.moonbit-viewer-hover-content');
  await expect(hover).toBeVisible();

  await content.hover();
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

async function hoverMainSymbol(page) {
  const target = page.locator('.view-line span', { hasText: 'main' }).first();
  await expect(target).toBeVisible();
  await target.hover();
  await expect(page.locator('.contentWidgets .hover-widget')).toBeVisible({
    timeout: 3_000,
  });
}

async function openMainFixture(page) {
  await openWorkspaceFile(page, 'src/main.mbt');
}

function workspaceItem(path) {
  return `[data-workspace-id="readonly-remote://workspace/${path}"]`;
}

async function openWorkspaceFile(page, workspacePath) {
  await expect(page.locator('.editor-shell')).toHaveAttribute('data-status', 'ready');
  const activeUri = await page.locator('.editor-shell').getAttribute('data-source-uri');
  if (activeUri) {
    await expect(page.locator(`[data-workspace-id="${activeUri}"]`)).toHaveAttribute(
      'aria-selected',
      'true',
    );
  }
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
  await expect(page.locator('.editor-shell')).toHaveAttribute('data-status', 'ready');
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
  };
}
