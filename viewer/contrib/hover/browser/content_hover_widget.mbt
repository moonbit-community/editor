// Ported from `vscode/src/vs/editor/contrib/hover/browser/contentHoverWidget.ts`
// (`ContentHoverWidget`) with the available-space arithmetic of its base
// `resizableContentWidget.ts` and the DOM skeleton of
// `vs/base/browser/ui/hover/hoverWidget.ts` (`HoverWidget`). The widget is a
// persistent content widget: its DOM mounts once via the editor's
// `add_content_widget` and stays in the tree; `show` rewrites the contents
// when a hover result changes, `hide` toggles the `.hidden` class — never an
// unmount, so the `fade-in` animation plays only on a genuine hidden→shown
// transition.
//
// Standing deviations carried forward from the previous port:
//   - No resize sashes (`ResizableHTMLElement` machinery unported); the
//     widget is not user-resizable.
//   - `allowEditorOverflow` is `false` (source: `true`): the viewer's hover is
//     clipped to `.overflow-guard` (the Phase 1b non-overflowing deviation),
//     so available space is measured against the editor box, not the page.
//   - Width sizing keeps the nowrap-probe / available-width cap adaptation of
//     `_findMaximumRenderingWidth` (no page-body overflow branch).

///|
/// Monaco `RenderedContentHover` (`contentHoverRendered.ts`), narrowed to what
/// the widget consumes: where to anchor (`showAtPosition` /
/// `showAtSecondaryPosition`, both model-space — `computeHoverPositions`'s
/// outputs) and the rendered part rows (the `RenderedContentHoverParts` DOM,
/// as one HTML string per focusable part row).
pub(all) struct RenderedContentHover {
  show_at_position : @base_common.Position
  show_at_secondary_position : @base_common.Position
  rows : Array[String]
}

///|
/// The editor/services capabilities the widget needs from `Viewer`, as
/// closures (Monaco's `this._editor` + DI services). Built once at widget
/// construction.
pub(all) struct ContentHoverWidgetHost {
  /// The editor's root node — the available-space / width-cap box (Monaco
  /// measures the page body; the non-overflowing deviation measures the
  /// editor).
  root : @rdom.Element
  /// `editor.layoutContentWidget(this)`: re-read `get_position()` and
  /// reposition on the next render.
  layout_content_widget : () -> Unit
  /// `editor.render()`: force a synchronous render so the freshly shown
  /// widget does not paint one frame at a stale position
  /// (`contentHoverWidget.ts:319-321`).
  render_now : () -> Unit
  /// `editor.focus()`, the `hide()` focus-restore arm.
  focus_editor : () -> Unit
  /// `getScrolledVisiblePosition(position).top`: the anchor line's top edge in
  /// editor-viewport pixels, the `_availableVerticalSpace*` input.
  scrolled_visible_position_top : (@base_common.Position) -> Double
  /// `fontInfo.lineHeight`, read live like the source's option access.
  line_height : () -> Double
  /// `layoutInfo` gutter width: the hover may occupy the content area right of
  /// the gutter (see `hover_available_width`).
  gutter_width : () -> Double
  /// The pointer is on the hover widget: keep the hover open (the controller's
  /// `_shouldKeepCurrentHover` arm over the content widget).
  keep_hover_open : () -> Unit
  /// Non-interactive mousedown on the hover starts editor selection at the
  /// underlying coordinate.
  handle_mousedown : (@rdom.Event, @rdom.MouseEvent) -> Unit
  /// Widget keydown resolves through the keybinding table (`hoverActions.ts`'s
  /// scroll cluster).
  handle_keydown : (@rdom.Event, @rdom.KeyboardEvent) -> Unit
  hook_scrollable_scrollbar_input : (
    @scrollbar.ScrollableElementDom,
    @scrollbar.ScrollableElementOwner,
  ) -> Unit
}

///|
/// Monaco `ContentHoverWidget`. `wrapper` is `_resizableNode.domNode`
/// (`.monaco-resizable-hover`), `hover` is the base `HoverWidget`'s
/// `containerDomNode` (`.monaco-hover.fade-in`), `scrollable` wraps its
/// `contentsDomNode` (`.monaco-hover-content`).
pub(all) struct ContentHoverWidget {
  wrapper : @rdom.Element
  hover : @rdom.Element
  scrollable : @scrollbar.ScrollableElementDom
  host : ContentHoverWidgetHost
  mut rendered_hover : RenderedContentHover?
  mut position_preference : @content_widgets.ContentWidgetPositionPreference?
}

