# Browser Conformance Tests

Conformance specs check reference parity rather than broad user workflows. They
may inspect exact DOM, computed styles, geometry, screenshots, and deterministic
test hooks.

## Monaco Hover And Scrollbar Contracts

These selectors are intentional contracts for Monaco-shaped behavior. Keep them
out of high-level harness docs; update this file and the matching specs when the
reference contract changes.

- The editor scroll surface is
  `.overflow-guard > .monaco-scrollable-element.editor-scrollable`.
- Monaco-shaped scrollables expose horizontal and vertical `.scrollbar` nodes
  with `.slider` children.
- The hover content widget is rooted at `[data-content-widget="hover"]`.
- The hover wrapper uses `.monaco-resizable-hover`.
- The visible hover node uses `.monaco-hover`.
- Hover content is inside `.monaco-scrollable-element .monaco-hover-content`.

The local oracle is `tests/reference/monaco-hover-scrollbar/`, with comparison
coverage in `tests/browser/conformance/monaco_hover_scrollbar.spec.js`.

## DOM Structure Contracts

`dom_structure.spec.js` locks the Monaco-shaped DOM hierarchy that copied
Monaco CSS depends on. It checks normalized element signatures and direct child
order for the editor scroll shell, view layers, hover widget, and hover
scrollbars without asserting text content, geometry, or virtualization window
size.

## Computed Style And Geometry Contracts

`computed_style_geometry.spec.js` checks the next parity layer: browser-resolved
CSS and layout dimensions for the editor scroll surface, hover shell, hover
scrollbars, and marker-hover affordances. It compares stable computed
properties against the Monaco oracle and uses pixel tolerance only for geometry
that can vary with browser rounding.

## Selection Geometry Contracts

`selection_geometry.spec.js` locks in the DOM-as-source-of-truth selection
behavior (Monaco's `MouseTargetFactory` + `SelectionsOverlay` roles): pointer
hits resolve through the browser caret APIs and the highlight is painted from
measured client rects, not monospace `ch` arithmetic. It asserts that a
contiguous single-line selection paints exactly one merged `.selected-text`
rectangle (no per-token seams) and that a selection continuing past a line's
text extends the highlight beyond the rendered text's right edge. It drives the
`component.html` harness with real pointer drags and tolerates
character-boundary snapping rather than asserting exact pixel widths.

## Scroll Windowing Boundary

`scroll_windowing.spec.js` keeps only the DOM-wiring smoke for virtualization:
that the wired-up app mounts a single `.view-lines` layer, windows visible nodes
(line 1 visible, line 10000 absent), and reveals the last line after a
scroll-to-bottom. The *semantic* windowing and view↔model projection assertions
— the frame's viewport window, projected view positions under soft wrap, and the
scroll-window math the memory note flagged as previously regressing only under
`just test-browser` — now live in the headless viewer harness
(`viewer/test_viewer_wbtest.mbt`, see `docs/harness.md`), where they are
deterministic and DOM-free.

## Control Hooks

Conformance specs may use these deterministic hooks:

- `__readonlyEditorSetHover`
- `__readonlyEditorClearHover`
- `__readonlyEditorScrollTo`
- `__readonlyEditorConformance`

These hooks are not smoke-test drivers. Use them only when the test needs exact
fixture payloads, deterministic scroll positions, or reference measurements.
