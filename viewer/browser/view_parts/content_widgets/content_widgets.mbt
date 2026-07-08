// Ported from `vscode/src/vs/editor/browser/viewParts/contentWidgets/contentWidgets.ts`
// (`ViewContentWidgets` + its inner `Widget`), with the `IContentWidget` /
// `IContentWidgetPosition` contracts of `editorBrowser.ts`. The `ViewPart`
// trait impl for `ContentWidgets` lives in `viewer/browser/view/view_part.mbt`,
// not here — see the exec-plan's cycle backlog and
// `viewer/browser/view_parts/view_zones`'s README for why.
//
// The widget lifecycle is the source's: a widget's DOM is appended once by
// `add_widget` and stays mounted until `remove_widget`; `set_widget_position`
// only records anchors/preference; each frame `prepare_render` computes the
// box layout and `render` writes `top`/`left`/`visibility`. Hiding is
// `visibility:hidden`, never unmounting — re-inserting a mounted node
// restarts CSS animations on its subtree (the hover's `fade-in`).

///|
/// Monaco `ContentWidgetPositionPreference` (`editorBrowser.ts`).
pub(all) enum ContentWidgetPositionPreference {
  Above
  Below
  Exact
} derive(Eq)

///|
/// Monaco `IContentWidgetPosition` (`editorBrowser.ts`): the model-space
/// anchors and the placement preference order. `position_affinity` is
/// unported — the only source consumer is `shouldAppearBeforeContent`
/// (inline-suggest), N-A here.
pub(all) struct ContentWidgetPosition {
  position : @base_common.Position?
  secondary_position : @base_common.Position?
  preference : Array[ContentWidgetPositionPreference]
}

///|
/// Monaco `IContentWidget` (`editorBrowser.ts`), the I-prefix dropped per the
/// repo's naming rule. `allow_editor_overflow` is a method rather than the
/// source's readonly field (MoonBit traits carry no data).
pub(open) trait ContentWidget {
  fn get_id(Self) -> String
  fn get_dom_node(Self) -> @rdom.Element
  fn get_position(Self) -> ContentWidgetPosition?
  fn allow_editor_overflow(Self) -> Bool
}

///|
/// Monaco's `IRenderData` (`contentWidgets.ts:177-188`): where the widget
/// renders this frame. `top` is viewport-relative (the render pass converts to
/// the content layer's coordinate space, the source's `+ ctx.scrollTop -
/// ctx.bigNumbersDelta`), `left` is content-space.
priv enum WidgetRenderData {
  InViewport(top~ : Double, left~ : Double)
  OffViewport(preserve_focus~ : Bool)
}

///|
/// Monaco's inner `Widget` (`contentWidgets.ts:190`): per-widget position
/// state, the cached DOM box, and this frame's render data. Anchors are held
/// model-space and resolved through the coordinates converter at
/// `prepare_render` (the source caches the view position and re-resolves on
/// line-mapping events; resolving per prepared frame is observably the same
/// and needs no `_updateAnchorsViewPositions` plumbing).
priv struct Widget {
  dom_node : @rdom.Element
  id : String
  mut position : @base_common.Position?
  mut secondary_position : @base_common.Position?
  mut preference : Array[ContentWidgetPositionPreference]
  /// Monaco `_cachedDomNodeOffsetWidth/Height`, invalidated by `set_position`.
  mut cached_dom_node_offset_width : Double
  mut cached_dom_node_offset_height : Double
  mut is_visible : Bool
  /// Whether `setPosition` switched the node to `display:block` so
  /// `prepare_render` can measure it (`contentWidgets.ts:296-304`).
  mut display_block : Bool
  /// The last written coordinate, kept so the hidden branch leaves `top`/
  /// `left` untouched like the source's per-property `FastDomNode` writes.
  mut top : Double
  mut left : Double
  mut render_data : WidgetRenderData?
}

///|
/// `pub(all)`: the `ViewPart` impl in `view_part.mbt` reads/writes
/// `should_render` / `dom_node` directly.
pub(all) struct ContentWidgets {
  dom_node : @rdom.Element
  overflowing_content_widgets_dom_node : @rdom.Element
  priv widgets : Map[String, Widget]
  mut should_render : Bool
}

///|
pub fn ContentWidgets::new(document : @rdom.Document) -> ContentWidgets {
  let dom_node = document.create_element("div")
  dom_node.set_attribute("class", "contentWidgets")
  dom_node.set_attribute("data-view-part", "contentWidgets")
  let overflowing_content_widgets_dom_node = document.create_element("div")
  overflowing_content_widgets_dom_node.set_attribute(
    "class", "overflowingContentWidgets",
  )
  overflowing_content_widgets_dom_node.set_attribute(
    "data-view-part", "overflowingContentWidgets",
  )
  {
    dom_node,
    overflowing_content_widgets_dom_node,
    widgets: {},
    should_render: true,
  }
}

