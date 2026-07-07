// Reference behaviors transcribed from
// `vscode/src/vs/editor/common/config/fontInfo.ts` (`BareFontInfo._create`).

///|
fn bare(line_height : Double, font_size : Double) -> @config.BareFontInfo {
  @config.BareFontInfo::create(
    font_family="Menlo",
    font_weight="normal",
    font_size~,
    font_feature_settings=@config.editor_font_ligatures_off,
    font_variation_settings=@config.font_variation_off,
    line_height~,
    letter_spacing=0.0,
    pixel_ratio=1.0,
  )
}

///|
test "lineHeight 0 derives the golden-ratio line height from the font size" {
  let expected = (@config.golden_line_height_ratio * 12.0 + 0.5).to_int()
  assert_eq(bare(0.0, 12.0).line_height, expected)
}

///|
test "lineHeight below the minimum is an em multiplier" {
  // 1.5em of a 12px font: 18px.
  assert_eq(bare(1.5, 12.0).line_height, 18)
  // 1.35em of a 14px font: round(18.9) = 19px.
  assert_eq(bare(1.35, 14.0).line_height, 19)
}

///|
test "lineHeight in pixels is rounded and floored at the minimum" {
  assert_eq(bare(18.0, 12.0).line_height, 18)
  assert_eq(bare(18.4, 12.0).line_height, 18)
  assert_eq(bare(18.5, 12.0).line_height, 19)
  // 0.5em of an 8px font resolves to 4px, below MINIMUM_LINE_HEIGHT.
  assert_eq(bare(0.5, 8.0).line_height, 8)
}

///|
test "fontVariationSettings translate maps numeric weights to wght" {
  let translated = @config.BareFontInfo::create(
    font_family="Menlo",
    font_weight="500",
    font_size=12.0,
    font_feature_settings=@config.editor_font_ligatures_off,
    font_variation_settings=@config.font_variation_translate,
    line_height=0.0,
    letter_spacing=0.0,
    pixel_ratio=1.0,
  )
  assert_eq(translated.font_weight, "normal")
  assert_eq(translated.font_variation_settings, "'wght' 500")
  let kept = @config.BareFontInfo::create(
    font_family="Menlo",
    font_weight="bold",
    font_size=12.0,
    font_feature_settings=@config.editor_font_ligatures_off,
    font_variation_settings=@config.font_variation_translate,
    line_height=0.0,
    letter_spacing=0.0,
    pixel_ratio=1.0,
  )
  assert_eq(kept.font_weight, "bold")
  assert_eq(kept.font_variation_settings, @config.font_variation_off)
}

///|
test "massaged font family appends the platform fallback and quotes spaces" {
  let custom = @config.BareFontInfo::create(
    font_family="Fira Code",
    font_weight="normal",
    font_size=12.0,
    font_feature_settings=@config.editor_font_ligatures_off,
    font_variation_settings=@config.font_variation_off,
    line_height=0.0,
    letter_spacing=0.0,
    pixel_ratio=1.0,
  )
  assert_eq(
    custom.get_massaged_font_family(),
    "\"Fira Code\", \{@config.editor_font_defaults.font_family}",
  )
  let default_family = bare(0.0, 12.0)
  // bare() uses "Menlo", not the full default stack, so the fallback appends.
  assert_true(default_family.get_massaged_font_family().contains("Menlo"))
}
