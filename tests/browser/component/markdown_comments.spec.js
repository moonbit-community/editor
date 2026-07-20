import { expect, test } from '../support/test.js';
import {
  expectMoonBitReportPassed,
  installMoonBitReporter,
} from '../support/moonbit_reporter.js';

const host = '.markdown-comments-host';
const editor = `${host} > .monaco-editor.readonly-editor`;
const zone = `${editor} .moonbit-viewer-markdown-comment`;
const content = '.moonbit-viewer-markdown-comment-content';
const imageUrl = 'https://images.example.test/markdown-comment.svg';

const fixtureSvg = `
  <svg xmlns="http://www.w3.org/2000/svg" width="180" height="48" viewBox="0 0 180 48">
    <rect width="180" height="48" rx="4" fill="#315f8c"/>
    <text x="12" y="30" fill="white" font-size="16">markdown fixture</text>
  </svg>
`;

async function settle(page, delay = 50) {
  await page.evaluate(
    () =>
      new Promise((resolve) =>
        requestAnimationFrame(() =>
          requestAnimationFrame(() => requestAnimationFrame(resolve)),
        ),
      ),
  );
  if (delay > 0) await page.waitForTimeout(delay);
}

async function mountMarkdownComments(page, testInfo) {
  await page.route(imageUrl, (route) =>
    route.fulfill({
      status: 200,
      contentType: 'image/svg+xml',
      body: fixtureSvg,
    }),
  );
  await page.addInitScript(() => {
    globalThis.__markdownCommentOpened = [];
    globalThis.open = (...args) => {
      globalThis.__markdownCommentOpened.push(args);
      return { opener: {} };
    };
  });
  const reporter = await installMoonBitReporter(page);
  await page.goto('/browser-tests/component.html?markdownComments=1');
  await page.waitForFunction(() => Boolean(globalThis.__markdownCommentsControls));
  const report = await reporter.waitForReport(testInfo, {
    suite: 'markdown_comments',
    timeout: 15_000,
  });
  expectMoonBitReportPassed(report, { suite: 'markdown_comments' });
  expect(report.metrics.initialZones).toBe(3);
  await expect(page.locator(zone)).toHaveCount(3);
  await settle(page);
  return reporter;
}

async function control(page, name, ...args) {
  return page.evaluate(
    ({ method, values }) =>
      globalThis.__markdownCommentsControls[method](...values),
    { method: name, values: args },
  );
}

async function state(page) {
  return control(page, 'state');
}

async function zoneRanges(page) {
  return page.locator(zone).evaluateAll((nodes) =>
    nodes.map((node) => [
      Number(node.getAttribute('data-start-line')),
      Number(node.getAttribute('data-end-line')),
    ]),
  );
}

async function transitionFrames(page, action) {
  return page.evaluate(async (method) => {
    const controls = globalThis.__markdownCommentsControls;
    const frames = [];
    const sample = (phase) => {
      const rawSourceVisible = Array.from(
        document.querySelectorAll(
          '.markdown-comments-host .view-lines .view-line',
        ),
      ).some((node) => node.textContent.includes('///'));
      const replacementCount = document.querySelectorAll(
        '.markdown-comments-host .moonbit-viewer-markdown-comment',
      ).length;
      frames.push({
        phase,
        rawSourceVisible,
        replacementCount,
        sourceAndReplacement: rawSourceVisible && replacementCount > 0,
      });
    };
    await new Promise((resolve) =>
      requestAnimationFrame(() => {
        sample('before');
        controls[method]();
        sample('synchronous');
        requestAnimationFrame(() => {
          sample('first-frame');
          requestAnimationFrame(() => {
            sample('second-frame');
            resolve();
          });
        });
      }),
    );
    return frames;
  }, action);
}