///|
pub fn ContentWidgets::dom_node(self : ContentWidgets) -> @rdom.Element {
  self.dom_node
}

///|
pub fn ContentWidgets::overflowing_content_widgets_dom_node(
  self : ContentWidgets,
) -> @rdom.Element {
  self.overflowing_content_widgets_dom_node
}

///|
/// Monaco `ViewContentWidgets.addWidget` (`contentWidgets.ts:102-113`): mount
/// the widget's DOM once — every later frame only repositions it. The initial
/// `display:none; visibility:hidden` mirrors the source `Widget` constructor.
pub fn ContentWidgets::add_widget(
  self : ContentWidgets,
  actual : &ContentWidget,
) -> Unit {
  let dom_node = actual.get_dom_node()
  let widget : Widget = {
    dom_node,
    id: actual.get_id(),
    position: None,
    secondary_position: None,
    preference: [],
    cached_dom_node_offset_width: -1.0,
    cached_dom_node_offset_height: -1.0,
    is_visible: false,
    display_block: false,
    top: 0.0,
    left: 0.0,
    render_data: None,
  }
  self.widgets[widget.id] = widget
  dom_node.set_attribute("data-content-widget", widget.id)
  widget.apply_style()
  if actual.allow_editor_overflow() {
    self.overflowing_content_widgets_dom_node.append_child(dom_node.as_node())
  } else {
    self.dom_node.append_child(dom_node.as_node())
  }
  self.should_render = true
}

///|
/// Monaco `ViewContentWidgets.setWidgetPosition` (`contentWidgets.ts:115-122`)
/// fed by `CodeEditorWidget.layoutContentWidget` reading the widget's
/// `getPosition()`: record the anchors/preference, flip `display` so the
/// prepare pass can measure a widget that wants to become visible, and
/// invalidate the cached box (`Widget.setPosition`, `:293-307`).
pub fn ContentWidgets::set_widget_position(
  self : ContentWidgets,
  actual : &ContentWidget,
) -> Unit {
  guard self.widgets.get(actual.get_id()) is Some(widget) else { return }
  match actual.get_position() {
    Some(position) => {
      widget.position = position.position
      widget.secondary_position = position.secondary_position
      widget.preference = position.preference
    }
    None => {
      widget.position = None
      widget.secondary_position = None
      widget.preference = []
    }
  }
  widget.display_block = widget.position is Some(_) &&
    widget.preference.length() > 0
  widget.apply_style()
  widget.cached_dom_node_offset_width = -1.0
  widget.cached_dom_node_offset_height = -1.0
  self.should_render = true
}

///|
/// Monaco `ViewContentWidgets.removeWidget` (`contentWidgets.ts:124-136`).
pub fn ContentWidgets::remove_widget(
  self : ContentWidgets,
  actual : &ContentWidget,
) -> Unit {
  let id = actual.get_id()
  guard self.widgets.get(id) is Some(widget) else { return }
  self.widgets.remove(id)
  let parent = if actual.allow_editor_overflow() {
    self.overflowing_content_widgets_dom_node
  } else {
    self.dom_node
  }
  parent.remove_child(widget.dom_node.as_node())
  self.should_render = true
}

///|
/// The geometry/converter capabilities the prepare pass needs from the render
/// context — Monaco's `RenderingContext` surface as data plus closures, the
/// same host pattern `PointerHandlerHelper` uses (this package cannot import
/// `browser/view`'s context types without a cycle).
pub(all) struct ContentWidgetsRenderContext {
  /// Model position → view position through the active coordinates converter
  /// (Monaco `getValidPositionPair`'s `convertModelPositionToViewPosition`).
  model_position_to_view_position : (@base_common.Position) -> @base_common.Position
  /// Content-space vertical offset of a view line
  /// (`ctx.getVerticalOffsetForLineNumber`).
  vertical_offset_for_line : (Int) -> Double
  /// The rendered view-line window (half-open); an anchor outside it has no
  /// line DOM, the analog of `visibleRangeForPosition` returning `null`.
  window_start : Int
  window_end : Int
  line_height : Double
  /// Measured monospace glyph advance: the anchor's `left` is
  /// `column * char_width` in exact pixels (Monaco measures via
  /// `visibleRangeForPosition`; the viewer's monospace metric is its
  /// established stand-in).
  char_width : Double
  /// `fontInfo.typicalFullwidthCharacterWidth`, the `_reduceAnchorCoordinates`
  /// clamp unit.
  typical_fullwidth_character_width : Double
  scroll_top : Double
  scroll_left : Double
  viewport_width : Double
  viewport_height : Double
}

