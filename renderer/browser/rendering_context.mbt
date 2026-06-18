///|
/// Inputs `Viewer` provides to `View` for one readonly browser render.
priv struct ViewRenderInput {
  frame : @view_model.RenderFrame
  view_model : @view_model.ViewModel?
  layout : @view_layout.ViewLayout
  browser_view_zones : Array[BrowserViewZone]
  decorations : Array[@decorations.Decoration]
  selection_range : @base_common.Range?
  folding_ranges : Array[@language.FoldingRange]
  folded_ranges : Array[@language.FoldingRange]
  hover_state : HoverController
  on_toggle_fold : (Int) -> Unit
  on_hover_measured : (Bool, Double) -> Unit
  generation : Int
  gutter_width : Double
  space_width : Double
}

///|
/// Read/prepare context for view parts. It owns measured viewport data and
/// derived geometry so parts can prepare without recomputing shared inputs.
priv struct RenderingContext {
  view_context : ViewContext
  input : ViewRenderInput
  snapshot : ViewRenderSnapshot
  change : ViewRenderChange
  viewport : @view_layout.ViewportData
  gutter_width : Double
  position : @view_layout.ScrollPosition
  dimensions : @view_layout.ScrollDimensions
  translate_y : Double
}

///|
/// Write-only render context for view parts.
priv struct RestrictedRenderingContext {
  view_context : ViewContext
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
  previous : ViewRenderSnapshot?,
) -> RenderingContext {
  let viewport = match input.view_model {
    Some(model) =>
      @view_layout.ViewportData::from_view_model(
        model,
        frame_window(input.frame),
        line_height=editor_line_height,
        decorations=input.decorations,
        layout=input.layout,
      )
    None =>
      @view_layout.ViewportData::from_render_frame(
        input.frame,
        line_height=editor_line_height,
        decorations=input.decorations,
      )
  }
  let position = input.layout.position()
  let dimensions = input.layout.dimensions()
  let origin = input.layout.window_origin(frame_window(input.frame))
  let snapshot = ViewRenderSnapshot::from_input(input, position, dimensions)
  {
    view_context,
    input,
    snapshot,
    change: ViewRenderChange::from_snapshots(previous, snapshot),
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
    viewport: self.viewport,
    gutter_width: self.gutter_width,
    position: self.position,
    dimensions: self.dimensions,
    translate_y: self.translate_y,
    content_transform: self.content_transform(),
    margin_transform: self.margin_transform(),
    line_height: editor_line_height,
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
  position : @view_layout.ScrollPosition
  dimensions : @view_layout.ScrollDimensions
  gutter_width : Double
  space_width : Double
  selection_range : @base_common.Range?
  folding_ranges : Array[@language.FoldingRange]
  folded_ranges : Array[@language.FoldingRange]
  browser_view_zones : Array[BrowserViewZone]
  hover_state : HoverController
}

///|
fn ViewRenderSnapshot::from_input(
  input : ViewRenderInput,
  position : @view_layout.ScrollPosition,
  dimensions : @view_layout.ScrollDimensions,
) -> ViewRenderSnapshot {
  {
    window: frame_window(input.frame),
    generation: input.generation,
    position,
    dimensions,
    gutter_width: input.gutter_width,
    space_width: input.space_width,
    selection_range: input.selection_range,
    folding_ranges: input.folding_ranges.copy(),
    folded_ranges: input.folded_ranges.copy(),
    browser_view_zones: input.browser_view_zones.copy(),
    hover_state: input.hover_state,
  }
}

///|
priv struct ViewRenderChange {
  first_render : Bool
  frame_generation_changed : Bool
  viewport_window_changed : Bool
  scroll_position_changed : Bool
  layout_dimensions_changed : Bool
  gutter_width_changed : Bool
  glyph_width_changed : Bool
  decorations_changed : Bool
  selection_changed : Bool
  folding_changed : Bool
  view_zones_changed : Bool
  hover_changed : Bool
}

///|
fn ViewRenderChange::from_snapshots(
  previous : ViewRenderSnapshot?,
  current : ViewRenderSnapshot,
) -> ViewRenderChange {
  match previous {
    None =>
      {
        first_render: true,
        frame_generation_changed: true,
        viewport_window_changed: true,
        scroll_position_changed: true,
        layout_dimensions_changed: true,
        gutter_width_changed: true,
        glyph_width_changed: true,
        decorations_changed: true,
        selection_changed: true,
        folding_changed: true,
        view_zones_changed: true,
        hover_changed: true,
      }
    Some(previous) => {
      let generation_changed = previous.generation != current.generation
      {
        first_render: false,
        frame_generation_changed: generation_changed,
        viewport_window_changed: previous.window != current.window,
        scroll_position_changed: previous.position != current.position,
        layout_dimensions_changed: previous.dimensions != current.dimensions,
        gutter_width_changed: previous.gutter_width != current.gutter_width,
        glyph_width_changed: previous.space_width != current.space_width,
        decorations_changed: generation_changed,
        selection_changed: previous.selection_range != current.selection_range,
        folding_changed: previous.folding_ranges != current.folding_ranges ||
        previous.folded_ranges != current.folded_ranges,
        view_zones_changed: !same_browser_view_zones(
          previous.browser_view_zones,
          current.browser_view_zones,
        ),
        hover_changed: previous.hover_state != current.hover_state,
      }
    }
  }
}

///|
fn same_browser_view_zones(
  left : Array[BrowserViewZone],
  right : Array[BrowserViewZone],
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
