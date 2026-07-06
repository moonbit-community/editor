// Ported from `vscode/src/vs/editor/browser/viewParts/contentWidgets/contentWidgets.ts`
// plus the hover content widget's DOM/geometry half from
// `vscode/src/vs/editor/contrib/hover/browser/contentHoverWidget.ts` (the
// viewer's only content widget). The `ViewPart` trait impl for
// `ContentWidgets` lives in `viewer/browser/view/view_part.mbt`, not here —
// see the exec-plan's cycle backlog and
// `viewer/browser/view_parts/view_zones`'s README for why.

///|
priv enum ContentWidgetPlacement {
  ContentWidgetAbove
  ContentWidgetBelow
}

///|
priv struct ContentWidgetAnchor {
  column : Int
  top : Int
}

///|
priv struct ContentWidget {
  id : String
  node : @rdom.Element
  anchor : ContentWidgetAnchor
  preferred_placement : ContentWidgetPlacement
  allow_overflow : Bool
  shift_left : Double
  /// Measured monospace glyph advance, so the horizontal anchor is placed in
  /// exact pixels (`column * char_width`) like Monaco, rather than CSS `ch`
  /// units that resolve against the widget's inherited proportional UI font.
  char_width : Double
  /// The widget's own box height, needed only for `ContentWidgetAbove`
  /// (Monaco `_layoutBoxInViewport`'s `aboveTop = aboveLineTop - height`,
  /// `contentWidgets.ts:317`) — `0.0` when not yet known (the measuring pass,
  /// before placement is decided; harmless, since that pass's position is
  /// discarded before the corrected placement pass repaints).
  height : Double
}

///|
/// `pub(all)`: appears in `ViewContext.handle_hover_keydown` (`view_context.mbt`)
/// and `Viewer::handle_hover_keydown`'s signature (`view_host.mbt`), so it must
/// be visible across the `browser/view_parts/content_widgets` ↔ `browser/view/`
/// / `browser/widget/code_editor` package boundaries.
pub(all) struct HoverWidgetDom {
  wrapper : @rdom.Element
  hover : @rdom.Element
  scrollable : @scrollbar.ScrollableElementDom
}

///|
/// The DOM/host capabilities `render_hover_widget`/`ensure_hover_widget` need
/// from `Viewer`, unpacked from `ViewContext`'s fields rather than taking that
/// struct directly — `ViewContext` lives in
/// `viewer/browser/view/view_context.mbt`, which this package cannot import
/// without creating a `browser/view/ ↔ browser/view_parts/content_widgets`
/// cycle (`browser/view/` already needs `ContentWidgets` for `View`'s fields
/// and the `ViewPartHandle` enum). Built from `context.view_context`'s fields
/// at the `ViewPart` impl in `view_part.mbt`, the same host/callback pattern
/// `controller_host.mbt`'s `PointerHandlerHelper` already uses. `pub(all)`
/// since it is constructed there, cross-package.
pub(all) struct HoverWidgetHost {
  root : @rdom.Element
  languages : @languages.Languages
  keep_hover_open : () -> Unit
  handle_hover_mousedown : (@rdom.Event, @rdom.MouseEvent) -> Unit
  hook_scrollable_scrollbar_input : (
    @scrollbar.ScrollableElementDom,
    @scrollbar.ScrollableElementOwner,
  ) -> Unit
  handle_hover_keydown : (HoverWidgetDom, @rdom.Event, @rdom.KeyboardEvent) -> Unit
  /// Model position → document offset (the model-snapshot boundary): the
  /// hover state is `Range`-typed; this pixel-placement site is the one
  /// offset consumer left, so the conversion happens here, through the host.
  model_position_to_offset : (@base_common.Position) -> Int
}

