import path from 'node:path';
import { pathToFileURL } from 'node:url';
import { expect, test } from '../support/test.js';
import { openWorkspaceFile } from '../support/app.js';
import {
  conformanceSourceText,
  conformanceStates,
  hoverPayloads,
} from '../fixtures/monaco_conformance_payloads.js';

const oracleUrl = pathToFileURL(
  path.join(process.cwd(), 'tests/reference/monaco-hover-scrollbar/index.html'),
).href;
const readonlyBaseUrl = process.env.READONLY_EDITOR_BASE_URL ?? '/';

test('compares Monaco oracle and readonly scrollbar/hover measurements', async ({
  browser,
}, testInfo) => {
  const oracle = await browser.newPage();
  const readonly = await browser.newPage();
  await oracle.goto(oracleUrl);
  await expect
    .poll(() => oracle.evaluate(() => globalThis.__monacoConformance?.ready()))
    .toBe(true);
  await oracle.evaluate(
    ([source, payloads]) => {
      globalThis.__monacoConformance.setPayloads(payloads);
      globalThis.__monacoConformance.setTheme('dark');
      globalThis.__monacoConformance.openDocument(source, 'moonbit');
    },
    [conformanceSourceText, hoverPayloads],
  );

  await readonly.goto(readonlyBaseUrl);
  await expect
    .poll(() => readonly.evaluate(() => typeof globalThis.__readonlyEditorConformance), {
      timeout: 10_000,
    })
    .toBe('object');
  await readonly.evaluate((payloads) => {
    globalThis.__readonlyEditorConformance.setPayloads(payloads);
  }, hoverPayloads);
  await openWorkspaceFile(readonly, 'src/monaco_conformance.mbt');

  const initialOracle = await oracle.evaluate(() => globalThis.__monacoConformance.measure());
  const initialReadonly = await readonly.evaluate(() =>
    globalThis.__readonlyEditorConformance.measure(),
  );

  expect(initialReadonly.editor.verticalScrollbar.role).toBe(
    initialOracle.editor.verticalScrollbar.role,
  );
  expect(initialReadonly.editor.verticalScrollbar.ariaHidden).toBe('true');
  expect(initialReadonly.editor.verticalScrollbar.box.width).toBe(14);
  expect(initialReadonly.editor.horizontalScrollbar.box.height).toBe(12);
  expect(initialReadonly.editor.verticalScrollbar.styles.display).not.toBe('none');
  expect(initialReadonly.editor.verticalScrollbar.styles.opacity).toBe(
    initialOracle.editor.verticalScrollbar.styles.opacity,
  );
  expect(initialReadonly.editor.verticalScrollbar.styles['pointer-events']).toBe(
    initialOracle.editor.verticalScrollbar.styles['pointer-events'],
  );
  expect(initialReadonly.editor.verticalScrollbar.styles.transition).toBe(
    initialOracle.editor.verticalScrollbar.styles.transition,
  );
  expect(initialReadonly.editor.shadows).toHaveLength(3);

  const shortHover = conformanceStates.shortHover;
  await oracle.evaluate((state) => {
    globalThis.__monacoConformance.showHover(state.payload, state.line, state.column);
  }, shortHover);
  await showReadonlyHover(readonly, shortHover);

  const hoverOracle = await oracle.evaluate(() => globalThis.__monacoConformance.measure());
  const hoverReadonly = await readonly.evaluate(() =>
    globalThis.__readonlyEditorConformance.measure(),
  );

  expect(hoverReadonly.hover.wrapperClassName).toContain('monaco-resizable-hover');
  expect(hoverReadonly.hover.className).toContain('monaco-hover');
  expect(hoverReadonly.hover.role).toBe(hoverOracle.hover.role);
  expect(hoverReadonly.hover.tabindex).toBe(hoverOracle.hover.tabindex);
  expect(hoverReadonly.hover.rowClasses).toEqual(hoverOracle.hover.rowClasses);
  expect(hoverReadonly.hover.verticalScrollbar.role).toBe('presentation');
  expect(hoverReadonly.hover.verticalScrollbar.ariaHidden).toBe('true');
  expect(hoverReadonly.hover.nativeScrollbarInset.y).toBe(0);

  const referenceScreenshot = testInfo.outputPath('monaco-reference-short-hover.png');
  const readonlyScreenshot = testInfo.outputPath('readonly-viewer-short-hover.png');
  await oracle.screenshot({ path: referenceScreenshot, fullPage: true });
  await readonly.screenshot({ path: readonlyScreenshot, fullPage: true });
  await testInfo.attach('monaco-reference-short-hover', {
    path: referenceScreenshot,
    contentType: 'image/png',
  });
  await testInfo.attach('readonly-viewer-short-hover', {
    path: readonlyScreenshot,
    contentType: 'image/png',
  });

  await oracle.close();
  await readonly.close();
});

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

test('marker hover status row and copy affordance match Monaco', async ({ browser }) => {
  const oracle = await browser.newPage();
  const readonly = await browser.newPage();
  await oracle.goto(oracleUrl);
  await expect
    .poll(() => oracle.evaluate(() => globalThis.__monacoConformance?.ready()))
    .toBe(true);
  await oracle.evaluate(
    ([source, payloads]) => {
      globalThis.__monacoConformance.setPayloads(payloads);
      globalThis.__monacoConformance.openDocument(source, 'moonbit');
    },
    [conformanceSourceText, hoverPayloads],
  );

  await readonly.goto(readonlyBaseUrl);
  await expect
    .poll(() => readonly.evaluate(() => typeof globalThis.__readonlyEditorConformance), {
      timeout: 10_000,
    })
    .toBe('object');
  await readonly.evaluate((payloads) => {
    globalThis.__readonlyEditorConformance.setPayloads(payloads);
  }, hoverPayloads);
  await openWorkspaceFile(readonly, 'src/monaco_conformance.mbt');

  const state = conformanceStates.markerHover;
  await oracle.evaluate((markerState) => {
    globalThis.__monacoConformance.showHover(
      markerState.payload,
      markerState.line,
      markerState.column,
    );
  }, state);
  await showReadonlyHover(readonly, state);

  const hoverOracle = await oracle.evaluate(() => globalThis.__monacoConformance.measure());
  const hoverReadonly = await readonly.evaluate(() =>
    globalThis.__readonlyEditorConformance.measure(),
  );
  expect(hoverReadonly.hover.rowClasses).toEqual(hoverOracle.hover.rowClasses);
  expect(hoverReadonly.hover.statusBar.present).toBe(true);
  expect(hoverReadonly.hover.statusBar.actionText).toBe(
    hoverOracle.hover.statusBar.actionText,
  );
  expect(hoverReadonly.hover.copyButton.present).toBe(true);
  expect(hoverReadonly.hover.copyButton.ariaLabel).toBe(
    hoverOracle.hover.copyButton.ariaLabel,
  );

  await oracle.locator('.hover-copy-button').click();
  await readonly.locator('[data-content-widget="hover"] .hover-copy-button').click();
  await expect
    .poll(() => oracle.evaluate(() => globalThis.__monacoConformanceCopiedText))
    .toBe(hoverPayloads.markerDiagnostic.contents);
  await expect
    .poll(() => readonly.evaluate(() => globalThis.__readonlyEditorCopiedText))
    .toBe(hoverPayloads.markerDiagnostic.contents);

  await oracle.close();
  await readonly.close();
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
