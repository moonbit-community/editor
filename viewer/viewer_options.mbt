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
) -> ViewerOptions {
  {
    soft_wrap,
    tab_size: tab_size.max(1),
    wrapping_indent,
    render_whitespace,
    render_control_characters,
    render_line_highlight,
    render_line_highlight_only_when_focus,
  }
}

///|
/// Default readonly viewer options.
pub fn ViewerOptions::default() -> ViewerOptions {
  ViewerOptions()
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
) -> @view_model.ViewModelOptions {
  if self.soft_wrap && soft_wrap_column > 0 {
    @view_model.ViewModelOptions::soft_wrap(
      soft_wrap_column,
      tab_size=self.tab_size,
      wrapping_indent=self.wrapping_indent,
    )
  } else {
    @view_model.ViewModelOptions::no_wrap()
  }
}