///|
/// `pub(all)`: the `ViewPart` impl in `view_part.mbt` constructs/reads this
/// directly.
pub(all) struct ContentWidgetsPrepared {
  frame : @view_model.RenderFrame
  layout : @view_layout.ViewLayout
  /// Resolved via `HoverController::widget_view` at `prepare_render` (staying
  /// in `view_part.mbt`, which already imports the hover package) — this
  /// package holds only the already-derived view, not the full
  /// `HoverController` (which stays with `Viewer`; see `HoverWidgetHost`).
  hover_view : @hover.HoverWidgetView?
  on_hover_measured : (Bool, Double, Double) -> Unit
  space_width : Double
}

///|
/// `pub(all)`: the `ViewPart` impl in `view_part.mbt` reads/writes
/// `should_render` / `prepared` / `content_widgets` directly.
pub(all) struct ContentWidgets {
  content_widgets : @rdom.Element
  overflowing_content_widgets : @rdom.Element
  mut hover_widget : HoverWidgetDom?
  mut should_render : Bool
  mut prepared : ContentWidgetsPrepared?
}

///|
pub fn ContentWidgets::new(document : @rdom.Document) -> ContentWidgets {
  let content_widgets = document.create_element("div")
  content_widgets.set_attribute("class", "contentWidgets")
  content_widgets.set_attribute("data-view-part", "contentWidgets")
  let overflowing_content_widgets = document.create_element("div")
  overflowing_content_widgets.set_attribute(
    "class", "overflowingContentWidgets",
  )
  overflowing_content_widgets.set_attribute(
    "data-view-part", "overflowingContentWidgets",
  )
  {
    content_widgets,
    overflowing_content_widgets,
    hover_widget: None,
    should_render: true,
    prepared: None,
  }
}

///|
pub fn ContentWidgets::dom(self : ContentWidgets) -> @rdom.Element {
  self.content_widgets
}

///|
pub fn ContentWidgets::overflowing_dom(self : ContentWidgets) -> @rdom.Element {
  self.overflowing_content_widgets
}

///|
pub fn ContentWidgets::hover_scrollable(
  self : ContentWidgets,
) -> @scrollbar.ScrollableElementDom? {
  match self.hover_widget {
    Some(widget) => Some(widget.scrollable)
    None => None
  }
}

///|
/// The hover widget's outer node, for the controller's
/// `_isMouseOnContentHoverWidget` hit test (none before the widget is first
/// shown).
pub fn ContentWidgets::hover_wrapper(self : ContentWidgets) -> @rdom.Element? {
  match self.hover_widget {
    Some(widget) => Some(widget.wrapper)
    None => None
  }
}

