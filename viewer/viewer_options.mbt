///|
/// Runtime viewer options that affect view-model construction and layout.
pub(all) struct ViewerOptions {
  soft_wrap : Bool
  tab_size : Int
  wrapping_indent : @view_model.WrappingIndent
  render_whitespace : @view_layout.RenderWhitespace
  render_control_characters : Bool
  render_line_highlight : @view_layout.RenderLineHighlight
  render_line_highlight_only_when_focus : Bool
  /// `renderValidationDecorations`. Product default `On` — Monaco defaults to
  /// `Editable`, which hides validation squiggles in readonly editors, and the
  /// readonly viewer's diagnostics rendering is a shipped feature. Hosts can
  /// pass `Editable`/`Off` for Monaco's semantics.
  render_validation_decorations : @view_model.RenderValidationDecorations
  /// The color theme, Monaco's standalone `theme` option
  /// (`IStandaloneEditorConstructionOptions.theme`, also accepted by
  /// `updateOptions`). Mirrored onto the view root as `data-theme`.
  theme : String
  /// The message shown while the viewer has no rendered model — Monaco's
  /// `placeholder` editor option.
  placeholder : String
  /// Width in pixels of the line-decorations gutter lane between the line
  /// numbers and the content — Monaco's `lineDecorationsWidth` editor option.
  /// `0` (the default) renders no lane, keeping the gutter pixel-identical to
  /// the pre-lane viewer; features that draw gutter decorations (e.g.
  /// comments) reserve their lane through `update_options`.
  line_decorations_width : Int
  /// Monaco's `showUnused` editor option (default `true`,
  /// `editorOptions.ts:6645-6647`): adds the `showUnused` root class that
  /// gates the `squiggly-unnecessary` / `squiggly-inline-unnecessary`
  /// styling (`EditorClassName.compute`, `editorOptions.ts:1680-1682`).
  show_unused : Bool
  /// Monaco's `showDeprecated` editor option (default `true`,
  /// `editorOptions.ts:6649-6653`): adds the `showDeprecated` root class
  /// gating the `squiggly-inline-deprecated` strike-through.
  show_deprecated : Bool
  /// Monaco's `fontFamily`/`fontWeight`/`fontSize`/`lineHeight`/
  /// `letterSpacing` editor options, defaulting to `EDITOR_FONT_DEFAULTS`.
  /// `line_height` follows `BareFontInfo._create`'s rules: `0` derives the
  /// golden-ratio height from `font_size`, values below `8` multiply the
  /// font size (ems), anything else is pixels.
  font_family : String
  font_weight : String
  font_size : Double
  line_height : Double
  letter_spacing : Double
} derive(Eq, Debug)

///|
/// Builds viewer options, normalizing `tab_size` to at least one column.
/// `wrapping_indent` defaults to `Same`, Monaco's default, and applies only when
/// `soft_wrap` is on. `render_whitespace` defaults to `Selection`, Monaco's
/// default — whitespace glyphs render under the active selection.
/// `render_control_characters` defaults to `true`, also matching Monaco — it
/// only changes output on lines that contain control characters.
/// `render_line_highlight` defaults to `Line` and
/// `render_line_highlight_only_when_focus` to `false`, Monaco's defaults for
/// the current-line highlight (`editorOptions.ts`).
pub fn ViewerOptions::ViewerOptions(
  soft_wrap? : Bool = false,
  tab_size? : Int = 2,
  wrapping_indent? : @view_model.WrappingIndent = Same,
  render_whitespace? : @view_layout.RenderWhitespace = Selection,
  render_control_characters? : Bool = true,
  render_line_highlight? : @view_layout.RenderLineHighlight = Line,
  render_line_highlight_only_when_focus? : Bool = false,
  render_validation_decorations? : @view_model.RenderValidationDecorations = On,
  theme? : String = "dark",
  placeholder? : String = "",
  line_decorations_width? : Int = 0,
  show_unused? : Bool = true,
  show_deprecated? : Bool = true,
  font_family? : String = @config.editor_font_defaults.font_family,
  font_weight? : String = @config.editor_font_defaults.font_weight,
  font_size? : Double = @config.editor_font_defaults.font_size,
  line_height? : Double = @config.editor_font_defaults.line_height,
  letter_spacing? : Double = @config.editor_font_defaults.letter_spacing,
) -> ViewerOptions {
  {
    soft_wrap,
    tab_size: tab_size.max(1),
    wrapping_indent,
    render_whitespace,
    render_control_characters,
    render_line_highlight,
    render_line_highlight_only_when_focus,
    render_validation_decorations,
    theme,
    placeholder,
    line_decorations_width: line_decorations_width.max(0),
    show_unused,
    show_deprecated,
    font_family,
    font_weight,
    font_size,
    line_height,
    letter_spacing,
  }
}

///|
/// Whether the two option sets agree on every field that feeds view-model
/// construction or layout — `theme`, `placeholder`, and the root-class flags
/// (`show_unused`/`show_deprecated`) apply without a rebuild.
fn ViewerOptions::same_layout_options(
  self : ViewerOptions,
  other : ViewerOptions,
) -> Bool {
  {
    ..self,
    theme: other.theme,
    placeholder: other.placeholder,
    show_unused: other.show_unused,
    show_deprecated: other.show_deprecated,
  } ==
  other
}

///|
/// Default readonly viewer options.
pub fn ViewerOptions::default() -> ViewerOptions {
  ViewerOptions()
}

///|
/// The `BareFontInfo` these options request — Monaco's
/// `BareFontInfo.createFromValidatedSettings`. The viewer has no
/// `fontLigatures` option, so `font-feature-settings` is constantly
/// `EditorFontLigatures.OFF` (Monaco's default).
fn ViewerOptions::bare_font_info(
  self : ViewerOptions,
  pixel_ratio~ : Double,
) -> @config.BareFontInfo {
  @config.BareFontInfo::create(
    font_family=self.font_family,
    font_weight=self.font_weight,
    font_size=self.font_size,
    font_feature_settings=@config.editor_font_ligatures_off,
    font_variation_settings=@config.font_variation_off,
    line_height=self.line_height,
    letter_spacing=self.letter_spacing,
    pixel_ratio~,
  )
}

///|
/// Computes the soft-wrap column that fits the measured content width, or zero
/// when wrapping is disabled or measurement is not ready.
pub fn ViewerOptions::soft_wrap_column_for_content_width(
  self : ViewerOptions,
  content_width : Double,
  char_width : Double,
) -> Int {
  if !self.soft_wrap || content_width <= 0.0 || char_width <= 0.0 {
    0
  } else {
    (1).max((content_width / char_width).to_int())
  }
}

///|
/// Converts browser-level options into backend-neutral view-model options.
pub fn ViewerOptions::view_model_options(
  self : ViewerOptions,
  soft_wrap_column : Int,
  editor_id? : Int = 0,
) -> @view_model.ViewModelOptions {
  if self.soft_wrap && soft_wrap_column > 0 {
    ViewModelOptions(
      soft_wrap_column~,
      tab_size=self.tab_size,
      wrapping_indent=self.wrapping_indent,
      editor_id~,
      render_validation_decorations=self.render_validation_decorations,
    )
  } else {
    ViewModelOptions(
      editor_id~,
      render_validation_decorations=self.render_validation_decorations,
    )
  }
}
