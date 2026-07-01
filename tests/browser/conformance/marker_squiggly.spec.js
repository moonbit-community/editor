import { expect, test } from '../support/test.js';
import { openWorkspaceFile } from '../support/app.js';
import { conformanceStates, hoverPayloads } from '../fixtures/monaco_conformance_payloads.js';

// Monaco's visible diagnostic squiggle is a runtime inline-SVG background
// image (`viewer/browser/view/squiggly_theme.mbt`, porting
// `codeEditorWidget.ts`'s `registerThemingParticipant`), not the static
// `border-bottom` double/dotted rule in `markers.css` (that rule is a
// high-contrast-only fallback and is correctly inert in this viewer's two
// normal themes).

test('diagnostic squiggle is a dynamic SVG background, not a static border', async ({ page }) => {
  await openConformanceFixture(page);
  await showMarkerDiagnostic(page);

  const squiggle = page.locator('.view-lines .squiggly-warning').first();
  await expect(squiggle).toBeVisible();

  const style = await squiggle.evaluate((node) => {
    const computed = getComputedStyle(node);
    return { backgroundImage: computed.backgroundImage, borderBottomStyle: computed.borderBottomStyle };
  });
  expect(style.backgroundImage).toContain('url("data:image/svg+xml,');
  expect(style.borderBottomStyle).toBe('none');
});

test('squiggle stylesheet is re-derived when the theme changes', async ({ page }) => {
  await openConformanceFixture(page);
  await showMarkerDiagnostic(page);

  const styleContent = () =>
    page.locator('style[data-squiggly-theme]').evaluate((node) => node.textContent);

  const darkCss = await styleContent();
  expect(darkCss).toContain('.squiggly-error');
  expect(darkCss).toContain('.squiggly-warning');
  expect(darkCss).toContain('.squiggly-info');
  expect(darkCss).toContain('.squiggly-hint');

  await page.locator('[data-action="toggle-theme"]').click();
  await expect(page.locator('.editor-shell')).toHaveAttribute('data-theme', 'light');

  const lightCss = await styleContent();
  expect(lightCss).not.toBe(darkCss);
  expect(lightCss).toContain('.squiggly-error');
});

async function openConformanceFixture(page) {
  await page.goto('/');
  await expect
    .poll(() => page.evaluate(() => typeof globalThis.__readonlyEditorConformance), {
      timeout: 10_000,
    })
    .toBe('object');
  await page.evaluate((payloads) => {
    globalThis.__readonlyEditorConformance.setPayloads(payloads);
  }, hoverPayloads);
  await openWorkspaceFile(page, 'src/monaco_conformance.mbt');
}

async function showMarkerDiagnostic(page) {
  await page.evaluate((payload) => {
    globalThis.__readonlyEditorConformance.setHoverPayload(payload);
  }, conformanceStates.markerHover.payload);
}
