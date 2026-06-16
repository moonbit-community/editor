# Monaco Render-Line IR Layer

Status: implemented.
Date: 2026-06-16

## Goal

Copy Monaco's pre-DOM render-line layer into our readonly viewer at the design
and semantic level. The target pipeline is:

```text
RenderFrame / layout state
  -> ViewportData
  -> ViewLineRenderingData
  -> RenderLineInput
  -> render_view_line / render_view_line2
  -> RenderLineOutput / RenderLineOutput2
  -> renderer/browser ViewLayer-style DOM application
```

This is a follow-up to the implemented Monaco IR/view plans. Do not rewrite
`monaco-ir-and-imperative-view.md` or `monaco-shaped-dom-rendering.md`; they are
historical evidence. This plan tightens the render-line IR seam that now exists
only loosely through `RenderFrame`, `RenderLine`, and `render_line_html`.

The editor stays readonly. Product code must remain MoonBit-owned and must not
import code, CSS, or runtime services from `vscode/`.

## Reference Shape

Use these VS Code / Monaco files as the reference map:

- `vscode/src/vs/editor/common/viewLayout/viewLineRenderer.ts`
  - `RenderLineInput`
  - `CharacterMapping`
  - `DomPosition`
  - `ForeignElementType`
  - `RenderLineOutput`
  - `RenderLineOutput2`
  - `renderViewLine`
  - `renderViewLine2`
- `vscode/src/vs/editor/common/viewLayout/viewLinesViewportData.ts`
  - `ViewportData`
- `vscode/src/vs/editor/common/viewModel.ts`
  - `ViewLineRenderingData`
- `vscode/src/vs/editor/common/viewLayout/lineDecorations.ts`
  - `LineDecoration`
  - `LineDecorationsNormalizer`
- `vscode/src/vs/editor/common/viewModel/inlineDecorations.ts`
  - `InlineDecoration`
  - `InlineDecorationType`
- `vscode/src/vs/editor/common/viewLayout/linePart.ts`
  - `LinePart`
- `vscode/src/vs/editor/browser/view/viewLayer.ts`
  - `RenderedLinesCollection`
  - `VisibleLinesCollection`
  - `ViewLayerRenderer`
- `vscode/src/vs/editor/browser/viewParts/viewLines/viewLine.ts`
  - line DOM node rendering from `ViewportData`

The implementation should copy the layer boundaries, data contracts, and
observable behavior where relevant to a readonly viewer. It must not mechanically
port TypeScript or keep references to VS Code services that do not exist in our
architecture.

## Current State

- `renderer/render_frame.mbt` owns `FrameViewport`, `RenderSpan`,
  `RenderLine`, and `RenderFrame`.
- `renderer/line_html.mbt` directly turns a `RenderLine` plus decorations into
  HTML through `render_line_html` and line classes through `render_line_class`.
- `renderer/browser/island.mbt` renders the frame with an imperative line
  recycler, but the recycler consumes `RenderLine` directly instead of a
  Monaco-shaped `ViewportData` / `RenderLineInput` layer.
- Existing tests already cover render frames, line HTML, view layout,
  scroll-window math, hit testing, browser smoke, browser conformance, browser
  component flows, and perf probes.

The gap is not that we lack windowing or browser recycling. The gap is that the
pure render-line contract is too local: it does not expose Monaco's explicit
line rendering input, output, decoration normalization, or character mapping
seam.

## Public API / Type Additions

Add these backend-neutral types in `renderer`:

- `ViewportData`
  - 1-based inclusive `start_line_number` and `end_line_number`.
  - `relative_vertical_offset` for each visible line.
  - `line_height`, `visible_range`, and `big_numbers_delta`.
  - Accessor for `ViewLineRenderingData` by line number.
  - Accessor for decorations in the current viewport.
