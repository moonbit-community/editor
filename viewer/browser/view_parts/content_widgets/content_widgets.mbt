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
  /// Monaco `Widget.allowEditorOverflow` (the `EditorOption.allowOverflow`
  /// gate is N-A: the viewer has no such option and it defaults `true`).
  allow_editor_overflow : Bool
  mut position : @base_common.Position?
  mut secondary_position : @base_common.Position?
  mut preference : Array[ContentWidgetPositionPreference]
  /// Monaco `_cachedDomNodeOffsetWidth/Height`, invalidated by `set_position`.
  mut cached_dom_node_offset_width : Double
  mut cached_dom_node_offset_height : Double
  /// Monaco `Widget._maxWidth` (`_getMaxWidth`), refreshed per prepared frame
  /// (the source refreshes in the constructor, `onConfigurationChanged`, and
  /// `onBeforeRender`). `-1` until the first prepare pass measures it.
  mut max_width : Double
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
  /// Monaco `ViewContentWidgets._viewDomNode`: the editor's root node, the
  /// page-space reference box for `_layoutBoxInPage`.
  view_dom_node : @rdom.Element
  priv widgets : Map[String, Widget]
  mut should_render : Bool
}

///|
pub fn ContentWidgets::new(
  document : @rdom.Document,
  view_dom_node : @rdom.Element,
) -> ContentWidgets {
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
    view_dom_node,
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
    allow_editor_overflow: actual.allow_editor_overflow(),
    position: None,
    secondary_position: None,
    preference: [],
    cached_dom_node_offset_width: -1.0,
    cached_dom_node_offset_height: -1.0,
    max_width: -1.0,
    is_visible: false,
    display_block: false,
    top: 0.0,
    left: 0.0,
    render_data: None,
  }
  self.widgets[widget.id] = widget
  dom_node.set_attribute("data-content-widget", widget.id)
  widget.apply_style()
  if widget.allow_editor_overflow {
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
  /// `layoutInfo.contentLeft` (the gutter width): converts a content-space
  /// `left` into editor-root space for the overflowing `_layoutBoxInPage` arm.
  content_left : Double
  scroll_top : Double
  scroll_left : Double
  viewport_width : Double
  viewport_height : Double
}

