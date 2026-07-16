# Monaco viewCursors + currentLineHighlight Port (and overlay-widgets parent fix)

Status: landed — Date: 2026-07-02 (Increments A–D implemented same day).
Oracle: checked-in reference tree.

Validation at closure: `just check` green (architecture + all targets);
`moon test --target all` 567 js / 526 native; browser suite 53/53 including
the new `cursor_current_line.spec.js` (3 specs: focused caret box +
current-line exact box, blur hides caret, non-empty selection suppresses the
content highlight and flags `has-selection`) and the updated
`dom_structure.spec.js` (overlayWidgets under the overflow guard,
cursors-layer in lines-content, current-line-highlight layer first in the
margin overlays). One pre-existing stale expectation fixed along the way
(markdown hover row `tabindex=0`, reproducible before this work at
recorded milestone).

Follow-on to `monaco-set-selection-api-port.md`: `set_position` currently has
no visible feedback (a collapsed selection paints nothing), because the
`viewCursors` and `currentLineHighlight` view parts were never ported. Also
fixes one DOM-structure drift found by the 2026-07-02 port audit.

## Scope (Phase 0)

| # | Source unit | Slice | Increment |
|---|---|---|---|
| 1 | `browser/view.ts` | overlay-widgets DOM parent (`:287`) | A |
| 2 | `browser/view.ts` `_getEditorClassName` (`:459-462`) + `viewOverlays.ts` focused toggle (`:125`) + `ViewFocusChangedEvent` | focus seam | B |
| 3 | `browser/viewParts/viewCursors/viewCursors.ts` | whole | C |
| 4 | `browser/viewParts/viewCursors/viewCursor.ts` | whole | C |
| 5 | `browser/viewParts/viewCursors/viewCursors.css` | whole | C |
| 6 | `browser/viewParts/currentLineHighlight/currentLineHighlight.ts` | whole | D |
| 7 | `browser/viewParts/currentLineHighlight/currentLineHighlight.css` | whole | D |
| 8 | `editorOptions` `renderLineHighlight` / `renderLineHighlightOnlyWhenFocus` | defaults `'line'` / `false` | D |

**Out of scope (named siblings, explicitly deferred — not "unseen"):**

- Secondary cursors / `CursorPlurality.Multi*` — the viewer's
  `CursorsController` holds exactly one cursor by deliberate design (see
  `monaco-set-selection-api-port.md` out-of-scope).
- `cursorStyle` option values other than `Line` (Block / Underline /
  BlockOutline / LineThin / UnderlineThin) and the `cursorWidth` /
  `cursorHeight` options — no viewer option models them; the effective style
  is Monaco's default `Line` with width 2 and full line height.
- Blink animation styles (`Blink` / `Smooth` / `Phase` / `Expand`) and both
  blink timers — unreachable in a readonly editor: `_getCursorBlinking`
  (`viewCursors.ts:227-240`) returns `Solid` whenever `readOnly` is set and
  `Hidden` when unfocused, so the animation arms are dead for this product.
- `cursorSmoothCaretAnimation` — option defaults `'off'`; the pause-animation
  transition plumbing rides on it.
- Composition events (`onCompositionStart/End`, `_isComposingInput`) — no
  input in a readonly viewer.
- The `DecorationsOverlay`, `IndentGuidesOverlay`, `WhitespaceOverlay`,
  `MarginViewLineDecorationsOverlay`, `LinesDecorationsOverlay` dynamic
  overlays that Monaco registers alongside these (`view.ts:216-231`) — each
  is its own future port.

## Deviations (rule: local seams allowed, invented math is not)

1. **Focus source.** Monaco tracks focus on the hidden textarea / edit
   context (`FocusTracker`); the viewer has no textarea — DOM `focus`/`blur`
   listeners on the root `<section tabindex="0">` are the local seam, and the
   root is explicitly `.focus()`ed on editor mousedown (the mouse handler
   `preventDefault`s mousedown, which suppresses native focusing — Monaco
   equally focuses explicitly via `focusTextArea()` on mouse down).
2. **Event sourcing.** `ViewFocusChanged` is sourced by the established
   frame-snapshot diff (`view_events.mbt` header), not emitted incrementally.
