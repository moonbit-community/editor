///|
/// Keeps the measured editor outer width invariant when a changed model-line
/// digit band moves `layoutInfo.contentLeft`. Monaco's
/// `EditorConfiguration.setModelLineCount` recomputes layout options before it
/// publishes the resulting Configuration event. The local Viewer already owns
/// the last measured content box, so it can derive the new content width
/// synchronously without another DOM read:
///
/// `outerWidth = oldContentLeft + oldContentWidth`
/// `newContentWidth = max(0, outerWidth - newContentLeft)`
///
/// Returns whether the content-left band changed. The caller emits LayoutInfo
/// only after this helper, so ContentWidgets' live configuration read observes
/// the matching `contentLeft`/`contentWidth` pair.
fn Viewer::sync_content_box_for_model_line_count(
  self : Viewer,
  view_model : @view_model.ViewModel,
  previous_model_line_count : Int,
  current_model_line_count : Int,
) -> Bool {
  let previous_content_left = self.gutter_width(previous_model_line_count)
  let current_content_left = self.gutter_width(current_model_line_count)
  if previous_content_left == current_content_left {
    return false
  }
  let measured_outer_width = previous_content_left + self.measured_content_width
  let available_content_width = measured_outer_width - current_content_left
  self.measured_content_width = if available_content_width > 0.0 {
    available_content_width
  } else {
    0.0
  }
  view_model.view_layout.set_viewport_size(
    width=self.measured_content_width,
    height=self.measured_height,
  )
  |> ignore
  self.sync_content_width()
  // A real View rechecks the DOM box in the next read phase. This does not
  // delay the configuration fact above; it catches an independent host resize
  // and lets wrapping react before the same frame writes.
  if self.get_view() is Some(_) {
    self.measure_requested = true
  }
  true
}
