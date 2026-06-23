import { expect, test } from '../support/test.js';

// Selection geometry parity: pointer hits resolve through the browser caret
// APIs and the selection highlight is painted from DOM-measured client rects
// (Monaco's MouseTargetFactory + SelectionsOverlay roles), not monospace `ch`
// arithmetic. These checks lock in the two observable wins of that rework: one
// merged rectangle per contiguous selection (no per-token seams) and an
// end-of-line fill when the selection continues past a line's text.

async function mountComponentViewer(page) {
  await page.goto('/browser-tests/component.html');
  await expect(page.locator('.monaco-editor.readonly-editor')).toContainText('component_answer', {
    timeout: 10_000,
  });
}

// Rects of `.selected-text` overlay nodes whose vertical center falls on the
// given line box, in viewport coordinates.
async function selectionRectsOnLine(page, lineBox) {
  return page.evaluate((box) => {
    const midY = box.y + box.height / 2;
    return Array.from(document.querySelectorAll('.selected-text'))
      .map((node) => node.getBoundingClientRect())
      .filter((rect) => rect.top <= midY && rect.bottom >= midY)
      .map((rect) => ({ left: rect.left, right: rect.right, width: rect.width }));
  }, lineBox);
}

test('paints one merged rectangle for a contiguous single-line selection', async ({ page }) => {
  await mountComponentViewer(page);

  const line = page.locator('.view-line').filter({ hasText: 'component_answe' });
  await expect(line).toHaveCount(1);
  const box = await line.boundingBox();
  expect(box).not.toBeNull();

  // Drag horizontally within the one line; the span covers several tokens.
  const y = box.y + box.height / 2;
  const startX = box.x + 2;
  const endX = box.x + 56;
  await page.mouse.move(startX, y);
  await page.mouse.down();
  await page.mouse.move(endX, y, { steps: 4 });
  await page.mouse.up();

  await expect
    .poll(() => page.locator('.selected-text').count(), { timeout: 2_000 })
    .toBeGreaterThan(0);

  const rects = await selectionRectsOnLine(page, box);
  // A contiguous same-line selection is one rectangle, regardless of how many
  // token spans it crosses. The old per-span overlay produced one div per span.
  expect(rects).toHaveLength(1);
  // The rectangle is DOM-measured: it is anchored at the line origin (where the
  // drag began) and spans several glyphs out toward the drop point. Exact width
  // depends on which character boundary the caret snaps to, so only the
  // measured, multi-character span is asserted here.
  expect(Math.abs(rects[0].left - startX)).toBeLessThanOrEqual(4);
  expect(rects[0].width).toBeGreaterThan(10);
});

test('extends the highlight past a line whose continuation is selected', async ({ page }) => {
  await mountComponentViewer(page);

  const firstLine = page.locator('.view-line').filter({ hasText: 'component_answe' });
  const lastLine = page.locator('.view-line').filter({ hasText: 'er_name =' });
  await expect(firstLine).toHaveCount(1);
  await expect(lastLine).toHaveCount(1);

  const firstBox = await firstLine.boundingBox();
  const lastBox = await lastLine.boundingBox();
  expect(firstBox).not.toBeNull();
  expect(lastBox).not.toBeNull();

  await page.mouse.move(firstBox.x + 2, firstBox.y + firstBox.height / 2);
  await page.mouse.down();
  await page.mouse.move(lastBox.x + lastBox.width - 2, lastBox.y + lastBox.height / 2, {
    steps: 6,
  });
  await page.mouse.up();

  await expect
    .poll(() => page.locator('.selected-text').count(), { timeout: 2_000 })
    .toBeGreaterThan(0);

  // The selection spans multiple stacked lines (distinct vertical bands).
  const bandCount = await page.evaluate(() => {
    const tops = new Set(
      Array.from(document.querySelectorAll('.selected-text')).map((node) =>
        Math.round(node.getBoundingClientRect().top),
      ),
    );
    return tops.size;
  });
  expect(bandCount).toBeGreaterThan(1);

  // The first line is selected through its end and continues onto the next
  // line, so its highlight extends past the rendered text's right edge.
  const textRight = await firstLine
    .locator('.view-line-content')
    .evaluate((node) => node.getBoundingClientRect().right);
  const rects = await selectionRectsOnLine(page, firstBox);
  const selectionRight = Math.max(...rects.map((rect) => rect.right));
  expect(selectionRight).toBeGreaterThan(textRight + 1);
});
