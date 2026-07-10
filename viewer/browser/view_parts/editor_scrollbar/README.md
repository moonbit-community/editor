# viewer/browser/view_parts/editor_scrollbar

The thin editor-scrollbar ViewPart, ported from Monaco's
`viewParts/editorScrollbar/editorScrollbar.ts`. `EditorScrollbar` owns one
`viewer/ui/scrollbar.ScrollableElementDom` and exposes its root, content node,
and scrollable object to `View` and the root input bridge.

Scrollbar DOM, slider arithmetic, reveal/fade, wheel normalization, and drag
geometry remain in `viewer/ui/scrollbar`; model scroll state remains in
`viewer/common/view_layout`. The `ViewPart` implementation lives in
`viewer/browser/view` for MoonBit orphan-rule reasons. This package is JS-only
and contains no `Viewer::` methods.
