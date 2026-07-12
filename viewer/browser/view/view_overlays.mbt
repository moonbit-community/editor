// Ported from `vscode/src/vs/editor/browser/view/viewOverlays.ts`
// (`ViewOverlays`, `ViewOverlayLine`, `ContentViewOverlays`) and
// `dynamicViewOverlay.ts` (`DynamicViewOverlay`), vscode submodule commit
// 294fb350837dbaee37b949533fead4df4e0e8971. Replaces the flat-overlay
// deviation: overlays now render per-line HTML strings composed into one
// absolutely positioned row div per rendered view line, exactly Monaco's
// shape (rows recycled the way `ViewLines` recycles text lines —
// `VisibleLinesCollection`'s role; content rewritten only when a row's
// concatenated HTML changed, `ViewOverlayLine._renderedContent`'s dedupe).
//
// Deviations:
// - Registration is Monaco's `addDynamicOverlay` array, but the per-overlay
//   `ViewEventHandler` dirtiness is folded into the owning part's frame
//   events: the frame-based model re-prepares every registered overlay when
//   the part renders (the row-content dedupe keeps DOM writes minimal).
// - The trait and its impls live in this package (the `ViewPart`
//   orphan-rule pattern): `RenderingContext` is package-private, so the
//   view-part packages export pure per-line string builders and this
//   package's impls feed them the context.

///|
/// Monaco `DynamicViewOverlay` (`dynamicViewOverlay.ts`): `prepare_render`
/// builds the per-line render result off the read context; `render(start,
/// line)` returns the line's HTML slice.
priv trait DynamicViewOverlay {
  fn prepare_render(Self, RenderingContext) -> Unit
  fn render(Self, Int, Int) -> String
}

///|
/// The shared `render(startLineNumber, lineNumber)` slice every Monaco
/// overlay implements over its `_renderResult`.
fn render_result_slice(
  render_result : Array[String],
  start_line_number : Int,
  line_number : Int,
) -> String {
  let line_index = line_number - start_line_number
  if line_index < 0 || line_index >= render_result.length() {
    return ""
  }
  render_result[line_index]
}

///|
/// `ViewOverlays` (`viewOverlays.ts:19`): a rows container — one absolutely
/// positioned div per rendered view line, whose innerHTML is the registered
/// overlays' output for that line concatenated in registration order.
pub struct ViewOverlays {
  dom_node : @scrollbar.CachedDomNode
  priv dynamic_overlays : Array[&DynamicViewOverlay]
  priv mut lines : Array[ViewOverlayLine]
  priv mut window : @view_layout.LineWindow
  // `ViewOverlays._isFocused` (`viewOverlays.ts:24,76-79,128`): focus is
  // retained when the event is handled and consumed later by `render`.
  priv mut is_focused : Bool
}

///|
/// Complete Monaco `ViewOverlayLine` retained row
/// (`viewOverlays.ts:133-197`).
priv struct ViewOverlayLine {
  dynamic_overlays : Array[&DynamicViewOverlay]
  mut dom_node : @scrollbar.CachedDomNode?
  mut rendered_content : String?
}

///|
fn ViewOverlayLine::new(
  dynamic_overlays : Array[&DynamicViewOverlay],
) -> ViewOverlayLine {
  { dynamic_overlays, dom_node: None, rendered_content: None }
}

///|
fn ViewOverlayLine::get_dom_node(self : ViewOverlayLine) -> @rdom.Element? {
  self.dom_node.map(node => node.element())
}

///|
fn ViewOverlayLine::set_dom_node(
  self : ViewOverlayLine,
  dom_node : @rdom.Element,
) -> Unit {
  self.dom_node = Some(@scrollbar.CachedDomNode::new(dom_node))
}

///|
fn ViewOverlayLine::on_content_changed(_self : ViewOverlayLine) -> Unit {
  // Nothing (`viewOverlays.ts:156-158`).
}

