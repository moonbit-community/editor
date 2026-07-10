import { expect, test } from '../support/test.js';

const editorSelector = '.async-feature-host > .monaco-editor[data-uri]';
const visibleHoverSelector =
  '[data-content-widget="editor.contrib.resizableContentHoverWidget"] .monaco-hover:not(.hidden)';

const source = (marker) => `pub fn target() -> Int { // ${marker}\n  1\n}\n`;

async function started(page) {
  return page.evaluate(() => globalThis.__asyncFeatureControls.started());
}

async function state(page) {
  return page.evaluate(() => globalThis.__asyncFeatureControls.state());
}

async function waitForNewCall(page, kind, afterId = 0) {
  await expect
    .poll(
      async () =>
        (await started(page)).filter((call) => call.kind === kind && call.id > afterId)
          .length,
      { timeout: 5_000 },
    )
    .toBeGreaterThan(0);
  return (await started(page)).find((call) => call.kind === kind && call.id > afterId);
}

async function waitForSettled(page, callIds) {
  await expect
    .poll(async () => {
      const calls = await started(page);
      return callIds.every((id) => calls.find((call) => call.id === id)?.settled);
    })
    .toBe(true);
}

async function waitForCancelled(page, callIds) {
  await expect
    .poll(async () => {
      const calls = await started(page);
      return callIds.every((id) => calls.find((call) => call.id === id)?.cancelled);
    })
    .toBe(true);
}

async function waitForRenderedTurn(page) {
  await page.evaluate(
    () =>
      new Promise((resolve) =>
        requestAnimationFrame(() => requestAnimationFrame(resolve)),
      ),
  );
}

async function release(page, call, outcome) {
  expect(
    await page.evaluate(
      ({ callId, value }) => globalThis.__asyncFeatureControls.release(callId, value),
      { callId: call.id, value: outcome },
    ),
  ).toBe(true);
}

async function hoverTarget(page) {
  const line = page.locator('.async-feature-host .view-line').filter({ hasText: 'target' });
  await expect(line).toBeVisible();
  const point = await line.evaluate((node) => {
    const walker = document.createTreeWalker(node, NodeFilter.SHOW_TEXT);
    for (let text = walker.nextNode(); text; text = walker.nextNode()) {
      const index = text.textContent.indexOf('target');
      if (index < 0) continue;
      const range = document.createRange();
      range.setStart(text, index);
      range.setEnd(text, index + 'target'.length);
      const rect = range.getBoundingClientRect();
      return { x: rect.x + rect.width / 2, y: rect.y + rect.height / 2 };
    }
    return null;
  });
  expect(point).not.toBeNull();
  await page.mouse.move(0, 0);
  await page.mouse.move(point.x, point.y);
}

async function hoverSecondLine(page) {
  const line = page.locator('.async-feature-host .view-line[data-line="2"]');
  await expect(line).toBeVisible();
  const point = await line.evaluate((node) => {
    const walker = document.createTreeWalker(node, NodeFilter.SHOW_TEXT);
    for (let text = walker.nextNode(); text; text = walker.nextNode()) {
      const index = text.textContent.indexOf('1');
      if (index < 0) continue;
      const range = document.createRange();
      range.setStart(text, index);
      range.setEnd(text, index + 1);
      const rect = range.getBoundingClientRect();
      return { x: rect.x + rect.width / 2, y: rect.y + rect.height / 2 };
    }
    return null;
  });
  expect(point).not.toBeNull();
  await page.mouse.move(point.x, point.y);
}

async function expectNoFeatureDom(page) {
  await expect(page.locator('.async-feature-host .inlay-hint')).toHaveCount(0);
  await expect(page.locator('.async-feature-host .hoverHighlight')).toHaveCount(0);
  await expect(
    page.locator(
      '.async-feature-host [data-content-widget="editor.contrib.resizableContentHoverWidget"]',
    ),
  ).toHaveCount(0);
}

