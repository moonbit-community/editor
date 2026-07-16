import { expect, test } from '../support/test.js';

const viewportLines = [10, 37, 100];
const smoothValues = [false, true];
const inputs = ['physical', 'trackpad'];
const repetitions = 3;
const frameCount = 40;

test.describe('source-relative scroll frame evidence', () => {
  // Keep the pinned 1 ms source-relative threshold and three-run matrix intact.
  // A retry gets a fresh Playwright worker when a long-lived browser process
  // suffers host scheduler jitter; the first failure and trace remain visible.
  test.describe.configure({ retries: 1 });
  test(
    'compares scroll frames and mutations with the pinned Monaco oracle',
    compareScrollFrameParity,
  );
});

async function compareScrollFrameParity({ page }, testInfo) {
  test.setTimeout(180_000);
  await page.addInitScript(installScrollProbe);
  const cells = [];

  for (const lines of viewportLines) {
    for (const smooth of smoothValues) {
      for (const input of inputs) {
        const monaco = await measureImplementation(page, 'monaco', { lines, smooth, input });
        const local = await measureImplementation(page, 'local', { lines, smooth, input });
        const cell = { lines, smooth, input, monaco, local };
        cells.push(cell);
        console.log('[perf] scroll cell', JSON.stringify({
          lines,
          smooth,
          input,
          monaco: monaco.samples.map((sample) => sample.finalScrollTop),
          local: local.samples.map((sample) => sample.finalScrollTop),
        }));

        const expectedTop = input === 'physical' ? 50 : 6;
        for (const sample of [...monaco.samples, ...local.samples]) {
          expect(sample.finalScrollTop).toBe(expectedTop);
          if (smooth && input === 'physical') {
            expect(sample.distinctPositions).toBeGreaterThan(2);
          } else {
            expect(sample.distinctPositions).toBeLessThanOrEqual(2);
          }
        }

        // Three-run medians remove a one-off scheduler interruption while
        // retaining the source-relative gate. One millisecond is the measured
        // headless-browser timestamp jitter at 120Hz; it cannot hide a missed
        // 8.3ms cadence slot and is not a performance budget.
        expect(local.medianDroppedFrameRatio).toBeLessThanOrEqual(
          monaco.medianDroppedFrameRatio,
        );
        expect(local.medianP95FrameInterval).toBeLessThanOrEqual(
          monaco.medianP95FrameInterval + 1.0,
        );

        if (input === 'trackpad') {
          // Same-window steady movement must not invoke either renderer batch.
          for (const sample of local.samples) {
            expect(sample.viewerMetrics.viewLayer ?? {}).toEqual({});
            expect(sample.mutations.innerHTMLWrites ?? 0).toBe(0);
            expect(sample.mutations.insertAdjacentHTML ?? 0).toBe(0);
            expect(sample.mutations.replaceChild ?? 0).toBe(0);
          }
        }
      }
    }
  }

  const observedCadence = percentile(
    cells.flatMap((cell) => [
      ...cell.local.samples.flatMap((sample) => sample.intervals),
      ...cell.monaco.samples.flatMap((sample) => sample.intervals),
    ]),
    0.5,
  );
  const report = {
    suite: 'scroll_frame_parity',
    status: 'passed',
    repetitions,
    frameCount,
    observedCadenceHz: Math.round(1000 / observedCadence),
    deferredCadences: observedCadence < 12
      ? [{ hz: 60, reason: 'this host exposes only the approximately 120Hz rAF cadence' }]
      : [{ hz: 120, reason: 'this host exposes only the approximately 60Hz rAF cadence' }],
    cells,
  };
  await testInfo.attach('scroll-frame-parity', {
    body: JSON.stringify(report, null, 2),
    contentType: 'application/json',
  });
  console.log('[perf] scroll frame parity', JSON.stringify({
    cells: cells.length,
    observedCadenceHz: report.observedCadenceHz,
    maxLocalDroppedRatio: Math.max(...cells.map((cell) => cell.local.medianDroppedFrameRatio)),
    maxMonacoDroppedRatio: Math.max(...cells.map((cell) => cell.monaco.medianDroppedFrameRatio)),
  }));
}