///|
/// Renders, positions, and (once) measures the hover content widget,
/// which shares the lines transform so it tracks content space. The
/// placement measurement is a read-after-write on the freshly written
/// widget, applied in the same flush.
pub fn ContentWidgets::render_hover_widget(
  self : ContentWidgets,
  host : HoverWidgetHost,
  frame : @view_model.RenderFrame,
  layout : @view_layout.ViewLayout,
  hover_view : @hover.HoverWidgetView?,
  on_hover_measured : (Bool, Double, Double) -> Unit,
  space_width : Double,
  gutter_width : Double,
) -> Unit {
  let hover_view = match hover_view {
    Some(hover_view) => hover_view
    None => {
      self.remove_hover_widget()
      return
    }
  }
  // The hover state is `Range`-typed; this pixel-placement site converts to
  // document offsets (through the host's model-snapshot boundary) to locate
  // the rendered view line + column — the one offset consumer left.
  let anchor_offset = (host.model_position_to_offset)(
    hover_view.anchor_range.get_start_position(),
  )
  let (line_number, anchor_view_column) = match
    line_col_for_offset(frame, anchor_offset) {
    Some(anchor) => anchor
    None => {
      self.remove_hover_widget()
      return
    }
  }
  // Monaco `RenderedContentHover.computeHoverPositions`: the widget body
  // left-aligns to the leftmost part column on the anchor line (the secondary
  // position). The anchor offset is the union-of-parts start, so the secondary
  // resolves to that same column today; routing it through the ported helper
  // keeps placement faithful as later increments add the start-column-boundary
  // clamp and forced ranges.
  let placement_parts : Array[@hover.HoverPositionPart] = []
  for part in hover_view.parts {
    let part_range = @hover.hover_part_range(part)
    match
      (
        line_col_for_offset(
          frame,
          (host.model_position_to_offset)(part_range.get_start_position()),
        ),
        line_col_for_offset(
          frame,
          (host.model_position_to_offset)(part_range.get_end_position()),
        ),
      ) {
      (Some((start_line, start_column)), Some((end_line, end_column))) =>
        placement_parts.push({
          range: Range(start_line, start_column, end_line, end_column),
          force_show_at_range: false,
        })
      _ => ()
    }
  }
  let (_show_at, show_at_secondary) = @hover.compute_hover_positions(
    Range(line_number, anchor_view_column, line_number, anchor_view_column),
    placement_parts,
    1,
  )
  let column = show_at_secondary.column
  let widget = self.ensure_hover_widget(host)
  let mut class_name = "monaco-resizable-hover"
  let mut shift_left = 0.0
  let mut preferred_placement = ContentWidgetAbove
  match hover_view.placement {
    Some(placement) => {
      if placement.below {
        preferred_placement = ContentWidgetBelow
      }
      shift_left = placement.shift_left
    }
    None => if hover_view.measurable { class_name = class_name + " measuring" }
  }
  match preferred_placement {
    ContentWidgetBelow => class_name = class_name + " below"
    ContentWidgetAbove => ()
  }
  // Monaco `_layoutBoxInViewport`'s `height` parameter (`contentWidgets.ts:309`,
  // `this._cachedDomNodeOffsetHeight`): the widget's own box height, needed to
  // compute `aboveTop = aboveLineTop - height`. Unknown during the measuring
  // pass (`placement is None`) — that pass's position is a throwaway,
  // discarded before the corrected placement pass repaints.
  let widget_height = match hover_view.placement {
    Some(placement) => placement.max_height
    None => 0.0
  }
  let content_widget : ContentWidget = {
    id: "hover",
    node: widget.wrapper,
    anchor: {
      column,
      top: layout.relative_vertical_offset_for_line(
        frame_window(frame),
        line_number,
      ),
    },
    preferred_placement,
    allow_overflow: false,
    shift_left,
    char_width: space_width,
    height: widget_height,
  }
  widget.wrapper.set_attribute("class", class_name)
  widget.hover.set_attribute("class", "monaco-hover fade-in")
  widget.clear_sizing()
  widget.set_hover_parts(
    @hover.render_hover_parts(hover_view.parts, frame.language_id),
  )
  self.mount_content_widget(content_widget)
  // The anchor line's top edge in editor-viewport pixels and the editor height,
  // the two inputs Monaco's `ResizableContentWidget` available-space helpers
  // need (`getScrolledVisiblePosition().top` and the editor DOM box).
  let line_top = layout.vertical_offset_for_line(line_number) -
    layout.position().scroll_top
  let editor_height = host.root.get_bounding_client_rect().get_height()
  if hover_view.measurable && hover_view.placement is None {
    // First (measuring) pass: lock the width to its resolved value (Monaco
    // `_findMaximumRenderingWidth`'s nowrap probe — natural width if it fits,
    // else the available-width cap) so the natural wrapped height is
    // measurable, then choose the side and the available-space height cap
    // (Monaco `_findPositionPreference` + `_findMaximumRenderingHeight`).
    let natural_width = widget.measure_natural_width()
    let available_width = hover_available_width(host.root, gutter_width)
    widget.apply_width_sizing(
      hover_resolved_width(natural_width, available_width),
    )
    let content_height = widget.wrapper.get_bounding_client_rect().get_height()
    let space_above = hover_available_space_above(line_top)
    let space_below = hover_available_space_below(
      line_top,
      @core.editor_line_height.to_double(),
      editor_height,
    )
    let below = !hover_prefer_above(
      content_height, space_above, space_below, hover_prefer_above_default,
    )
    let available = if below { space_below } else { space_above }
    let max_height = hover_maximum_rendering_height(available, content_height)
    let widget_rect = widget.wrapper.get_bounding_client_rect()
    let root_rect = host.root.get_bounding_client_rect()
    let overflow = widget_rect.get_right() - root_rect.get_right() + 12.0
    let shift_left = if overflow > 0.0 { overflow } else { 0.0 }
    on_hover_measured(below, shift_left, max_height)
    self.render_hover_widget(
      host,
      frame,
      layout,
      Some(hover_view.measured(below, shift_left, max_height)),
      on_hover_measured,
      space_width,
      gutter_width,
    )
    return
  }
  // Placement-set pass, or the unmeasured loading hover (rendered above by
  // default, capped to the room above so it cannot spill past `.overflow-guard`).
  let max_height = match hover_view.placement {
    Some(placement) => placement.max_height
    None =>
      @hover.max_hover_double(
        hover_loading_min_height,
        hover_available_space_above(line_top),
      )
  }
  let natural_width = widget.measure_natural_width()
  let available_width = hover_available_width(host.root, gutter_width)
  widget.apply_sizing(
    hover_resolved_width(natural_width, available_width),
    max_height,
  )
}

