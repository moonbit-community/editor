///|
pub(all) struct ViewModelOptions {
  soft_wrap_column : Int
  tab_size : Int
} derive(Eq, Debug)

///|
pub fn ViewModelOptions::ViewModelOptions(
  soft_wrap_column? : Int = 0,
  tab_size? : Int = 2,
) -> ViewModelOptions {
  {
    soft_wrap_column: max_int(soft_wrap_column, 0),
    tab_size: max_int(tab_size, 1),
  }
}

///|
pub fn ViewModelOptions::no_wrap() -> ViewModelOptions {
  ViewModelOptions(soft_wrap_column=0)
}

///|
pub fn ViewModelOptions::soft_wrap(
  column : Int,
  tab_size? : Int = 2,
) -> ViewModelOptions {
  ViewModelOptions(soft_wrap_column=column, tab_size~)
}

///|
pub fn ViewModelOptions::is_soft_wrap_enabled(self : ViewModelOptions) -> Bool {
  self.soft_wrap_column > 0
}
