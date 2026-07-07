///|
/// Inputs `Viewer` provides to `View` for one readonly browser render.
/// `pub(all)`: `Viewer::flush_render` (`view_host.mbt`, root `viewer`
/// package) builds this via a struct literal passed straight into
/// `View::render` — the foreign-method rule keeps that call out of this
/// package, so the literal construction crosses the package boundary.
pub(all) struct ViewRenderInput {
  /// The rendered 1-based half-open view-line window: exactly the lines
  /// intersecting the viewport (already clamped to the document).
  window : @view_layout.LineWindow
  view_model : @view_model.ViewModel
  layout : @view_layout.ViewLayout
  browser_view_zones : Array[@view_zones.BrowserViewZone]
  selection_view_range : @base_common.Range?
  /// The full view-space selection (anchor + active position), Monaco's
  /// `ViewCursorStateChangedEvent.selections[0]`. Unlike
  /// `selection_view_range` (which is `None` when collapsed), this carries the
  /// caret position of an empty selection — the cursor part renders from it.
  view_selection : @view_model.Selection?
  hover_state : @hover.HoverController
  on_hover_measured : (Bool, Double, Double) -> Unit
  generation : Int
  /// Bumped by the `Viewer` per model `onDidChangeDecorations` event; a
  /// change dispatches `ViewDecorationsChanged` (plan Deviation 3).
  decorations_generation : Int
  gutter_width : Double
  /// Width of the line-decorations lane inside the gutter,
  /// `layoutInfo.decorationsWidth` (the margin part renders the lane at
  /// `left = gutter_width - line_decorations_width`).
  line_decorations_width : Double
  space_width : Double
  /// `fontInfo.canUseHalfwidthRightwardsArrow`: whether the whitespace
  /// renderer may paint tabs as U+FFEB without breaking monospace.
  can_use_halfwidth_rightwards_arrow : Bool
  render_whitespace : @view_layout.RenderWhitespace
  render_control_characters : Bool
  /// Whether the editor root has DOM focus (Monaco `ViewFocusChangedEvent`
  /// state; see `Viewer.editor_has_focus`).
  editor_has_focus : Bool
  /// Whether soft wrapping is in effect (Monaco `layoutInfo.isViewportWrapping`)
  /// — gates the current-line highlight's wrapped-line pass.
  word_wrap : Bool
  /// The current-line highlight options (`renderLineHighlight` /
  /// `renderLineHighlightOnlyWhenFocus`, Monaco defaults `'line'`/`false`).
  render_line_highlight : @view_layout.RenderLineHighlight
  render_line_highlight_only_when_focus : Bool
  /// Root-class flags from Monaco's `showUnused`/`showDeprecated` editor
  /// options (`EditorClassName.compute`, `editorOptions.ts:1680-1686`).
  show_unused : Bool
  show_deprecated : Bool
}

///|
/// Read/prepare context for view parts. It owns measured viewport data and
/// derived geometry so parts can prepare without recomputing shared inputs.
priv struct RenderingContext {
  view_context : ViewContext
  input : ViewRenderInput
  snapshot : ViewRenderSnapshot
  viewport : @view_layout.ViewportData
  gutter_width : Double
  position : @view_layout.ScrollPosition
  dimensions : @view_layout.ScrollDimensions
  translate_y : Double
}

///|
/// Write-phase render context for view parts — Monaco's
/// `RestrictedRenderingContext`, which carries the viewport data, scroll
/// state, and viewport decorations into `render`. The viewer's frame inputs
/// ride along as `input` (its stand-in for Monaco parts reading
/// `this._context` and event-tracked fields during render).
priv struct RestrictedRenderingContext {
  view_context : ViewContext
  input : ViewRenderInput
  viewport : @view_layout.ViewportData
  gutter_width : Double
  position : @view_layout.ScrollPosition
  dimensions : @view_layout.ScrollDimensions
  translate_y : Double
  content_transform : String
  margin_transform : String
  line_height : Int
}

///|
fn RenderingContext::from_input(
  view_context : ViewContext,
  input : ViewRenderInput,
) -> RenderingContext {
  // Pulled from the view model per render pass — Monaco's `view.ts` building
  // a fresh `ViewportData` over `viewLayout.getLinesViewportData()`.
  let viewport = @view_model.viewport_data_from_view_model(
    input.view_model,
    input.window,
    line_height=input.layout.line_height(),
    layout=input.layout,
  )
  let position = input.layout.position()
  let dimensions = input.layout.dimensions()
  let origin = input.layout.window_origin(input.window)
  let snapshot = ViewRenderSnapshot::from_input(input, position, dimensions)
  {
    view_context,
    input,
    snapshot,
    viewport,
    gutter_width: input.gutter_width,
    position,
    dimensions,
    translate_y: origin - position.scroll_top,
  }
}

///|
fn RenderingContext::restricted(
  self : RenderingContext,
) -> RestrictedRenderingContext {
  {
    view_context: self.view_context,
    input: self.input,
    viewport: self.viewport,
    gutter_width: self.gutter_width,
    position: self.position,
    dimensions: self.dimensions,
    translate_y: self.translate_y,
    content_transform: self.content_transform(),
    margin_transform: self.margin_transform(),
    line_height: self.viewport.line_height,
  }
}

///|
fn RenderingContext::content_transform(self : RenderingContext) -> String {
  "transform:translate(" +
  (-self.position.scroll_left).to_string() +
  "px," +
  self.translate_y.to_string() +
  "px)"
}

///|
fn RenderingContext::margin_transform(self : RenderingContext) -> String {
  "transform:translateY(" + self.translate_y.to_string() + "px)"
}

///|
priv struct ViewRenderSnapshot {
  window : @view_layout.LineWindow
  generation : Int
  decorations_generation : Int
  position : @view_layout.ScrollPosition
  dimensions : @view_layout.ScrollDimensions
  gutter_width : Double
  space_width : Double
  view_selection : @view_model.Selection?
  browser_view_zones : Array[@view_zones.BrowserViewZone]
  hover_state : @hover.HoverController
  editor_has_focus : Bool
}

///|
fn ViewRenderSnapshot::from_input(
  input : ViewRenderInput,
  position : @view_layout.ScrollPosition,
  dimensions : @view_layout.ScrollDimensions,
) -> ViewRenderSnapshot {
  {
    window: input.window,
    generation: input.generation,
    decorations_generation: input.decorations_generation,
    position,
    dimensions,
    gutter_width: input.gutter_width,
    space_width: input.space_width,
    view_selection: input.view_selection,
    browser_view_zones: input.browser_view_zones.copy(),
    hover_state: input.hover_state,
    editor_has_focus: input.editor_has_focus,
  }
}

///|
fn same_browser_view_zones(
  left : Array[@view_zones.BrowserViewZone],
  right : Array[@view_zones.BrowserViewZone],
) -> Bool {
  if left.length() != right.length() {
    return false
  }
  for index in 0..<left.length() {
    let left_zone = left[index]
    let right_zone = right[index]
    if left_zone.id != right_zone.id ||
      left_zone.anchor_line != right_zone.anchor_line ||
      left_zone.height_px != right_zone.height_px {
      return false
    }
  }
  true
}