///|
fn ContentWidgets::ensure_hover_widget(
  self : ContentWidgets,
  host : HoverWidgetHost,
) -> HoverWidgetDom {
  match self.hover_widget {
    Some(widget) => widget
    None => {
      let document = @rdom.document()
      let wrapper = document.create_element("div")
      let hover = document.create_element("div")
      hover.set_attribute("class", "monaco-hover fade-in")
      hover.set_attribute("role", "tooltip")
      hover.set_attribute("tabindex", "0")
      let scrollable = @scrollbar.ScrollableElementDom::new(
        "monaco-hover-content",
      )
      hover.append_child(scrollable.wrapper.as_node())
      wrapper.append_child(hover.as_node())
      let widget : HoverWidgetDom = { wrapper, hover, scrollable }
      // Content widgets swallow pointer motion, but a hover may overlap source
      // text; non-interactive mousedown should still start editor selection at
      // the underlying coordinate.
      widget.wrapper.add_event_listener("mousemove", event => {
        // The pointer is on the hover widget: keep it open. The editor never
        // sees this move (stop_propagation), so the controller's grace timer
        // would otherwise still fire and hide the widget out from under it.
        (host.keep_hover_open)()
        event.stop_propagation()
      })
      widget.wrapper.add_event_listener("mousedown", event => {
        if hover_mousedown_is_interactive(event) {
          event.stop_propagation()
        } else {
          match event.to_mouse_event() {
            Some(mouse) => (host.handle_hover_mousedown)(event, mouse)
            None => event.stop_propagation()
          }
        }
      })
      widget.wrapper.add_event_listener("click", event => {
        if handle_hover_copy_click(event) {
          event.prevent_default()
        }
        event.stop_propagation()
      })
      widget.wrapper.add_event_listener("contextmenu", event => {
        event.stop_propagation()
      })
      widget.wrapper.add_event_listener("focusin", event => {
        event.stop_propagation()
      })
      widget.wrapper.add_event_listener("focusout", event => {
        event.stop_propagation()
      })
      widget.wrapper.add_event_listener("wheel", event => {
        match event.to_wheel_event() {
          Some(wheel) => {
            event.prevent_default()
            event.stop_propagation()
            handle_hover_wheel(widget, wheel)
          }
          None => event.stop_propagation()
        }
      })
      widget.scrollable.content.add_event_listener("wheel", event => {
        match event.to_wheel_event() {
          Some(wheel) => {
            event.prevent_default()
            event.stop_propagation()
            handle_hover_wheel(widget, wheel)
          }
          None => event.stop_propagation()
        }
      })
      widget.scrollable.content.add_event_listener("scroll", _ => {
        widget.scrollable.update_from_native_content()
      })
      (host.hook_scrollable_scrollbar_input)(
        widget.scrollable,
        HoverScrollableElement,
      )
      widget.wrapper.add_event_listener("keydown", event => {
        match event.to_keyboard_event() {
          Some(keyboard) => (host.handle_hover_keydown)(widget, event, keyboard)
          None => event.stop_propagation()
        }
      })
      self.hover_widget = Some(widget)
      widget
    }
  }
}

