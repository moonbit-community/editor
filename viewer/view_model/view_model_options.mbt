///|
/// Backend-neutral view-model options derived from browser layout settings.
pub(all) struct ViewModelOptions {
  soft_wrap_column : Int
  tab_size : Int
} derive(Eq, Debug)

///|
/// Builds options while clamping wrapping column and tab size.
pub fn ViewModelOptions::ViewModelOptions(
  soft_wrap_column? : Int = 0,
  tab_size? : Int = 2,
) -> ViewModelOptions {
  { soft_wrap_column: soft_wrap_column.max(0), tab_size: tab_size.max(1) }
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
) -> ViewModelOptions {
  ViewModelOptions(soft_wrap_column=column, tab_size~)
}

///|
/// Whether wrapping should produce projected view lines.
pub fn ViewModelOptions::is_soft_wrap_enabled(self : ViewModelOptions) -> Bool {
  self.soft_wrap_column > 0
}
