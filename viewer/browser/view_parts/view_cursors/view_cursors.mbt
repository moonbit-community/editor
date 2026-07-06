// Ported from `vscode/src/vs/editor/browser/viewParts/viewCursors/viewCursors.ts`
// and `viewCursor.ts` (oracle 294fb350), reduced to the arms reachable in this
// readonly single-cursor product — see the parity ledger in
// `docs/exec-plans/monaco-view-cursors-current-line-port.md`:
//
// - one primary cursor, no `CursorPlurality`/secondary cursors;
// - `readOnly` is constant `true`, so `_getCursorBlinking`
//   (`viewCursors.ts:227-240`) collapses to `focused ? Solid : Hidden` and the
//   blink timers/animation classes are unreachable (`cursor-solid` always);
// - `cursorStyle` is Monaco's default `Line` with `cursorWidth` 0 (→ width 2)
//   and `cursorHeight` 0 (→ full line height); the Block/Underline arms and
//   the block-cursor `textContent`/token-class plumbing are not ported.
//
// The `ViewPart` trait impl lives in `viewer/browser/view/view_part.mbt`, not
// here — see the exec-plan's cycle backlog and
// `viewer/browser/view_parts/view_zones`'s README for why.

///|
/// Monaco's `ViewCursorRenderData` (`viewCursor.ts:26-36`), minus the
/// block-cursor `textContent`/`textContentClassName` (N-A for the Line style).
pub(all) struct CursorRenderData {
  top : Int
  left : Double
  padding_left : Double
  width : Double
  height : Int
} derive(Eq, Debug)

///|
/// `pub(all)`: the `ViewPart` impl in `view_part.mbt` reads/writes
/// `should_render` / `render_data` directly.
pub(all) struct ViewCursors {
  cursors_layer : @rdom.Element
  cursor : @rdom.Element
  mut should_render : Bool
  /// Monaco `ViewCursor._renderData`, stored by `prepare_render` and written
  /// out by `render`. `None` when the cursor's view line is outside the
  /// rendered window or its line node is not measurable yet — Monaco's
  /// "Outside viewport → null" arms (`viewCursor.ts:177-180`).
  mut render_data : CursorRenderData?
}

///|
/// Builds the `.cursors-layer` part with its single `.cursor` child —
/// `ViewCursors` constructor (`viewCursors.ts:74-79`) + `ViewCursor`
/// constructor (`viewCursor.ts:74-80`; `monaco-mouse-cursor-text` is Monaco's
/// `MOUSE_CURSOR_TEXT_CSS_CLASS_NAME`).
pub fn ViewCursors::new(document : @rdom.Document) -> ViewCursors {
  let cursors_layer = document.create_element("div")
  cursors_layer.set_attribute("class", cursors_layer_class(false))
  cursors_layer.set_attribute("role", "presentation")
  cursors_layer.set_attribute("aria-hidden", "true")
  cursors_layer.set_attribute("data-view-part", "cursors-layer")
  let cursor = document.create_element("div")
  cursor.set_attribute("class", "cursor monaco-mouse-cursor-text")
  cursor.set_attribute("style", "display:none")
  cursors_layer.append_child(cursor.as_node())
  { cursors_layer, cursor, should_render: true, render_data: None }
}

///|
pub fn ViewCursors::dom(self : ViewCursors) -> @rdom.Element {
  self.cursors_layer
}

///|
/// The layer class — `_getClassName` (`viewCursors.ts:286-340`) with only the
/// reachable arms: `has-selection` (`:288-290`), the `cursor-line-style`
/// default (`:292-294`), and `cursor-solid` (`_blinkingEnabled` is constant
/// `false` in the readonly product, `:333-335`). The smooth-caret-animation
/// suffix rides on an unmodeled option (off by default).
pub fn cursors_layer_class(has_selection : Bool) -> String {
  "cursors-layer" +
  (if has_selection { " has-selection" } else { "" }) +
  " cursor-line-style cursor-solid"
}

///|
/// Monaco `dom.computeScreenAwareSize`: snaps a CSS pixel size onto the device
/// pixel grid, `max(1, floor(dpr * css_px)) / dpr`.
pub fn compute_screen_aware_size(
  device_pixel_ratio : Double,
  css_px : Double,
) -> Double {
  let screen_px = device_pixel_ratio * css_px
  let snapped = screen_px.floor()
  (if snapped < 1.0 { 1.0 } else { snapped }) / device_pixel_ratio
}

///|
/// FFI gap-fill (no `devicePixelRatio` binding in the vendored `@rdom`).
pub extern "js" fn device_pixel_ratio() -> Double =
  #| () => globalThis.devicePixelRatio || 1

///|
/// The Line-style arm of `ViewCursor._prepareRender` (`viewCursor.ts:175-203`)
/// for a caret already measured at `measured_left` on its rendered line:
/// width is `computeScreenAwareSize(2)` (`cursorWidth` 0 → the `2` default,
/// `:185`), and a caret at least 1px in shifts left by a 1px `padding-left`
/// so the bar straddles the character boundary (`:196-200`). Height is the
/// full line height (`cursorHeight` 0 → `lineHeight`, `:168-173`, so the
/// centering adjustment is zero).
pub fn prepare_cursor_render_data(
  measured_left : Double,
  top : Int,
  line_height : Int,
  device_pixel_ratio : Double,
) -> CursorRenderData {
  let width = compute_screen_aware_size(device_pixel_ratio, 2.0)
  let mut left = measured_left
  let mut padding_left = 0.0
  if width >= 2.0 && left >= 1.0 {
    padding_left = 1.0
    left -= padding_left
  }
  { top, left, padding_left, width, height: line_height }
}

///|
/// Writes the prepared `render_data` out — `ViewCursors.render` +
/// `ViewCursor.render` (`viewCursor.ts:254-282`) plus the show/hide half of
/// `_updateBlinking` (`viewCursors.ts:242-256`): in this readonly product the
/// blinking style is `focused ? Solid : Hidden`, and with no blink timers the
/// visibility flip happens here rather than between renders.
pub fn ViewCursors::render_cursor(
  self : ViewCursors,
  has_selection~ : Bool,
  editor_has_focus~ : Bool,
  content_transform : String,
) -> Unit {
  self.cursors_layer.set_attribute("class", cursors_layer_class(has_selection))
  self.cursors_layer.set_attribute("style", content_transform)
  match self.render_data {
    None => self.cursor.set_attribute("style", "display:none")
    Some(data) =>
      self.cursor.set_attribute(
        "style",
        cursor_style(data, visible=editor_has_focus),
      )
  }
}

///|
/// The inline style `ViewCursor.render` writes field-by-field through
/// `FastDomNode` (`viewCursor.ts:267-273`), with the `show`/`hide` visibility
/// (`:115-127`) folded in.
fn cursor_style(data : CursorRenderData, visible~ : Bool) -> String {
  "display:block;visibility:" +
  (if visible { "inherit" } else { "hidden" }) +
  ";top:\{data.top}px;left:\{data.left}px;padding-left:\{data.padding_left}px;width:\{data.width}px;height:\{data.height}px;line-height:\{data.height}px"
}