///|
fn handle_hover_wheel(
  widget : HoverWidgetDom,
  wheel : @rdom.WheelEvent,
) -> Unit {
  let (delta_left, delta_top) = @scrollbar.normalized_wheel_delta(
    wheel,
    @core.editor_line_height.to_double(),
    widget.scrollable.native_page_delta(),
  )
  widget.scrollable.native_scroll_by(delta_left~, delta_top~)
}

///|
/// Monaco `contentHoverWidget.ts` `HORIZONTAL_SCROLLING_BY`: the fixed pixel
/// step the hover scrolls left/right per arrow press (font-independent, unlike
/// the previous `4 × charWidth` heuristic).
let hover_horizontal_scrolling_by : Double = 30.0

///|
/// Monaco `ContentHoverWidget.scrollUp`: `scrollTop -= fontInfo.lineHeight`.
pub fn HoverWidgetDom::scroll_up(self : HoverWidgetDom) -> Unit {
  self.scrollable.native_scroll_by(
    delta_top=-@core.editor_line_height.to_double(),
  )
}

///|
/// Monaco `ContentHoverWidget.scrollDown`: `scrollTop += fontInfo.lineHeight`.
pub fn HoverWidgetDom::scroll_down(self : HoverWidgetDom) -> Unit {
  self.scrollable.native_scroll_by(
    delta_top=@core.editor_line_height.to_double(),
  )
}

///|
/// Monaco `ContentHoverWidget.scrollLeft`: `scrollLeft -= HORIZONTAL_SCROLLING_BY`.
pub fn HoverWidgetDom::scroll_left(self : HoverWidgetDom) -> Unit {
  self.scrollable.native_scroll_by(delta_left=-hover_horizontal_scrolling_by)
}

///|
/// Monaco `ContentHoverWidget.scrollRight`: `scrollLeft += HORIZONTAL_SCROLLING_BY`.
pub fn HoverWidgetDom::scroll_right(self : HoverWidgetDom) -> Unit {
  self.scrollable.native_scroll_by(delta_left=hover_horizontal_scrolling_by)
}

///|
/// Monaco `ContentHoverWidget.pageUp`: `scrollTop -= getScrollDimensions().height`
/// (the visible content height).
pub fn HoverWidgetDom::page_up(self : HoverWidgetDom) -> Unit {
  self.scrollable.native_scroll_by(
    delta_top=-self.scrollable.native_page_delta(),
  )
}

///|
/// Monaco `ContentHoverWidget.pageDown`: `scrollTop += getScrollDimensions().height`.
pub fn HoverWidgetDom::page_down(self : HoverWidgetDom) -> Unit {
  self.scrollable.native_scroll_by(
    delta_top=self.scrollable.native_page_delta(),
  )
}

///|
/// Monaco `ContentHoverWidget.goToTop`: `scrollTop = 0`.
pub fn HoverWidgetDom::go_to_top(self : HoverWidgetDom) -> Unit {
  self.scrollable.native_scroll_to(vertical=true, 0.0)
}

///|
/// Monaco `ContentHoverWidget.goToBottom`: `scrollTop = getScrollDimensions().scrollHeight`
/// (the total content height).
pub fn HoverWidgetDom::go_to_bottom(self : HoverWidgetDom) -> Unit {
  self.scrollable.native_scroll_to(
    vertical=true,
    self.scrollable.content.get_scroll_height(),
  )
}