3. **Flat overlay containers.** The port renders overlay pieces as flat
   absolutely-positioned children (no per-line `ViewOverlayLine` recycling) —
   pre-existing recorded deviation of the `selections`/`margin` parts; the
   current-line overlays follow it. DOM order (current-line before
   selected-text) preserves Monaco's registration z-order
   (`view.ts:218-219`).
4. **Package placement.** `viewCursors` gets its own mirror package
   (`viewer/browser/view_parts/view_cursors`). `currentLineHighlight`'s two
   overlays are merged into the packages that own their containers —
   content half into `view_parts/selections` (the ContentViewOverlays merge,
   per that package's header) and margin half into `view_parts/margin` —
   following the established foldingDecorations/selections merge precedent.
   The shared DOM-free predicates + `RenderLineHighlight` option enum live in
   `viewer/common/view_layout` (precedent: `RenderWhitespace`).
5. **Static theme CSS.** Monaco's `registerThemingParticipant` rules become
   static CSS over `--vscode-*` custom properties (the viewer's theming
   design; same deviation the marker port recorded for non-squiggly rules).
   The conditional "border only when no background color is defined" logic
   (`currentLineHighlight.ts:253-263`) is not replicated at runtime; the
   shipped theme defines only `editor.lineHighlightBorder` (both Monaco dark
   and light defaults leave `editor.lineHighlightBackground` null), so the
   static rules produce Monaco's default-theme output.
6. **Grapheme-aware position** (`viewCursor.ts:156-161`): not ported.
   Cursor positions are validated (`validate_position`) and the caret x is
   measured off the live DOM at the UTF-16 column, so a position inside a
   combining-cluster measures that unit's caret rect instead of the grapheme
   start. No crash path; visual-only divergence for mid-grapheme positions.
7. **`computeScreenAwareSize`** is ported (`max(1, floor(dpr*size))/dpr`),
   with `devicePixelRatio` read via a local extern.

## Parity ledger — Increment A (`view.ts:281-297` wiring slice)

| Member | Monaco | Local | Status |
|---|---|---|---|
| `overflowGuardContainer.appendChild(overlayWidgets)` (:287) | overlay widgets are viewport-fixed | `view.mbt` append to `overflow_guard` after scrollbar | PORTED |
| `linesContent.appendChild(viewCursors)` (:280) | cursors after content widgets in lines content | `view.mbt` | PORTED (Increment C) |
| scrollDecoration / minimap / blockOutline appends (:286,288,289) | — | — | DEFERRED (parts not ported; marker plan Increment H) |

## Parity ledger — Increment B (focus seam)

| Member | Monaco | Local | Status |
|---|---|---|---|
| `_getEditorClassName` focused suffix (view.ts:459-462) | `' focused'` on the editor root | `view_root_class(focused~)` | PORTED |
| `onFocusChanged` → `setClassName` (view.ts:485-489) | reapply root class | `View::render` applies per-frame | PORTED |
| `ViewOverlays.onFocusChanged` (viewOverlays.ts:76-79) | `_isFocused = e.isFocused; true` | `ContentViewOverlays` on_view_event | PORTED |
| `ViewOverlays.render` focused toggle (viewOverlays.ts:125) | `toggleClassName('focused', _isFocused)` | render sets `view-overlays focused` | PORTED |
| `ViewFocusChangedEvent` (viewEvents.ts) | isFocused payload | `ViewFocusChanged(Bool)` sourced from snapshot diff | PORTED (deviation 2) |
| textarea FocusTracker | textarea focus/blur | root focus/blur listeners + mousedown `.focus()` | PORTED (deviation 1) |

## Parity ledger — Increment C (`viewCursors.ts` 30 members + `viewCursor.ts` 20 members)

`viewCursors.ts`:

| Member | Monaco behavior | Local | Status |
|---|---|---|---|
| `BLINK_INTERVAL` (:32) | 500 | — | N-A (blink timers unreachable readonly) |
| `_readOnly` (:34,:60) | gates blinking → Solid | constant `true` (readonly product) | PORTED (constant-folded) |
| `_cursorBlinking` (:35,:61) | option | — | N-A (readonly forces Solid/Hidden) |
| `_cursorStyle` (:36,:62) | option | Line fixed | DEFERRED (no cursorStyle option) |
| `_cursorSmoothCaretAnimation` (:37,:63) | option | — | DEFERRED (option not modeled; off default) |
| `_editContextEnabled` (:38) | edit-context flag | — | N-A (no input) |
| `_selectionIsEmpty` (:39,:168-172) | class `has-selection` | `ViewCursors` render input | PORTED |
| `_isComposingInput` (:40,:102-111) | hide during composition | — | N-A (no input) |
| `_isVisible` / `_show`/`_hide` (:42,:342-356) | visibility on cursor nodes | `set_cursor_visible` | PORTED |
| `_domNode` `.cursors-layer` + role/aria (:74-77) | presentation, aria-hidden | `ViewCursors::new` | PORTED |
| `_startCursorBlinkAnimation`/`_cursorFlatBlinkInterval` (:81-82) | blink timers | — | N-A (unreachable readonly) |
| `_blinkingEnabled` (:84) | animation gate | constant `false` | PORTED (constant-folded: `cursor-solid` arm) |
| `_editorHasFocus` (:86,:183-187) | hidden when unfocused | `editor_has_focus` input | PORTED |
| `_primaryCursor` (:70,:79) | single ViewCursor child | `cursor` node | PORTED |
| `_secondaryCursors`/`_renderData`/`getLastRenderData` (:53-54,:139-158,:386-388) | multi-cursor + IME rect | — | N-A / DEFERRED (single cursor; no IME) |
| `onConfigurationChanged` (:112-129) | re-read options | ViewConfigurationChanged → true | PORTED (reduced option set) |
| `_onCursorPositionChanged` pauseAnimation (:130-137) | transition pause | — | DEFERRED (smooth caret option) |
| `onCursorStateChanged` (:161-175) | position + has-selection | ViewCursorStateChanged → true | PORTED |
| `onDecorationsChanged`/`onFlushed`/`onLines*`/`onScrollChanged`/`onZonesChanged` (:176-221) | true | event map in `view_part.mbt` | PORTED |
| `onTokensChanged` line-range check (:200-218) | render if cursor line retokenized | ViewLinesChanged → true | PORTED (coarser: port has no per-range token event) |
| `_getCursorBlinking` (:227-240) | composing→Hidden; !focus→Hidden; readOnly→Solid | focused ? Solid : Hidden | PORTED (readonly constant-folded) |
| `_updateBlinking` (:242-278) | timers + show/hide | show/hide on render | PORTED (animation arms N-A) |
| `_updateDomClassName`/`_getClassName` (:282-340) | layer class | `cursors_layer_class` | PORTED (reachable arms: has-selection, cursor-line-style, cursor-solid) |
| `prepareRender`/`render` (:360-384) | delegate to cursors | ViewPart impl | PORTED |
| theming participant (:391-417) | caret color rules | static CSS (deviation 5) | PORTED |

`viewCursor.ts`:

| Member | Monaco behavior | Local | Status |
|---|---|---|---|
| `IViewCursorRenderData` (:18-24) | IME/testing rect | — | N-A (no consumer) |
| `ViewCursorRenderData` (:26-36) | top/left/paddingLeft/width/height/textContent | `CursorRenderData` (no textContent) | PORTED (textContent N-A, width fixed 2) |
| `CursorPlurality`/`setPlurality` (:38-42,:98-113) | multi-cursor classes | — | N-A (single) |
| ctor dom node `.cursor` + mouse-cursor-text class (:74-80) | class, display none | `ViewCursors::new` | PORTED |
| `getPosition` (:94) | last position | prepared position | PORTED |
| `show`/`hide` (:115-127) | visibility inherit/hidden | `set_cursor_visible` | PORTED |
| `onConfigurationChanged` (:129-140) | re-read fontInfo etc. | config event → re-render | PORTED (reduced) |
| `onCursorPositionChanged` transition (:142-150) | pause transition | — | DEFERRED (smooth caret) |
| `_getGraphemeAwarePosition` (:156-161) | grapheme start + next grapheme | — | DEFERRED (deviation 6) |
| `_prepareRender` Line arm (:175-203) | visibleRangeForPosition; width=screenAware(2); paddingLeft shift; top=vertical offset | `prepare_cursor_render_data` | PORTED |
| `_prepareRender` Block/Underline arm (:206-241) | linesVisibleRangesForRange | — | DEFERRED (no cursorStyle option) |
| `_getTokenClassName` (:244-248) | block-cursor text color | — | N-A (Line style) |
| `render` (:254-282) | apply render data / display none | `ViewCursors` render | PORTED |

## Parity ledger — Increment D (`currentLineHighlight.ts` 24 members)

| Member | Monaco behavior | Local | Status |
|---|---|---|---|
| `_renderLineHighlight` option (:41) | none/gutter/line/all | `@view_layout.RenderLineHighlight` viewer option, default Line | PORTED |
| `_renderLineHighlightOnlyWhenFocus` (:42) | default false | viewer option | PORTED |
| `_wordWrap` = isViewportWrapping (:43) | wrapped-line pass gate | `soft_wrap` option via render input | PORTED |
| `_contentLeft` (:44) | margin width | `gutter_width` | PORTED |
| `_contentWidth` (:45) | content viewport width | `dimensions.width` | PORTED |
| `_selectionIsEmpty` (:46,:74-78) | all selections empty | single view selection `is_empty` | PORTED |
| `_focused` (:47,:116-123) | focus gate | `editor_has_focus` | PORTED |
| `_cursorLineNumbers` (:31,:63-72) | unique sorted cursor lines | single line | PORTED (single cursor) |
| `_readFromSelections` (:60-81) | change detection | snapshot diff drives re-render | PORTED (event-sourced) |
| `onThemeChanged` (:84-86) | re-read | — | N-A (no theme event; CSS variables cascade) |
| `onConfigurationChanged` (:87-96) | re-read options | options fixed at construction | N-A (no runtime option changes in viewer) |
| `onCursorStateChanged`/`onFlushed`/`onLines*`/`onZonesChanged` (:97-115) | dirty | ContentViewOverlays/margin event maps | PORTED |
| `onScrollChanged` scrollWidth/scrollTop (:110-112) | dirty on those | ViewScrollChanged position/dimensions | PORTED |
| `prepareRender` viewport pass (:126-171) | wrapped pass + exact pass | `prepare_current_line_render` | PORTED |
| wrapped-line first/last view line (:141-158) | converter round-trip | model-line scan over `model_line_number_of_view_line` | PORTED (local seam, same result) |
| `render(start,line)` (:173-182) | per-line HTML | flat positioned divs (deviation 3) | PORTED |
| `_shouldRenderInMargin` (:184-189) | gutter/all + focus opt | `should_render_in_margin` (view_layout) | PORTED |
| `_shouldRenderInContent` (:191-197) | line/all + empty + focus opt | `should_render_in_content` (view_layout) | PORTED |
| `CurrentLineHighlightOverlay._renderOne` (:209-212) | classes + width max(scrollWidth, contentWidth) | `current_line_content_class` + width | PORTED |
| `CurrentLineHighlightOverlay._shouldRenderThis/Other` (:213-218) | content/margin | ported | PORTED |
| `CurrentLineMarginHighlightOverlay._renderOne` (:225-228) | margin classes + width contentLeft | `current_line_margin_class` | PORTED |
| `CurrentLineMarginHighlightOverlay._shouldRenderThis/Other` (:229-234) | always render margin overlay | ported | PORTED |
| theming participant (:237-264) | bg/border rules | static CSS (deviation 5) | PORTED |
| css file (:1-27) | base positioning + margin-both border-right | `current_line_highlight.css` | PORTED |

## Validation

- `just check`; `moon test --target js viewer viewer/common viewer/browser/...`
- wbtests: cursor render-data math + class strings; current-line predicates +
  class strings across `renderLineHighlight` modes; focus gating.
- Browser: `dom_structure.spec.js` updated for the corrected shell;
  new `cursor_current_line.spec.js` conformance spec driving the harness
  (`setPosition`/`setSelection`/focus hooks added to
  `__readonlyEditorConformance`) asserting caret box position, hidden-on-blur,
  `.current-line` exact/wrapped classes, and `has-selection` suppression.
