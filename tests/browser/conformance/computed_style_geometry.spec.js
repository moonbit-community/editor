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
const hoverWidget = '[data-content-widget="hover"]';

test('resolves Monaco editor scroll surface styles and geometry', async ({ browser }) => {
  const { oracle, readonly, close } = await openOracleAndReadonly(browser);
  try {
    const editorProps = ['position', 'overflow-x', 'overflow-y'];
    const oracleEditor = await measureNode(
      oracle,
      '.monaco-scrollable-element.editor-scrollable',
      editorProps,
    );
    const readonlyEditor = await measureNode(
      readonly,
      '.monaco-scrollable-element.editor-scrollable',
      editorProps,
    );
    expectStyleSubset(readonlyEditor, oracleEditor, editorProps);

    const barProps = ['display', 'opacity', 'pointer-events'];
    const oracleVerticalBar = await measureNode(
      oracle,
      '.monaco-scrollable-element.editor-scrollable > .scrollbar.vertical',
      barProps,
    );
    const readonlyVerticalBar = await measureNode(
      readonly,
      '.monaco-scrollable-element.editor-scrollable > .scrollbar.vertical',
      barProps,
    );
    expect(readonlyVerticalBar.box.width).toBe(14);
    expect(readonlyVerticalBar.styles.display).not.toBe('none');
    expectStyleSubset(readonlyVerticalBar, oracleVerticalBar, barProps);

    const oracleHorizontalBar = await measureNode(
      oracle,
      '.monaco-scrollable-element.editor-scrollable > .scrollbar.horizontal',
      barProps,
    );
    const readonlyHorizontalBar = await measureNode(
      readonly,
      '.monaco-scrollable-element.editor-scrollable > .scrollbar.horizontal',
      barProps,
    );
    expect(readonlyHorizontalBar.box.height).toBe(12);
    expect(readonlyHorizontalBar.styles.display).not.toBe('none');
    expectStyleSubset(readonlyHorizontalBar, oracleHorizontalBar, barProps);

    const sliderProps = ['position', 'background-color'];
    const oracleSlider = await measureNode(
      oracle,
      '.monaco-scrollable-element.editor-scrollable > .scrollbar.vertical > .slider',
      sliderProps,
    );
    const readonlySlider = await measureNode(
      readonly,
      '.monaco-scrollable-element.editor-scrollable > .scrollbar.vertical > .slider',
      sliderProps,
    );
    expectStyleSubset(readonlySlider, oracleSlider, sliderProps);
    expect(readonlySlider.styles['background-color']).not.toBe('rgba(0, 0, 0, 0)');
  } finally {
    await close();
  }
});

test('resolves short hover shell styles and stable geometry like Monaco', async ({
  browser,
}) => {
  const { oracle, readonly, close } = await openOracleAndReadonly(browser);
  try {
    await showHoverPair(oracle, readonly, conformanceStates.shortHover);

    const wrapperProps = [
      'position',
      'z-index',
      'cursor',
      'box-sizing',
      'border-top-color',
      'border-top-width',
      'border-radius',
      'background-color',
    ];
    const oracleWrapper = await measureNode(oracle, hoverWidget, wrapperProps);
    const readonlyWrapper = await measureNode(readonly, hoverWidget, wrapperProps);
    expectStyleSubset(readonlyWrapper, oracleWrapper, wrapperProps);
    expectBoxClose(readonlyWrapper, oracleWrapper);

    const hoverProps = [
      'overflow-x',
      'overflow-y',
      'color',
      'background-color',
      'border-radius',
      'box-shadow',
      'font-size',
      'line-height',
      'box-sizing',
    ];
    const oracleHover = await measureNode(oracle, `${hoverWidget} .monaco-hover`, hoverProps);
    const readonlyHover = await measureNode(
      readonly,
      `${hoverWidget} .monaco-hover`,
      hoverProps,
    );
    expectStyleSubset(readonlyHover, oracleHover, hoverProps);
    expectBoxClose(readonlyHover, oracleHover);

    const contentProps = ['overflow-x', 'overflow-y', 'scrollbar-width', 'max-width', 'max-height'];
    const oracleContent = await measureNode(
      oracle,
      `${hoverWidget} .monaco-hover-content`,
      contentProps,
    );
    const readonlyContent = await measureNode(
      readonly,
      `${hoverWidget} .monaco-hover-content`,
      contentProps,
    );
    expectStyleSubset(readonlyContent, oracleContent, [
      'overflow-x',
      'overflow-y',
      'scrollbar-width',
    ]);
    await expectHoverMaxConstraints(oracle, oracleContent);
    await expectHoverMaxConstraints(readonly, readonlyContent);
  } finally {
    await close();
  }
});

