///|
/// Backend-neutral view-model options derived from browser layout settings.
pub(all) struct ViewModelOptions {
  soft_wrap_column : Int
  tab_size : Int
  wrapping_indent : WrappingIndent
  /// The owning editor's id — the `ownerId` filter for decoration queries
  /// (Monaco's `editorId` handed to `ViewModelDecorations`). `0` means "no
  /// editor": only ownerId-0 decorations match.
  editor_id : Int
  /// `renderValidationDecorations`. Monaco defaults to `Editable` (which
  /// hides validation decorations in readonly editors); the `Viewer` passes
  /// `On` — see `filter_validation_decorations`.
  render_validation_decorations : RenderValidationDecorations
} derive(Eq, Debug)

///|
/// Builds options while clamping wrapping column and tab size.
/// `wrapping_indent` defaults to `Same`, Monaco's default.
pub fn ViewModelOptions::ViewModelOptions(
  soft_wrap_column? : Int = 0,
  tab_size? : Int = 2,
  wrapping_indent? : WrappingIndent = Same,
  editor_id? : Int = 0,
  render_validation_decorations? : RenderValidationDecorations = Editable,
) -> ViewModelOptions {
  {
    soft_wrap_column: soft_wrap_column.max(0),
    tab_size: tab_size.max(1),
    wrapping_indent,
    editor_id,
    render_validation_decorations,
  }
}

///|
/// Options with soft wrapping disabled.
pub fn ViewModelOptions::no_wrap() -> ViewModelOptions {
  ViewModelOptions(soft_wrap_column=0)
}

///|
/// Options with soft wrapping enabled at the given column.
pub fn ViewModelOptions::soft_wrap(
  column : Int,
  tab_size? : Int = 2,
  wrapping_indent? : WrappingIndent = Same,
) -> ViewModelOptions {
  ViewModelOptions(soft_wrap_column=column, tab_size~, wrapping_indent~)
}

///|
/// Whether wrapping should produce projected view lines.
pub fn ViewModelOptions::is_soft_wrap_enabled(self : ViewModelOptions) -> Bool {
  self.soft_wrap_column > 0
}
