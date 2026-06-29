const LINE_HEIGHT = 18;
const CHAR_WIDTH = 7.2;
const VERTICAL_SCROLLBAR = 14;
const HORIZONTAL_SCROLLBAR = 12;
const HOVER_SCROLLBAR = 10;
const MINIMUM_SLIDER = 20;
// Monaco resizableContentWidget.ts BOTTOM_HEIGHT: the margin kept between the
// hover and the editor bottom edge when measuring how much room is below.
const BOTTOM_HEIGHT = 24;

let sourceLines = [''];
let scrollTop = 0;
let scrollLeft = 0;
let hoverPayloads = {};

const container = document.getElementById('container');
const scrollable = document.createElement('div');
scrollable.className = 'monaco-scrollable-element editor-scrollable';
scrollable.setAttribute('role', 'presentation');
const linesContent = document.createElement('div');
linesContent.className = 'lines-content';
const viewLines = document.createElement('div');
viewLines.className = 'view-lines';
linesContent.appendChild(viewLines);
scrollable.appendChild(linesContent);
const editorBars = createBars(VERTICAL_SCROLLBAR, HORIZONTAL_SCROLLBAR);
appendBars(scrollable, editorBars);
container.appendChild(scrollable);

function escapeHtml(value) {
  return String(value)
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');
}

function createBars(verticalSize, horizontalSize) {
  const horizontal = document.createElement('div');
  horizontal.className = 'scrollbar horizontal invisible';
  horizontal.setAttribute('role', 'presentation');
  horizontal.setAttribute('aria-hidden', 'true');
  const horizontalSlider = document.createElement('div');
  horizontalSlider.className = 'slider';
  horizontal.appendChild(horizontalSlider);
  const vertical = document.createElement('div');
  vertical.className = 'scrollbar vertical invisible';
  vertical.setAttribute('role', 'presentation');
  vertical.setAttribute('aria-hidden', 'true');
  const verticalSlider = document.createElement('div');
  verticalSlider.className = 'slider';
  vertical.appendChild(verticalSlider);
  const leftShadow = document.createElement('div');
  leftShadow.className = 'shadow';
  const topShadow = document.createElement('div');
  topShadow.className = 'shadow';
  const topLeftShadow = document.createElement('div');
  topLeftShadow.className = 'shadow';
  return {
    horizontal,
    horizontalSlider,
    vertical,
    verticalSlider,
    leftShadow,
    topShadow,
    topLeftShadow,
    verticalSize,
    horizontalSize,
    verticalRevealed: false,
    horizontalRevealed: false,
    verticalFade: false,
    horizontalFade: false,
  };
}

function appendBars(parent, bars) {
  parent.appendChild(bars.horizontal);
  parent.appendChild(bars.vertical);
  parent.appendChild(bars.leftShadow);
  parent.appendChild(bars.topShadow);
  parent.appendChild(bars.topLeftShadow);
}

function scrollbarState({ visibleSize, scrollSize, scrollPosition, oppositeSize }) {
  const available = Math.max(0, Math.round(visibleSize) - Math.round(oppositeSize));
  const representable = Math.max(0, available);
  const needed = scrollSize > 0 && scrollSize > visibleSize;
  if (!needed) {
    return { available, needed, sliderSize: representable, ratio: 0, sliderPosition: 0 };
  }
  const sliderSize = Math.round(
    Math.max(MINIMUM_SLIDER, Math.floor((visibleSize * representable) / scrollSize)),
  );
  const ratio = (representable - sliderSize) / (scrollSize - visibleSize);
  return {
    available,
    needed,
    sliderSize,
    ratio,
    sliderPosition: Math.round(scrollPosition * ratio),
  };
}

function scrollbarClass(bars, axis, needed) {
  const revealed = axis === 'vertical' ? bars.verticalRevealed : bars.horizontalRevealed;
  const fade = axis === 'vertical' ? bars.verticalFade : bars.horizontalFade;
  return `${needed && revealed ? 'visible' : `invisible${needed && fade ? ' fade' : ''}`} scrollbar ${axis}`;
}