///|
fn ContentWidgets::remove_hover_widget(self : ContentWidgets) -> Unit {
  match self.hover_widget {
    Some(widget) => {
      self.content_widgets.remove_child(widget.wrapper.as_node())
      self.hover_widget = None
    }
    None => ()
  }
}

///|
fn HoverWidgetDom::clear_sizing(self : HoverWidgetDom) -> Unit {
  self.hover.set_attribute("style", "")
  self.scrollable.wrapper.set_attribute("style", "")
  self.scrollable.content.set_attribute("style", "")
}

///|
/// Mounts the rendered hover parts as the scrollable content's children — one
/// `.hover-row` per rendered part — and gives each part its own `tabIndex` so it
/// is an independent focus stop, mirroring Monaco
/// `RenderedContentHoverParts._registerListenersOnRenderedParts`, which sets
/// `element.tabIndex = 0` on every rendered part. The per-part `focusin` /
/// `focusout` index tracking and the `focus*` navigation it feeds land with their
/// keyboard / verbosity consumers (Phase 5 / 6).
fn HoverWidgetDom::set_hover_parts(
  self : HoverWidgetDom,
  rows : Array[String],
) -> Unit {
  self.scrollable.content.set_inner_html(rows.join(""))
  for part in self.scrollable.content.get_children() {
    part.set_attribute("tabindex", "0")
  }
}

///|
/// Floor for the unmeasured loading hover's height cap, so a near-top anchor
/// (tiny available space above) still leaves room for the one-line placeholder.
let hover_loading_min_height : Double = 80.0

///|
/// `editor.hover.above`'s VS Code default: prefer rendering the hover above the
/// anchor line when it fits there.
let hover_prefer_above_default : Bool = true

///|
/// Monaco `resizableContentWidget.ts` `TOP_HEIGHT` / `BOTTOM_HEIGHT`: the margin
/// kept between the hover and the editor top / bottom edge when measuring how
/// much vertical room each side has.
let hover_top_height : Double = 30.0

///|
let hover_bottom_height : Double = 24.0

///|
/// Monaco `ResizableContentWidget._availableVerticalSpaceAbove`, adapted to the
/// non-overflowing (clipped to `.overflow-guard`) hover: the room from the
/// anchor line top up to the editor top edge, less `TOP_HEIGHT`. `line_top` is
/// the anchor line's top in editor-viewport pixels.
fn hover_available_space_above(line_top : Double) -> Double {
  line_top - hover_top_height
}

///|
/// Monaco `ResizableContentWidget._availableVerticalSpaceBelow`, editor-relative:
/// the room from the anchor line bottom down to the editor bottom edge, less
/// `BOTTOM_HEIGHT`.
fn hover_available_space_below(
  line_top : Double,
  line_height : Double,
  editor_height : Double,
) -> Double {
  editor_height - (line_top + line_height) - hover_bottom_height
}

///|
/// Monaco `ContentHoverWidget._findMaximumRenderingHeight`: the rendered hover
/// height is the lesser of the chosen side's available space and the natural
/// content height, so the `.monaco-hover-content` `overflow:auto` scrollbar
/// engages exactly when the content does not fit the available room.
fn hover_maximum_rendering_height(
  available : Double,
  content_height : Double,
) -> Double {
  @hover.min_hover_double(available, content_height)
}

///|
/// Monaco `ResizableContentWidget._findPositionPreference`: choose ABOVE vs
/// BELOW. Returns `true` for ABOVE. `prefer_above` mirrors `editor.hover.above`.
fn hover_prefer_above(
  widget_height : Double,
  space_above : Double,
  space_below : Double,
  prefer_above : Bool,
) -> Bool {
  let max_above = @hover.min_hover_double(space_above, widget_height)
  let max_below = @hover.min_hover_double(space_below, widget_height)
  let max_height = @hover.min_hover_double(
    @hover.max_hover_double(max_above, max_below),
    widget_height,
  )
  let height = @hover.min_hover_double(widget_height, max_height)
  if prefer_above {
    height <= max_above
  } else {
    !(height <= max_below)
  }
}

