# Monaco-Exact Hover Widget

Status: implemented, with scrollable-element scope broadened.
Date: 2026-06-15

## Summary

Make the readonly hover experience match Monaco's hover widget internals and
move custom scrollbar behavior onto a shared Monaco-shaped scrollable element.
The original hover-only scope was broadened because Monaco uses one
`ScrollableElement` family for editor and widget scrolling; keeping hover
scrollbars bespoke would preserve the same drift this plan was meant to remove.
The outer viewer DOM contract remains owned by this project, but the main
editor content and hover content now both render through
`.monaco-scrollable-element` wrappers.

This supersedes only the hover portion of the implemented
`monaco-shaped-dom-rendering.md` plan. Do not rewrite that historical plan.

## Current Problems

- The hover DOM uses local classes (`.hover-widget`,
  `.moonbit-viewer-hover-content`) instead of Monaco's
  `.monaco-resizable-hover`, `.monaco-hover`, `.monaco-scrollable-element`, and
  `.monaco-hover-content` structure.
- Long hover content is capped by local `max-height` / `max-width` rules and can
  look truncated instead of resizing and scrolling like Monaco.
- Hover scrolling uses native scrollbar styling inside the content element,
  while Monaco uses a `monaco-scrollable-element` wrapper with custom
  `.scrollbar > .slider` nodes.
- Markdown fenced code blocks are emitted by `cmark_html.render` as plain
  `<pre><code>` HTML, so they never receive the viewer's token classes.
- The main editor and hover had separate wheel, scrollbar drag, track jump,
  and slider update implementations even though both used the same
  `ScrollbarState` arithmetic.

## Target DOM

The hover remains a content widget under `.contentWidgets`, but the widget node
becomes the resizable wrapper and contains Monaco's hover subtree:

```html
<div class="monaco-resizable-hover" data-content-widget="hover">
  <div class="monaco-hover fade-in" tabindex="0" role="tooltip">
    <div class="monaco-scrollable-element" role="presentation">
      <div class="monaco-hover-content">
        <div class="hover-row">
          <div class="hover-row-contents">
            <div class="markdown-hover">
              <div class="hover-contents">...</div>
            </div>
          </div>
        </div>
      </div>
      <div class="scrollbar horizontal invisible"><div class="slider"></div></div>
      <div class="scrollbar vertical invisible"><div class="slider"></div></div>
    </div>
  </div>
</div>
```

Keep `data-content-widget="hover"` on the outer wrapper for harness lookup.
Use `.below` or an equivalent local placement class only on the outer wrapper,
not on `.monaco-hover`.

## Implementation

### Shared Scrollable Element

- Add a browser-local `ScrollableElementDom` that owns the
  `.monaco-scrollable-element` wrapper, content node, vertical/horizontal
  `.scrollbar > .slider` nodes, visibility classes, wheel normalization helper,
  thumb-drag state, track-jump arithmetic, and native-content scrollbar updates.
- Use the same `ScrollableElementDom` for the main editor and hover. The editor
  writes desired positions back into `ViewLayout`; hover writes positions into
  its native `.monaco-hover-content` scroll container.
- Keep `ViewLayout` as the editor's single scroll truth. Browser-originated DOM
  scroll offsets on editor nodes are treated as Monaco-style reveal deltas,
  folded into `ViewLayout`, and reset instead of becoming a second source of
  truth.

### Hover Shell and Placement

- In `renderer/browser/island.mbt`, change `ensure_hover_widget` to create the
  wrapper plus inner `.monaco-hover` and a shared `ScrollableElementDom`
  containing `.monaco-scrollable-element`, `.monaco-hover-content`, vertical
  scrollbar, and horizontal scrollbar nodes.
- Store enough browser-local state to update the inner content node and both
  hover scrollbar sliders without querying by selector. A small private
  `HoverWidgetDom` record is preferable to repeated child indexing.
- Keep the existing hover controller state machine and stale-result guards.
  Only the DOM rendering, measurement, and scroll handling change.
- Mount the wrapper through the existing content-widget path. Placement still
  uses the anchor line/column, flips above/below after measuring, and shifts
  left when the measured widget overflows the editor root.
- Perform sizing in the render flush:
  1. Clear explicit width/height/max constraints.
  2. Write the new hover content.
  3. Measure content width/height.
  4. Set max width to the available body/editor width minus a small margin.
  5. Set max height to available vertical space, with a Monaco-like minimum cap
     of at least 250px when the editor is tall enough.
  6. Recompute placement and scrollbar visibility from real dimensions.

### Scrollable Hover Content

- Hide native scrollbars on `.monaco-hover-content`; the content node remains
  the real scroll container.
- Route hover scrollbar input through the shared scrollable element:
  - wheel events on the hover scroll content update `scrollTop` / `scrollLeft`
    and never reach editor scroll input;
  - vertical and horizontal thumb drag update the content scroll position;
  - track clicks page toward the pointer;
  - keyboard handling keeps `Escape`, `ArrowUp`, `ArrowDown`, `PageUp`,
    `PageDown`, `Home`, and `End`; add `ArrowLeft` / `ArrowRight` for
    horizontal code blocks.
- Add/remove Monaco visibility classes on hover scrollbars:
  `visible scrollbar vertical`, `invisible scrollbar vertical`,
  `visible scrollbar horizontal`, and `invisible scrollbar horizontal`.