function writeBars(bars, dimensions, position, horizontalLeft = 0, reveal = false) {
  const vertical = scrollbarState({
    visibleSize: dimensions.height,
    scrollSize: dimensions.scrollHeight,
    scrollPosition: position.top,
    oppositeSize: 0,
  });
  if (vertical.needed && reveal) {
    bars.verticalRevealed = true;
    bars.verticalFade = false;
  }
  if (!vertical.needed) {
    bars.verticalRevealed = false;
    bars.verticalFade = false;
  }
  bars.vertical.className = scrollbarClass(bars, 'vertical', vertical.needed);
  bars.vertical.style.cssText = `width:${bars.verticalSize}px;height:${vertical.available}px;right:0px;top:0px`;
  bars.verticalSlider.style.cssText = vertical.needed
    ? `width:${bars.verticalSize}px;height:${vertical.sliderSize}px;transform:translateY(${vertical.sliderPosition}px)`
    : '';

  const horizontal = scrollbarState({
    visibleSize: dimensions.width,
    scrollSize: dimensions.scrollWidth,
    scrollPosition: position.left,
    oppositeSize: bars.verticalSize,
  });
  if (horizontal.needed && reveal) {
    bars.horizontalRevealed = true;
    bars.horizontalFade = false;
  }
  if (!horizontal.needed) {
    bars.horizontalRevealed = false;
    bars.horizontalFade = false;
  }
  bars.horizontal.className = scrollbarClass(bars, 'horizontal', horizontal.needed);
  bars.horizontal.style.cssText = `height:${bars.horizontalSize}px;width:${horizontal.available}px;bottom:0px;left:${horizontalLeft}px`;
  bars.horizontalSlider.style.cssText = horizontal.needed
    ? `height:${bars.horizontalSize}px;width:${horizontal.sliderSize}px;transform:translateX(${horizontal.sliderPosition}px)`
    : '';

  bars.topShadow.className = position.top > 0 ? 'shadow top' : 'shadow';
  bars.leftShadow.className = position.left > 0 ? 'shadow left' : 'shadow';
  bars.topLeftShadow.className = `shadow${position.top > 0 || position.left > 0 ? ' top-left-corner' : ''}${position.top > 0 ? ' top' : ''}${position.left > 0 ? ' left' : ''}`;
}

function renderDocument() {
  viewLines.textContent = '';
  sourceLines.forEach((line, index) => {
    const node = document.createElement('div');
    node.className = 'view-line';
    node.dataset.line = String(index + 1);
    node.style.top = `${index * LINE_HEIGHT}px`;
    node.innerHTML = escapeHtml(line);
    viewLines.appendChild(node);
  });
  applyEditorScroll();
}

function editorDimensions() {
  const rect = container.getBoundingClientRect();
  const maxLine = sourceLines.reduce((max, line) => Math.max(max, line.length), 0);
  return {
    width: rect.width,
    height: rect.height,
    scrollWidth: Math.max(rect.width, maxLine * CHAR_WIDTH + 16),
    scrollHeight: Math.max(rect.height, sourceLines.length * LINE_HEIGHT),
  };
}

function applyEditorScroll(reveal = false) {
  const dimensions = editorDimensions();
  scrollTop = Math.max(0, Math.min(scrollTop, dimensions.scrollHeight - dimensions.height));
  scrollLeft = Math.max(0, Math.min(scrollLeft, dimensions.scrollWidth - dimensions.width));
  viewLines.style.transform = `translate(${-scrollLeft}px,${-scrollTop}px)`;
  writeBars(editorBars, dimensions, { top: scrollTop, left: scrollLeft }, 0, reveal);
}

