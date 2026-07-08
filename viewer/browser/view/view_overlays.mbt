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
  dom_node : @rdom.Element
  priv dynamic_overlays : Array[&DynamicViewOverlay]
  priv line_nodes : Array[@rdom.Element]
  priv rendered_contents : Array[String]
  priv mut window : @view_layout.LineWindow
}

///|
fn ViewOverlays::new(
  document : @rdom.Document,
  class_name : String,
) -> ViewOverlays {
  let dom_node = document.create_element("div")
  dom_node.set_attribute("class", class_name)
  dom_node.set_attribute("data-view-part", class_name)
  {
    dom_node,
    dynamic_overlays: [],
    line_nodes: [],
    rendered_contents: [],
    window: { start: 0, end: 0 },
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
/// The row style of `ViewOverlayLine.renderLine` (`viewOverlays.ts:178-185`):
/// `top`/`height`/`line-height` inline; `position:absolute; width:100%` come
/// from the shared row CSS (`editor.css`'s `.view-overlays > div` rule).
fn overlay_row_style(top : Int, line_height : Int) -> String {
  "top:" +
  top.to_string() +
  "px;height:" +
  line_height.to_string() +
  "px;line-height:" +
  line_height.to_string() +
  "px;"
}

///|
/// `VisibleLinesCollection.renderLines` + `ViewOverlayLine.renderLine`: the
/// row recycler. Rows for lines leaving the window are dropped, entering
/// lines get fresh row nodes, and a surviving row's innerHTML is rewritten
/// only when its concatenated overlay HTML changed; every row's
/// `top`/`height` is (re)laid out (`layoutLine`).
fn ViewOverlays::render_lines(
  self : ViewOverlays,
  viewport : @view_layout.ViewportData,
) -> Unit {
  let target = @view_lines.viewport_window(viewport)
  let document = @rdom.document()
  let previous = self.window
  let next_nodes : Array[@rdom.Element] = []
  let next_contents : Array[String] = []
  for index in 0..<viewport.lines.length() {
    let line_number = viewport.start_line_number + index
    let mut content = ""
    for overlay in self.dynamic_overlays {
      content = content +
        overlay.render(viewport.start_line_number, line_number)
    }
    let reused = line_number >= previous.start && line_number < previous.end
    let node = if reused {
      self.line_nodes[line_number - previous.start]
    } else {
      let node = document.create_element("div")
      self.dom_node.append_child(node.as_node())
      node
    }
    let content_changed = if reused {
      self.rendered_contents[line_number - previous.start] != content
    } else {
      true
    }
    if content_changed {
      node.set_inner_html(content)
    }
    node.set_attribute(
      "style",
      overlay_row_style(
        viewport.relative_vertical_offset[index],
        viewport.line_height,
      ),
    )
    next_nodes.push(node)
    next_contents.push(content)
  }
  for line_number in previous.start..<previous.end {
    if line_number < target.start || line_number >= target.end {
      self.dom_node.remove_child(
        self.line_nodes[line_number - previous.start].as_node(),
      )
    }
  }
  self.line_nodes.clear()
  for node in next_nodes {
    self.line_nodes.push(node)
  }
  self.rendered_contents.clear()
  for content in next_contents {
    self.rendered_contents.push(content)
  }
  self.window = target
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
  { overlays, current_line, selections, decorations, should_render: true }
}

///|
pub fn ContentViewOverlays::get_dom_node(
  self : ContentViewOverlays,
) -> @rdom.Element {
  self.overlays.dom_node
}

///|
/// Monaco `ViewOverlays.render` (`viewOverlays.ts:125`):
/// `toggleClassName('focused', this._isFocused)` on the overlay container —
/// selection colors key off `.focused .selected-text` (`selections.css`).
pub fn ContentViewOverlays::set_focused(
  self : ContentViewOverlays,
  focused : Bool,
) -> Unit {
  self.overlays.dom_node.set_attribute(
    "class",
    if focused {
      "view-overlays focused"
    } else {
      "view-overlays"
    },
  )
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
  dom_node.append_child(overlays.dom_node.as_node())
  {
    dom_node,
    overlays,
    current_line_margin,
    lines_decorations,
    line_numbers,
    should_render: true,
  }
}

///|
pub fn MarginViewOverlays::get_dom_node(
  self : MarginViewOverlays,
) -> @rdom.Element {
  self.dom_node
}