///|
fn ViewOverlayLine::on_tokens_changed(_self : ViewOverlayLine) -> Unit {
  // Nothing (`viewOverlays.ts:159-161`).
}

///|
fn ViewOverlayLine::render_line(
  self : ViewOverlayLine,
  line_number : Int,
  delta_top : Int,
  line_height : Int,
  viewport : @view_layout.ViewportData,
  builder : StringBuilder,
) -> Bool {
  let content = StringBuilder()
  for overlay in self.dynamic_overlays {
    content.write_string(
      overlay.render(viewport.start_line_number, line_number),
    )
  }
  let content = content.to_string()
  if self.rendered_content == Some(content) {
    return false
  }
  self.rendered_content = Some(content)
  builder.write_string(
    "<div style=\"top:" +
    delta_top.to_string() +
    "px;height:" +
    line_height.to_string() +
    "px;line-height:" +
    line_height.to_string() +
    "px;\">" +
    content +
    "</div>",
  )
  true
}

///|
fn ViewOverlayLine::layout_line(
  self : ViewOverlayLine,
  _line_number : Int,
  delta_top : Int,
  line_height : Int,
) -> Unit {
  match self.dom_node {
    Some(node) => {
      node.set_top(Pixels(delta_top.to_double()))
      node.set_height(Pixels(line_height.to_double()))
      node.set_line_height(Pixels(line_height.to_double()))
    }
    None => ()
  }
}

///|
fn ViewOverlays::new(
  document : @rdom.Document,
  class_name : String,
) -> ViewOverlays {
  let dom_element = document.create_element("div")
  dom_element.set_attribute("class", class_name)
  dom_element.set_attribute("data-view-part", class_name)
  {
    dom_node: @scrollbar.CachedDomNode::new(dom_element),
    dynamic_overlays: [],
    lines: [],
    window: { start: 0, end: 0 },
    is_focused: false,
  }
}

///|
/// `addDynamicOverlay` (`viewOverlays.ts:69`): registration order is row
/// concatenation order (Monaco's `view.ts:218-231` z-order).
fn ViewOverlays::add_dynamic_overlay(
  self : ViewOverlays,
  overlay : &DynamicViewOverlay,
) -> Unit {
  self.dynamic_overlays.push(overlay)
}

///|
/// `ViewOverlays.prepareRender` (`viewOverlays.ts:113-121`) without the
/// per-overlay `shouldRender` filter (header deviation): every registered
/// overlay prepares its per-line render result.
fn ViewOverlays::prepare_overlays(
  self : ViewOverlays,
  context : RenderingContext,
) -> Unit {
  for overlay in self.dynamic_overlays {
    overlay.prepare_render(context)
  }
}

///|
fn ViewOverlays::on_content_or_tokens_changed(self : ViewOverlays) -> Unit {
  for line in self.lines {
    line.on_content_changed()
    line.on_tokens_changed()
  }
}

///|
/// `ViewOverlays.onFocusChanged` (`viewOverlays.ts:76-79`).
fn ViewOverlays::on_focus_changed(
  self : ViewOverlays,
  is_focused : Bool,
) -> Unit {
  self.is_focused = is_focused
}

///|
/// `ViewOverlays.render`'s equality-gated focused-class write. The source uses
/// `FastDomNode.toggleClassName`; the retained Bool, not frame-final input,
/// decides the class.
fn ViewOverlays::render_focused_class(
  self : ViewOverlays,
  base_class_name : String,
) -> Unit {
  let element = self.dom_node.element()
  let class_name = if self.is_focused {
    base_class_name + " focused"
  } else {
    base_class_name
  }
  if element.get_attribute("class") != class_name {
    element.set_attribute("class", class_name)
  }
}

