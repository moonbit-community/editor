import { expect, test } from '../support/test.js';
import { openWorkspaceFile } from '../support/app.js';
import {
  conformanceStates,
  hoverPayloads,
} from '../fixtures/monaco_conformance_payloads.js';

const readonlyBaseUrl = process.env.READONLY_EDITOR_BASE_URL ?? '/';

// These specs drive the real readonly editor and assert Monaco-shaped hover and
// scrollbar behavior directly. There is no Monaco reference page: parity is held
// by porting Monaco logic into the viewer, not by diffing a copied oracle.

test('editor track click centers the thumb like Monaco scrollByPage=false', async ({ page }) => {
  await page.goto(readonlyBaseUrl);
  await expect
    .poll(() => page.evaluate(() => typeof globalThis.__readonlyEditorConformance), {
      timeout: 10_000,
    })
    .toBe('object');
  await openWorkspaceFile(page, 'src/monaco_conformance.mbt');
  await page.locator('.monaco-scrollable-element.editor-scrollable').hover();

  let measurement = await page.evaluate(() => globalThis.__readonlyEditorConformance.measure());
  expect(measurement.editor.verticalScrollbar.visible).toBe(true);
  const bar = measurement.editor.verticalScrollbar.box;
  const slider = measurement.editor.verticalScrollbar.sliderBox;
  expect(bar.height).toBeGreaterThan(slider.height + 40);

  const clickX = bar.left + Math.min(6, bar.width / 2);
  const clickY = bar.top + Math.min(bar.height - 24, slider.height + 120);
  await page.mouse.click(clickX, clickY);
  await expect
    .poll(async () => {
      const after = await page.evaluate(() => globalThis.__readonlyEditorConformance.measure());
      const nextSlider = after.editor.verticalScrollbar.sliderBox;
      return Math.abs(nextSlider.top + nextSlider.height / 2 - clickY);
    })
    .toBeLessThan(2.5);

  measurement = await page.evaluate(() => globalThis.__readonlyEditorConformance.measure());
  expect(measurement.editor.shadows.some((shadow) => shadow.className.includes('top'))).toBe(
    true,
  );
});

test('long and wide hover payloads use custom hover scrollbars', async ({ page }) => {
  await page.goto(readonlyBaseUrl);
  await expect
    .poll(() => page.evaluate(() => typeof globalThis.__readonlyEditorConformance), {
      timeout: 10_000,
    })
    .toBe('object');
  await page.evaluate((payloads) => {
    globalThis.__readonlyEditorConformance.setPayloads(payloads);
  }, hoverPayloads);
  await openWorkspaceFile(page, 'src/monaco_conformance.mbt');

  await showReadonlyHover(page, conformanceStates.longHover);
  await page.locator('[data-content-widget="hover"] .monaco-hover-content').hover();
  let measurement = await page.evaluate(() => globalThis.__readonlyEditorConformance.measure());
  expect(measurement.hover.verticalScrollbar.visible).toBe(true);
  expect(measurement.hover.contentStyles['scrollbar-width']).not.toBe('auto');

  await page.evaluate(() => globalThis.__readonlyEditorConformance.hideHover());
  await showReadonlyHover(page, conformanceStates.wideHover);
  await page.locator('[data-content-widget="hover"] .monaco-hover-content').hover();
  measurement = await page.evaluate(() => globalThis.__readonlyEditorConformance.measure());
  expect(measurement.hover.horizontalScrollbar.visible).toBe(true);

  const scrollEventsBefore = await readonlyScrollEventCount(page);
  await page.locator('[data-content-widget="hover"] .monaco-hover-content').hover();
  await page.mouse.wheel(600, 0);
  await expect
    .poll(() =>
      page
        .locator('[data-content-widget="hover"] .monaco-hover-content')
        .evaluate((node) => node.scrollLeft),
    )
    .toBeGreaterThan(0);
  expect(await readonlyScrollEventCount(page)).toBe(scrollEventsBefore);
});