test('covers unchanged, overlap, jump, entering, leaving, and invalid row batches', async ({ page }) => {
  await page.addInitScript(installScrollProbe);
  await page.goto('/browser-tests/component.html?scrollPerf=1&lines=10&smooth=false');
  await expect(page.locator('.scroll-perf-host[data-scroll-ready="true"]')).toHaveCount(1, {
    timeout: 15_000,
  });
  // Seed retained geometry, then move inside the same line band.
  await applyMutationStep(page, 3);
  const unchanged = await applyMutationStep(page, 6);
  expect(unchanged.viewerMetrics.viewLayer ?? {}).toEqual({});
  expect(unchanged.mutations.innerHTMLWrites ?? 0).toBe(0);
  expect(unchanged.mutations.insertAdjacentHTML ?? 0).toBe(0);

  const oneLineOverlap = await applyMutationStep(page, 24);
  expect(oneLineOverlap.viewerMetrics.viewLayer['new-batch']).toBeGreaterThanOrEqual(1);
  const multiLineOverlap = await applyMutationStep(page, 114);
  expect(multiLineOverlap.viewerMetrics.viewLayer['new-batch']).toBeGreaterThanOrEqual(1);
  const noOverlapJump = await applyMutationStep(page, 18_000);
  expect(noOverlapJump.viewerMetrics.viewLayer['new-batch']).toBeGreaterThanOrEqual(1);

  const invalid = await page.evaluate(async () => {
    globalThis.__moonbitViewerScrollMetrics = {};
    globalThis.__scrollProbe.reset();
    globalThis.__scrollProbe.start();
    const visibleLine = Math.floor(globalThis.__scrollPerfControls.getScrollTop() / 18) + 2;
    globalThis.__scrollPerfControls.setSelection(visibleLine);
    await new Promise((resolve) => requestAnimationFrame(() => requestAnimationFrame(resolve)));
    globalThis.__scrollProbe.stop();
    return {
      viewerMetrics: globalThis.__moonbitViewerScrollMetrics,
      mutations: globalThis.__scrollProbe.snapshot(),
    };
  });
  expect(invalid.viewerMetrics.viewLayer['invalid-batch']).toBeGreaterThanOrEqual(1);
  expect(invalid.viewerMetrics.viewLayer['new-batch'] ?? 0).toBe(0);
});

async function applyMutationStep(page, scrollTop) {
  return page.evaluate(async ({ scrollTop }) => {
    globalThis.__moonbitViewerScrollMetrics = {};
    globalThis.__scrollProbe.reset();
    globalThis.__scrollProbe.start();
    globalThis.__scrollPerfControls.setScrollTop(scrollTop);
    await new Promise((resolve) => requestAnimationFrame(() => requestAnimationFrame(resolve)));
    globalThis.__scrollProbe.stop();
    return {
      viewerMetrics: globalThis.__moonbitViewerScrollMetrics,
      mutations: globalThis.__scrollProbe.snapshot(),
    };
  }, { scrollTop });
}

async function measureImplementation(page, implementation, config) {
  if (implementation === 'local') {
    await page.goto(
      `/browser-tests/component.html?scrollPerf=1&lines=${config.lines}&smooth=${config.smooth}`,
    );
    await expect(page.locator('.scroll-perf-host[data-scroll-ready="true"]')).toHaveCount(1, {
      timeout: 15_000,
    });
    await page.evaluate(() => {
      globalThis.__scrollPerfControls.wheelTarget = document.querySelector('.overflow-guard');
    });
  } else {
    await page.goto('/browser-tests/monaco-oracle.html');
    await setupMonaco(page, config);
  }

  // Seed retained-row geometry caches without affecting the wheel classifier.
  await page.evaluate(async () => {
    globalThis.__scrollPerfControls.setScrollTop(3);
    await new Promise((resolve) => requestAnimationFrame(() => requestAnimationFrame(resolve)));
    globalThis.__scrollPerfControls.reset();
    await new Promise((resolve) => requestAnimationFrame(() => requestAnimationFrame(resolve)));
  });

  const samples = [];
  for (let repetition = 0; repetition < repetitions; repetition++) {
    await page.evaluate(async ({ startTop }) => {
      globalThis.__scrollPerfControls.setScrollTop(startTop);
      await new Promise((resolve) => requestAnimationFrame(() => requestAnimationFrame(resolve)));
    }, { startTop: config.input === 'trackpad' ? 3 : 0 });
    samples.push(await runTrace(page, config.input, implementation));
  }
  return {
    samples,
    medianDroppedFrameRatio: median(samples.map((sample) => sample.droppedFrameRatio)),
    medianP95FrameInterval: median(samples.map((sample) => sample.p95FrameInterval)),
  };
}

