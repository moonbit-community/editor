// Ported from `vscode/src/vs/editor/contrib/zoneWidget/browser/zoneWidget.ts`.
// A zone widget renders as a view zone (an empty spacer that reserves
// vertical space in the scrolled content) plus an overlay widget (the visible
// framed DOM in the viewport-fixed overlay layer) that tracks the zone
// through `IViewZone.onDomNodeTop`. Dropped from the source: the resize sash
// (`_initSash`, out of scope), `keepEditorSelection`/`revealRange` policy
// (the viewer glue reveals explicitly), theming `style()`/`_applyStyles`
// (colors come from CSS variables), and the generated-CSS-rule `Arrow`
// decoration — the arrow here is a positioned child div with a CSS border
// triangle at a fixed left offset, visually equivalent for line-anchored
// widgets (recorded deviation).
//
// The widget cannot import the root `viewer` package (cycle), so it calls
// back through a `ZoneWidgetHost` closure struct the root builds — the same
// seam style as the controller's `PointerHandlerHelper`.

///|
/// The editor capabilities a zone widget consumes, built by the root glue
/// closing over the `Viewer` (the `ICodeEditor` surface of `zoneWidget.ts`).
pub(all) struct ZoneWidgetHost {
  /// `editor.changeViewZones` + `accessor.addZone` collapsed to an upsert:
  /// `(zone_id, anchor_view_line, height_px, spacer_node, on_dom_node_top,
  /// on_computed_height)`. Re-adding an id relayouts the zone
  /// (`accessor.layoutZone`).
  add_zone : (String, Int, Int, @rdom.Element, (Double) -> Unit, (Int) -> Unit) -> Unit
  /// `accessor.removeZone`.
  remove_zone : (String) -> Unit
  /// `editor.addOverlayWidget` for the widget's visible DOM.
  add_overlay_widget : (String, @rdom.Element) -> Unit
  /// `editor.removeOverlayWidget`.
  remove_overlay_widget : (String) -> Unit
  /// `_getWidth(editor.getLayoutInfo())` — the full editor width (no minimap
  /// or vertical-scrollbar reservation in the viewer).
  layout_width : () -> Double
  /// `editor.getLayoutInfo().height`, for the maximum-height clamp.
  viewport_height : () -> Double
  /// `editor.getOption(EditorOption.lineHeight)`.
  line_height : () -> Int
  /// `StableEditorScrollState.capture(editor)`; the returned closure is the
  /// matching `restore(editor)`. Consumers bracket a zone relayout with it so
  /// a zone growing above the viewport does not shift the visible content
  /// (`commentThreadZoneWidget.ts:521-523`).
  capture_stable_scroll : () -> () -> Unit
}

///|
/// `abstract class ZoneWidget` collapsed to a concrete widget: subclass hooks
/// become the `fill` closure (`_fillContainer`), invoked once on
/// construction (`create()`).
pub struct ZoneWidget {
  host : ZoneWidgetHost
  /// Zone id; the overlay widget id derives from it (`WIDGET_ID + id`).
  id : String
  /// `this.domNode` — the visible `.zone-widget` overlay node.
  dom_node : @rdom.Element
  /// `this.container` — the framed `.zone-widget-container` the content
  /// fills.
  container : @rdom.Element
  arrow : @rdom.Element?
  show_frame : Bool
  mut visible : Bool
  mut anchor_view_line : Int
  mut height_in_lines : Int
  mut top_px : Double
  mut width_px : Double
  mut dom_height_px : Int
}

