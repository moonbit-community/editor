import { expect, test } from '../support/test.js';
import {
  expectMoonBitReportPassed,
  installMoonBitReporter,
} from '../support/moonbit_reporter.js';

// End-to-end coverage for the comments contrib: gutter glyphs from the
// comment service, the hover "+" affordance, gutter-click create with a real
// textarea submit, edit/delete mutations (observed through the service events
// mirrored on #comment-events), collapse/expand of a host-supplied thread,
// folding interplay, and the overlay widget tracking editor scrolls.

const eventCounts = async (page) => {
  const log = page.locator('#comment-events');
  return {
    created: Number(await log.getAttribute('data-created')),
    updated: Number(await log.getAttribute('data-updated')),
    deleted: Number(await log.getAttribute('data-deleted')),
    lastBody: await log.getAttribute('data-last-body'),
  };
};

// The margin layers rebuild their children via innerHTML on every render, so
// an element handle can detach between resolving a locator and reading its
// box; retry the read (the locator re-resolves per call).
const boxOf = async (locator) => {
  let box = null;
  await expect
    .poll(async () => {
      box = await locator.boundingBox();
      return box;
    }, { timeout: 5_000 })
    .not.toBeNull();
  return box;
};

const clickCenter = async (page, locator) => {
  const box = await boxOf(locator);
  await page.mouse.click(box.x + box.width / 2, box.y + box.height / 2);
};