async function setupMonaco(page, config) {
  await page.evaluate(async ({ lines, smooth }) => {
    const monaco = await import('/browser-tests/monaco-oracle.mjs');
    const host = document.querySelector('#monaco-host');
    host.style.width = '800px';
    host.style.height = `${lines * 18}px`;
    const text = Array.from(
      { length: 3000 },
      (_, index) =>
        `perf line ${index + 1} alpha beta gamma delta epsilon zeta eta theta\n`,
    ).join('');
    const editor = monaco.editor.create(host, {
      value: text,
      language: 'plaintext',
      readOnly: true,
      automaticLayout: false,
      dimension: { width: 800, height: lines * 18 },
      lineHeight: 18,
      fontSize: 13,
      smoothScrolling: smooth,
      scrollBeyondLastLine: false,
      folding: false,
      minimap: { enabled: false },
      scrollbar: { mouseWheelSmoothScroll: true },
    });
    const decorations = [];
    for (let line = 2; line <= 3000; line += 2) {
      decorations.push({
        range: new monaco.Range(line, 1, line, 10),
        options: {
          className: 'scroll-perf-line',
          inlineClassName: 'scroll-perf-inline',
          description: 'scroll performance oracle',
        },
      });
    }
    editor.createDecorationsCollection(decorations);
    editor.changeViewZones((accessor) => {
      const node = document.createElement('div');
      node.textContent = 'scroll performance view zone';
      accessor.addZone({
        afterLineNumber: 5,
        heightInPx: 18,
        domNode: node,
      });
    });
    editor.layout({ width: 800, height: lines * 18 });
    globalThis.__scrollPerfControls = {
      reset: () => editor.setScrollPosition({ scrollTop: 0, scrollLeft: 0 }, 1),
      setScrollTop: (top) => editor.setScrollPosition({ scrollTop: top }, 1),
      getScrollTop: () => editor.getScrollTop(),
      setSelection: (line) => editor.setSelection(new monaco.Selection(line, 1, line, 5)),
      wheelTarget: document.querySelector('.monaco-editor[role="code"]'),
    };
  }, config);
}

async function runTrace(page, input, implementation) {
  await page.evaluate(({ frameCount }) => {
    globalThis.__moonbitViewerScrollMetrics = {};
    const probe = globalThis.__scrollProbe;
    probe.reset();
    probe.start();
    const timestamps = [];
    const positions = [];
    globalThis.__scrollTracePromise = new Promise((resolve) => {
      const sample = (timestamp) => {
        timestamps.push(timestamp);
        positions.push(globalThis.__scrollPerfControls.getScrollTop());
        if (timestamps.length >= frameCount) {
          resolve();
        } else {
          requestAnimationFrame(sample);
        }
      };
      requestAnimationFrame(sample);
      }).then(() => {
        probe.stop();
        const intervals = timestamps.slice(1).map(
          (time, index) => time - timestamps[index],
        );
        const cadence = percentileInBrowser(intervals, 0.5);
        const longFrames = intervals.filter(
          (interval) => interval > cadence * 1.5,
        ).length;
        return {
          timestamps,
          positions,
          intervals,
          finalScrollTop: globalThis.__scrollPerfControls.getScrollTop(),
          distinctPositions: new Set(positions).size,
          longFrameCount: longFrames,
          droppedFrameRatio: intervals.length ? longFrames / intervals.length : 0,
          p50FrameInterval: cadence,
          p95FrameInterval: percentileInBrowser(intervals, 0.95),
          mutations: probe.snapshot(),
          viewerMetrics: globalThis.__moonbitViewerScrollMetrics,
        };
      });
  }, { frameCount });
  await page.evaluate(({ input }) => {
    const event = new WheelEvent('wheel', {
      deltaX: input === 'trackpad' ? 1 : 0,
      deltaY: input === 'trackpad' ? 2.37 : 40,
      deltaMode: 0,
      bubbles: true,
      cancelable: true,
    });
    // Chromium synthesizes legacy wheelDelta accessors as zero for a JS-made
    // WheelEvent. Shadow them with undefined so Monaco's StandardWheelEvent
    // takes the modern deltaX/deltaY branch, matching the local normalizer.
    for (const key of ['wheelDelta', 'wheelDeltaX', 'wheelDeltaY']) {
      Object.defineProperty(event, key, { value: undefined });
    }
    globalThis.__scrollPerfControls.wheelTarget.dispatchEvent(event);
  }, { input });
  return page.evaluate(() => globalThis.__scrollTracePromise);
}

