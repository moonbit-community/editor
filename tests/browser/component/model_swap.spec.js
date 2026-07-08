import { expect, test } from '../support/test.js';
import {
  expectMoonBitReportPassed,
  installMoonBitReporter,
} from '../support/moonbit_reporter.js';

// Pins Monaco's per-model View lifecycle (setModel = detach-then-attach,
// codeEditorWidget.ts:506): across a model swap the old view's DOM leaves
// the container and a fresh view appears with data-uri/data-mode-id stamps,
// registered view zones re-mount, text focus carries over, and detaching to
// no model restores the placeholder. The assertions run MoonBit-side in
// tests/browser/moonbit/model_swap.
test('rebuilds the view per model and carries focus across set_model', async ({ page }, testInfo) => {
  const reporter = await installMoonBitReporter(page);
  try {
    await page.goto('/browser-tests/model_swap.html');
    const report = await reporter.waitForReport(testInfo, { suite: 'model_swap' });
    expectMoonBitReportPassed(report, { suite: 'model_swap' });
  } finally {
    reporter.dispose();
  }
});