///|
/// Monaco `ViewContentWidgets.prepareRender` (`contentWidgets.ts:152-157`):
/// compute each widget's render data for this frame.
pub fn ContentWidgets::prepare_render_widgets(
  self : ContentWidgets,
  ctx : ContentWidgetsRenderContext,
) -> Unit {
  for _, widget in self.widgets {
    widget.render_data = widget.prepare_render_widget(ctx)
  }
}

///|
/// Monaco `ViewContentWidgets.render` (`contentWidgets.ts:159-164`) over
/// `Widget.render` (`:556-596`). `translate_y` is the content layer's vertical
/// transform, so `top_style = viewport_top - translate_y` is the source's
/// `coordinate.top + ctx.scrollTop - ctx.bigNumbersDelta` on the transformed
/// layer.
pub fn ContentWidgets::render_widgets(
  self : ContentWidgets,
  translate_y : Double,
) -> Unit {
  for _, widget in self.widgets {
    widget.render(translate_y)
  }
}

///|
/// Monaco `AnchorCoordinate` (`contentWidgets.ts:615-623`).
priv struct AnchorCoordinate {
  top : Double
  left : Double
  height : Double
}

///|
/// Monaco `IBoxLayoutResult` (`contentWidgets.ts:167-175`).
priv struct BoxLayoutResult {
  fits_above : Bool
  above_top : Double
  fits_below : Bool
  below_top : Double
  left : Double
}

///|
/// Monaco `Widget._prepareRenderWidget` (`contentWidgets.ts:447-534`), the
/// non-overflowing arm only (the viewer's hover is clipped to
/// `.overflow-guard` — the Phase 1b non-overflowing deviation — so
/// `_layoutBoxInPage` is N-A).
fn Widget::prepare_render_widget(
  self : Widget,
  ctx : ContentWidgetsRenderContext,
) -> WidgetRenderData? {
  if self.preference.length() == 0 {
    return None
  }
  let (primary, secondary) = self.anchors_coordinates(ctx)
  guard primary is Some(primary) else {
    return Some(
      OffViewport(preserve_focus=element_contains_active_element(self.dom_node)),
    )
  }
  if self.cached_dom_node_offset_width < 0.0 ||
    self.cached_dom_node_offset_height < 0.0 {
    // The `beforeRender` preferred-dimensions arm is N-A (no viewer widget
    // implements it); measure the live box like the source's fallback.
    let rect = self.dom_node.get_bounding_client_rect()
    self.cached_dom_node_offset_width = rect.get_width()
    self.cached_dom_node_offset_height = rect.get_height()
  }
  let anchor = reduce_anchor_coordinates(
    primary,
    secondary,
    self.cached_dom_node_offset_width,
    ctx.typical_fullwidth_character_width,
  )
  let placement = layout_box_in_viewport(
    anchor,
    self.cached_dom_node_offset_width,
    self.cached_dom_node_offset_height,
    ctx,
  )
  // Do two passes, first for perfect fit, second picks first option.
  for pass in 1..<=2 {
    for pref in self.preference {
      match pref {
        Above =>
          if pass == 2 || placement.fits_above {
            return Some(
              InViewport(top=placement.above_top, left=placement.left),
            )
          }
        Below =>
          if pass == 2 || placement.fits_below {
            return Some(
              InViewport(top=placement.below_top, left=placement.left),
            )
          }
        Exact => return Some(InViewport(top=anchor.top, left=anchor.left))
      }
    }
  }
  None
}

///|
/// Monaco `Widget._getAnchorsCoordinates` (`contentWidgets.ts:407-429`): the
/// primary/secondary anchors as viewport-relative top + content-space left.
/// The secondary participates only when it sits on the primary's line.
fn Widget::anchors_coordinates(
  self : Widget,
  ctx : ContentWidgetsRenderContext,
) -> (AnchorCoordinate?, AnchorCoordinate?) {
  let primary_view = match self.position {
    Some(position) => Some((ctx.model_position_to_view_position)(position))
    None => None
  }
  let secondary_view = match (self.secondary_position, primary_view) {
    (Some(position), Some(primary)) => {
      let secondary = (ctx.model_position_to_view_position)(position)
      if secondary.line_number == primary.line_number {
        Some(secondary)
      } else {
        None
      }
    }
    _ => None
  }
  let coordinate = fn(position : @base_common.Position) -> AnchorCoordinate? {
    // An anchor line outside the rendered window has no line DOM — the
    // source's `visibleRangeForPosition` returns `null` there.
    if position.line_number < ctx.window_start ||
      position.line_number >= ctx.window_end {
      return None
    }
    Some({
      top: (ctx.vertical_offset_for_line)(position.line_number) - ctx.scroll_top,
      left: (position.column - 1).to_double() * ctx.char_width,
      height: ctx.line_height,
    })
  }
  let primary = match primary_view {
    Some(position) => coordinate(position)
    None => None
  }
  let secondary = match secondary_view {
    Some(position) => coordinate(position)
    None => None
  }
  (primary, secondary)
}

