// Shared editor layout constants. DOM-free (plain numbers/strings), but used
// pervasively across every browser tier package (`viewer/browser/view`,
// every `view_parts/*`, controller, widget/code_editor) — moved here rather
// than left in `viewer/view.mbt` (which didn't carve out until Increment D,
// after this file landed) so that view-parts carved in Increment E didn't
// need an import back into the still-undivided root `viewer` package for
// just a numeric constant.

///|
/// Pixel height of one rendered code line. Keep in sync with
/// `--editor-line-height` in internal/shell/workbench/theme.css.
pub let editor_line_height = 18

///|
/// Total horizontal padding of the line-number gutter. Keep in sync with
/// `.line-number` padding in viewer/margin.css.
pub let gutter_padding_px = 34

///|
/// Right padding of `.view-line-content`, part of the horizontal scroll extent.
pub let code_right_padding = 16.0

///|
/// Minimum line-number digit slots.
pub let gutter_min_digits = 5

///|
/// Editor scrollbar defaults from Monaco's `EditorScrollbar` option.
pub let editor_vertical_scrollbar_size = 14.0

///|
pub let editor_horizontal_scrollbar_size = 12.0

///|
/// Lines rendered beyond each viewport edge so scrolling stays inside
/// already-rendered DOM between window updates.
pub let line_overscan = 20

///|
pub let char_probe_text = "0000000000"

///|
/// Fallback advance width for the editor's 12px monospace stack, used
/// until the char probe is measured after attach.
pub let fallback_char_width = 7.2