test('constrains long and wide hover geometry with custom scrollbars', async ({
  browser,
}) => {
  const { oracle, readonly, close } = await openOracleAndReadonly(browser);
  try {
    await showHoverPair(oracle, readonly, conformanceStates.longHover);
    await readonly.locator(`${hoverWidget} .monaco-hover-content`).hover();
    const longOracle = await oracle.evaluate(() => globalThis.__monacoConformance.measure());
    const longReadonly = await readonly.evaluate(() =>
      globalThis.__readonlyEditorConformance.measure(),
    );
    const longReadonlyContent = await measureNode(
      readonly,
      `${hoverWidget} .monaco-hover-content`,
      ['max-height'],
    );
    expect(longReadonly.hover.verticalScrollbar.visible).toBe(true);
    expect(longReadonly.hover.nativeScrollbarInset).toEqual({ x: 0, y: 0 });
    expect(longReadonlyContent.box.height).toBeLessThanOrEqual(
      numericStyle(longReadonlyContent, 'max-height') + 1,
    );
    expectBoxClose(
      longReadonly.hover.verticalScrollbar,
      longOracle.hover.verticalScrollbar,
      2,
      ['width'],
    );
    expectBoxClose(
      longReadonly.hover.verticalScrollbar,
      longOracle.hover.verticalScrollbar,
      2,
      ['width'],
      'sliderBox',
    );

    await oracle.evaluate(() => globalThis.__monacoConformance.hideHover());
    await readonly.evaluate(() => globalThis.__readonlyEditorConformance.hideHover());
    await showHoverPair(oracle, readonly, conformanceStates.wideHover);
    await readonly.locator(`${hoverWidget} .monaco-hover-content`).hover();
    const wideOracle = await oracle.evaluate(() => globalThis.__monacoConformance.measure());
    const wideReadonly = await readonly.evaluate(() =>
      globalThis.__readonlyEditorConformance.measure(),
    );
    const wideReadonlyContent = await measureNode(
      readonly,
      `${hoverWidget} .monaco-hover-content`,
      ['max-width'],
    );
    expect(wideReadonly.hover.horizontalScrollbar.visible).toBe(true);
    expect(wideReadonly.hover.nativeScrollbarInset).toEqual({ x: 0, y: 0 });
    expect(wideReadonlyContent.scrollWidth).toBeGreaterThan(wideReadonlyContent.clientWidth);
    expect(wideReadonlyContent.box.width).toBeLessThanOrEqual(
      numericStyle(wideReadonlyContent, 'max-width') + 1,
    );
    expectBoxClose(
      wideReadonly.hover.horizontalScrollbar,
      wideOracle.hover.horizontalScrollbar,
      2,
      ['height'],
    );
    expectBoxClose(
      wideReadonly.hover.horizontalScrollbar,
      wideOracle.hover.horizontalScrollbar,
      2,
      ['height'],
      'sliderBox',
    );
  } finally {
    await close();
  }
});