///|
/// `constructor` + `create()`: builds the widget DOM and fills the container.
pub fn ZoneWidget::new(
  host : ZoneWidgetHost,
  id : String,
  show_arrow~ : Bool,
  show_frame~ : Bool,
  class_name? : String,
  fill~ : (@rdom.Element) -> Unit,
) -> ZoneWidget {
  let document = @rdom.document()
  let dom_node = document.create_element("div")
  let classes = match class_name {
    Some(extra) => "zone-widget " + extra
    None => "zone-widget"
  }
  dom_node.set_attribute("class", classes)
  let container = document.create_element("div")
  container.set_attribute("class", "zone-widget-container")
  let arrow = if show_arrow {
    let arrow = document.create_element("div")
    arrow.set_attribute("class", "zone-widget-arrow")
    dom_node.append_child(arrow.as_node())
    Some(arrow)
  } else {
    None
  }
  dom_node.append_child(container.as_node())
  fill(container)
  {
    host,
    id,
    dom_node,
    container,
    arrow,
    show_frame,
    visible: false,
    anchor_view_line: 0,
    height_in_lines: 0,
    top_px: -1000.0,
    width_px: 0.0,
    dom_height_px: 0,
  }
}

///|
pub fn ZoneWidget::dom(self : ZoneWidget) -> @rdom.Element {
  self.dom_node
}

///|
pub fn ZoneWidget::is_visible(self : ZoneWidget) -> Bool {
  self.visible
}

///|
/// `_getMaximumHeightInLines`: `max(12, viewport_lines * 0.8)` (`:381-383`).
fn ZoneWidget::max_height_in_lines(self : ZoneWidget) -> Int {
  let line_height = (self.host.line_height)()
  let viewport_lines = if line_height > 0 {
    (self.host.viewport_height)() / line_height.to_double() * 0.8
  } else {
    0.0
  }
  let clamped = viewport_lines.to_int()
  if clamped > 12 {
    clamped
  } else {
    12
  }
}

///|
/// `_decoratingElementsHeight` (`:363-378`): the arrow band plus the frame
/// borders, subtracted from the zone height to size the content container.
fn ZoneWidget::decorating_elements_height(self : ZoneWidget) -> Int {
  let line_height = (self.host.line_height)()
  let mut result = 0
  if self.arrow is Some(_) {
    result += 2 * arrow_height(line_height)
  }
  if self.show_frame {
    result += 2 * frame_thickness(line_height)
  }
  result
}

///|
/// "Render the arrow one 1/3 of an editor line height" (`:406-411`).
fn arrow_height(line_height : Int) -> Int {
  (line_height.to_double() / 3.0 + 0.5).to_int()
}

///|
/// "Render the frame as 1/9 of an editor line height" (`:413-416`).
fn frame_thickness(line_height : Int) -> Int {
  (line_height.to_double() / 9.0 + 0.5).to_int()
}

///|
/// `show` + `_showImpl` (`:319-325`, `:385-469`): clamps the height, inserts
/// the spacer zone with the position callbacks, mounts the overlay widget,
/// and sizes the frame/arrow/container.
pub fn ZoneWidget::show(
  self : ZoneWidget,
  anchor_view_line : Int,
  height_in_lines : Int,
) -> Unit {
  let line_height = (self.host.line_height)()
  // adjust heightInLines to viewport (`:397-401`)
  let max_lines = self.max_height_in_lines()
  let lines = if height_in_lines < max_lines {
    height_in_lines
  } else {
    max_lines
  }
  self.anchor_view_line = anchor_view_line
  self.height_in_lines = lines
  self.width_px = (self.host.layout_width)()
  self.top_px = -1000.0
  self.dom_height_px = lines * line_height
  self.sync_widget_styles()
  self.insert_zone()
  (self.host.add_overlay_widget)(self.overlay_widget_id(), self.dom_node)
  self.visible = true
}

///|
/// `_relayout` (`:502-514`): only relayouts when the line count actually
/// changed (the scroll-stability guard).
pub fn ZoneWidget::relayout(self : ZoneWidget, height_in_lines : Int) -> Unit {
  guard self.visible else { return }
  let max_lines = self.max_height_in_lines()
  let lines = if height_in_lines < max_lines {
    height_in_lines
  } else {
    max_lines
  }
  if lines == self.height_in_lines {
    return
  }
  self.height_in_lines = lines
  self.width_px = (self.host.layout_width)()
  self.insert_zone()
}

