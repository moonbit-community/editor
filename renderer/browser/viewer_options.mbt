///|
pub(all) struct ViewerOptions {
  soft_wrap : Bool
  tab_size : Int
} derive(Eq, Debug)

///|
pub fn ViewerOptions::ViewerOptions(
  soft_wrap? : Bool = false,
  tab_size? : Int = 2,
) -> ViewerOptions {
  { soft_wrap, tab_size: max_int(tab_size, 1) }
}

///|
pub fn ViewerOptions::default() -> ViewerOptions {
  ViewerOptions()
}

///|
pub fn ViewerOptions::soft_wrap_column_for_content_width(
  self : ViewerOptions,
  content_width : Double,
  char_width : Double,
) -> Int {
  if !self.soft_wrap || content_width <= 0.0 || char_width <= 0.0 {
    0
  } else {
    max_int(1, (content_width / char_width).to_int())
  }
}

///|
pub fn ViewerOptions::view_model_options(
  self : ViewerOptions,
  soft_wrap_column : Int,
) -> @view_model.ViewModelOptions {
  if self.soft_wrap && soft_wrap_column > 0 {
    @view_model.ViewModelOptions::soft_wrap(
      soft_wrap_column,
      tab_size=self.tab_size,
    )
  } else {
    @view_model.ViewModelOptions::no_wrap()
  }
}