function percentile(values, quantile) {
  if (!values.length) return 0;
  const sorted = [...values].sort((a, b) => a - b);
  return sorted[Math.min(sorted.length - 1, Math.floor(sorted.length * quantile))];
}

function median(values) {
  return percentile(values, 0.5);
}

function installScrollProbe() {
  const metrics = {};
  let active = false;
  const increment = (key) => {
    if (active) metrics[key] = (metrics[key] || 0) + 1;
  };
  const wrapMethod = (prototype, key, metric) => {
    const original = prototype[key];
    if (typeof original !== 'function') return;
    prototype[key] = function (...args) {
      increment(metric);
      return original.apply(this, args);
    };
  };
  wrapMethod(Element.prototype, 'setAttribute', 'attributeWrites');
  wrapMethod(Element.prototype, 'insertAdjacentHTML', 'insertAdjacentHTML');
  wrapMethod(Node.prototype, 'insertBefore', 'insertBefore');
  wrapMethod(Node.prototype, 'appendChild', 'appendChild');
  wrapMethod(Node.prototype, 'removeChild', 'removeChild');
  wrapMethod(Node.prototype, 'replaceChild', 'replaceChild');
  wrapMethod(Element.prototype, 'getBoundingClientRect', 'forcedLayoutReads');
  wrapMethod(Element.prototype, 'getClientRects', 'forcedLayoutReads');
  const innerHTML = Object.getOwnPropertyDescriptor(Element.prototype, 'innerHTML');
  if (innerHTML?.set) {
    Object.defineProperty(Element.prototype, 'innerHTML', {
      ...innerHTML,
      set(value) {
        increment('innerHTMLWrites');
        if (active) {
          metrics.innerHTMLTargets ??= [];
          metrics.innerHTMLTargets.push(this.className || this.tagName);
        }
        return innerHTML.set.call(this, value);
      },
    });
  }
  for (const key of ['top', 'left', 'width', 'height', 'lineHeight', 'transform', 'contain']) {
    const descriptor = Object.getOwnPropertyDescriptor(CSSStyleDeclaration.prototype, key);
    if (!descriptor?.set) continue;
    Object.defineProperty(CSSStyleDeclaration.prototype, key, {
      ...descriptor,
      set(value) {
        increment('styleWrites');
        return descriptor.set.call(this, value);
      },
    });
  }
  for (const key of [
    'offsetWidth', 'offsetHeight', 'clientWidth', 'clientHeight',
    'scrollWidth', 'scrollHeight',
  ]) {
    const descriptor = Object.getOwnPropertyDescriptor(HTMLElement.prototype, key);
    if (!descriptor?.get) continue;
    Object.defineProperty(HTMLElement.prototype, key, {
      ...descriptor,
      get() {
        increment('forcedLayoutReads');
        return descriptor.get.call(this);
      },
    });
  }
  globalThis.__scrollProbe = {
    reset() {
      for (const key of Object.keys(metrics)) delete metrics[key];
    },
    start() { active = true; },
    stop() { active = false; },
    snapshot() { return { ...metrics }; },
  };
  globalThis.percentileInBrowser = (values, quantile) => {
    if (!values.length) return 0;
    const sorted = [...values].sort((a, b) => a - b);
    return sorted[Math.min(sorted.length - 1, Math.floor(sorted.length * quantile))];
  };
}