///|
/// `VisibleLinesCollection.renderLines` + `ViewOverlayLine`, through the same
/// source-ordered renderer used by text rows.
fn ViewOverlays::render_lines(
  self : ViewOverlays,
  viewport : @view_layout.ViewportData,
) -> Unit {
  let renderer = @view_layer.ViewLayerRenderer::new(
    self.dom_node.element(),
    () => ViewOverlayLine::new(self.dynamic_overlays),
    line => line.get_dom_node(),
    (line, node) => line.set_dom_node(node),
    (line, line_number, delta_top, line_height) => {
      line.layout_line(line_number, delta_top, line_height)
    },
    (line, line_number, delta_top, line_height, viewport, builder) => {
      line.render_line(line_number, delta_top, line_height, viewport, builder)
    },
    viewport,
    _line_number => viewport.line_height,
  )
  let result = renderer.render(
    {
      rend_line_number_start: self.window.start,
      lines: self.lines,
      lines_length: self.lines.length(),
    },
    viewport.start_line_number,
    viewport.end_line_number,
    viewport.relative_vertical_offset,
  )
  self.lines = result.lines
  self.window = @view_lines.viewport_window(viewport)
}

///|
/// `ContentViewOverlays` (`viewOverlays.ts:204`): the content-side rows
/// container hosting the current-line, selection, and decoration overlays in
/// Monaco's registration order (`view.ts:218-221`). `pub(all)`: `View` holds
/// and constructs it, and the `ViewPart` impl reads/writes `should_render`
/// (both in this package); kept `pub(all)` for parity with the other part
/// structs the root package may probe.
pub(all) struct ContentViewOverlays {
  overlays : ViewOverlays
  current_line : @current_line_highlight.CurrentLineHighlightOverlay
  selections : @selections.SelectionsOverlay
  decorations : @decorations.DecorationsOverlay
  mut should_render : Bool
  // `ContentViewOverlays._contentWidth` (`viewOverlays.ts:204,210-213,226`).
  priv mut content_width : Double
  priv mut read_content_width : () -> Double
}

///|
pub fn ContentViewOverlays::new(
  document : @rdom.Document,
) -> ContentViewOverlays {
  let overlays = ViewOverlays::new(document, "view-overlays")
  let current_line = @current_line_highlight.CurrentLineHighlightOverlay::new()
  let selections = @selections.SelectionsOverlay::new()
  let decorations = @decorations.DecorationsOverlay::new()
  overlays.add_dynamic_overlay(current_line)
  overlays.add_dynamic_overlay(selections)
  overlays.add_dynamic_overlay(decorations)
  {
    overlays,
    current_line,
    selections,
    decorations,
    should_render: true,
    content_width: 0.0,
    read_content_width: () => 0.0,
  }
}

///|
/// Installs the local `ViewContext.configuration.options.layoutInfo` seam and
/// performs the constructor-time `_contentWidth` read.
fn ContentViewOverlays::install_content_width_reader(
  self : ContentViewOverlays,
  read_content_width : () -> Double,
) -> Unit {
  self.read_content_width = read_content_width
  self.on_configuration_changed()
}

///|
/// `ContentViewOverlays.onConfigurationChanged`'s retained layout read.
fn ContentViewOverlays::on_configuration_changed(
  self : ContentViewOverlays,
) -> Unit {
  self.content_width = (self.read_content_width)()
}

///|
pub fn ContentViewOverlays::get_dom_node(
  self : ContentViewOverlays,
) -> @rdom.Element {
  self.overlays.dom_node.element()
}

///|
/// Monaco `ViewOverlays.render` (`viewOverlays.ts:125`):
/// `toggleClassName('focused', this._isFocused)` on the overlay container —
/// selection colors key off `.focused .selected-text` (`selections.css`).
pub fn ContentViewOverlays::set_focused(
  self : ContentViewOverlays,
  focused : Bool,
) -> Unit {
  // Retain the public helper's existing signature; production render passes
  // only `overlays.is_focused`, the source event cache.
  let element = self.overlays.dom_node.element()
  let class_name = if focused {
    "view-overlays focused"
  } else {
    "view-overlays"
  }
  if element.get_attribute("class") != class_name {
    element.set_attribute("class", class_name)
  }
}