test('public Viewer replaces whole-line source with themed Markdown while model and native input stay truthful', async ({
  page,
}, testInfo) => {
  await page.context().grantPermissions(['clipboard-read', 'clipboard-write']);
  const reporter = await mountMarkdownComments(page, testInfo);
  try {
    expect(await zoneRanges(page)).toEqual([
      [1, 3],
      [5, 9],
      [10, 16],
    ]);

    const zones = page.locator(zone);
    await expect(zones.nth(0).locator('h1')).toHaveText('Start comment');
    await expect(zones.nth(1).locator('h2')).toHaveText('Middle comment');
    await expect(zones.nth(1).locator('strong')).toHaveText(
      'same-key initial phrase',
    );
    await expect(zones.nth(1).locator('li')).toHaveCount(2);
    const fencedCode = zones.nth(2).locator('.monaco-tokenized-source');
    await expect(fencedCode).toContainText(
      'let fenced_value = 42',
    );
    await expect(fencedCode.locator('.mtk3')).not.toHaveCount(0);
    const renderedImage = zones.nth(2).locator('img');
    await expect(renderedImage).toHaveAttribute('src', imageUrl);
    await expect
      .poll(() =>
        renderedImage.evaluate((node) => ({
          complete: node.complete,
          width: node.naturalWidth,
          height: node.naturalHeight,
        })),
      )
      .toEqual({ complete: true, width: 180, height: 48 });

    // The retained ViewZones container is intentionally aria-hidden, so this
    // deferred-accessibility surface cannot be located through the role tree.
    const link = zones.nth(0).locator('a');
    await expect(link).toHaveText('fixture link');
    await expect(link).toHaveAttribute('role', 'link');
    await expect(link).toHaveAttribute('tabindex', '0');
    await expect(link).not.toHaveAttribute('href', /.+/);
    await expect(zones.nth(0).locator(content)).toHaveCSS(
      'user-select',
      'text',
    );
    await expect(page.locator(`${editor} .view-zones`)).toHaveAttribute(
      'aria-hidden',
      'true',
    );

    await expect
      .poll(() =>
        zones.evaluateAll((nodes) =>
          nodes.every((outer) => {
            const inner = outer.querySelector(
              '.moonbit-viewer-markdown-comment-content',
            );
            const outerHeight = outer.getBoundingClientRect().height;
            const innerHeight = inner.offsetHeight;
            const styleHeight = Number.parseFloat(outer.style.height);
            return (
              innerHeight > 0 &&
              outerHeight > 0 &&
              Math.abs(outerHeight - innerHeight) <= 1 &&
              Math.abs(styleHeight - innerHeight) <= 1
            );
          }),
        ),
      )
      .toBe(true);

    const geometry = await page.locator(editor).evaluate((root) => {
      const rect = (node) => {
        const value = node.getBoundingClientRect();
        return {
          top: value.top,
          bottom: value.bottom,
          left: value.left,
          height: value.height,
        };
      };
      const byRange = (start, end) =>
        root.querySelector(
          `.moonbit-viewer-markdown-comment[data-start-line="${start}"][data-end-line="${end}"]`,
        );
      const lines = Array.from(root.querySelectorAll('.view-lines .view-line'));
      const lineWith = (needle) =>
        lines.find((node) => node.textContent.includes(needle));
      return {
        start: rect(byRange(1, 3)),
        middle: rect(byRange(5, 9)),
        eof: rect(byRange(10, 16)),
        alpha: rect(lineWith('alpha_code_truth')),
        omega: rect(lineWith('omega_code_truth')),
        startHeading: rect(byRange(1, 3).querySelector('h1')),
        eofCode: rect(
          byRange(10, 16).querySelector('.monaco-tokenized-source'),
        ),
        alphaContent: rect(
          lineWith('alpha_code_truth').querySelector('.view-line-content'),
        ),
        omegaContent: rect(
          lineWith('omega_code_truth').querySelector('.view-line-content'),
        ),
        visibleLineCount: lines.length,
        visibleSourceText: lines.map((node) => node.textContent).join('\n'),
      };
    });
    expect(geometry.start.bottom).toBeLessThanOrEqual(geometry.alpha.top + 1);
    expect(geometry.alpha.bottom).toBeLessThanOrEqual(geometry.middle.top + 1);
    expect(geometry.middle.bottom).toBeLessThanOrEqual(geometry.omega.top + 1);
    expect(geometry.omega.bottom).toBeLessThanOrEqual(geometry.eof.top + 1);
    expect(
      Math.abs(geometry.startHeading.left - geometry.alphaContent.left),
    ).toBeLessThanOrEqual(1);
    expect(
      Math.abs(geometry.eofCode.left - geometry.omegaContent.left),
    ).toBeLessThanOrEqual(1);
    expect(geometry.visibleLineCount).toBeGreaterThan(3);
    expect(geometry.visibleSourceText).not.toContain('///');
    expect(geometry.visibleSourceText).not.toContain('Start comment');

    const initialState = await state(page);
    expect(initialState).toMatchObject({
      attachedKind: 'primary',
      primaryAttachedEditors: 1,
      replacementAttachedEditors: 0,
      selection: {
        anchorLine: 1,
        anchorColumn: 1,
        activeLine: 1,
        activeColumn: 1,
      },
    });
    expect(initialState.attachedValue).toBe(initialState.primaryValue);
    expect(initialState.primaryValue).toContain('/// # Start comment');
    expect(initialState.primaryValue).toContain(imageUrl);

    await control(page, 'set_model_selection');
    await control(page, 'focus');
    await control(page, 'clear_input_log');
    expect((await state(page)).selection).toEqual({
      anchorLine: 3,
      anchorColumn: 1,
      activeLine: 3,
      activeColumn: 17,
    });
    await page.keyboard.press('ControlOrMeta+C');
    expect(
      await page.evaluate(() => globalThis.__readonlyEditorCopiedText),
    ).toBe('alpha_code_truth');
    expect(
      await page.evaluate(() => globalThis.__readonlyEditorCopiedHtml),
    ).toContain('alpha_code_truth');
    expect(await page.evaluate(() => navigator.clipboard.readText())).toBe(
      'alpha_code_truth',
    );
    expect((await control(page, 'copies')).at(-1)).toMatchObject({
      defaultPrevented: true,
      nativeSelection: '',
    });

    const nativeSelection = await page.evaluate(() => {
      const controls = globalThis.__markdownCommentsControls;
      controls.set_model_selection();
      controls.focus();
      controls.clear_input_log();
      const target = document.querySelector(
        '.moonbit-viewer-markdown-comment strong',
      );
      const range = document.createRange();
      range.selectNodeContents(target);
      const selection = document.getSelection();
      selection.removeAllRanges();
      selection.addRange(range);
      return selection.toString();
    });
    expect(nativeSelection).toBe('same-key initial phrase');
    await page.keyboard.press('ControlOrMeta+C');
    expect(await control(page, 'copies')).toEqual([
      expect.objectContaining({
        defaultPrevented: false,
        nativeSelection: 'same-key initial phrase',
      }),
    ]);
    expect(
      await page.evaluate(() => globalThis.__readonlyEditorCopiedText || ''),
    ).toBe('');
    expect(await page.evaluate(() => navigator.clipboard.readText())).toBe(
      'same-key initial phrase',
    );

    await page.evaluate(() => document.getSelection()?.removeAllRanges());
    const selectionBeforeLink = (await state(page)).selection;
    await link.click();
    await link.focus();
    await page.keyboard.press('ArrowLeft');
    await page.keyboard.press('Enter');
    await page.keyboard.press('Space');
    await settle(page);
    expect((await state(page)).selection).toEqual(selectionBeforeLink);
    expect(await page.evaluate(() => globalThis.__markdownCommentOpened)).toEqual([
      ['https://example.test/docs', '_blank', 'noopener,noreferrer'],
      ['https://example.test/docs', '_blank', 'noopener,noreferrer'],
      ['https://example.test/docs', '_blank', 'noopener,noreferrer'],
    ]);
    const keyLog = await control(page, 'keys');
    expect(keyLog.slice(-3)).toEqual([
      expect.objectContaining({
        key: 'ArrowLeft',
        defaultPrevented: false,
        targetRole: 'link',
      }),
      expect.objectContaining({
        key: 'Enter',
        defaultPrevented: true,
        targetRole: 'link',
      }),
      expect.objectContaining({
        key: ' ',
        defaultPrevented: true,
        targetRole: 'link',
      }),
    ]);
  } finally {
    reporter.dispose();
  }
});