///|
/// Monaco `ContentHoverWidget.ID`.
pub let content_hover_widget_id : String = "editor.contrib.resizableContentHoverWidget"

///|
pub impl @content_widgets.ContentWidget for ContentHoverWidget with fn get_id(
  _self,
) {
  content_hover_widget_id
}

///|
pub impl @content_widgets.ContentWidget for ContentHoverWidget with fn get_dom_node(
  self,
) {
  self.wrapper
}

///|
/// Source: `true`. The viewer's hover stays clipped to `.overflow-guard`
/// (non-overflowing deviation), so the widget renders in the content layer.
pub impl @content_widgets.ContentWidget for ContentHoverWidget with fn allow_editor_overflow(
  _self,
) {
  false
}

///|
/// Monaco `ContentHoverWidget.getPosition` (`contentHoverWidget.ts:324-334`);
/// `positionAffinity` (`shouldAppearBeforeContent`) is N-A.
pub impl @content_widgets.ContentWidget for ContentHoverWidget with fn get_position(
  self,
) {
  match self.rendered_hover {
    Some(rendered) =>
      Some({
        position: Some(rendered.show_at_position),
        secondary_position: Some(rendered.show_at_secondary_position),
        preference: [
          match self.position_preference {
            Some(preference) => preference
            None => Above
          },
        ],
      })
    None => None
  }
}

///|
/// Builds the persistent widget DOM and its listeners (Monaco's constructor +
/// `HoverWidget(fadeIn: true)`); starts hidden (`_setRenderedHover(undefined)`).
/// The caller mounts it exactly once through the editor's content-widget seam.
pub fn ContentHoverWidget::new(
  host : ContentHoverWidgetHost,
) -> ContentHoverWidget {
  let document = @rdom.document()
  let wrapper = document.create_element("div")
  wrapper.set_attribute("class", "monaco-resizable-hover")
  let hover = document.create_element("div")
  hover.set_attribute("class", "monaco-hover fade-in hidden")
  hover.set_attribute("role", "tooltip")
  hover.set_attribute("tabindex", "0")
  let scrollable = @scrollbar.ScrollableElementDom::new("monaco-hover-content")
  hover.append_child(scrollable.wrapper.as_node())
  wrapper.append_child(hover.as_node())
  let widget : ContentHoverWidget = {
    wrapper,
    hover,
    scrollable,
    host,
    rendered_hover: None,
    position_preference: None,
  }
  // Content widgets swallow pointer motion, but a hover may overlap source
  // text; non-interactive mousedown should still start editor selection at
  // the underlying coordinate.
  wrapper.add_event_listener("mousemove", event => {
    // The pointer is on the hover widget: keep it open. The editor never
    // sees this move (stop_propagation), so the controller's grace timer
    // would otherwise still fire and hide the widget out from under it.
    (host.keep_hover_open)()
    event.stop_propagation()
  })
  wrapper.add_event_listener("mousedown", event => {
    if hover_mousedown_is_interactive(event) {
      event.stop_propagation()
    } else {
      match event.to_mouse_event() {
        Some(mouse) => (host.handle_mousedown)(event, mouse)
        None => event.stop_propagation()
      }
    }
  })
  wrapper.add_event_listener("click", event => {
    if handle_hover_copy_click(event) {
      event.prevent_default()
    }
    event.stop_propagation()
  })
  wrapper.add_event_listener("contextmenu", event => event.stop_propagation())
  wrapper.add_event_listener("focusin", event => event.stop_propagation())
  wrapper.add_event_listener("focusout", event => event.stop_propagation())
  wrapper.add_event_listener("wheel", event => {
    match event.to_wheel_event() {
      Some(wheel) => {
        event.prevent_default()
        event.stop_propagation()
        widget.handle_wheel(wheel)
      }
      None => event.stop_propagation()
    }
  })
  scrollable.content.add_event_listener("wheel", event => {
    match event.to_wheel_event() {
      Some(wheel) => {
        event.prevent_default()
        event.stop_propagation()
        widget.handle_wheel(wheel)
      }
      None => event.stop_propagation()
    }
  })
  scrollable.content.add_event_listener("scroll", _ => {
    scrollable.update_from_native_content()
  })
  (host.hook_scrollable_scrollbar_input)(scrollable, HoverScrollableElement)
  wrapper.add_event_listener("keydown", event => {
    match event.to_keyboard_event() {
      Some(keyboard) => (host.handle_keydown)(event, keyboard)
      None => event.stop_propagation()
    }
  })
  widget
}

