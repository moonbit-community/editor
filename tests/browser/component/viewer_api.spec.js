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
  } finally {
    reporter.dispose();
  }
});