test('resolves marker hover status row and copy affordance styles', async ({
  browser,
}) => {
  const { oracle, readonly, close } = await openOracleAndReadonly(browser);
  try {
    await showHoverPair(oracle, readonly, conformanceStates.markerHover);

    await compareNodeStyles(oracle, readonly, `${hoverWidget} .hover-row.status-bar`, [
      'font-size',
      'line-height',
    ]);
    await compareNodeStyles(oracle, readonly, `${hoverWidget} .hover-row.status-bar .actions`, [
      'display',
      'box-sizing',
      'padding-left',
      'padding-right',
      'background-color',
    ]);
    await compareNodeStyles(oracle, readonly, `${hoverWidget} .hover-copy-button`, [
      'position',
      'top',
      'right',
      'display',
      'align-items',
      'justify-content',
      'padding-top',
      'padding-right',
      'padding-bottom',
      'padding-left',
      'border-top-width',
      'border-radius',
      'background-color',
      'opacity',
    ]);

    const copyButton = await measureNode(readonly, `${hoverWidget} .hover-copy-button`, [
      'opacity',
    ]);
    expect(copyButton.styles.opacity).toBe('0');
  } finally {
    await close();
  }
});

async function openOracleAndReadonly(browser) {
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

  return {
    oracle,
    readonly,
    async close() {
      await oracle.close();
      await readonly.close();
    },
  };
}

async function showHoverPair(oracle, readonly, state) {
  await oracle.evaluate((hoverState) => {
    globalThis.__monacoConformance.showHover(
      hoverState.payload,
      hoverState.line,
      hoverState.column,
    );
  }, state);
  await readonly.evaluate((payload) => {
    globalThis.__readonlyEditorConformance.setHoverPayload(payload);
  }, state.payload);
  await expect
    .poll(
      () =>
        readonly.evaluate(
          ({ line, column }) => globalThis.__readonlyEditorConformance.showHover(line, column),
          { line: state.line, column: state.column },
        ),
      { timeout: 5_000 },
    )
    .toBe(true);
  await expect(readonly.locator(`${hoverWidget} .monaco-hover`)).toBeVisible({
    timeout: 3_000,
  });
}

async function compareNodeStyles(oracle, readonly, selector, props) {
  const oracleNode = await measureNode(oracle, selector, props);
  const readonlyNode = await measureNode(readonly, selector, props);
  expectStyleSubset(readonlyNode, oracleNode, props);
}

async function measureNode(page, selector, props) {
  const locator = page.locator(selector);
  await expect(locator).toHaveCount(1);
  return locator.evaluate((node, styleProps) => {
    const rounded = (value) => Math.round(Number(value) * 100) / 100;
    const rect = node.getBoundingClientRect();
    const computed = getComputedStyle(node);
    return {
      box: {
        x: rounded(rect.x),
        y: rounded(rect.y),
        width: rounded(rect.width),
        height: rounded(rect.height),
        top: rounded(rect.top),
        right: rounded(rect.right),
        bottom: rounded(rect.bottom),
        left: rounded(rect.left),
      },
      clientWidth: node.clientWidth,
      clientHeight: node.clientHeight,
      scrollWidth: node.scrollWidth,
      scrollHeight: node.scrollHeight,
      styles: Object.fromEntries(
        styleProps.map((prop) => [prop, computed.getPropertyValue(prop)]),
      ),
    };
  }, props);
}

function expectStyleSubset(actual, expected, props) {
  for (const prop of props) {
    expect(actual.styles[prop], prop).toBe(expected.styles[prop]);
  }
}

function expectBoxClose(
  actual,
  expected,
  tolerance = 2,
  fields = ['width', 'height'],
  key = 'box',
) {
  for (const field of fields) {
    expect(
      Math.abs(actual[key][field] - expected[key][field]),
      `${key}.${field}`,
    ).toBeLessThanOrEqual(tolerance);
  }
}

async function expectHoverMaxConstraints(page, content) {
  const root = await measureNode(page, '.monaco-editor', []);
  expect(numericStyle(content, 'max-width')).toBeCloseTo(
    Math.max(160, root.box.width - 24),
    0,
  );
  expect(numericStyle(content, 'max-height')).toBeCloseTo(
    Math.max(80, root.box.height - 24),
    0,
  );
}

function numericStyle(measurement, prop) {
  return Number.parseFloat(measurement.styles[prop]);
}