test('comments: glyphs, create flow, edit/delete, folding, scroll', async ({ page }, testInfo) => {
  const reporter = await installMoonBitReporter(page);
  await page.goto('/browser-tests/comments.html');
  await expect(page.locator('.monaco-editor.readonly-editor')).toContainText(
    'commented_area',
    { timeout: 10_000 },
  );
  const report = await reporter.waitForReport(testInfo, { suite: 'comments' });
  expectMoonBitReportPassed(report, { suite: 'comments' });
  expect(report.metrics.rangeGlyphs).toBeGreaterThanOrEqual(6);
  expect(report.metrics.threadGlyphs).toBe(1);

  const rangeGlyphs = page.locator(
    '.lines-decorations .cldr.comment-diff-added',
  );
  const threadGlyph = page.locator('.lines-decorations .cldr.comment-thread');
  const widget = page.locator('.review-widget');

  // The codicon font is served and the "+" affordance renders through it.
  expect((await page.request.get('/codicon.ttf')).status()).toBe(200);

  // Hovering a commenting-range line swaps in the "+" affordance
  // (CommentingRangeDecorator.updateHover).
  const hoverBox = await boxOf(rangeGlyphs.nth(2));
  await page.mouse.move(hoverBox.x + 2, hoverBox.y + hoverBox.height / 2);
  await expect(page.locator('.lines-decorations .cldr.line-hover')).toHaveCount(1);
  expect(
    await page
      .locator('.lines-decorations .cldr.line-hover')
      .evaluate((el) => getComputedStyle(el, ':before').fontFamily),
  ).toContain('codicon');

  // Gutter click on a commenting-range line opens a template thread with a
  // focused textarea.
  await clickCenter(page, page.locator('.lines-decorations .cldr.line-hover'));
  await expect(widget).toBeVisible();
  const form = page.locator('.review-widget [data-comment-form]');
  await expect(form).toBeFocused();
  await expect(widget).toContainText('Start discussion');

  // Type markdown and submit via the button; the service reports the
  // creation and the thread becomes a real glyph.
  await form.fill('hello **world**');
  await clickCenter(page, page.locator('.review-widget [data-comment-action="submit"]'));
  await expect(widget).toContainText('tester');
  await expect(page.locator('.review-widget .comment-body strong')).toHaveText('world');
  await expect(threadGlyph).toHaveCount(2);
  expect((await eventCounts(page)).created).toBe(1);
  expect((await eventCounts(page)).lastBody).toBe('hello **world**');
  // The submitted thread no longer offers a second comment (no replies).
  await expect(form).toHaveCount(0);

  // Edit the comment in place.
  await clickCenter(page, page.locator('.review-widget [data-comment-action="edit"]'));
  const editArea = page.locator('.review-widget [data-comment-edit]');
  await expect(editArea).toBeVisible();
  await editArea.fill('edited body');
  await clickCenter(page, page.locator('.review-widget [data-comment-action="save"]'));
  await expect(page.locator('.review-widget .comment-body')).toContainText('edited body');
  expect((await eventCounts(page)).updated).toBe(1);

  // Collapse via the glyph and re-expand: the reopened zone must be sized
  // from the thread content (ReviewZoneWidget._refresh's headHeight + body
  // dimensions), not latch at the 2-line spacer and clip the comment away.
  await clickCenter(page, threadGlyph.first());
  await expect(widget).toBeHidden();
  await clickCenter(page, threadGlyph.first());
  await expect(widget).toBeVisible();
  await expect(page.locator('.review-widget .comment-body')).toContainText('edited body');
  await expect
    .poll(async () => (await widget.boundingBox()).height, { timeout: 5_000 })
    .toBeGreaterThan(70);

  // Deleting the only comment removes the thread, its widget, and its glyph.
  await clickCenter(page, page.locator('.review-widget [data-comment-action="delete"]'));
  await expect(widget).toHaveCount(0);
  await expect(threadGlyph).toHaveCount(1);
  expect((await eventCounts(page)).deleted).toBe(1);

  // Dragging along the gutter comments the dragged line span: the multiline
  // dotted decoration tracks the drag, the released range becomes the
  // thread (CommentingRangeDecorator.updateSelection + onEditorMouseUp's
  // drag arm).
  const dragMargin = await page.locator('.margin').boundingBox();
  const dragEditor = await page
    .locator('.monaco-editor.readonly-editor')
    .boundingBox();
  const laneX = dragMargin.x + dragMargin.width - 12;
  const lineY = (line) => dragEditor.y + (line - 0.5) * 18;
  await page.mouse.move(laneX, lineY(2));
  await page.mouse.down();
  await page.mouse.move(laneX, lineY(4), { steps: 3 });
  await expect(
    page.locator('.lines-decorations .cldr.multiline-add'),
  ).toHaveCount(2);
  await page.mouse.up();
  await expect(widget).toBeVisible();
  const dragForm = page.locator('.review-widget [data-comment-form]');
  await expect(dragForm).toBeFocused();
  await dragForm.fill('drag comment');
  await page.keyboard.press('Control+Enter');
  await expect(threadGlyph).toHaveCount(2);
  expect((await eventCounts(page)).created).toBe(2);
  // Clean the drag thread up so the seed-thread steps below see one glyph.
  await clickCenter(page, page.locator('.review-widget [data-comment-action="delete"]'));
  await expect(threadGlyph).toHaveCount(1);

  // Clicking the host-supplied thread's glyph expands both comments; a second
  // click collapses it (addOrToggleCommentAtLine).
  await clickCenter(page, threadGlyph);
  await expect(widget).toBeVisible();
  await expect(widget).toContainText('Host-supplied first comment');
  await expect(widget).toContainText('Host-supplied second comment');
  await expect(widget).toContainText('alice');
  await clickCenter(page, threadGlyph);
  await expect(widget).toBeHidden();

  // Folding the region that contains the thread hides the open widget;
  // unfolding brings it back (view-addressed zone anchors re-derive).
  await clickCenter(page, threadGlyph);
  await expect(widget).toBeVisible();
  await page.locator('.folding-marker[data-line="8"]').click();
  await expect(widget).toBeHidden();
  await page.locator('.folding-marker[data-line="8"]').click();
  await expect(widget).toBeVisible();

  // The overlay widget follows the zone through editor scrolls
  // (IViewZone.onDomNodeTop). The unfolded widget re-enters from the parked
  // offscreen position on the next frame, so wait for an on-screen top first.
  await expect
    .poll(async () => (await widget.boundingBox()).y, { timeout: 5_000 })
    .toBeGreaterThan(0);
  const before = await widget.boundingBox();
  const editor = await page.locator('.monaco-editor.readonly-editor').boundingBox();
  await page.mouse.move(editor.x + editor.width / 2, editor.y + 20);
  await page.mouse.wheel(0, 36);
  await expect
    .poll(async () => Math.round((await widget.boundingBox()).y), { timeout: 5_000 })
    .toBe(Math.round(before.y - 36));

  // Clicking the lane on a line outside the commenting ranges and thread
  // lines (line 7, the blank separator) opens nothing; the seed widget stays.
  const margin = await page.locator('.margin').boundingBox();
  const lineSevenY = editor.y + 6 * 18 + 9 - 36; // line 7 center, scrolled by 36
  await page.mouse.click(margin.x + margin.width - 12, lineSevenY);
  await expect(page.locator('.review-widget')).toHaveCount(1);
  await expect(widget).toBeVisible();

  // The widget chrome follows the shell theme (editorWidget.background in
  // theme.css): flipping to Light Modern restyles the open zone container.
  await page.evaluate(() => {
    document.querySelector('.editor-shell').setAttribute('data-theme', 'light');
  });
  await expect
    .poll(() =>
      page
        .locator('.zone-widget-container')
        .evaluate((el) => getComputedStyle(el).backgroundColor),
    )
    .toBe('rgb(248, 248, 248)');
});
