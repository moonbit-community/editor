// Shared editor layout constants. DOM-free (plain numbers/strings), but used
// pervasively across every browser tier package (`viewer/browser/view`,
// every `view_parts/*`, controller, widget/code_editor) — moved here rather
// than left in `viewer/view.mbt` (which didn't carve out until Increment D,
// after this file landed) so that view-parts carved in Increment E didn't
// need an import back into the still-undivided root `viewer` package for
// just a numeric constant.

///|
/// Total horizontal padding of the line-number gutter. Keep in sync with
/// `.line-number` padding in viewer/margin.css.
pub let gutter_padding_px = 34

///|
/// Right padding of `.view-line-content`, part of the horizontal scroll extent.
pub let code_right_padding = 16.0

///|
/// Editor scrollbar defaults from Monaco's `EditorScrollbar` option.
pub let editor_vertical_scrollbar_size = 14.0

///|
pub let editor_horizontal_scrollbar_size = 12.0