///|
/// Monaco `isVisible` (the `hoverVisible` context key `_setRenderedHover`
/// maintains).
pub fn ContentHoverWidget::is_visible(self : ContentHoverWidget) -> Bool {
  self.rendered_hover is Some(_)
}

///|
/// Monaco `_setRenderedHover` (`contentHoverWidget.ts:278-283`): swap the
/// rendered state and toggle the container's `hidden` class.
fn ContentHoverWidget::set_rendered_hover(
  self : ContentHoverWidget,
  rendered_hover : RenderedContentHover?,
) -> Unit {
  self.rendered_hover = rendered_hover
  let hidden = if rendered_hover is Some(_) { "" } else { " hidden" }
  self.hover.set_attribute("class", "monaco-hover fade-in" + hidden)
}

///|
/// Monaco `_updateContent` (`contentHoverWidget.ts:295-300`) +
/// `RenderedContentHoverParts._registerListenersOnRenderedParts`' `tabIndex = 0`
/// per rendered part row.
fn ContentHoverWidget::update_content(
  self : ContentHoverWidget,
  rows : Array[String],
) -> Unit {
  self.scrollable.content.set_inner_html(rows.join(""))
  for part in self.scrollable.content.get_children() {
    part.set_attribute("tabindex", "0")
  }
}

///|
/// Monaco `_render` (`contentHoverWidget.ts:314-322`): swap in the rendered
/// hover, write its contents, lay out, then force a synchronous editor render
/// so the widget does not really render at a stale position. (`_updateFont` is
/// N-A: the viewer's hover font comes from `hover.css`.)
fn ContentHoverWidget::render_rendered_hover(
  self : ContentHoverWidget,
  rendered_hover : RenderedContentHover,
) -> Unit {
  self.set_rendered_hover(Some(rendered_hover))
  self.update_content(rendered_hover.rows)
  self.handle_contents_changed()
  // Simply force a synchronous render on the editor
  // such that the widget does not really render with left = '0px'
  (self.host.render_now)()
}

///|
/// Monaco `show` (`contentHoverWidget.ts:336-362`): render, then re-derive the
/// position preference from the freshly measured box and lay out again (the
/// source's post-render second layout; the accessible-view hint and
/// keyboard-focus arms are N-A).
pub fn ContentHoverWidget::show(
  self : ContentHoverWidget,
  rendered_hover : RenderedContentHover,
) -> Unit {
  self.render_rendered_hover(rendered_hover)
  // See https://github.com/microsoft/vscode/issues/140339
  // TODO: Doing a second layout of the hover after force rendering the editor
  self.handle_contents_changed()
}

///|
/// Monaco `hide` (`contentHoverWidget.ts:364-377`): clear the rendered state
/// (the `hidden` class hides the container), reposition (the widget's
/// `get_position()` is now `None`, so the content-widget layer hides the
/// node), and give focus back to the editor when the hover had stolen it.
pub fn ContentHoverWidget::hide(self : ContentHoverWidget) -> Unit {
  guard self.rendered_hover is Some(_) else { return }
  let hover_stole_focus = hover_element_contains_active(self.wrapper)
  self.set_rendered_hover(None)
  (self.host.layout_content_widget)()
  if hover_stole_focus {
    (self.host.focus_editor)()
  }
}

