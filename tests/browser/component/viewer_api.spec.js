import { expect, test } from '../support/test.js';
import {
  expectMoonBitReportPassed,
  installMoonBitReporter,
} from '../support/moonbit_reporter.js';

test('runs MoonBit viewer API component checks in the browser', async ({ page }, testInfo) => {
  const reporter = await installMoonBitReporter(page);
  try {
    await page.goto('/browser-tests/component.html');
    await expect(page.locator('.monaco-editor.readonly-editor')).toContainText(
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
    // wrappingIndent=Same (the default): the wrapped continuation of the
    // two-space-indented line is itself indented, so its first visible glyph
    // sits to the right of a flush-left line's first glyph (the DOM left offset
    // proves the indent renders, not just that the content carries spaces).
    const firstGlyphLeft = (locator) =>
      locator.first().evaluate((node) => {
        const text = node.textContent || '';
        const idx = text.search(/\S/);
        if (idx < 0) return null;
        const walker = document.createTreeWalker(node, NodeFilter.SHOW_TEXT);
        let remaining = idx;
        let target = null;
        let offset = 0;
        let current;
        while ((current = walker.nextNode())) {
          const len = current.textContent.length;
          if (remaining < len) {
            target = current;
            offset = remaining;
            break;
          }
          remaining -= len;
        }
        if (!target) return null;
        const range = document.createRange();
        range.setStart(target, offset);
        range.setEnd(target, offset + 1);
        const root = node.closest('.monaco-editor');
        return Math.round(
          range.getBoundingClientRect().left - root.getBoundingClientRect().left,
        );
      });
    const flushLeftGlyph = await firstGlyphLeft(page.locator('.view-line[data-line="1"]'));
    const wrappedGlyph = await firstGlyphLeft(wrappedHoverLine);
    expect(wrappedGlyph).not.toBeNull();
    expect(flushLeftGlyph).not.toBeNull();
    expect(wrappedGlyph).toBeGreaterThan(flushLeftGlyph + 5);
    const inlayHint = page.locator('.view-line .inlay-hint', { hasText: ': T' });
    await expect(inlayHint).toHaveCount(1, { timeout: 10_000 });
    await expect(inlayHint).toHaveClass(/inlay-hint-type/);
    const componentZone = page.locator('.view-zone[data-view-zone-id="component-zone"]');
    await expect(componentZone).toContainText('component view zone');
    const braceLine = page.locator('.view-line').filter({ hasText: '{' });
    await expect(braceLine).toHaveCount(1);
    const zoneBox = await componentZone.boundingBox();
    const braceBox = await braceLine.boundingBox();
    expect(zoneBox).not.toBeNull();
    expect(braceBox).not.toBeNull();
    expect(Math.abs(Math.round(braceBox.y - (zoneBox.y + zoneBox.height)))).toBeLessThanOrEqual(1);
    await inlayHint.hover();
    await expect(page.locator('[data-content-widget="hover"] .monaco-hover')).toContainText(
      'component inlay hint',
      { timeout: 3_000 },
    );
    const signatureStart = page.locator('.view-line').filter({ hasText: 'component_answe' });
    // A view segment near the top of the wrapped body line is a stable drag
    // endpoint (the deeper continuations scroll out of reach). The identifier
    // text repeats on the later `.length()` line, so take the first occurrence.
    const bodyEndLine = page
      .locator('.view-line')
      .filter({ hasText: 'really_long_c' })
      .first();
    await expect(signatureStart).toHaveCount(1);
    await expect(bodyEndLine).toBeVisible();
    const startBox = await signatureStart.boundingBox();
    const endBox = await bodyEndLine.boundingBox();
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
    expect(copiedText).toContain('let really_l');
    expect(copiedText).not.toContain(': T');
    const copiedHtml = await page.evaluate(() => globalThis.__readonlyEditorCopiedHtml || '');
    expect(copiedHtml).toContain('mtk4');
    expect(copiedHtml).not.toContain('inlay-hint');
    // Collapse the drag selection before the fold checks: with the default
    // renderWhitespace=selection, a selection spanning the inlay hint renders
    // whitespace glyphs inside the injected text (as Monaco does), which
    // fragments the hint span the later assertions look for.
    await page.locator('.view-line[data-line="1"]').click();
    await expect.poll(() => page.locator('.selected-text').count(), { timeout: 2_000 }).toBe(0);
    // The warning squiggle renders as an absolutely positioned overlay piece
    // (`<div class="cdr squiggly-warning">`, Monaco's DecorationsOverlay), not
    // as an inline span inside the view line.
    await expect(page.locator('.cdr.squiggly-warning')).toHaveCount(1, {
      timeout: 10_000,
    });
    const foldMarker = page.locator('.folding-marker[data-line="2"]');
    await expect(foldMarker).toHaveAttribute('data-folded', 'false', { timeout: 10_000 });
    await foldMarker.click();
    await expect(foldMarker).toHaveAttribute('data-folded', 'true');
    await expect(inlayHint).toHaveCount(1);
    await expect(page.locator('.view-line').filter({ hasText: 'keeps' })).toHaveCount(0);
    // Marker decorations set `showIfCollapsed`, so folding the squiggled
    // region leaves a min-width squiggle at the fold anchor (Monaco behavior:
    // errors hidden in a folded region still surface on the folded line).
    await expect(page.locator('.cdr.squiggly-warning')).toHaveCount(1);
    await foldMarker.click();
    await expect(foldMarker).toHaveAttribute('data-folded', 'false');
    await expect(inlayHint).toHaveCount(1);
    await expect(wrappedHoverLine).toHaveCount(1);
    await expect(page.locator('.cdr.squiggly-warning')).toHaveCount(1);
    const firstLineTop = async () =>
      page.locator('.view-line[data-line="1"]').evaluate((node) => {
        const root = node.closest('.monaco-editor');
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
