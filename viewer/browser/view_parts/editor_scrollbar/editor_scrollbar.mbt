// Ported from `vscode/src/vs/editor/browser/viewParts/editorScrollbar/editorScrollbar.ts`.
// The custom scrollbar geometry/DOM itself lives in `viewer/ui/scrollbar`
// (Monaco's `base/browser/ui/scrollbar/`); this package is the thin
// view-part wrapper around it. The `ViewPart` trait impl lives in
// `viewer/browser/view/view_part.mbt`, not here — see the exec-plan's cycle
// backlog and `viewer/browser/view_parts/view_zones`'s README for why.

///|
/// `pub(all)`: the `ViewPart` impl in `view_part.mbt` reads/writes
/// `should_render` directly.
pub(all) struct EditorScrollbar {
  editor_scrollable : @scrollbar.ScrollableElementDom
  mut should_render : Bool
}

///|
pub fn EditorScrollbar::new() -> EditorScrollbar {
  let editor_scrollable = @scrollbar.ScrollableElementDom::new(
    "lines-content moonbit-viewer-background",
    vertical_size=@core.editor_vertical_scrollbar_size,
    horizontal_size=@core.editor_horizontal_scrollbar_size,
  )
  editor_scrollable.set_wrapper_class(
    "monaco-scrollable-element editor-scrollable",
  )
  editor_scrollable.wrapper.set_attribute("data-view-part", "editor-scrollable")
  editor_scrollable.content.set_attribute("data-view-part", "lines-content")
  editor_scrollable.update_from_model(
    { width: 0.0, scroll_width: 0.0, height: 0.0, scroll_height: 0.0 },
    { scroll_left: 0.0, scroll_top: 0.0 },
  )
  { editor_scrollable, should_render: true }
}

///|
pub fn EditorScrollbar::get_dom_node(self : EditorScrollbar) -> @rdom.Element {
  self.editor_scrollable.wrapper
}

///|
pub fn EditorScrollbar::content(self : EditorScrollbar) -> @rdom.Element {
  self.editor_scrollable.content
}

///|
pub fn EditorScrollbar::scrollable(
  self : EditorScrollbar,
) -> @scrollbar.ScrollableElementDom {
  self.editor_scrollable
}