///|
/// Monaco `Widget._reduceAnchorCoordinates` (`contentWidgets.ts:431-445`): the
/// widget must touch the primary anchor; the secondary pulls its left edge as
/// far as one fullwidth glyph keeps them overlapping.
fn reduce_anchor_coordinates(
  primary : AnchorCoordinate,
  secondary : AnchorCoordinate?,
  width : Double,
  typical_fullwidth_character_width : Double,
) -> AnchorCoordinate {
  guard secondary is Some(secondary) else { return primary }
  let mut left = secondary.left
  if left < primary.left {
    left = double_max(
      left,
      primary.left - width + typical_fullwidth_character_width,
    )
  } else {
    left = double_min(
      left,
      primary.left + width - typical_fullwidth_character_width,
    )
  }
  { top: primary.top, left, height: primary.height }
}

///|
/// Monaco `Widget._layoutBoxInViewport` (`contentWidgets.ts:309-335`). Vertical
/// coordinates are viewport-relative; `left` is content-space, clamped to the
/// horizontal scroll window (`[scrollLeft, scrollLeft + viewportWidth]`) — the
/// source's right/left-edge containment.
fn layout_box_in_viewport(
  anchor : AnchorCoordinate,
  width : Double,
  height : Double,
  ctx : ContentWidgetsRenderContext,
) -> BoxLayoutResult {
  // Our visible box is split horizontally by the current line => 2 boxes

  // a) the box above the line
  let above_line_top = anchor.top
  let height_available_above_line = above_line_top

  // b) the box under the line
  let under_line_top = anchor.top + anchor.height
  let height_available_under_line = ctx.viewport_height - under_line_top
  let above_top = above_line_top - height
  let fits_above = height_available_above_line >= height
  let below_top = under_line_top
  let fits_below = height_available_under_line >= height

  // And its left
  let mut left = anchor.left
  if left + width > ctx.scroll_left + ctx.viewport_width {
    left = ctx.scroll_left + ctx.viewport_width - width
  }
  if left < ctx.scroll_left {
    left = ctx.scroll_left
  }
  { fits_above, above_top, fits_below, below_top, left }
}

///|
/// Monaco `Widget.render` (`contentWidgets.ts:556-596`), the write half: only
/// `top`/`left`/`visibility` change per frame; the DOM stays mounted.
fn Widget::render(self : Widget, translate_y : Double) -> Unit {
  let was_visible = self.is_visible
  match self.render_data {
    Some(InViewport(top~, left~)) => {
      self.top = top - translate_y
      self.left = left
      self.is_visible = true
      self.apply_style()
      if !was_visible {
        self.dom_node.set_attribute("monaco-visible-content-widget", "true")
      }
    }
    Some(OffViewport(preserve_focus~)) => {
      // The widget wants to be shown, but its anchor is outside the viewport.
      self.is_visible = false
      if preserve_focus {
        // It has focus which we need to preserve: park it off-screen instead
        // of hiding (`contentWidgets.ts:563-569`).
        self.top = -1000.0
      }
      self.apply_style()
      if was_visible {
        self.dom_node.remove_attribute("monaco-visible-content-widget")
      }
    }
    None => {
      self.is_visible = false
      self.apply_style()
      if was_visible {
        self.dom_node.remove_attribute("monaco-visible-content-widget")
      }
    }
  }
}

///|
/// Writes the widget's positioning style in one attribute set — the stand-in
/// for the source's per-property `FastDomNode` mutations (`setTop`/`setLeft`/
/// `setVisibility`/`setDisplay`). The widget's own classes/styles live on its
/// descendants, so owning the wrapper's `style` here is safe.
fn Widget::apply_style(self : Widget) -> Unit {
  let display = if self.display_block { "block" } else { "none" }
  let visibility = if self.is_visible { "inherit" } else { "hidden" }
  self.dom_node.set_attribute(
    "style",
    "position:absolute;display:" +
    display +
    ";visibility:" +
    visibility +
    ";top:" +
    self.top.to_string() +
    "px;left:" +
    self.left.to_string() +
    "px",
  )
}

///|
fn double_max(left : Double, right : Double) -> Double {
  if left > right {
    left
  } else {
    right
  }
}

///|
fn double_min(left : Double, right : Double) -> Double {
  if left < right {
    left
  } else {
    right
  }
}

///|
/// Whether the document's active element sits inside `element` — the
/// `OffViewport` `preserveFocus` probe (`contentWidgets.ts:456`).
extern "js" fn element_contains_active_element(element : @rdom.Element) -> Bool =
  #| (element) => {
  #|   const active = element?.ownerDocument?.activeElement;
  #|   return Boolean(active && element.contains(active));
  #| }