///|
/// `MarginViewOverlays` (`viewOverlays.ts:236`): the margin-side rows
/// container, hosting the current-line-margin, lines-decorations, and
/// line-number overlays in Monaco's margin registration order
/// (`view.ts:225-231`; the glyph-margin overlay between them is unported).
/// The viewer keeps Monaco's separate `Margin` part (`margin.ts` — the
/// `.margin` background/clip container) merged onto this struct: the
/// readonly margin has no glyph lane to justify the split.
pub(all) struct MarginViewOverlays {
  dom_node : @rdom.Element
  overlays : ViewOverlays
  current_line_margin : @margin.CurrentLineMarginHighlightOverlay
  lines_decorations : @margin.LinesDecorationsOverlay
  line_numbers : @margin.LineNumbersOverlay
  mut should_render : Bool
  // `MarginViewOverlays._contentLeft` (`viewOverlays.ts:238,244-248,265`).
  priv mut content_left : Double
  priv mut read_content_left : () -> Double
}

///|
pub fn MarginViewOverlays::new(document : @rdom.Document) -> MarginViewOverlays {
  let dom_node = document.create_element("div")
  dom_node.set_attribute("class", "margin")
  dom_node.set_attribute("data-view-part", "margin")
  dom_node.set_attribute("aria-hidden", "true")
  let overlays = ViewOverlays::new(document, "margin-view-overlays")
  let current_line_margin = @margin.CurrentLineMarginHighlightOverlay::new()
  let lines_decorations = @margin.LinesDecorationsOverlay::new()
  let line_numbers = @margin.LineNumbersOverlay::new()
  overlays.add_dynamic_overlay(current_line_margin)
  overlays.add_dynamic_overlay(lines_decorations)
  overlays.add_dynamic_overlay(line_numbers)
  dom_node.append_child(overlays.dom_node.element().as_node())
  {
    dom_node,
    overlays,
    current_line_margin,
    lines_decorations,
    line_numbers,
    should_render: true,
    content_left: 0.0,
    read_content_left: () => 0.0,
  }
}

///|
/// Installs the local `ViewContext.configuration.options.layoutInfo` seam and
/// performs the constructor-time `_contentLeft` read.
fn MarginViewOverlays::install_content_left_reader(
  self : MarginViewOverlays,
  read_content_left : () -> Double,
) -> Unit {
  self.read_content_left = read_content_left
  self.on_configuration_changed()
}

///|
/// `MarginViewOverlays.onConfigurationChanged`'s retained layout read.
fn MarginViewOverlays::on_configuration_changed(
  self : MarginViewOverlays,
) -> Unit {
  self.content_left = (self.read_content_left)()
}

///|
/// Applies the base `ViewOverlays.render` focus-class write to the margin
/// overlay container from its retained focus cache.
fn MarginViewOverlays::render_focused(self : MarginViewOverlays) -> Unit {
  self.overlays.render_focused_class("margin-view-overlays")
}

///|
pub fn MarginViewOverlays::get_dom_node(
  self : MarginViewOverlays,
) -> @rdom.Element {
  self.dom_node
}

///|
/// Installs the model-scoped live configuration reader used by both concrete
/// current-line overlays. Each state reads it immediately and again in its
/// source-time `ViewConfigurationChanged` handler.
pub fn View::install_current_line_configuration_reader(
  self : View,
  read_configuration : () -> (
    @view_layout.RenderLineHighlight,
    Bool,
    Bool,
    Double,
    Double,
  ),
) -> Unit {
  self.content_view_overlays.install_content_width_reader(() => {
    let (_, _, _, _, content_width) = read_configuration()
    content_width
  })
  self.margin_view_overlays.install_content_left_reader(() => {
    let (_, _, _, content_left, _) = read_configuration()
    content_left
  })
  self.content_view_overlays.current_line.state.install_configuration_reader(
    read_configuration,
  )
  self.margin_view_overlays.current_line_margin.state.install_configuration_reader(
    read_configuration,
  )
}