test('same-key replacement retains zone identity, reflows, and reconciles add remove move atomically', async ({
  page,
}, testInfo) => {
  const reporter = await mountMarkdownComments(page, testInfo);
  try {
    const middleSelector = `${zone}[data-start-line="5"][data-end-line="9"]`;
    const oldOuter = await page.locator(middleSelector).elementHandle();
    const oldContent = await page
      .locator(`${middleSelector} ${content}`)
      .elementHandle();
    const oldHeading = await page.locator(`${middleSelector} h2`).elementHandle();
    expect(oldOuter).not.toBeNull();
    expect(oldContent).not.toBeNull();
    expect(oldHeading).not.toBeNull();
    const versionBefore = (await state(page)).primaryVersion;

    const updateFrames = await transitionFrames(page, 'same_key_update');
    expect(updateFrames.map((frame) => frame.sourceAndReplacement)).toEqual([
      false,
      false,
      false,
      false,
    ]);
    expect(updateFrames.every((frame) => !frame.rawSourceVisible)).toBe(true);
    await expect(page.locator(middleSelector)).toContainText('Middle updated');
    await expect(page.locator(middleSelector)).not.toContainText(
      'same-key initial phrase',
    );
    expect(await oldOuter.evaluate((node, selector) =>
      node === document.querySelector(selector), middleSelector)).toBe(true);
    expect(await oldContent.evaluate((node, selector) =>
      node === document.querySelector(selector), `${middleSelector} ${content}`)).toBe(true);
    expect(await oldHeading.evaluate((node) => node.isConnected)).toBe(false);
    expect((await state(page)).primaryVersion).toBeGreaterThan(versionBefore);
    expect(await zoneRanges(page)).toEqual([
      [1, 3],
      [5, 9],
      [10, 16],
    ]);

    const wideHeight = await page
      .locator(`${middleSelector} ${content}`)
      .evaluate((node) => node.offsetHeight);
    await control(page, 'resize', 240);
    await expect
      .poll(() =>
        page
          .locator(`${middleSelector} ${content}`)
          .evaluate((node) => node.offsetHeight),
      )
      .toBeGreaterThan(wideHeight);
    const narrowHeight = await page
      .locator(`${middleSelector} ${content}`)
      .evaluate((node) => node.offsetHeight);
    await expect
      .poll(() =>
        page.locator(middleSelector).evaluate((node) => {
          const box = node.getBoundingClientRect().height;
          const style = Number.parseFloat(node.style.height);
          const inner = node.querySelector(
            '.moonbit-viewer-markdown-comment-content',
          ).offsetHeight;
          return (
            Math.abs(box - inner) <= 1 && Math.abs(style - inner) <= 1
          );
        }),
      )
      .toBe(true);
    expect(await oldOuter.evaluate((node) => node.isConnected)).toBe(true);
    await control(page, 'resize', 620);
    await expect
      .poll(() =>
        page
          .locator(`${middleSelector} ${content}`)
          .evaluate((node) => node.offsetHeight),
      )
      .toBeLessThan(narrowHeight);

    const previousZones = await page.locator(zone).elementHandles();
    const restructureFrames = await transitionFrames(page, 'restructure');
    expect(restructureFrames.every((frame) => !frame.sourceAndReplacement)).toBe(
      true,
    );
    expect(restructureFrames.every((frame) => !frame.rawSourceVisible)).toBe(true);
    await expect(page.locator(zone)).toHaveCount(3);
    await expect(page.locator(zone)).toContainText([
      'Middle moved',
      'Added comment',
      'EOF moved',
    ]);
    expect(await zoneRanges(page)).toEqual([
      [2, 4],
      [5, 7],
      [8, 10],
    ]);
    for (const previous of previousZones) {
      expect(await previous.evaluate((node) => node.isConnected)).toBe(false);
    }
    await expect(page.locator(editor)).not.toContainText('Start comment');
    expect((await state(page)).attachedValue).toContain('/// ### Added comment');
    expect(
      await page
        .locator(`${editor} .view-lines`)
        .evaluate((node) => node.textContent),
    ).not.toContain('///');
  } finally {
    reporter.dispose();
  }
});

