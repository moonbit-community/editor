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
  view_selection : @core.Selection?
  gutter_width : Double
  /// Width of the line-decorations lane inside the gutter,
  /// `layoutInfo.decorationsWidth` (the margin part renders the lane at
  /// `left = gutter_width - line_decorations_width`).
  line_decorations_width : Double
  space_width : Double
  /// `fontInfo.typicalFullwidthCharacterWidth`: the content-widget layer's
  /// `_reduceAnchorCoordinates` clamp unit.
  typical_fullwidth_character_width : Double
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
  {
    view_context,
    input,
    viewport,
    gutter_width: input.gutter_width,
    position,
    dimensions,
    translate_y: viewport.big_numbers_delta.to_double() - position.scroll_top,
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
    margin_transform: self.margin_transform(),
    line_height: self.viewport.line_height,
  }
}

///|
fn RenderingContext::margin_transform(self : RenderingContext) -> String {
  "transform:translateY(" + self.translate_y.to_string() + "px)"
}

///|
/// `HorizontalPosition` (`vscode/src/vs/editor/browser/view/renderingContext.ts:196-209`,
/// vscode submodule commit b18492a288de038fbc7643aae6de8247029d11bd): a
/// measured caret x on a rendered line. `left` is `Math.round(original_left)`.
pub(all) struct HorizontalPosition {
  outside_rendered_line : Bool
  left : Int
  original_left : Double
} derive(Eq, Debug)

///|
pub fn HorizontalPosition::new(
  outside_rendered_line : Bool,
  left : Double,
) -> HorizontalPosition {
  {
    outside_rendered_line,
    original_left: left,
    left: (left + 0.5).floor().to_int(),
  }
}
