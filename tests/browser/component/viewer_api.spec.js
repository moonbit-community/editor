import { expect, test } from '../support/test.js';
import {
  expectMoonBitReportPassed,
  installMoonBitReporter,
} from '../support/moonbit_reporter.js';

test('runs MoonBit viewer API component checks in the browser', async ({ page }, testInfo) => {
  const reporter = await installMoonBitReporter(page);
  try {
    await page.goto('/browser-tests/component.html');
    await expect(page.locator('.moonbit-viewer.readonly-editor')).toContainText(
      'component_answer',
      { timeout: 10_000 },
    );
    const report = await reporter.waitForReport(testInfo, { suite: 'viewer_api' });
    expectMoonBitReportPassed(report, { suite: 'viewer_api' });
    expect(report.metrics.renderedLines).toBeGreaterThan(0);
    expect(report.metrics.viewLines).toBeGreaterThan(report.metrics.modelLines);
    const wrappedHoverLine = page.locator('.view-line').filter({ hasText: 'keeps' });
    await expect(wrappedHoverLine).toHaveCount(1);
    expect(Number(await wrappedHoverLine.getAttribute('data-line'))).toBeGreaterThan(
      report.metrics.modelLines,
    );
    const inlayHint = page.locator('.view-line .inlay-hint', { hasText: ': T' });
    await expect(inlayHint).toHaveCount(1, { timeout: 10_000 });
    await expect(inlayHint).toHaveClass(/inlay-hint-type/);
    await inlayHint.hover();
    await expect(page.locator('[data-content-widget="hover"] .monaco-hover')).toContainText(
      'component inlay hint',
      { timeout: 3_000 },
    );
    const signatureStart = page.locator('.view-line').filter({ hasText: 'component_answe' });
    const signatureEnd = page.locator('.view-line').filter({ hasText: 'r : T() -> Int' });
    await expect(signatureStart).toHaveCount(1);
    await expect(signatureEnd).toHaveCount(1);
    const startBox = await signatureStart.boundingBox();
    const endBox = await signatureEnd.boundingBox();
    expect(startBox).not.toBeNull();
    expect(endBox).not.toBeNull();
    await page.mouse.move(startBox.x + 1, startBox.y + startBox.height / 2);
    await page.mouse.down();
    await page.mouse.move(endBox.x + endBox.width - 1, endBox.y + endBox.height / 2, {
      steps: 4,
    });
    await page.mouse.up();
    await expect.poll(() => page.locator('.selected-text').count(), { timeout: 2_000 }).toBeGreaterThan(0);
    await page.keyboard.press('ControlOrMeta+C');
    const copiedText = await page.evaluate(() => globalThis.__readonlyEditorCopiedText || '');
    expect(copiedText).toContain('component_answer() -> Int');
    expect(copiedText).not.toContain(': T');
    const copiedHtml = await page.evaluate(() => globalThis.__readonlyEditorCopiedHtml || '');
    expect(copiedHtml).toContain('tok-identifier');
    expect(copiedHtml).not.toContain('inlay-hint');
    await expect(wrappedHoverLine.locator('.diag-warning', { hasText: 'keeps' })).toHaveCount(1, {
      timeout: 10_000,
    });
    const foldMarker = page.locator('.folding-marker[data-line="2"]');
    await expect(foldMarker).toHaveAttribute('data-folded', 'false', { timeout: 10_000 });
    await foldMarker.click();
    await expect(foldMarker).toHaveAttribute('data-folded', 'true');
    await expect(inlayHint).toHaveCount(1);
    await expect(page.locator('.view-line').filter({ hasText: 'keeps' })).toHaveCount(0);
    await expect(page.locator('.diag-warning', { hasText: 'keeps' })).toHaveCount(0);
    await foldMarker.click();
    await expect(foldMarker).toHaveAttribute('data-folded', 'false');
    await expect(inlayHint).toHaveCount(1);
    await expect(wrappedHoverLine).toHaveCount(1);
    await expect(wrappedHoverLine.locator('.diag-warning', { hasText: 'keeps' })).toHaveCount(1);
    const firstLineTop = async () =>
      page.locator('.view-line[data-line="1"]').evaluate((node) => {
        const root = node.closest('.moonbit-viewer');
        return Math.round(node.getBoundingClientRect().top - root.getBoundingClientRect().top);
      });
    const beforeScrollTop = await firstLineTop();
    await page.locator('.overflow-guard').hover();
    await page.mouse.wheel(0, 72);
    await expect.poll(firstLineTop, { timeout: 2_000 }).toBeLessThan(beforeScrollTop - 20);
    await wrappedHoverLine.hover();
    await expect(page.locator('[data-content-widget="hover"] .monaco-hover')).toContainText(
      'wrapped component hover',
      { timeout: 3_000 },
    );
  } finally {
    reporter.dispose();
  }
});
