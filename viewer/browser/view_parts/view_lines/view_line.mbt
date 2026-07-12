// Ported from `vscode/src/vs/editor/browser/viewParts/viewLines/viewLine.ts`
// (vscode submodule commit b18492a288de038fbc7643aae6de8247029d11bd): the
// pieces the mouse hit test reads — `ViewLine.CLASS_NAME`, the module-level
// `getColumnOfNodeOffset`, and the rendered line's DOM width read.
//
// Omissions:
//   * The `FastRenderedViewLine`/`RenderedViewLine`/`WebKitRenderedViewLine`
//     class family — the readonly `ViewLine` retains the normalized input, DOM,
//     and character map directly. `getWidth` therefore always takes the
//     source's DOM-measured arm
//     (`RenderedViewLine.getWidth`, viewLine.ts:522-531:
//     `_getReadingTarget(...).offsetWidth`) — which is also the arm every
//     line with foreign elements (e.g. a folded header's `inline-folded`
//     `::after` ellipsis) takes in the source, since
//     `FastRenderedViewLine`'s monospace shortcut is gated on
//     `containsForeignElements === None`.
//   * `_cachedWidth`: the width is re-read per call, so the source-shaped
//     content/token/decoration/option invalidators have no width cache to
//     reset; the only caller is the per-gesture hit test.

///|
/// `ViewLine.CLASS_NAME` (viewLine.ts:53) — the exact string the caret hit
/// test's ancestor walk compares `className` against.
pub const VIEW_LINE_CLASS_NAME : String = "view-line"

///|
/// The scoped local equivalent of Monaco `ViewLineOptions`. It retains every
/// option that participates in the readonly viewer's normalized
/// `RenderLineInput`; configuration events compare this snapshot rather than
/// treating a changed option id as proof that a retained row changed.
pub(all) struct ViewLineOptions {
  line_height : Int
  space_width : Double
  middot_width : Double
  wsmiddot_width : Double
  use_monospace_optimizations : Bool
  can_use_halfwidth_rightwards_arrow : Bool
  stop_rendering_line_after : Int
  render_whitespace : @view_layout.RenderWhitespace
  render_control_characters : Bool
  font_ligatures : Bool
  vertical_scrollbar_size : Double
} derive(Eq, Debug)

///|
pub fn ViewLineOptions::new(
  line_height? : Int = 20,
  space_width? : Double = 7.2,
  middot_width? : Double = 7.2,
  wsmiddot_width? : Double = 7.2,
  use_monospace_optimizations? : Bool = true,
  can_use_halfwidth_rightwards_arrow? : Bool = true,
  stop_rendering_line_after? : Int = -1,
  render_whitespace? : @view_layout.RenderWhitespace = None,
  render_control_characters? : Bool = false,
  font_ligatures? : Bool = false,
  vertical_scrollbar_size? : Double = @core.editor_vertical_scrollbar_size,
) -> ViewLineOptions {
  {
    line_height,
    space_width,
    middot_width,
    wsmiddot_width,
    use_monospace_optimizations,
    can_use_halfwidth_rightwards_arrow,
    stop_rendering_line_after,
    render_whitespace,
    render_control_characters,
    font_ligatures,
    vertical_scrollbar_size,
  }
}

///|
fn ViewLineOptions::equals(
  self : ViewLineOptions,
  other : ViewLineOptions,
) -> Bool {
  self == other
}

///|
/// Monaco `ViewLine`'s retained render state narrowed to the fields consumed
/// by `ViewLayerRenderer`: cached DOM, last render input, and character map.
pub struct ViewLine {
  priv mut options : ViewLineOptions
  priv mut dom_node : @scrollbar.CachedDomNode?
  priv mut render_input : @view_layout.RenderLineInput?
  priv mut character_mapping : @view_layout.CharacterMapping?
  // `ViewLine._isMaybeInvalid` (`viewLine.ts:56,61,81-96,109-114`).
  // Invalidators only latch this bit. The next render consumes it before the
  // normalized-input equality gate, so a notification can be proven harmless
  // without replacing the retained DOM node.
  priv mut is_maybe_invalid : Bool
}

///|
pub fn ViewLine::new(
  options? : ViewLineOptions = ViewLineOptions::new(),
) -> ViewLine {
  {
    options,
    dom_node: None,
    render_input: None,
    character_mapping: None,
    is_maybe_invalid: true,
  }
}

///|
fn ViewLine::option_snapshot(self : ViewLine) -> ViewLineOptions {
  self.options
}

///|
/// `ViewLine.onContentChanged` (`viewLine.ts:81-83`).
fn ViewLine::on_content_changed(self : ViewLine) -> Unit {
  self.is_maybe_invalid = true
}

///|
/// `ViewLine.onTokensChanged` (`viewLine.ts:84-86`).
fn ViewLine::on_tokens_changed(self : ViewLine) -> Unit {
  self.is_maybe_invalid = true
}