///|
/// Horizontal space the hover may occupy: the editor content area to the right
/// of the line-number/glyph gutter, less a trailing gap for the vertical
/// scrollbar. Capping to the *content area* (not the whole editor box) keeps the
/// right-aligned widget from being shifted left into the gutter, where the
/// margin overlays clip its leading text. Mirrors Monaco's content-relative
/// width cap (`contentHoverWidget.ts` `_findMaximumRenderingWidth`).
fn hover_available_width(root : @rdom.Element, gutter_width : Double) -> Double {
  let root_rect = root.get_bounding_client_rect()
  @hover.max_hover_double(160.0, root_rect.get_width() - gutter_width - 24.0)
}

///|
/// `ContentHoverWidget._findMaximumRenderingWidth` (`contentHoverWidget.ts:
/// 217-236`), adapted: the natural (unwrapped) width if it fits the available
/// space, else the available-width cap. The viewer has no page-body overflow
/// branch (Phase 1b's non-overflowing-viewer deviation carries forward), so
/// there is no separate "overflowing → cap to document body" case — capping
/// to `available_width` already is that fallback.
fn hover_resolved_width(
  natural_width : Double,
  available_width : Double,
) -> Double {
  @hover.min_hover_double(natural_width, available_width)
}

///|
/// `ContentHoverWidget._isHoverTextOverflowing`'s nowrap probe
/// (`contentHoverWidget.ts:202-215`), narrowed to just the measurement: force
/// single-line rendering via the CSS hooks `hover.css` already exposes
/// (`--vscode-hover-whiteSpace`/`--vscode-hover-sourceWhiteSpace`, ported but
/// never driven until now), read the natural width, then release the hooks.
fn HoverWidgetDom::measure_natural_width(self : HoverWidgetDom) -> Double {
  self.hover.set_attribute(
    "style", "--vscode-hover-whiteSpace:nowrap;--vscode-hover-sourceWhiteSpace:nowrap",
  )
  let width = self.scrollable.content.get_bounding_client_rect().get_width()
  self.hover.set_attribute("style", "")
  width
}

///|
/// Locks the hover to an explicit width (not `max-width`), leaving height
/// natural so the width-constrained wrapped content height can be measured
/// for the placement decision. Applied to all three DOM levels Monaco's
/// `_setHoverWidgetDimensions` touches (`contentHoverWidget.ts:113-137`,
/// `_setContainerDomNodeDimensions`/`_setScrollableElementDimensions`/
/// `_setContentsDomNodeDimensions`) — this port's `hover`/`scrollable.wrapper`/
/// `scrollable.content`. The outermost `wrapper` (Monaco's
/// `_resizableNode.domNode`) is untouched; its sizing is the still-deferred
/// sash/resize machinery's job.
fn HoverWidgetDom::apply_width_sizing(
  self : HoverWidgetDom,
  width : Double,
) -> Unit {
  let style = hover_width_style(width)
  self.hover.set_attribute("style", style)
  self.scrollable.wrapper.set_attribute("style", style)
  self.scrollable.content.set_attribute("style", style)
  self.scrollable.update_from_native_content()
}

///|
fn HoverWidgetDom::apply_sizing(
  self : HoverWidgetDom,
  width : Double,
  max_height : Double,
) -> Unit {
  let style = hover_width_style(width) +
    ";max-height:" +
    max_height.to_string() +
    "px"
  self.hover.set_attribute("style", style)
  self.scrollable.wrapper.set_attribute("style", style)
  self.scrollable.content.set_attribute("style", style)
  self.scrollable.update_from_native_content()
}

///|
/// The explicit `width`, plus the `--vscode-hover-maxWidth` custom property
/// `.markdown-hover .hover-contents` reads (`hover.css:98`) so nested content
/// tracks the same resolved width instead of falling back to its 500px
/// default.
fn hover_width_style(width : Double) -> String {
  let px = width.to_string() + "px"
  "width:" + px + ";--vscode-hover-maxWidth:" + px
}