///|
/// Monaco `handleContentsChanged` (`contentHoverWidget.ts:406-428`), with the
/// port's adapted sizing pass: probe the natural (nowrap) width, cap it to the
/// available content-area width, measure the width-constrained height, choose
/// the side (`_findPositionPreference`) and its available-space height cap
/// (`_findMaximumRenderingHeight`), then reposition and rescan the scrollbar
/// (`_layoutContentWidget`).
pub fn ContentHoverWidget::handle_contents_changed(
  self : ContentHoverWidget,
) -> Unit {
  self.clear_sizing()
  let natural_width = self.measure_natural_width()
  let available_width = hover_available_width(
    self.host.root,
    (self.host.gutter_width)(),
  )
  let width = hover_resolved_width(natural_width, available_width)
  self.apply_width_sizing(width)
  match self.rendered_hover {
    Some(rendered) => {
      let content_height = self.wrapper.get_bounding_client_rect().get_height()
      // `_availableVerticalSpaceAbove/Below` measured editor-relative (the
      // non-overflowing deviation; the source measures against the page).
      let line_top = (self.host.scrolled_visible_position_top)(
        rendered.show_at_position,
      )
      let editor_height = self.host.root.get_bounding_client_rect().get_height()
      let space_above = hover_available_space_above(line_top)
      let space_below = hover_available_space_below(
        line_top,
        (self.host.line_height)(),
        editor_height,
      )
      let above = hover_prefer_above(
        content_height, space_above, space_below, hover_prefer_above_default,
      )
      self.position_preference = Some(if above { Above } else { Below })
      let available = if above { space_above } else { space_below }
      let max_height = hover_maximum_rendering_height(available, content_height)
      self.apply_sizing(width, max_height)
    }
    None => ()
  }
  (self.host.layout_content_widget)()
  self.scrollable.update_from_native_content()
}

///|
fn ContentHoverWidget::clear_sizing(self : ContentHoverWidget) -> Unit {
  self.hover.set_attribute("style", "")
  self.scrollable.wrapper.set_attribute("style", "")
  self.scrollable.content.set_attribute("style", "")
}