///|
/// `ViewLine.onDecorationsChanged` (`viewLine.ts:87-89`).
fn ViewLine::on_decorations_changed(self : ViewLine) -> Unit {
  self.is_maybe_invalid = true
}

///|
/// `ViewLine.onOptionsChanged` (`viewLine.ts:90-93`). The readonly port
/// retains the new option snapshot after setting the source invalidation latch;
/// the next render derives `RenderLineInput` from this exact snapshot.
fn ViewLine::on_options_changed(
  self : ViewLine,
  new_options : ViewLineOptions,
) -> Unit {
  self.is_maybe_invalid = true
  self.options = new_options
}

///|
/// `ViewLine.onSelectionChanged` (`viewLine.ts:94-100`), reduced only by the
/// documented absence of a typed high-contrast theme branch. Selection dirties
/// a retained row iff its last rendered input used Selection whitespace.
fn ViewLine::on_selection_changed(self : ViewLine) -> Bool {
  match self.render_input {
    Some(input) if input.render_whitespace == Selection => {
      self.is_maybe_invalid = true
      true
    }
    _ => false
  }
}

///|
pub fn ViewLine::get_dom_node(self : ViewLine) -> @rdom.Element? {
  self.dom_node.map(node => node.element())
}

///|
pub fn ViewLine::set_dom_node(
  self : ViewLine,
  dom_node : @rdom.Element,
) -> Unit {
  self.dom_node = Some(@scrollbar.CachedDomNode::new(dom_node))
}

///|
pub fn ViewLine::mapping(self : ViewLine) -> @view_layout.CharacterMapping? {
  self.character_mapping
}

///|
/// `ViewLine.layoutLine` (`viewLine.ts:235-241`).
pub fn ViewLine::layout_line(
  self : ViewLine,
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
/// The `ViewLine.renderLine` half consumed by `ViewLayerRenderer`. Equal
/// `RenderLineInput` is the source's unchanged-line early return; changed
/// lines append one complete row to the renderer's shared HTML batch.
pub fn ViewLine::render_line(
  self : ViewLine,
  line_number : Int,
  input : @view_layout.RenderLineInput,
  delta_top : Int,
  line_height : Int,
  builder : StringBuilder,
) -> Bool {
  if !self.is_maybe_invalid {
    return false
  }
  self.is_maybe_invalid = false
  if self.render_input == Some(input) {
    return false
  }
  let output = @view_layout.render_view_line2(input)
  self.render_input = Some(input)
  self.character_mapping = Some(output.character_mapping)
  builder.write_string(
    "<div class=\"" +
    @viewer_common.render_line_class() +
    "\" data-line=\"" +
    line_number.to_string() +
    "\" style=\"top:" +
    delta_top.to_string() +
    "px;height:" +
    line_height.to_string() +
    "px;line-height:" +
    line_height.to_string() +
    "px\">" +
    output.html +
    "</div>",
  )
  true
}

///|
/// `getColumnOfNodeOffset` (viewLine.ts:724-733): resolves a browser caret
/// answer (token span + character offset) to a one-based column through the
/// line's `CharacterMapping`. The span index counts every previous sibling,
/// exactly like the source's `previousSibling` walk.
pub fn get_column_of_node_offset(
  character_mapping : @view_layout.CharacterMapping,
  span_node : @rdom.Element,
  offset : Int,
) -> Int {
  let span_node_text_content_length = element_text_content_length(span_node)
  let span_index = count_previous_siblings(span_node)
  character_mapping.get_column(
    { part_index: span_index, char_index: offset },
    span_node_text_content_length,
  )
}

///|
/// `RenderedViewLine.getWidth` (viewLine.ts:516-531): the rendered width of a
/// line node, read as the `offsetWidth` of its reading target — the
/// `.view-line-content` span (`_getReadingTarget`: the line node's first
/// child). This is a layout read; the passed context records it.
pub fn rendered_view_line_width(
  line_node : @rdom.Element,
  context : DomReadingContext?,
) -> Double {
  let width = reading_target_offset_width(line_node)
  match context {
    Some(ctx) => ctx.mark_did_dom_layout()
    None => ()
  }
  width
}

///|
/// FFI gap-fills (no `textContent`/`previousSibling`/`firstChild.offsetWidth`
/// bindings in the vendored `@rdom`).
extern "js" fn element_text_content_length(el : @rdom.Element) -> Int =
  #| (el) => (el.textContent || "").length

///|
/// The source's `while (spanNode) { spanNode = spanNode.previousSibling;
/// spanIndex++; }` starting from `spanIndex = -1`.
extern "js" fn count_previous_siblings(el : @rdom.Element) -> Int =
  #| (el) => {
  #|   let i = -1;
  #|   let n = el;
  #|   while (n) {
  #|     n = n.previousSibling;
  #|     i++;
  #|   }
  #|   return i;
  #| }

///|
extern "js" fn reading_target_offset_width(line_node : @rdom.Element) -> Double =
  #| (el) => {
  #|   const target = el.firstChild;
  #|   return target ? target.offsetWidth : 0;
  #| }
