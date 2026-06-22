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

## Control Hooks

Conformance specs may use these deterministic hooks:

- `__readonlyEditorSetHover`
- `__readonlyEditorClearHover`
- `__readonlyEditorScrollTo`
- `__readonlyEditorConformance`

These hooks are not smoke-test drivers. Use them only when the test needs exact
fixture payloads, deterministic scroll positions, or reference measurements.
