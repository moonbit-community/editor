import { expect, test } from '../support/test.js';
import { openWorkspaceFile } from '../support/app.js';
import {
  conformanceStates,
  hoverPayloads,
} from '../fixtures/monaco_conformance_payloads.js';

const ATTRS = ['role', 'aria-hidden', 'tabindex', 'data-content-widget'];
const STATE_CLASSES = ['active', 'below', 'fade', 'fade-in', 'invisible', 'measuring', 'visible'];

test('keeps the Monaco-shaped editor shell DOM structure', async ({ page }) => {
  await openConformanceFixture(page);

  await expectDirectChildren(page, '.overflow-guard', [
    element('div', ['margin'], { 'aria-hidden': 'true' }),
    element('div', ['editor-scrollable', 'monaco-scrollable-element'], {
      role: 'presentation',
    }),
    // Monaco `view.ts:287`: overlay widgets are viewport-fixed children of the
    // overflow guard, not of the scrolling lines content.
    element('div', ['overlayWidgets']),
  ]);
  await expectDirectChildren(page, '.margin', [
    element('div', ['margin-view-overlays']),
  ]);
  await expectDirectChildren(page, '.margin > .margin-view-overlays', [
    element('div', ['folding', 'view-layer']),
    element('div', ['line-numbers', 'view-layer']),
  ]);

  const editorScrollable = '.monaco-scrollable-element.editor-scrollable';
  await expectDirectChildren(page, editorScrollable, [
    element('div', ['lines-content', 'moonbit-viewer-background']),
    element('div', ['horizontal', 'scrollbar'], {
      role: 'presentation',
      'aria-hidden': 'true',
    }),
    element('div', ['scrollbar', 'vertical'], {
      role: 'presentation',
      'aria-hidden': 'true',
    }),
    element('div', ['shadow']),
    element('div', ['shadow']),
    element('div', ['shadow']),
  ]);
  await expectDirectChildren(page, `${editorScrollable} > .lines-content`, [
    element('div', ['view-overlays']),
    element('div', ['view-zones']),
    element('div', ['view-lines']),
    element('div', ['contentWidgets']),
    // Monaco `view.ts:280`: the cursors layer renders above content widgets
    // inside the scrolling lines content.
    element('div', ['cursor-line-style', 'cursor-solid', 'cursors-layer'], {
      role: 'presentation',
      'aria-hidden': 'true',
    }),
  ]);
  await expectDirectChildren(page, `${editorScrollable} > .scrollbar.horizontal`, [
    element('div', ['slider']),
  ]);
  await expectDirectChildren(page, `${editorScrollable} > .scrollbar.vertical`, [
    element('div', ['slider']),
  ]);
});

test('keeps the Monaco-shaped markdown hover DOM structure', async ({ page }) => {
  await openConformanceFixture(page);
  await showReadonlyHover(page, conformanceStates.shortHover);

  const widget = '[data-content-widget="hover"]';
  await expectElement(page, widget, element('div', ['monaco-resizable-hover'], {
    'data-content-widget': 'hover',
  }));
  await expectDirectChildren(page, widget, [
    element('div', ['monaco-hover'], { role: 'tooltip', tabindex: '0' }),
  ]);
  await expectDirectChildren(page, `${widget} > .monaco-hover`, [
    element('div', ['monaco-scrollable-element'], { role: 'presentation' }),
  ]);
  await expectDirectChildren(page, `${widget} .monaco-hover > .monaco-scrollable-element`, [
    element('div', ['monaco-hover-content']),
    element('div', ['horizontal', 'scrollbar'], {
      role: 'presentation',
      'aria-hidden': 'true',
    }),
    element('div', ['scrollbar', 'vertical'], {
      role: 'presentation',
      'aria-hidden': 'true',
    }),
    element('div', ['shadow']),
    element('div', ['shadow']),
    element('div', ['shadow']),
  ]);
  await expectDirectChildren(page, `${widget} .monaco-hover-content`, [
    element('div', ['hover-row']),
  ]);
  await expectDirectChildren(page, `${widget} .hover-row`, [
    element('div', ['hover-row-contents']),
  ]);
  await expectDirectChildren(page, `${widget} .hover-row-contents`, [
    element('div', ['markdown-hover']),
  ]);
  await expectDirectChildren(page, `${widget} .markdown-hover`, [
    element('div', ['hover-contents']),
  ]);
});