test('folding hides a Markdown zone for another hidden source while its own source remains ignored', async ({
  page,
}, testInfo) => {
  const reporter = await mountMarkdownComments(page, testInfo);
  try {
    await control(page, 'folding_source');
    await expect(page.locator(zone)).toHaveCount(1);
    await expect(page.locator(zone)).toContainText('Folded Markdown comment');
    expect(await zoneRanges(page)).toEqual([[2, 4]]);
    const retainedZone = await page.locator(zone).elementHandle();
    expect(retainedZone).not.toBeNull();

    // The comment contribution's own hidden-source projection must not hide
    // its replacement zone.
    await expect(page.locator(zone)).toBeVisible();
    await expect(page.locator(zone)).toHaveAttribute(
      'monaco-visible-view-zone',
      'true',
    );
    await expect(page.locator(editor)).toContainText('folded_child_code');

    const expanded = page.locator(
      `${editor} .margin-view-overlays .cldr.codicon-folding-expanded`,
    );
    const collapsed = page.locator(
      `${editor} .margin-view-overlays .cldr.codicon-folding-collapsed`,
    );
    await expect(expanded).toHaveCount(1);
    await expanded.click({ force: true });

    // Folding is a distinct hidden-area source, so it suppresses both the
    // indented code and the retained replacement zone.
    await expect(page.locator(editor)).not.toContainText('folded_child_code');
    await expect(page.locator(zone)).not.toBeVisible();
    await expect(collapsed).toHaveCount(1);
    expect(await retainedZone.evaluate((node) => node.isConnected)).toBe(true);

    await collapsed.click({ force: true });
    await expect(page.locator(editor)).toContainText('folded_child_code');
    await expect(page.locator(zone)).toBeVisible();
    expect(
      await retainedZone.evaluate(
        (node) =>
          node ===
          document.querySelector('.moonbit-viewer-markdown-comment'),
      ),
    ).toBe(true);
  } finally {
    reporter.dispose();
  }
});