///|
/// The anchor half of `updatePositionAndHeight` (`:327-343`), for
/// re-anchoring an open widget after folding/wrapping changes the view line.
pub fn ZoneWidget::update_anchor(
  self : ZoneWidget,
  anchor_view_line : Int,
) -> Unit {
  guard self.visible && anchor_view_line != self.anchor_view_line else {
    return
  }
  self.anchor_view_line = anchor_view_line
  self.insert_zone()
}

///|
/// `hide` (`:345-361`).
pub fn ZoneWidget::hide(self : ZoneWidget) -> Unit {
  guard self.visible else { return }
  self.visible = false
  (self.host.remove_zone)(self.id)
  (self.host.remove_overlay_widget)(self.overlay_widget_id())
}

///|
fn ZoneWidget::overlay_widget_id(self : ZoneWidget) -> String {
  // `WIDGET_ID + this._viewZone.id` (`:439`).
  "zone-widget-" + self.id
}

///|
/// Upserts the spacer zone (`accessor.addZone` with a fresh
/// `ViewZoneDelegate`, `:419-441`; re-adding the id is `layoutZone`).
fn ZoneWidget::insert_zone(self : ZoneWidget) -> Unit {
  let document = @rdom.document()
  // "Render the widget as zone (rendering) and widget (lifecycle)" (`:392-394`).
  let spacer = document.create_element("div")
  spacer.set_attribute("style", "overflow:hidden")
  (self.host.add_zone)(
    self.id,
    self.anchor_view_line,
    self.height_in_lines * (self.host.line_height)(),
    spacer,
    top => self.on_view_zone_top(top),
    height => self.on_view_zone_height(height),
  )
}

///|
/// `_onViewZoneTop` (`:288-290`): the overlay follows the zone.
fn ZoneWidget::on_view_zone_top(self : ZoneWidget, top : Double) -> Unit {
  self.top_px = top
  self.sync_dom_node_style()
}

///|
/// `_onViewZoneHeight` (`:292-303`).
fn ZoneWidget::on_view_zone_height(self : ZoneWidget, height : Int) -> Unit {
  self.dom_height_px = height
  self.sync_widget_styles()
}

///|
fn ZoneWidget::sync_dom_node_style(self : ZoneWidget) -> Unit {
  self.dom_node.set_attribute(
    "style",
    "top:" +
    self.top_px.to_string() +
    "px;width:" +
    self.width_px.to_string() +
    "px;height:" +
    self.dom_height_px.to_string() +
    "px",
  )
}

///|
/// Sizes the widget chrome for the current zone height: container top =
/// arrow band, container height = zone height minus the decorating elements,
/// frame borders at 1/9 line height (`_showImpl:444-456` +
/// `_onViewZoneHeight`).
fn ZoneWidget::sync_widget_styles(self : ZoneWidget) -> Unit {
  self.sync_dom_node_style()
  let line_height = (self.host.line_height)()
  let arrow_band = match self.arrow {
    Some(arrow) => {
      let height = arrow_height(line_height)
      arrow.set_attribute(
        "style",
        "border-top-width:0;border-left-width:" +
        height.to_string() +
        "px;border-right-width:" +
        height.to_string() +
        "px;border-bottom-width:" +
        height.to_string() +
        "px",
      )
      height
    }
    None => 0
  }
  let frame = if self.show_frame { frame_thickness(line_height) } else { 0 }
  let container_height = self.dom_height_px - self.decorating_elements_height()
  self.container.set_attribute(
    "style",
    "top:" +
    arrow_band.to_string() +
    "px;height:" +
    container_height.to_string() +
    "px;border-top-width:" +
    frame.to_string() +
    "px;border-bottom-width:" +
    frame.to_string() +
    "px",
  )
}