test('keeps the Monaco-shaped marker hover DOM structure', async ({ page }) => {
  await openConformanceFixture(page);
  await showReadonlyHover(page, conformanceStates.markerHover);

  const widget = '[data-content-widget="hover"]';
  await expectDirectChildren(page, `${widget} .monaco-hover-content`, [
    element('div', ['hover-row', 'hover-row-with-copy'], { tabindex: '0' }),
    element('div', ['hover-row', 'status-bar'], { tabindex: '0' }),
  ]);
  await expectDirectChildren(page, `${widget} .hover-row-with-copy`, [
    element('div', ['hover-contents', 'marker']),
    element('button', ['hover-copy-button']),
  ]);
  await expect(page.locator(`${widget} .hover-copy-button`)).toHaveAttribute('aria-label', 'Copy');
  await expectDirectChildren(page, `${widget} .hover-copy-button`, [
    element('span', ['codicon', 'codicon-copy'], { 'aria-hidden': 'true' }),
  ]);
  await expectDirectChildren(page, `${widget} .hover-row.status-bar`, [
    element('div', ['actions']),
  ]);
  // Monaco's `HoverAction.render` (`hoverWidget.ts:52-92`) puts `tabindex` on
  // `.action-container`, never on the `<a>` inside it.
  await expectDirectChildren(page, `${widget} .hover-row.status-bar > .actions`, [
    element('div', ['action-container'], { tabindex: '0' }),
  ]);
  await expectDirectChildren(page, `${widget} .action-container`, [
    element('a', ['action'], { role: 'button' }),
  ]);
  await expectDirectChildren(page, `${widget} .action`, [element('span', [])]);
});

test('renders a marker part, a later-ordinal hover part, then the status bar last', async ({ page }) => {
  await openConformanceFixture(page);
  await showReadonlyHover(page, conformanceStates.markerAndMarkdownHover);

  const widget = '[data-content-widget="hover"]';
  await expectDirectChildren(page, `${widget} .monaco-hover-content`, [
    element('div', ['hover-row', 'hover-row-with-copy'], { tabindex: '0' }),
    element('div', ['hover-row'], { tabindex: '0' }),
    element('div', ['hover-row', 'status-bar'], { tabindex: '0' }),
  ]);
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

async function expectElement(page, selector, expected) {
  const locator = page.locator(selector);
  await expect(locator).toHaveCount(1);
  expect(await locator.evaluate((node, options) => {
    const resultAttrs = {};
    for (const attr of options.attrs) {
      const value = node.getAttribute(attr);
      if (value !== null) {
        resultAttrs[attr] = value;
      }
    }
    return {
      tag: node.tagName.toLowerCase(),
      classes: Array.from(node.classList)
        .filter((className) => !options.stateClasses.includes(className))
        .sort(),
      attrs: resultAttrs,
    };
  }, options())).toEqual(expected);
}

async function expectDirectChildren(page, selector, expected) {
  const locator = page.locator(selector);
  await expect(locator).toHaveCount(1);
  const children = await locator.evaluate(
    (node, options) =>
      Array.from(node.children).map((child) => {
        const resultAttrs = {};
        for (const attr of options.attrs) {
          const value = child.getAttribute(attr);
          if (value !== null) {
            resultAttrs[attr] = value;
          }
        }
        return {
          tag: child.tagName.toLowerCase(),
          classes: Array.from(child.classList)
            .filter((className) => !options.stateClasses.includes(className))
            .sort(),
          attrs: resultAttrs,
        };
      }),
    options(),
  );
  expect(children).toEqual(expected);
}

function element(tag, classes, attrs = {}) {
  return { tag, classes: [...classes].sort(), attrs };
}

function options() {
  return { attrs: ATTRS, stateClasses: STATE_CLASSES };
}