- Update `.slider` inline size/position from content `client*`, `scroll*`, and
  `scroll*` position. Reuse the same minimum 20px slider size used by the
  editor scrollbar model.

### CSS

- Port the relevant Monaco rules into `app/src/style.css`, scoped to the viewer
  or editor shell:
  - `vscode/src/vs/base/browser/ui/hover/hoverWidget.css`
  - `vscode/src/vs/editor/contrib/hover/browser/hover.css`
  - `vscode/src/vs/base/browser/ui/scrollbar/media/scrollbars.css`
- Add missing VS Code variables in `.editor-shell` for both themes:
  `--vscode-scrollbar-background`, `--vscode-scrollbar-shadow`,
  `--vscode-textLink-foreground`, `--vscode-textLink-activeForeground`,
  `--vscode-textCodeBlock-background`, `--vscode-shadow-hover`,
  `--vscode-cornerRadius-large`, and `--monaco-monospace-font`.
- Remove hover-specific local styles that fight Monaco behavior
  (`.hover-widget`, `.moonbit-viewer-hover-content`, local `pre code` caps).
  Keep existing `tok-*` and `sem-*` token colors.

### Markdown Code Blocks

- Extend `renderer/browser/moon.pkg` imports with
  `moonbit-community/cmark/cmark` and
  `moonbit-community/cmark/cmark_renderer`.
- Replace `hover_markdown_html` with a composed cmark renderer:
  `@cmark_html.renderer(safe=true)` plus a block override for
  `@cmark.CodeBlock`.
- For each code block:
  - resolve the fence language from `CodeBlock::language_of_info_string`;
  - normalize aliases: `mbt` to `moonbit`, `js` to `javascript`, and `ts` to
    `typescript`;
  - if the fence has no language, use the active document language id;
  - fall back to `@syntax.PlainTokenizer::new()` when the registry has no
    tokenizer for the resolved language.
- Tokenize code with the existing browser tokenizer registry. Build a temporary
  `@core.DocumentSnapshot`, `@renderer.TokenizedDocument`,
  `@renderer.FrameSource(..., @decorations.DecorationSet::empty(),
  @language.ProviderResult::empty())`, then render every frame line with
  `@renderer.render_line_html`.
- Wrap the highlighted code as Monaco does:

```html
<div class="monaco-tokenized-source">
  <span class="view-line-content"><span class="tok-keyword">fn</span> ...</span>
  <br/>
  ...
</div>
```

Do not introduce semantic tokens for hover code blocks in this plan.

## Docs and Harness

- Update `docs/harness.md` so hover selectors use
  `[data-content-widget="hover"] .monaco-hover`,
  `.monaco-hover-content`, and `.monaco-scrollable-element`.
- Update `docs/harness.md` and `renderer/browser/README.md` to say the main
  editor also exposes `.monaco-scrollable-element.editor-scrollable`, and that
  both editor and hover scrollbars use the shared browser scrollable element.

## Tests

- Add/extend MoonBit tests for hover rendering:
  - markdown rows render as `.hover-row > .hover-row-contents >
    .markdown-hover > .hover-contents`;
  - unsafe markdown is still sanitized;
  - plaintext remains escaped;
  - `moonbit` and `mbt` fenced code blocks emit `.monaco-tokenized-source` and
    `tok-*` spans;
  - unknown languages use plain fallback without dropping content.
- Update Playwright hover tests:
  - assert the Monaco hover subtree and remove assertions for
    `.moonbit-viewer-hover-content`;
  - long markdown scrolls vertically with the custom `.scrollbar.vertical`
    slider and does not emit editor `view:scroll`;
  - long fenced code scrolls horizontally with `.scrollbar.horizontal`;
  - code fences contain visible token classes such as `.tok-keyword` and
    `.tok-function`;
  - pointer hover, focus, wheel, keyboard scrolling, and Escape dismissal still
    work.
- Update Playwright scroll tests:
  - assert the main editor DOM includes
    `.overflow-guard > .monaco-scrollable-element.editor-scrollable`;
  - assert vertical editor scrollbar nodes use the shared
    `.scrollbar.vertical.visible > .slider` structure;
  - wheel the editor scrollable element and verify `view:scroll` is emitted.

## Validation

Run:

```sh
just check
just test
just build
just test-browser
git diff --check
```

Then smoke the real viewer:

```sh
just dev ROOT=/Users/baozhiyuan/Workspace/moonbit-project/simple PORT=<free-port>
```

In the browser, hover a MoonBit symbol and verify the Monaco hover DOM, custom
hover scrollbars, non-truncated long content, and highlighted fenced code.

## Acceptance Criteria

- Hover internals use the Monaco-shaped DOM and CSS named in this plan.
- Long hover content scrolls inside the hover widget instead of appearing
  truncated.
- Hover scrollbars visually match the Monaco `monaco-scrollable-element`
  scrollbar structure and do not move the editor scroll position.
- Markdown fenced code blocks render with the viewer's token classes.
- The outer readonly viewer DOM contract remains MoonBit-owned.
- The main editor and hover share one browser-side scrollable-element
  implementation for scrollbar DOM and input.
- No product code imports from `vscode/` or `codemirror/`.
- All validation commands pass.
