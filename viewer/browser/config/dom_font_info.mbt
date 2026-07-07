// Ported from `vscode/src/vs/editor/browser/config/domFontInfo.ts`.

///|
/// Monaco `applyFontInfo`: writes a `BareFontInfo`'s font style properties
/// onto an element's inline style.
pub fn apply_font_info(
  node : @rdom.Element,
  font_info : @common_config.BareFontInfo,
) -> Unit {
  set_style_property(node, "font-family", font_info.get_massaged_font_family())
  set_style_property(node, "font-weight", font_info.font_weight)
  set_style_property(node, "font-size", "\{font_info.font_size}px")
  set_style_property(
    node,
    "font-feature-settings",
    font_info.font_feature_settings,
  )
  set_style_property(
    node,
    "font-variation-settings",
    font_info.font_variation_settings,
  )
  set_style_property(node, "line-height", "\{font_info.line_height}px")
  set_style_property(node, "letter-spacing", "\{font_info.letter_spacing}px")
}

///|
/// FFI gap-fill (no `style.setProperty` shortcut on the vendored `@rdom`
/// element).
pub extern "js" fn set_style_property(
  el : @rdom.Element,
  name : String,
  value : String,
) -> Unit = "(el, name, value) => el.style.setProperty(name, value)"
