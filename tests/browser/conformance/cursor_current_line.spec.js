import { expect, test } from '../support/test.js';
import { openWorkspaceFile } from '../support/app.js';

// Conformance for the viewCursors + currentLineHighlight ports
// (docs/exec-plans/monaco-view-cursors-current-line-port.md): a focused
// editor paints a solid caret at the set position (readonly Monaco never
// blinks), the cursor line carries the exact current-line box in content and
// margin, blur hides the caret, and a non-empty selection suppresses the
// content highlight (cLH:191-197) while flagging the cursors layer.

test('setPosition paints a solid caret and the current-line highlight when focused', async ({ page }) => {
  await openFixture(page);

  await conformance(page, 'focusEditor');
  await conformance(page, 'setPosition', 3, 5);

  const root = page.locator('.moonbit-viewer.readonly-editor');
  await expect(root).toHaveClass(/\bfocused\b/);

  const cursor = page.locator('.cursors-layer > .cursor');
  await expect(cursor).toHaveCount(1);
  await expect(cursor).toBeVisible();
  await expect(cursor).toHaveCSS('visibility', 'visible');

  // The caret sits inside line 3's box, at the line's height.
  const line = page.locator('.view-line[data-line="3"]');
  const lineBox = await line.boundingBox();
  const cursorBox = await cursor.boundingBox();
  expect(cursorBox.y).toBeCloseTo(lineBox.y, 0);
  expect(cursorBox.height).toBeCloseTo(lineBox.height, 0);
  expect(cursorBox.x).toBeGreaterThanOrEqual(lineBox.x);

  // Exact current-line box on the cursor line, content + margin
  // (renderLineHighlight default 'line': margin pieces carry only the bare
  // class, so no current-line-margin variant).
  const currentLine = page.locator('.view-overlays > .current-line');
  await expect(currentLine).toHaveCount(1);
  await expect(currentLine).toHaveClass(/\bcurrent-line-exact\b/);
  const currentLineBox = await currentLine.boundingBox();
  expect(currentLineBox.y).toBeCloseTo(lineBox.y, 0);
  await expect(
    page.locator('.margin-view-overlays .current-line-margin'),
  ).toHaveCount(0);
});

test('blur hides the caret (readonly cursor is Hidden when unfocused)', async ({ page }) => {
  await openFixture(page);

  await conformance(page, 'focusEditor');
  await conformance(page, 'setPosition', 2, 1);
  const cursor = page.locator('.cursors-layer > .cursor');
  await expect(cursor).toHaveCSS('visibility', 'visible');

  await conformance(page, 'blurEditor');
  await expect(cursor).toHaveCSS('visibility', 'hidden');
  const root = page.locator('.moonbit-viewer.readonly-editor');
  await expect(root).not.toHaveClass(/\bfocused\b/);
});

test('a non-empty selection suppresses the content highlight and flags the layer', async ({ page }) => {
  await openFixture(page);

  await conformance(page, 'focusEditor');
  await conformance(page, 'setSelection', 1, 1, 2, 4);

  await expect(page.locator('.cursors-layer')).toHaveClass(/\bhas-selection\b/);
  // _shouldRenderInContent requires an empty selection (cLH:191-197).
  await expect(page.locator('.view-overlays > .current-line')).toHaveCount(0);
  // The caret still renders at the selection's active end (line 2).
  const cursor = page.locator('.cursors-layer > .cursor');
  await expect(cursor).toBeVisible();
  const lineBox = await page.locator('.view-line[data-line="2"]').boundingBox();
  const cursorBox = await cursor.boundingBox();
  expect(cursorBox.y).toBeCloseTo(lineBox.y, 0);

  // Collapsing back restores the highlight.
  await conformance(page, 'setPosition', 2, 4);
  await expect(page.locator('.view-overlays > .current-line')).toHaveCount(1);
});

async function openFixture(page) {
  await page.goto('/');
  await expect
    .poll(() => page.evaluate(() => typeof globalThis.__readonlyEditorConformance), {
      timeout: 10_000,
    })
    .toBe('object');
  await openWorkspaceFile(page, 'src/monaco_conformance.mbt');
}

async function conformance(page, method, ...args) {
  await page.evaluate(
    ({ method, args }) => globalThis.__readonlyEditorConformance[method](...args),
    { method, args },
  );
}