///|
/// Monaco `ViewContentWidgets.prepareRender` (`contentWidgets.ts:152-157`):
/// compute each widget's render data for this frame. The max-width refresh
/// folds in Monaco's `Widget.onBeforeRender` (`setMaxWidth(this._maxWidth)`,
/// run before the box is measured) and `_getMaxWidth`'s recompute.
pub fn ContentWidgets::prepare_render_widgets(
  self : ContentWidgets,
  ctx : ContentWidgetsRenderContext,
) -> Unit {
  for _, widget in self.widgets {
    widget.update_max_width(ctx)
    widget.render_data = widget.prepare_render_widget(ctx, self.view_dom_node)
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
/// Monaco `Widget._getMaxWidth` (`contentWidgets.ts:284-293`) applied through
/// the FastDomNode-style per-property write: an overflowing widget may grow to
/// the window width; a clipped one to the content area width.
fn Widget::update_max_width(
  self : Widget,
  ctx : ContentWidgetsRenderContext,
) -> Unit {
  self.max_width = if self.allow_editor_overflow {
    @rdom.window().inner_width().to_double()
  } else {
    ctx.viewport_width
  }
  set_style_property(
    self.dom_node,
    "max-width",
    self.max_width.to_string() + "px",
  )
}

///|
/// Monaco `Widget._prepareRenderWidget` (`contentWidgets.ts:447-534`):
/// `_layoutBoxInPage` for overflowing widgets (`allowEditorOverflow`, e.g.
/// the content hover), `_layoutBoxInViewport` for widgets clipped to the
/// content area.
fn Widget::prepare_render_widget(
  self : Widget,
  ctx : ContentWidgetsRenderContext,
  view_dom_node : @rdom.Element,
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
  let placement = if self.allow_editor_overflow {
    layout_box_in_page(
      anchor,
      self.cached_dom_node_offset_width,
      self.cached_dom_node_offset_height,
      ctx,
      view_dom_node,
    )
  } else {
    layout_box_in_viewport(
      anchor,
      self.cached_dom_node_offset_width,
      self.cached_dom_node_offset_height,
      ctx,
    )
  }
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
        Exact =>
          // `_prepareRenderWidgetAtExactPositionOverflowing`: the overflowing
          // layer's coordinate space is the editor root, so the content-space
          // `left` shifts right by `contentLeft`.
          if self.allow_editor_overflow {
            return Some(
              InViewport(top=anchor.top, left=anchor.left + ctx.content_left),
            )
          } else {
            return Some(InViewport(top=anchor.top, left=anchor.left))
          }
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
/// Monaco `dom.getDomNodePagePosition` narrowed to the fields
/// `_layoutBoxInPage` reads: the node's page-space box (client rect plus the
/// window scroll offset).
priv struct DomNodePagePosition {
  top : Double
  left : Double
  width : Double
}

///|
fn dom_node_page_position(node : @rdom.Element) -> DomNodePagePosition {
  let rect = node.get_bounding_client_rect()
  let window = @rdom.window()
  {
    top: rect.get_top() + window.scroll_y().to_double(),
    left: rect.get_left() + window.scroll_x().to_double(),
    width: rect.get_width(),
  }
}

///|
/// Monaco `Widget._layoutHorizontalSegmentInPage` (`contentWidgets.ts:
/// 337-362`): clamp the widget's horizontal segment so it stays inside the
/// window (15px side clearance) while staying within one widget-width of the
/// editor box. Returns the clamped editor-root-relative `left` (the absolute
/// variant only feeds the unported `fixedOverflowWidgets` arm).
fn layout_horizontal_segment_in_page(
  window_width : Double,
  dom_node_position : DomNodePagePosition,
  left : Double,
  width : Double,
) -> Double {
  // Leave some clearance to the left/right
  let left_padding = 15.0
  let right_padding = 15.0

  // Initially, the limits are defined as the dom node limits
  let min_limit = double_max(left_padding, dom_node_position.left - width)
  let max_limit = double_min(
    dom_node_position.left + dom_node_position.width + width,
    window_width - right_padding,
  )
  let scroll_x = @rdom.window().scroll_x().to_double()
  let mut left = left
  let mut absolute_left = dom_node_position.left + left - scroll_x
  if absolute_left + width > max_limit {
    let delta = absolute_left - (max_limit - width)
    absolute_left -= delta
    left -= delta
  }
  if absolute_left < min_limit {
    let delta = absolute_left - min_limit
    absolute_left -= delta
    left -= delta
  }
  left
}

///|
/// Monaco `Widget._layoutBoxInPage` (`contentWidgets.ts:364-395`): the
/// overflowing widget renders in the editor root's coordinate space but its
/// fit is judged against the *page* (22px top/bottom clearance), so a narrow
/// or short editor no longer constrains the widget. The
/// `fixedOverflowWidgets` arm is unported (the viewer never sets the option).
fn layout_box_in_page(
  anchor : AnchorCoordinate,
  width : Double,
  height : Double,
  ctx : ContentWidgetsRenderContext,
  view_dom_node : @rdom.Element,
) -> BoxLayoutResult {
  let above_top = anchor.top - height
  let below_top = anchor.top + anchor.height
  let dom_node_position = dom_node_page_position(view_dom_node)
  let window = @rdom.window()
  let scroll_y = window.scroll_y().to_double()
  let absolute_above_top = dom_node_position.top + above_top - scroll_y
  let absolute_below_top = dom_node_position.top + below_top - scroll_y
  let (window_width, window_height) = body_client_area(view_dom_node)
  let left = layout_horizontal_segment_in_page(
    window_width,
    dom_node_position,
    anchor.left - ctx.scroll_left + ctx.content_left,
    width,
  )

  // Leave some clearance to the top/bottom
  let top_padding = 22.0
  let bottom_padding = 22.0
  let fits_above = absolute_above_top >= top_padding
  let fits_below = absolute_below_top + height <= window_height - bottom_padding
  { fits_above, above_top, fits_below, below_top, left }
}

///|
/// Monaco `Widget.render` (`contentWidgets.ts:556-596`), the write half: only
/// `top`/`left`/`visibility` change per frame; the DOM stays mounted. An
/// overflowing widget's coordinates are already editor-root-relative, so the
/// content layer's `translate_y` does not apply (`contentWidgets.ts:585-591`).
fn Widget::render(self : Widget, translate_y : Double) -> Unit {
  let was_visible = self.is_visible
  match self.render_data {
    Some(InViewport(top~, left~)) => {
      self.top = if self.allow_editor_overflow {
        top
      } else {
        top - translate_y
      }
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
/// Writes the widget's positioning style through per-property mutations — the
/// source's `FastDomNode` writes (`setTop`/`setLeft`/`setVisibility`/
/// `setDisplay`). Property-level (not a whole-attribute rewrite) because the
/// widget owner writes sizing properties onto the same node: the content
/// hover's `_resizableNode.layout` sets `width`/`height` on its wrapper,
/// exactly as Monaco's `ResizableHTMLElement` shares the node with
/// `ViewContentWidgets`.
fn Widget::apply_style(self : Widget) -> Unit {
  let display = if self.display_block { "block" } else { "none" }
  let visibility = if self.is_visible { "inherit" } else { "hidden" }
  set_style_property(self.dom_node, "position", "absolute")
  set_style_property(self.dom_node, "display", display)
  set_style_property(self.dom_node, "visibility", visibility)
  set_style_property(self.dom_node, "top", self.top.to_string() + "px")
  set_style_property(self.dom_node, "left", self.left.to_string() + "px")
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

///|
/// `element.style.setProperty` — the `FastDomNode` per-property style write.
extern "js" fn set_style_property(
  element : @rdom.Element,
  name : String,
  value : String,
) -> Unit =
  #| (element, name, value) => { element.style.setProperty(name, value); }

///|
/// Monaco `dom.getClientArea(elDocument.body)`: the page box the overflowing
/// placement is clamped to.
fn body_client_area(node : @rdom.Element) -> (Double, Double) {
  (body_client_width(node), body_client_height(node))
}

///|
extern "js" fn body_client_width(node : @rdom.Element) -> Double =
  #| (node) => node.ownerDocument.body.clientWidth

///|
extern "js" fn body_client_height(node : @rdom.Element) -> Double =
  #| (node) => node.ownerDocument.body.clientHeight