- `ViewLineRenderingData`
  - `min_column`, `max_column`, `content`, `continues_with_wrapped_line`,
    `contains_rtl`, `is_basic_ascii`, `tokens`, `inline_decorations`,
    `tab_size`, `start_visible_column`, `text_direction`, and
    `has_variable_fonts`.
- `RenderLineInput`
  - Field-compatible with Monaco's render input:
    `use_monospace_optimizations`,
    `can_use_halfwidth_rightwards_arrow`, `line_content`,
    `continues_with_wrapped_line`, `is_basic_ascii`, `contains_rtl`,
    `faux_indent_length`, `line_tokens`, `line_decorations`, `tab_size`,
    `start_visible_column`, `space_width`, `middot_width`,
    `wsmiddot_width`, `stop_rendering_line_after`, `render_whitespace`,
    `render_control_characters`, `font_ligatures`, `selections_on_line`,
    `text_direction`, `vertical_scrollbar_size`, and
    `render_new_line_when_empty`.
  - Provide readonly viewer defaults for fields that are not yet product
    configurable.
  - Provide equality so unchanged visible lines can skip HTML regeneration.
- `CharacterMapping`
  - Stores DOM part index, character index, and visible column data.
  - Supports column-to-DOM and DOM-to-column round trips.
- `DomPosition`
- `ForeignElementType`
  - `None`, `Before`, and `After`.
- `RenderLineOutput`
  - Character mapping plus foreign-element state for builder-based rendering.
- `RenderLineOutput2`
  - HTML string plus character mapping plus foreign-element state, matching
    Monaco's convenience API shape.
- `LinePart`
  - End index, token type/class, metadata, and RTL flag.
- `InlineDecoration`
- `InlineDecorationType`
  - `Regular`, `Before`, `After`, and `RegularAffectingLetterSpacing`.
- `LineDecoration`
- `LineDecorationsNormalizer`
  - Normalizes overlapping inline decorations into stable line segments before
    HTML emission.

Keep these compatibility surfaces initially:

- `RenderFrame`
- `RenderLine`
- `render_line_html`
- `render_line_class`

Those existing APIs should route through the new Monaco-shaped path once the
new renderer is in place. Do not force all callers to migrate in the same
commit that introduces the IR layer.

## Implementation Plan

### Phase 1: Viewport and Per-Line Rendering Data

Add `ViewportData` in `renderer` as the canonical pre-DOM viewport object.

Implementation requirements:

- Build it from the existing `RenderFrame` plus layout state.
- Use 1-based inclusive line numbers at this boundary, matching Monaco.
- Preserve current viewport/window behavior and current line-height math.
- Set `big_numbers_delta` to `0` for now; keep the field so future large-offset
  handling has the same seam as Monaco.
- Derive `ViewLineRenderingData` for each visible line.
- Convert existing `RenderSpan` token data into `LinePart` data without copying
  text into each token part.
- Convert existing regular decorations into `InlineDecorationType::Regular`.
- Keep current-line line classes outside inline decoration normalization unless
  the implementation explicitly models them as overlay data.

### Phase 2: Canonical Render-Line Input and Output

Add `RenderLineInput`, `CharacterMapping`, `RenderLineOutput`, and
`RenderLineOutput2` in `renderer`.

Implementation requirements:

- Construct `RenderLineInput` from `ViewLineRenderingData` plus render options.
- Include every Monaco render-input field listed above, even when the readonly
  viewer uses a fixed default.
- Implement equality over all fields that can affect generated HTML or mapping.
- Implement `CharacterMapping` with deterministic inflated mapping data.
- Implement `DomPosition` and round-trip helpers:
  - column -> DOM position
  - DOM position -> column
  - column -> horizontal offset for monospace layout
- Keep mappings correct for escaped text, token splits, empty lines, and
  inline decorations.

### Phase 3: Pure Line Renderer

Replace `render_line_html` as the core implementation with Monaco-shaped pure
rendering:

- `render_view_line(input, builder) -> RenderLineOutput`
- `render_view_line2(input) -> RenderLineOutput2`

