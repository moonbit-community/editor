// Ported from `vscode/src/vs/editor/browser/viewParts/linesDecorations/
// linesDecorations.ts` (`LinesDecorationsOverlay.prepareRender`/`render`).
// The DOM-free half (decoration filtering + `DedupOverlay` expansion) lives
// in `viewer/common/view_model/margin_decorations.mbt`. Deviation: the
// viewer's margin layers are flat absolutely-positioned divs (like the
// folding markers), not Monaco's per-line wrapper divs, so each `.cldr`
// carries its own `top`/`height` instead of inheriting them from a line
// wrapper.

///|
/// Rebuilds the `.lines-decorations` layer: per visible line, one
/// `div.cldr.<class>` at `left = decorations_left`,
/// `width = decorations_width` (`LinesDecorationsOverlay.prepareRender`).
pub fn MarginViewOverlays::render_lines_decorations(
  self : MarginViewOverlays,
  viewport : @view_layout.ViewportData,
  class_names_per_line : Array[Array[String]],
  decorations_left~ : Double,
  decorations_width~ : Double,
) -> Unit {
  if decorations_width <= 0.0 {
    self.lines_decorations.set_inner_html("")
    return
  }
  let common = "\" style=\"left:" +
    decorations_left.to_string() +
    "px;width:" +
    decorations_width.to_string() +
    "px;"
  let mut html = ""
  for index in 0..<viewport.lines.length() {
    if index >= class_names_per_line.length() {
      break
    }
    for class_name in class_names_per_line[index] {
      html += "<div class=\"cldr " +
        class_name +
        common +
        "top:" +
        viewport.relative_vertical_offset[index].to_string() +
        "px;height:" +
        viewport.line_height.to_string() +
        "px;\"></div>"
    }
  }
  self.lines_decorations.set_inner_html(html)
}
