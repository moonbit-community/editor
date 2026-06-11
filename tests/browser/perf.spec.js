import { expect, test } from '@playwright/test';
import { promises as fs } from 'node:fs';

const largeFixture = 'docs/fixtures/project/src/generated_large.mbt';

// Non-failing perf probe: opens the small fixture and a generated ~10k-line
// fixture and logs frame build / DOM patch timings from the structured
// render events. The budget (documented in docs/harness.md) is interaction
// re-renders under ~2ms and scrolling at 60fps; this spec records evidence,
// it does not enforce the budget.
test('logs render timings for small and large documents', async ({ page }) => {
  test.setTimeout(120_000);
  const chunks = [];
  for (let i = 0; i < 2000; i++) {
    chunks.push(`///|\npub fn generated_value_${i}() -> Int {\n  ${i}\n}\n`);
  }
  await fs.writeFile(largeFixture, chunks.join('\n'), 'utf8');

  const events = [];
  page.on('console', (message) => {
    const text = message.text();
    if (text.includes('[readonly-editor]')) {
      events.push(text);
    }
  });

  try {
    await page.goto('/');
    await openWorkspaceFile(page, 'src/main.mbt');
    await expect
      .poll(() => events.some((event) => event.includes('dom:mounted')))
      .toBeTruthy();
    const smallMark = events.length;

    await openWorkspaceFile(page, 'src/generated_large.mbt');
    await expect
      .poll(() => events.slice(smallMark).some((event) => event.includes('dom:mounted')), {
        timeout: 60_000,
      })
      .toBeTruthy();

    const timings = events.filter(
      (event) => event.includes('moonbit:render') || event.includes('dom:mounted'),
    );
    console.log('[perf] render timings (buildMs from moonbit:render, patchMs from dom:mounted):');
    for (const line of timings) {
      console.log('[perf]', line);
    }
  } finally {
    await fs.rm(largeFixture, { force: true });
  }
});

async function openWorkspaceFile(page, workspaceId) {
  await expect(page.locator(`[data-workspace-id="${workspaceId}"]`)).toBeVisible();
  await page.locator(`[data-workspace-id="${workspaceId}"]`).click();
  await expect(page.locator('.editor-shell')).toHaveAttribute('data-status', 'ready', {
    timeout: 60_000,
  });
  await expect(page.locator('.editor-shell')).toHaveAttribute(
    'data-source-uri',
    `readonly-remote://workspace/${workspaceId}`,
  );
}