Implementation requirements:

- Emit escaped HTML with the current token class behavior preserved.
- Normalize overlapping line decorations before rendering.
- Support `Regular`, `Before`, `After`, and
  `RegularAffectingLetterSpacing` decoration types in the renderer, even if
  only `Regular` has a product caller at first.
- Implement Monaco's large-token split behavior so long spans are broken into
  stable chunks instead of producing one unbounded DOM text span.
- Preserve empty-line rendering, including the configured
  `render_new_line_when_empty` behavior.
- Preserve current default whitespace behavior, then pin it with snapshots.
- Keep `render_line_html(line, decorations)` as a wrapper that creates a
  default `RenderLineInput` and returns `render_view_line2(input).html`.
- Keep `render_line_class(line, decorations)` as the compatibility wrapper for
  line-node classes until overlay extraction is handled by a later plan.

### Phase 4: Browser ViewLayer Wiring

Refactor `renderer/browser` line application to consume the new IR instead of
raw `RenderLine` values.

Implementation requirements:

- Introduce a local `ViewLayer`-style helper in `renderer/browser`.
- The helper owns the currently rendered line range and line/gutter node
  collections.
- Browser rendering should flow:

  ```text
  ViewportData
    -> ViewLineRenderingData
    -> RenderLineInput
    -> render_view_line2
    -> set_inner_html only when line content changed or line entered viewport
  ```

- Preserve current DOM contracts:
  - `.moonbit-viewer.readonly-editor`
  - `.overflow-guard`
  - `.lines-content`
  - `.view-lines`
  - `.view-line`
  - `data-line`
  - line top/height style
  - semantic token span classes
  - margin/gutter alignment
- Preserve current incremental behavior:
  - unchanged visible line nodes are retained;
  - entering lines are inserted;
  - leaving lines are removed;
  - unchanged line HTML is not rewritten.
- Keep all DOM, measurement, event wiring, and CSS ownership in
  `renderer/browser`.

### Phase 5: Documentation

Update documentation after implementation lands:

- `renderer/README.md`
  - Describe the new render-line IR layer as the Monaco `viewLineRenderer`
    role.
  - Document which fields are exact Monaco equivalents and which are readonly
    defaults.
- `renderer/browser/README.md`
  - Describe the browser `ViewLayer` consumer and the rule that DOM code
    consumes `ViewportData`, not raw `RenderFrame` lines.
- `docs/architecture.md`
  - Refresh the render split:
    workspace/source document -> tokenized frame/window -> `ViewportData` ->
    render-line IR -> browser view layer.

## Tests

Use inline snapshots for the new pre-DOM tests.

Add or extend `renderer` tests for:

- `ViewportData`
  - 1-based inclusive start/end line behavior.
  - Relative vertical offsets.
  - Empty, single-line, and multi-line windows.
  - Clamped viewport bounds.
- `ViewLineRenderingData`
  - min/max columns.
  - ASCII and RTL flags.
  - token conversion from existing `RenderSpan` data.
  - decoration conversion and ordering.
- `RenderLineInput`
  - readonly defaults.
  - equality when render-affecting fields are unchanged.
  - inequality when content, tokens, decorations, whitespace mode, or mapping
    inputs change.
- `LineDecorationsNormalizer`
  - non-overlapping decorations.
  - overlapping decorations.
  - adjacent decorations.
  - before/after decorations.
- `render_view_line2`
  - escaped text.
  - empty line.
  - semantic-token spans.
  - overlapping inline decorations.
  - before and after decorations.
  - large-token splitting.
  - default whitespace/control-character behavior.
  - returned HTML plus character mapping.
- `CharacterMapping`
  - column-to-DOM round trips.
  - DOM-to-column round trips.
  - mapping through escaped content and split tokens.

Add or extend browser tests for:

- Line nodes are retained when scrolling within the same generation and the
  same lines remain visible.