test('tall hover is capped to the available space and stays fully scrollable', async ({
  page,
}) => {
  // Phase 1 of monaco-hover-logic-chain-port.md: a hover taller than the room on
  // its chosen side must cap its height to that room (Monaco
  // _findMaximumRenderingHeight) so the .monaco-hover-content scrollbar engages
  // and the whole hover stays inside the editor instead of spilling past
  // .overflow-guard, which clips the overflow and leaves it unreachable.
  await page.goto(readonlyBaseUrl);
  await expect
    .poll(() => page.evaluate(() => typeof globalThis.__readonlyEditorConformance), {
      timeout: 10_000,
    })
    .toBe('object');
  await page.evaluate((payloads) => {
    globalThis.__readonlyEditorConformance.setPayloads(payloads);
  }, hoverPayloads);
  await openWorkspaceFile(page, 'src/monaco_conformance.mbt');

  // Anchor near the vertical middle of the editor so neither side has room for
  // the tall payload: the height must be capped whichever way it flips.
  const anchor = await pickRenderedLineNearFraction(page, 0.45);
  expect(anchor).not.toBeNull();

  await showReadonlyHover(page, {
    payload: 'markdownLong',
    line: anchor.line,
    column: 8,
  });

  const metrics = await hoverContentMetrics(page);
  // The content overflows its capped box, so the custom scrollbar is needed.
  expect(metrics.scrollHeight).toBeGreaterThan(metrics.clientHeight + 1);
  // The whole hover stays within the editor viewport (the bug let it spill).
  expect(metrics.contentTop).toBeGreaterThanOrEqual(metrics.editorTop - 2);
  expect(metrics.contentBottom).toBeLessThanOrEqual(metrics.editorBottom + 2);

  // The full content is reachable: scrolling to the end lands at the maximum
  // scroll offset rather than off-screen behind the editor clip.
  const reachedBottom = await page
    .locator('[data-content-widget="hover"] .monaco-hover-content')
    .evaluate((node) => {
      node.scrollTop = node.scrollHeight;
      return {
        scrollTop: node.scrollTop,
        maxScrollTop: node.scrollHeight - node.clientHeight,
      };
    });
  expect(reachedBottom.maxScrollTop).toBeGreaterThan(0);
  expect(Math.abs(reachedBottom.scrollTop - reachedBottom.maxScrollTop)).toBeLessThan(2);
});

test('a medium hover payload renders proportioned to its text, not collapsed to the CSS min-width floor', async ({
  page,
}) => {
  // Bug fix regression, reproducing the exact reported symptom: a diagnostic
  // hover message wrapped across many narrow lines instead of a well-
  // proportioned box. Root cause was `apply_width_sizing` only ever setting
  // `max-width` (a ceiling) with no explicit `width`, so a block-level
  // `.monaco-hover-content` with no natural sizing pressure collapsed to
  // `.monaco-resizable-hover`'s CSS `min-width: 150px` floor, forcing the
  // text to wrap far more aggressively than its natural (nowrap) width
  // needs. `hover_resolved_width` now locks an explicit width derived from
  // that natural measurement instead.
  await page.goto(readonlyBaseUrl);
  await expect
    .poll(() => page.evaluate(() => typeof globalThis.__readonlyEditorConformance), {
      timeout: 10_000,
    })
    .toBe('object');
  await page.evaluate((payloads) => {
    globalThis.__readonlyEditorConformance.setPayloads(payloads);
  }, hoverPayloads);
  await openWorkspaceFile(page, 'src/monaco_conformance.mbt');

  await showReadonlyHover(page, conformanceStates.markerHover);

  const metrics = await page.evaluate(() => {
    const editor = document.querySelector('.monaco-scrollable-element.editor-scrollable');
    const content = document.querySelector('[data-content-widget="hover"] .monaco-hover-content');
    return {
      contentWidth: content.getBoundingClientRect().width,
      availableWidth: editor.getBoundingClientRect().width,
    };
  });
  // Pre-fix, this collapsed to the 150px CSS min-width floor regardless of
  // the message's own natural width; post-fix it renders measurably wider
  // (proportioned to the text) while staying well short of the full
  // available width (proving it isn't just stretched to the other extreme).
  expect(metrics.contentWidth).toBeGreaterThan(200);
  expect(metrics.contentWidth).toBeLessThan(metrics.availableWidth * 0.5);
});