test('offscreen Markdown measures before first reveal and reflows without a scroll jump', async ({
  page,
}, testInfo) => {
  const reporter = await mountMarkdownComments(page, testInfo);
  try {
    await control(page, 'offscreen_source');
    await expect(page.locator(zone)).toHaveCount(1);
    expect(await zoneRanges(page)).toEqual([[81, 91]]);
    const retained = await page.locator(zone).elementHandle();
    expect(retained).not.toBeNull();
    await expect(page.locator(zone)).not.toBeVisible();

    // Eighty short visible lines contribute 1440px. The provisional zone is
    // only one 18px line; crossing this threshold proves the still-offscreen
    // heading/list/image body has already entered scroll geometry.
    await expect
      .poll(async () => (await state(page)).scrollHeight)
      .toBeGreaterThan(1560);
    const wideHeight = (await state(page)).scrollHeight;

    await control(page, 'resize', 240);
    await expect(page.locator(zone)).not.toBeVisible();
    await expect
      .poll(async () => (await state(page)).scrollHeight)
      .toBeGreaterThan(wideHeight + 20);
    const narrowHeight = (await state(page)).scrollHeight;

    await control(page, 'scroll_to_bottom');
    await settle(page);
    await expect(page.locator(zone)).toBeVisible();
    expect(
      await retained.evaluate(
        (node) =>
          node ===
          document.querySelector('.moonbit-viewer-markdown-comment'),
      ),
    ).toBe(true);
    await expect
      .poll(async () =>
        Math.abs((await state(page)).scrollHeight - narrowHeight),
      )
      .toBeLessThanOrEqual(1);
    await expect
      .poll(() =>
        page.locator(zone).evaluate((outer) => {
          const inner = outer.querySelector(
            '.moonbit-viewer-markdown-comment-content',
          );
          return Math.abs(outer.getBoundingClientRect().height - inner.offsetHeight);
        }),
      )
      .toBeLessThanOrEqual(1);
  } finally {
    reporter.dispose();
  }
});

