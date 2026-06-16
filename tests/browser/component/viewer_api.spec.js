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
    await expect(wrappedHoverLine.locator('.diag-warning', { hasText: 'keeps' })).toBeVisible({
      timeout: 10_000,
    });
    await wrappedHoverLine.hover();
    await expect(page.locator('[data-content-widget="hover"] .monaco-hover')).toContainText(
      'wrapped component hover',
      { timeout: 3_000 },
    );
  } finally {
    reporter.dispose();
  }
});