test('wrappable hover content is capped to the editor content area in a narrow window', async ({
  page,
}) => {
  // Horizontal counterpart to the tall-hover cap: when the editor is narrower
  // than the hover's natural width, the content must wrap to the available
  // width (the content area to the right of the gutter) instead of defaulting
  // to --vscode-hover-maxWidth (500px) and overflowing. The right-aligned
  // widget must also stay out of the line-number gutter, where the margin
  // overlays clip its leading text.
  await page.setViewportSize({ width: 520, height: 800 });
  await page.goto(readonlyBaseUrl);
  await expect
    .poll(() => page.evaluate(() => typeof globalThis.__readonlyEditorConformance), {
      timeout: 10_000,
    })
    .toBe('object');
  await page.evaluate((payloads) => {
    globalThis.__readonlyEditorConformance.setPayloads(payloads);
  }, hoverPayloads);
  await openWorkspaceFile(page, 'src/monaco_conformance.mbt');

  await showReadonlyHover(page, conformanceStates.wrappableHover);

  const metrics = await page.evaluate(() => {
    const editor = document.querySelector('.monaco-scrollable-element.editor-scrollable');
    const lines = document.querySelector('.lines-content');
    const wrapper = document.querySelector('[data-content-widget="hover"]');
    const content = wrapper.querySelector('.monaco-hover-content');
    const editorRect = editor.getBoundingClientRect();
    const linesRect = lines.getBoundingClientRect();
    const wrapperRect = wrapper.getBoundingClientRect();
    return {
      scrollWidth: content.scrollWidth,
      clientWidth: content.clientWidth,
      scrollLeft: content.scrollLeft,
      wrapperLeft: wrapperRect.left,
      wrapperRight: wrapperRect.right,
      // Left edge of the text content area (gutter ends here).
      contentAreaLeft: linesRect.left,
      editorRight: editorRect.right,
    };
  });

  // Wrappable content wraps instead of overflowing: no leading text is hidden.
  expect(metrics.scrollWidth).toBeLessThanOrEqual(metrics.clientWidth + 1);
  expect(metrics.scrollLeft).toBe(0);
  // The widget stays within the content area (not shifted into the gutter) and
  // inside the editor's right edge.
  expect(metrics.wrapperLeft).toBeGreaterThanOrEqual(metrics.contentAreaLeft - 1);
  expect(metrics.wrapperRight).toBeLessThanOrEqual(metrics.editorRight + 1);
});

async function showReadonlyHover(page, state) {
  await page.evaluate((payload) => {
    globalThis.__readonlyEditorConformance.setHoverPayload(payload);
  }, state.payload);
  await expect
    .poll(
      () =>
        page.evaluate(
          ({ line, column }) => globalThis.__readonlyEditorConformance.showHover(line, column),
          { line: state.line, column: state.column },
        ),
      { timeout: 5_000 },
    )
    .toBe(true);
  await expect(page.locator('[data-content-widget="hover"] .monaco-hover')).toBeVisible({
    timeout: 3_000,
  });
}

async function pickRenderedLineNearFraction(page, fraction) {
  return page.evaluate((target) => {
    const editor = document.querySelector('.monaco-scrollable-element.editor-scrollable');
    if (!editor) return null;
    const editorRect = editor.getBoundingClientRect();
    const wantY = editorRect.top + editorRect.height * target;
    let best = null;
    for (const node of document.querySelectorAll('.view-line[data-line]')) {
      const rect = node.getBoundingClientRect();
      const center = rect.top + rect.height / 2;
      // Only consider lines comfortably inside the viewport so the hover has
      // room to flip either way.
      if (center < editorRect.top + 24 || center > editorRect.bottom - 24) {
        continue;
      }
      const distance = Math.abs(center - wantY);
      if (!best || distance < best.distance) {
        best = { line: Number(node.dataset.line), distance };
      }
    }
    return best ? { line: best.line } : null;
  }, fraction);
}

async function hoverContentMetrics(page) {
  return page.evaluate(() => {
    const editor = document.querySelector('.monaco-scrollable-element.editor-scrollable');
    const content = document.querySelector(
      '[data-content-widget="hover"] .monaco-hover-content',
    );
    const editorRect = editor.getBoundingClientRect();
    const contentRect = content.getBoundingClientRect();
    return {
      scrollHeight: content.scrollHeight,
      clientHeight: content.clientHeight,
      contentTop: contentRect.top,
      contentBottom: contentRect.bottom,
      editorTop: editorRect.top,
      editorBottom: editorRect.bottom,
    };
  });
}

async function readonlyScrollEventCount(page) {
  return page.evaluate(() => {
    globalThis.__readonlyEditorConformanceScrollEvents ??= 0;
    if (!globalThis.__readonlyEditorConformanceWrappedEvents) {
      const previous = globalThis.__readonlyEditorEvent;
      globalThis.__readonlyEditorEvent = (name, payload) => {
        if (name === 'view:scroll') {
          globalThis.__readonlyEditorConformanceScrollEvents += 1;
        }
        previous?.(name, payload);
      };
      globalThis.__readonlyEditorConformanceWrappedEvents = true;
    }
    return globalThis.__readonlyEditorConformanceScrollEvents;
  });
}