///|
/// `ContentHoverWidget._isHoverTextOverflowing`'s nowrap probe
/// (`contentHoverWidget.ts:202-215`), narrowed to just the measurement: force
/// single-line rendering via the CSS hooks `hover.css` exposes
/// (`--vscode-hover-whiteSpace`/`--vscode-hover-sourceWhiteSpace`), read the
/// natural width, then release the hooks.
fn ContentHoverWidget::measure_natural_width(
  self : ContentHoverWidget,
) -> Double {
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
/// `_setHoverWidgetDimensions` touches (`contentHoverWidget.ts:113-137`) —
/// this port's `hover`/`scrollable.wrapper`/`scrollable.content`. The
/// outermost `wrapper` (Monaco's `_resizableNode.domNode`) is untouched; its
/// sizing is the unported sash/resize machinery's job.
fn ContentHoverWidget::apply_width_sizing(
  self : ContentHoverWidget,
  width : Double,
) -> Unit {
  let style = hover_width_style(width)
  self.hover.set_attribute("style", style)
  self.scrollable.wrapper.set_attribute("style", style)
  self.scrollable.content.set_attribute("style", style)
  self.scrollable.update_from_native_content()
}

///|
fn ContentHoverWidget::apply_sizing(
  self : ContentHoverWidget,
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
/// `.markdown-hover .hover-contents` reads (`hover.css`) so nested content
/// tracks the same resolved width instead of falling back to its 500px
/// default.
fn hover_width_style(width : Double) -> String {
  let px = width.to_string() + "px"
  "width:" + px + ";--vscode-hover-maxWidth:" + px
}

///|
/// The hover's `DomScrollableElement` wheel path: the same `_onMouseWheel`
/// delta pipeline as the editor, at `resolveOptions` defaults, applied to the
/// widget's native scroll offsets.
fn ContentHoverWidget::handle_wheel(
  self : ContentHoverWidget,
  wheel : @rdom.WheelEvent,
) -> Unit {
  let (delta_left, delta_top) = @scrollbar.mouse_wheel_scroll_deltas(
    @scrollbar.StandardWheelEvent::new(wheel),
    alt_key=wheel.get_alt_key(),
    shift_key=wheel.get_shift_key(),
  )
  self.scrollable.native_scroll_by(delta_left~, delta_top~)
}

///|
/// Monaco `contentHoverWidget.ts` `HORIZONTAL_SCROLLING_BY`: the fixed pixel
/// step the hover scrolls left/right per arrow press.
let hover_horizontal_scrolling_by : Double = 30.0

///|
/// Monaco `ContentHoverWidget.scrollUp`: `scrollTop -= fontInfo.lineHeight`.
pub fn ContentHoverWidget::scroll_up(self : ContentHoverWidget) -> Unit {
  self.scrollable.native_scroll_by(delta_top=-(self.host.line_height)())
}

///|
/// Monaco `ContentHoverWidget.scrollDown`: `scrollTop += fontInfo.lineHeight`.
pub fn ContentHoverWidget::scroll_down(self : ContentHoverWidget) -> Unit {
  self.scrollable.native_scroll_by(delta_top=(self.host.line_height)())
}

///|
/// Monaco `ContentHoverWidget.scrollLeft`: `scrollLeft -= HORIZONTAL_SCROLLING_BY`.
pub fn ContentHoverWidget::scroll_left(self : ContentHoverWidget) -> Unit {
  self.scrollable.native_scroll_by(delta_left=-hover_horizontal_scrolling_by)
}

///|
/// Monaco `ContentHoverWidget.scrollRight`: `scrollLeft += HORIZONTAL_SCROLLING_BY`.
pub fn ContentHoverWidget::scroll_right(self : ContentHoverWidget) -> Unit {
  self.scrollable.native_scroll_by(delta_left=hover_horizontal_scrolling_by)
}

///|
/// Monaco `ContentHoverWidget.pageUp`: `scrollTop -= getScrollDimensions().height`
/// (the visible content height).
pub fn ContentHoverWidget::page_up(self : ContentHoverWidget) -> Unit {
  self.scrollable.native_scroll_by(
    delta_top=-self.scrollable.native_page_delta(),
  )
}

///|
/// Monaco `ContentHoverWidget.pageDown`: `scrollTop += getScrollDimensions().height`.
pub fn ContentHoverWidget::page_down(self : ContentHoverWidget) -> Unit {
  self.scrollable.native_scroll_by(
    delta_top=self.scrollable.native_page_delta(),
  )
}

///|
/// Monaco `ContentHoverWidget.goToTop`: `scrollTop = 0`.
pub fn ContentHoverWidget::go_to_top(self : ContentHoverWidget) -> Unit {
  self.scrollable.native_scroll_to(vertical=true, 0.0)
}

///|
/// Monaco `ContentHoverWidget.goToBottom`: `scrollTop = getScrollDimensions().scrollHeight`.
pub fn ContentHoverWidget::go_to_bottom(self : ContentHoverWidget) -> Unit {
  self.scrollable.native_scroll_to(
    vertical=true,
    self.scrollable.content.get_scroll_height(),
  )
}

///|
/// Monaco `resizableContentWidget.ts` `TOP_HEIGHT` / `BOTTOM_HEIGHT`: the margin
/// kept between the hover and the editor top / bottom edge when measuring how
/// much vertical room each side has.
let hover_top_height : Double = 30.0

///|
let hover_bottom_height : Double = 24.0

///|
/// `editor.hover.above`'s VS Code default: prefer rendering the hover above the
/// anchor line when it fits there.
pub let hover_prefer_above_default : Bool = true

///|
/// Monaco `ResizableContentWidget._availableVerticalSpaceAbove`, adapted to the
/// non-overflowing (clipped to `.overflow-guard`) hover: the room from the
/// anchor line top up to the editor top edge, less `TOP_HEIGHT`. `line_top` is
/// the anchor line's top in editor-viewport pixels.
pub fn hover_available_space_above(line_top : Double) -> Double {
  line_top - hover_top_height
}

///|
/// Monaco `ResizableContentWidget._availableVerticalSpaceBelow`, editor-relative:
/// the room from the anchor line bottom down to the editor bottom edge, less
/// `BOTTOM_HEIGHT`.
pub fn hover_available_space_below(
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
pub fn hover_maximum_rendering_height(
  available : Double,
  content_height : Double,
) -> Double {
  @hover.min_hover_double(available, content_height)
}

///|
/// Monaco `ResizableContentWidget._findPositionPreference`: choose ABOVE vs
/// BELOW. Returns `true` for ABOVE. `prefer_above` mirrors `editor.hover.above`.
pub fn hover_prefer_above(
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
pub fn hover_available_width(
  root : @rdom.Element,
  gutter_width : Double,
) -> Double {
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
pub fn hover_resolved_width(
  natural_width : Double,
  available_width : Double,
) -> Double {
  @hover.min_hover_double(natural_width, available_width)
}

///|
extern "js" fn handle_hover_copy_click(event : @rdom.Event) -> Bool =
  #| (event) => {
  #|   const target = event?.target;
  #|   const button = target?.closest?.(".hover-copy-button");
  #|   if (!button || !button.closest?.('.monaco-resizable-hover')) {
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

///|
extern "js" fn hover_element_contains_active(el : @rdom.Element) -> Bool =
  #| (el) => {
  #|   const active = el?.ownerDocument?.activeElement;
  #|   return Boolean(active && el.contains(active));
  #| }