- Only entering or changed lines rewrite `innerHTML`.
- Rendered DOM still exposes expected `.view-line`, `data-line`, top/height,
  semantic token, and gutter alignment contracts.
- Existing smoke, conformance, component, and perf suites continue to pass.

## Validation

Run these checks before considering the plan implemented:

```sh
moon test renderer
just check
just test-browser-conformance
just test-browser-component
just test-browser-perf
```

If the browser changes are broad, also run:

```sh
just test-browser
```

For the PR or final implementation note, record:

- which Monaco reference files were used;
- which renderer APIs were added;
- which compatibility wrappers remain;
- browser evidence that node retention and limited HTML rewrites still work.

## Implementation Evidence

Reference files used:

- `vscode/src/vs/editor/common/viewLayout/viewLineRenderer.ts`
- `vscode/src/vs/editor/common/viewLayout/lineDecorations.ts`
- `vscode/src/vs/editor/common/viewModel/inlineDecorations.ts`
- `vscode/src/vs/editor/test/common/viewLayout/viewLineRenderer.test.ts`
- `vscode/src/vs/editor/test/common/viewLayout/lineDecorations.test.ts`

Renderer APIs added:

- `ViewportData`, `ViewLineRenderingData`, and `ViewRange`
- `RenderLineInput`, `RenderLineOutput`, and `RenderLineOutput2`
- `CharacterMapping` and `DomPosition`
- `LinePart`, `LineDecoration`, `InlineDecoration`,
  `InlineDecorationType`, `ForeignElementType`, and
  `LineDecorationsNormalizer`
- `render_view_line`, `render_view_line2`, and
  `RenderFrame::to_viewport_data`

Compatibility wrappers retained:

- `RenderFrame` / `RenderLine`
- `render_line_html`
- `render_line_class`

Monaco test coverage ported:

- Full direct port of the upstream `LineDecorationsNormalizer` test cases that
  apply to this offset-based renderer.
- Direct render-line checks for escaping, empty lines, token classes, two-token
  rendering, large-token split boundaries, and simple `getColumn` behavior.
- A broader upstream-named renderer case matrix covering Monaco issues and
  scenarios including `issue-2255`, `issue-91178`, RTL lines, link
  decorations, visible whitespace modes, unsorted decorations, before/after
  decorations on empty and non-empty lines, surrogate-boundary emoji
  decorations, fullwidth characters, long lines, and multiple EOL text
  decorations.
- The two upstream `LineDecoration.filter` tests are not direct ports because
  our `InlineDecoration` range is a backend-neutral offset range, not Monaco's
  line/column model range.

Validation run on 2026-06-16:

```sh
moon test --target js renderer
moon test --target native renderer
just check
just test
just test-browser-conformance
just test-browser
```

Results:

- Renderer tests: 37 passed on JS and native.
- `just check`: passed with the repository's existing warning set.
- `just test`: 98 JS tests and 104 native tests passed.
- `just test-browser-conformance`: 13 Playwright tests passed.
- `just test-browser`: 29 Playwright tests passed, covering conformance,
  component, perf, and smoke suites.

## Non-Goals

- Do not make the viewer editable.
- Do not add cursor, selection rendering, IME/edit-context, accessibility
  textarea, minimap, overview ruler, find, command services, editor
  contributions, or Monaco dependency injection.
- Do not import or generate product code from `vscode/`.
- Do not make browser code depend on raw VS Code CSS.
- Do not remove existing compatibility wrappers until all current callers and
  tests are migrated.

## Assumptions

- "Exactly the same as Monaco's" means the same render-line layer roles, type
  inventory, field inventory, data flow, and observable readonly behavior where
  the concepts apply.
- Editable-only fields are represented with deterministic readonly defaults
  until the viewer has a product need for them.
- Public viewer embedding APIs remain stable.
- The root DOM shape from the implemented Monaco-shaped DOM plan remains the
  browser contract.
- Inline snapshots are the default golden format for the new IR tests.