test('model detach replacement reattach and Viewer disposal release every rendered zone', async ({
  page,
}, testInfo) => {
  const reporter = await mountMarkdownComments(page, testInfo);
  try {
    const initialRoot = await page.locator(editor).elementHandle();
    const initialZone = await page.locator(zone).first().elementHandle();
    expect(initialRoot).not.toBeNull();
    expect(initialZone).not.toBeNull();

    await control(page, 'detach');
    await settle(page);
    // Detach restores the no-model placeholder, which deliberately carries
    // the same editor root classes but has no live view/model DOM.
    await expect(page.locator(editor)).toHaveCount(1);
    await expect(page.locator(`${editor} .lines-content`)).toHaveCount(0);
    await expect(page.locator(zone)).toHaveCount(0);
    expect(await initialRoot.evaluate((node) => node.isConnected)).toBe(false);
    expect(await initialZone.evaluate((node) => node.isConnected)).toBe(false);
    expect(await state(page)).toMatchObject({
      attachedKind: 'none',
      attachedValue: '',
      primaryAttachedEditors: 0,
      replacementAttachedEditors: 0,
    });

    await control(page, 'attach_replacement');
    await expect(page.locator(editor)).toHaveCount(1);
    await expect(page.locator(zone)).toHaveCount(1);
    await expect(page.locator(zone)).toContainText('Replacement comment');
    expect(await zoneRanges(page)).toEqual([[2, 4]]);
    expect(await state(page)).toMatchObject({
      attachedKind: 'replacement',
      replacementAttachedEditors: 1,
      primaryAttachedEditors: 0,
    });
    const replacementRoot = await page.locator(editor).elementHandle();
    const replacementZone = await page.locator(zone).elementHandle();

    await control(page, 'reattach_primary');
    await expect(page.locator(zone)).toHaveCount(3);
    await expect(page.locator(zone).first()).toContainText('Start comment');
    expect(await replacementRoot.evaluate((node) => node.isConnected)).toBe(false);
    expect(await replacementZone.evaluate((node) => node.isConnected)).toBe(false);
    expect(await state(page)).toMatchObject({
      attachedKind: 'primary',
      primaryAttachedEditors: 1,
      replacementAttachedEditors: 0,
    });
    const reattachedZones = await page.locator(zone).elementHandles();
    expect(
      await reattachedZones[0].evaluate(
        (node, original) => node === original,
        initialZone,
      ),
    ).toBe(false);

    await control(page, 'dispose');
    await control(page, 'dispose');
    await settle(page);
    await expect(page.locator(editor)).toHaveCount(0);
    await expect(page.locator(zone)).toHaveCount(0);
    await expect(page.locator(host)).toBeEmpty();
    expect(await state(page)).toMatchObject({
      attachedKind: 'none',
      attachedValue: '',
      primaryAttachedEditors: 0,
      replacementAttachedEditors: 0,
      disposed: true,
    });
    for (const rendered of reattachedZones) {
      expect(await rendered.evaluate((node) => node.isConnected)).toBe(false);
    }
  } finally {
    reporter.dispose();
  }
});