function renderMarkdown(markdown) {
  const parts = [];
  const lines = String(markdown).split('\n');
  for (let index = 0; index < lines.length; index += 1) {
    const line = lines[index];
    if (line.startsWith('```')) {
      const code = [];
      index += 1;
      while (index < lines.length && !lines[index].startsWith('```')) {
        code.push(lines[index]);
        index += 1;
      }
      parts.push(`<div class="monaco-tokenized-source">${escapeHtml(code.join('\n'))}</div>`);
    } else if (line.startsWith('- ')) {
      const items = [];
      while (index < lines.length && lines[index].startsWith('- ')) {
        items.push(`<li>${escapeHtml(lines[index].slice(2))}</li>`);
        index += 1;
      }
      index -= 1;
      parts.push(`<ul>${items.join('')}</ul>`);
    } else if (line.startsWith('### ')) {
      parts.push(`<h3>${escapeHtml(line.slice(4))}</h3>`);
    } else if (line.trim()) {
      const html = escapeHtml(line).replace(/`([^`]+)`/g, '<code>$1</code>');
      parts.push(`<p>${html}</p>`);
    }
  }
  return parts.join('');
}

function renderMarkerHover(content, row) {
  row.classList.add('hover-row-with-copy');
  row.setAttribute('tabindex', '0');
  const marker = document.createElement('div');
  marker.className = 'marker hover-contents';
  marker.textContent = content;
  row.appendChild(marker);
  const button = document.createElement('button');
  button.type = 'button';
  button.className = 'hover-copy-button';
  button.setAttribute('aria-label', 'Copy');
  button.dataset.hoverCopy = content;
  const icon = document.createElement('span');
  icon.className = 'codicon codicon-copy';
  icon.setAttribute('aria-hidden', 'true');
  button.appendChild(icon);
  row.appendChild(button);
}

function renderStatusBar() {
  const status = document.createElement('div');
  status.className = 'hover-row status-bar';
  status.setAttribute('tabindex', '0');
  const actions = document.createElement('div');
  actions.className = 'actions';
  const actionContainer = document.createElement('div');
  actionContainer.className = 'action-container';
  const action = document.createElement('a');
  action.className = 'action';
  action.setAttribute('role', 'button');
  action.setAttribute('tabindex', '0');
  action.textContent = 'View Problem';
  actionContainer.appendChild(action);
  actions.appendChild(actionContainer);
  status.appendChild(actions);
  return status;
}

function showHover(payloadName, line, column) {
  hideHover();
  const payload = hoverPayloads[payloadName];
  if (!payload) {
    throw new Error(`Unknown hover payload: ${payloadName}`);
  }
  const wrapper = document.createElement('div');
  wrapper.className = 'monaco-resizable-hover';
  wrapper.dataset.contentWidget = 'hover';
  const hover = document.createElement('div');
  hover.className = 'monaco-hover fade-in';
  hover.setAttribute('role', 'tooltip');
  hover.setAttribute('tabindex', '0');
  const hoverScrollable = document.createElement('div');
  hoverScrollable.className = 'monaco-scrollable-element';
  hoverScrollable.setAttribute('role', 'presentation');
  const content = document.createElement('div');
  content.className = 'monaco-hover-content';
  const row = document.createElement('div');
  row.className = 'hover-row';
  if (payload.kind === 'marker') {
    renderMarkerHover(payload.contents, row);
  } else {
    const rowContents = document.createElement('div');
    rowContents.className = 'hover-row-contents';
    const markdown = document.createElement('div');
    markdown.className = 'markdown-hover';
    const hoverContents = document.createElement('div');
    hoverContents.className = 'hover-contents';
    hoverContents.innerHTML = payload.kind === 'plaintext'
      ? `<div class="hover-plaintext">${escapeHtml(payload.contents)}</div>`
      : renderMarkdown(payload.contents);
    markdown.appendChild(hoverContents);
    rowContents.appendChild(markdown);
    row.appendChild(rowContents);
  }
  content.appendChild(row);
  if (payload.kind === 'marker') {
    content.appendChild(renderStatusBar());
  }
  hoverScrollable.appendChild(content);
  const hoverBars = createBars(HOVER_SCROLLBAR, HOVER_SCROLLBAR);
  appendBars(hoverScrollable, hoverBars);
  hover.appendChild(hoverScrollable);
  wrapper.appendChild(hover);
  container.appendChild(wrapper);
  wrapper.addEventListener('click', (event) => {
    const button = event.target?.closest?.('.hover-copy-button');
    if (!button) return;
    event.preventDefault();
    globalThis.__monacoConformanceCopiedText = button.dataset.hoverCopy || '';
  });

  const top = (line - 1) * LINE_HEIGHT - scrollTop;
  const left = Math.max(0, column * CHAR_WIDTH - scrollLeft);
  wrapper.style.top = `${top}px`;
  wrapper.style.left = `${left}px`;
  content.style.maxWidth = `${Math.max(160, container.clientWidth - 24)}px`;
  // Port of ContentHoverWidget._findMaximumRenderingHeight: cap the rendered
  // height to the lesser of the available vertical space and the natural content
  // height so the .monaco-hover-content overflow:auto scrollbar engages instead
  // of the editor clipping the spill. The oracle renders downward from the
  // anchor line top, so the available room is measured to the editor bottom.
  // (Previously this mirrored the buggy Math.max(80, clientHeight - 24), which
  // blessed a height larger than the room below and never scrolled.)
  const availableSpaceBelow = container.clientHeight - top - BOTTOM_HEIGHT;
  const contentHeight = content.scrollHeight;
  const maximumRenderingHeight = Math.max(
    0,
    Math.min(availableSpaceBelow, contentHeight),
  );
  content.style.maxHeight = `${maximumRenderingHeight}px`;
  updateHoverBars(content, hoverBars);
  content.addEventListener('scroll', () => updateHoverBars(content, hoverBars, true));
}

function updateHoverBars(content, bars, reveal = false) {
  writeBars(
    bars,
    {
      width: content.clientWidth,
      height: content.clientHeight,
      scrollWidth: content.scrollWidth,
      scrollHeight: content.scrollHeight,
    },
    { top: content.scrollTop, left: content.scrollLeft },
    0,
    reveal,
  );
}

function hideHover() {
  container.querySelector('[data-content-widget="hover"]')?.remove();
}

const STYLE_PROPS = [
  'opacity',
  'display',
  'pointer-events',
  'transition',
  'background-color',
  'color',
  'border-top-color',
  'border-top-width',
  'border-radius',
  'box-shadow',
  'padding-top',
  'padding-right',
  'padding-bottom',
  'padding-left',
  'font-family',
  'font-size',
  'line-height',
  'overflow-x',
  'overflow-y',
  'scrollbar-width',
  'max-width',
  'max-height',
  'cursor',
  'z-index',
  'visibility',
];

function rounded(value) {
  return Math.round(Number(value) * 100) / 100;
}

function box(node) {
  if (!node) return null;
  const rect = node.getBoundingClientRect();
  return {
    x: rounded(rect.x),
    y: rounded(rect.y),
    width: rounded(rect.width),
    height: rounded(rect.height),
    top: rounded(rect.top),
    right: rounded(rect.right),
    bottom: rounded(rect.bottom),
    left: rounded(rect.left),
  };
}

function styles(node) {
  if (!node) return null;
  const computed = getComputedStyle(node);
  return Object.fromEntries(STYLE_PROPS.map((prop) => [prop, computed.getPropertyValue(prop)]));
}

function measureScrollbar(root, axis) {
  const bar = root?.querySelector(`:scope > .scrollbar.${axis}`) ?? null;
  const slider = bar?.querySelector(':scope > .slider') ?? null;
  return {
    className: bar?.className ?? '',
    role: bar?.getAttribute('role'),
    ariaHidden: bar?.getAttribute('aria-hidden'),
    box: box(bar),
    styles: styles(bar),
    sliderClassName: slider?.className ?? '',
    sliderBox: box(slider),
    sliderStyles: styles(slider),
    visible: !!bar?.classList.contains('visible'),
    invisible: !!bar?.classList.contains('invisible'),
    fade: !!bar?.classList.contains('fade'),
    active: !!slider?.classList.contains('active'),
  };
}

function measure() {
  const hoverWidget = container.querySelector('[data-content-widget="hover"]');
  const hover = hoverWidget?.querySelector('.monaco-hover') ?? null;
  const hoverScrollable = hover?.querySelector('.monaco-scrollable-element') ?? null;
  const hoverContent = hover?.querySelector('.monaco-hover-content') ?? null;
  const rows = Array.from(hover?.querySelectorAll('.hover-row') ?? []);
  const copyButton = hover?.querySelector('.hover-copy-button') ?? null;
  const statusBar = hover?.querySelector('.hover-row.status-bar') ?? null;
  return {
    rootClassName: container.className,
    editor: {
      className: scrollable.className,
      box: box(scrollable),
      styles: styles(scrollable),
      verticalScrollbar: measureScrollbar(scrollable, 'vertical'),
      horizontalScrollbar: measureScrollbar(scrollable, 'horizontal'),
      shadows: Array.from(scrollable.querySelectorAll(':scope > .shadow')).map((node) => ({
        className: node.className,
        box: box(node),
        styles: styles(node),
      })),
    },
    hover: {
      wrapperClassName: hoverWidget?.className ?? '',
      wrapperBox: box(hoverWidget),
      wrapperStyles: styles(hoverWidget),
      className: hover?.className ?? '',
      role: hover?.getAttribute('role'),
      tabindex: hover?.getAttribute('tabindex'),
      box: box(hover),
      styles: styles(hover),
      contentBox: box(hoverContent),
      contentStyles: styles(hoverContent),
      nativeScrollbarInset: hoverContent
        ? {
          x: hoverContent.offsetHeight - hoverContent.clientHeight,
          y: hoverContent.offsetWidth - hoverContent.clientWidth,
        }
        : null,
      verticalScrollbar: measureScrollbar(hoverScrollable, 'vertical'),
      horizontalScrollbar: measureScrollbar(hoverScrollable, 'horizontal'),
      rowClasses: rows.map((node) => node.className),
      rowBoxes: rows.map(box),
      statusBar: {
        present: !!statusBar,
        box: box(statusBar),
        styles: styles(statusBar),
        actionText: statusBar?.querySelector('.action')?.textContent ?? '',
      },
      copyButton: {
        present: !!copyButton,
        box: box(copyButton),
        styles: styles(copyButton),
        ariaLabel: copyButton?.getAttribute('aria-label'),
      },
    },
  };
}

window.__monacoConformance = {
  ready() {
    return true;
  },
  setPayloads(payloads) {
    hoverPayloads = payloads || {};
  },
  setTheme(theme) {
    document.documentElement.dataset.theme = theme === 'light' ? 'light' : 'dark';
  },
  openDocument(text) {
    sourceLines = String(text || '').split('\n');
    scrollTop = 0;
    scrollLeft = 0;
    renderDocument();
  },
  showHover,
  hideHover,
  scrollEditor(top, left = 0) {
    scrollTop = Number(top) || 0;
    scrollLeft = Number(left) || 0;
    applyEditorScroll(true);
  },
  measure,
};

renderDocument();