///|
fn ContentWidgets::mount_content_widget(
  self : ContentWidgets,
  widget : ContentWidget,
) -> Unit {
  let parent = if widget.allow_overflow {
    self.overflowing_content_widgets
  } else {
    self.content_widgets
  }
  parent.append_child(widget.node.as_node())
  widget.node.set_attribute("data-content-widget", widget.id)
  widget.node.set_attribute("style", widget.style())
}

///|
fn ContentWidget::style(self : ContentWidget) -> String {
  // Monaco `_layoutBoxInViewport` (`contentWidgets.ts:309-333`): `aboveTop =
  // aboveLineTop - height`, `belowTop = underLineTop` (`anchor.top +
  // anchor.height`, `anchor.height` = one line here). The exact top
  // coordinate is computed once in JS and set directly — Monaco never uses a
  // CSS transform for this; that was this port's own invention (a `transform:
  // translateY(-100%)` shift-after-position trick) and, ported alongside the
  // sizing-cluster completion, reproducibly corrupted the widget's background
  // paint in Chromium (heavy synchronous style churn under a GPU-promoted
  // transformed layer — see `hover.css`'s removed `.monaco-resizable-hover`
  // transform rules).
  let top = match self.preferred_placement {
    ContentWidgetBelow =>
      self.anchor.top.to_double() + @core.editor_line_height.to_double()
    ContentWidgetAbove => self.anchor.top.to_double() - self.height
  }
  let left = self.anchor.column.to_double() * self.char_width
  let mut style = "top:" +
    top.to_string() +
    "px;left:" +
    left.to_string() +
    "px"
  if self.shift_left > 0.0 {
    style = style + ";margin-left:-" + self.shift_left.to_string() + "px"
  }
  style
}

///|
fn line_col_for_offset(
  frame : @view_model.RenderFrame,
  offset : Int,
) -> (Int, Int)? {
  for line in frame.lines {
    let start = line.source_offset_at_column(0)
    let end = line.source_offset_at_column(line.text.length())
    if offset >= start && offset <= end {
      return Some((line.line_number, line.view_column_at_source_offset(offset)))
    }
  }
  None
}

///|
/// Duplicated from `viewer/browser/view/view.mbt`, rather than imported:
/// this two-field record construction is small enough that pulling in a
/// dependency on `browser/view/` — which needs `ContentWidgets` back for
/// `View`'s fields and the `ViewPartHandle` enum — isn't worth avoiding a
/// four-line duplicate.
fn frame_window(frame : @view_model.RenderFrame) -> @view_layout.LineWindow {
  { start: frame.viewport.start_line, end: frame.viewport.end_line }
}

///|
extern "js" fn handle_hover_copy_click(event : @rdom.Event) -> Bool =
  #| (event) => {
  #|   const target = event?.target;
  #|   const button = target?.closest?.(".hover-copy-button");
  #|   if (!button || !button.closest?.('[data-content-widget="hover"]')) {
  #|     return false;
  #|   }
  #|   const row = button.closest(".hover-row");
  #|   const content = button.getAttribute("data-hover-copy") || row?.innerText || "";
  #|   globalThis.__readonlyEditorCopiedText = content;
  #|   try {
  #|     const write = globalThis.navigator?.clipboard?.writeText;
  #|     if (typeof write === "function") {
  #|       write.call(globalThis.navigator.clipboard, content).catch(() => {});
  #|     }
  #|   } catch {
  #|   }
  #|   return true;
  #| }

///|
extern "js" fn hover_mousedown_is_interactive(event : @rdom.Event) -> Bool =
  #| (event) => {
  #|   const target = event?.target;
  #|   return Boolean(target?.closest?.("button, a, input, textarea, select, [role='button'], .hover-copy-button"));
  #| }
