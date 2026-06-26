///|
/// Runtime viewer options that affect view-model construction and layout.
pub(all) struct ViewerOptions {
  soft_wrap : Bool
  tab_size : Int
} derive(Eq, Debug)

///|
/// Builds viewer options, normalizing `tab_size` to at least one column.
pub fn ViewerOptions::ViewerOptions(
  soft_wrap? : Bool = false,
  tab_size? : Int = 2,
) -> ViewerOptions {
  { soft_wrap, tab_size: tab_size.max(1) }
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
    )
  } else {
    @view_model.ViewModelOptions::no_wrap()
  }
}