test('rejects stale async inlay and hover results across model ownership changes', async ({
  page,
}) => {
  await page.goto('/browser-tests/component.html?asyncFeatures=1');
  await page.waitForFunction(() => Boolean(globalThis.__asyncFeatureControls));
  await expect(page.locator(editorSelector)).toContainText('initial');

  const initialState = await state(page);
  const uri = initialState.currentUri;
  const modelOne = initialState.currentModelId;
  const initialInlay = await waitForNewCall(page, 'inlay');
  await hoverTarget(page);
  const initialHover = await waitForNewCall(page, 'hover', initialInlay.id);

  await page.evaluate(
    (value) => globalThis.__asyncFeatureControls.set_value(value),
    source('same-object'),
  );
  await expect(page.locator(editorSelector)).toContainText('same-object');
  const afterSetValue = await state(page);
  expect(afterSetValue.currentModelId).toBe(modelOne);
  expect(afterSetValue.internalVersion).toBeGreaterThan(initialState.internalVersion);
  const sameModelInlay = await waitForNewCall(page, 'inlay', initialHover.id);
  await hoverTarget(page);
  const sameModelHoverNonempty = await waitForNewCall(
    page,
    'hover',
    sameModelInlay.id,
  );

  // Old-first/new-last: finish requests invalidated by set_value before the
  // replacement/newest requests. Neither old apply boundary may win.
  const reportsBeforeOldFirst = (await state(page)).resolveReports;
  await release(page, initialInlay, 'old-first inlay');
  await release(page, initialHover, 'old-first hover');
  await waitForSettled(page, [initialInlay.id, initialHover.id]);
  await waitForRenderedTurn(page);
  await expect(page.locator('.async-feature-host .inlay-hint')).toHaveCount(0);
  await expect(
    page.locator('.async-feature-host .inlay-hint', { hasText: 'old-first' }),
  ).toHaveCount(0);
  await expect(page.locator(visibleHoverSelector)).not.toContainText('old-first hover');
  await expect.poll(async () => (await state(page)).resolveReports).toBe(reportsBeforeOldFirst);

  // A different target supersedes the pending same-content hover. Keep both
  // generations so old-last nonempty and empty outcomes are observable.
  await hoverSecondLine(page);
  await waitForCancelled(page, [sameModelHoverNonempty.id]);
  const sameModelHoverEmpty = await waitForNewCall(
    page,
    'hover',
    sameModelHoverNonempty.id,
  );

  await page.evaluate(
    (value) => globalThis.__asyncFeatureControls.replace_same_uri(value),
    source('replacement-newest'),
  );
  await expect(page.locator(editorSelector)).toContainText('replacement-newest');
  await expect.poll(async () => (await state(page)).currentModelId).not.toBe(modelOne);
  const replacementState = await state(page);
  expect(replacementState.currentUri).toBe(uri);
  const replacementInlay = await waitForNewCall(page, 'inlay', sameModelHoverEmpty.id);

  expect(initialInlay.modelId).toBe(modelOne);
  expect(initialHover.modelId).toBe(modelOne);
  expect(sameModelInlay.modelId).toBe(modelOne);
  expect(sameModelHoverNonempty.modelId).toBe(modelOne);
  expect(sameModelHoverEmpty.modelId).toBe(modelOne);
  expect(replacementInlay.modelId).toBe(replacementState.currentModelId);
  expect(replacementInlay.modelId).not.toBe(modelOne);
  expect(replacementInlay.uri).toBe(initialInlay.uri);
  expect(replacementInlay.hostVersion).toBe(initialInlay.hostVersion);
  expect(replacementState.currentHostVersion).toBe(initialState.currentHostVersion);
  expect(replacementState.currentRevision).toBe(initialState.currentRevision);

  await release(page, replacementInlay, 'newest inlay');
  await waitForSettled(page, [replacementInlay.id]);
  const newestInlay = page.locator('.async-feature-host .inlay-hint', {
    hasText: 'newest inlay',
  });
  await expect(newestInlay).toHaveCount(1);
  await expect(page.locator('.async-feature-host .inlay-hint')).toHaveCount(1);

  await hoverTarget(page);
  const replacementHover = await waitForNewCall(page, 'hover', replacementInlay.id);
  expect(replacementHover.modelId).toBe(replacementState.currentModelId);
  const reportsBeforeNewest = (await state(page)).resolveReports;
  await release(page, replacementHover, 'newest hover');
  await waitForSettled(page, [replacementHover.id]);
  await expect
    .poll(async () => (await state(page)).resolveReports)
    .toBe(reportsBeforeNewest + 1);
  const newestResolvedState = await state(page);
  expect(newestResolvedState.reports.at(-1)).toEqual({
    ok: true,
    revision: replacementState.currentRevision,
  });
  const hover = page.locator(visibleHoverSelector);
  await expect(hover).toContainText('newest hover');
  await expect(hover).toHaveCount(1);
  expect((await hover.textContent()).split('newest hover').length - 1).toBe(1);
  await expect(page.locator('.async-feature-host .hoverHighlight')).toHaveCount(1);

  await waitForCancelled(page, [
    sameModelInlay.id,
    sameModelHoverNonempty.id,
    sameModelHoverEmpty.id,
  ]);
  await release(page, sameModelInlay, 'empty');
  await waitForSettled(page, [sameModelInlay.id]);
  await waitForRenderedTurn(page);
  await expect(newestInlay).toHaveCount(1);
  await expect(page.locator('.async-feature-host .inlay-hint')).toHaveCount(1);

  const reportsAfterNewest = (await state(page)).resolveReports;
  await release(page, sameModelHoverNonempty, 'old-last nonempty hover');
  await release(page, sameModelHoverEmpty, 'empty');
  await waitForSettled(page, [sameModelHoverNonempty.id, sameModelHoverEmpty.id]);
  await waitForRenderedTurn(page);
  await expect.poll(async () => (await state(page)).resolveReports).toBe(reportsAfterNewest);
  await expect(hover).toContainText('newest hover');
  await expect(hover).not.toContainText('old-last nonempty hover');
  expect((await hover.textContent()).split('newest hover').length - 1).toBe(1);

  // The wrapper mouseleave keeps the hover when the pointer is still inside
  // the editor DOM and hides it only after the pointer leaves both boxes.
  const editorBox = await page.locator(editorSelector).boundingBox();
  expect(editorBox).not.toBeNull();
  const hoverWidget = page.locator(
    '.async-feature-host [data-content-widget="editor.contrib.resizableContentHoverWidget"]',
  );
  await hoverWidget.dispatchEvent('mouseleave', {
    clientX: editorBox.x + editorBox.width / 2,
    clientY: editorBox.y + editorBox.height / 2,
  });
  await expect(hover).toContainText('newest hover');
  await hoverWidget.dispatchEvent('mouseleave', { clientX: -10, clientY: -10 });
  await expect(page.locator(visibleHoverSelector)).toHaveCount(0);

  const lastCallBeforeModelDispose = Math.max(
    ...(await started(page)).map((call) => call.id),
  );
  await page.evaluate(
    (value) => globalThis.__asyncFeatureControls.set_value(value),
    source('model-dispose-pending'),
  );
  await expect(page.locator(editorSelector)).toContainText('model-dispose-pending');
  await waitForRenderedTurn(page);
  const modelDisposeInlay = await waitForNewCall(page, 'inlay', lastCallBeforeModelDispose);
  await hoverTarget(page);
  const modelDisposeHover = await waitForNewCall(page, 'hover', modelDisposeInlay.id);
  const reportsBeforeModelDispose = (await state(page)).resolveReports;
  await page.evaluate(() => globalThis.__asyncFeatureControls.dispose_model());
  await expect.poll(async () => (await state(page)).attached).toBe(false);
  await waitForCancelled(page, [modelDisposeInlay.id, modelDisposeHover.id]);
  await expect(page.locator(editorSelector)).toHaveCount(0);
  await release(page, modelDisposeInlay, 'model-disposed stale inlay');
  await release(page, modelDisposeHover, 'cancelled-empty');
  await waitForSettled(page, [modelDisposeInlay.id, modelDisposeHover.id]);
  await waitForRenderedTurn(page);
  await expect.poll(async () => (await state(page)).resolveReports).toBe(
    reportsBeforeModelDispose,
  );
  await expectNoFeatureDom(page);

  const lastCallBeforeDetach = Math.max(
    ...(await started(page)).map((call) => call.id),
  );
  await page.evaluate(
    (value) => globalThis.__asyncFeatureControls.replace_same_uri(value),
    source('detach-pending'),
  );
  await expect(page.locator(editorSelector)).toContainText('detach-pending');
  const detachInlay = await waitForNewCall(page, 'inlay', lastCallBeforeDetach);
  await page.mouse.move(0, 0);
  await expect(page.locator(visibleHoverSelector)).toHaveCount(0);
  await hoverTarget(page);
  const detachHover = await waitForNewCall(page, 'hover', detachInlay.id);
  const reportsBeforeDetach = (await state(page)).resolveReports;
  await page.evaluate(() => globalThis.__asyncFeatureControls.detach());
  await expect.poll(async () => (await state(page)).attached).toBe(false);
  await waitForCancelled(page, [detachInlay.id, detachHover.id]);
  await expect(page.locator(editorSelector)).toHaveCount(0);
  await expectNoFeatureDom(page);
  await release(page, detachInlay, 'cancelled-empty');
  await release(page, detachHover, 'error');
  await waitForSettled(page, [detachInlay.id, detachHover.id]);
  await waitForRenderedTurn(page);
  await expect.poll(async () => (await state(page)).resolveReports).toBe(reportsBeforeDetach);
  await expectNoFeatureDom(page);

  const lastCallBeforeDispose = Math.max(
    ...(await started(page)).map((call) => call.id),
  );
  await page.evaluate(
    (value) => globalThis.__asyncFeatureControls.replace_same_uri(value),
    source('dispose-pending'),
  );
  await expect(page.locator(editorSelector)).toContainText('dispose-pending');
  const disposeInlay = await waitForNewCall(page, 'inlay', lastCallBeforeDispose);
  await hoverTarget(page);
  const disposeHover = await waitForNewCall(page, 'hover', disposeInlay.id);
  const reportsBeforeDispose = (await state(page)).resolveReports;
  await page.evaluate(() => globalThis.__asyncFeatureControls.dispose());
  await expect.poll(async () => (await state(page)).disposed).toBe(true);
  await waitForCancelled(page, [disposeInlay.id, disposeHover.id]);
  await expect(page.locator(editorSelector)).toHaveCount(0);
  await expectNoFeatureDom(page);
  await release(page, disposeInlay, 'disposed stale inlay');
  await release(page, disposeHover, 'disposed stale hover');
  await waitForSettled(page, [disposeInlay.id, disposeHover.id]);
  await waitForRenderedTurn(page);
  await expect.poll(async () => (await state(page)).resolveReports).toBe(reportsBeforeDispose);
  await expectNoFeatureDom(page);
  await expect.poll(async () => (await state(page)).pending).toBe(0);
});
