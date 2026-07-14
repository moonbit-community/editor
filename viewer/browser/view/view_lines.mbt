// Ported from `vscode/src/vs/editor/browser/viewParts/viewLines/viewLines.ts`
// (`ViewLines`, the recycler) and `viewLine.ts` (the per-line render input +
// DOM write). Its event adapter lives at the owning private-event boundary in
// `viewer/browser/view/view_lines_zones_lifecycle.mbt`.

///|
/// Live configuration values read by `ViewLines.onConfigurationChanged` in the
/// same order as Monaco's retained caches. `view_line_options` is the exact
/// equality-gated subset owned by each retained `ViewLine`.
pub(all) struct ViewLinesConfiguration {
  line_height : Int
  typical_halfwidth_character_width : Double
  is_viewport_wrapping : Bool
  can_use_layer_hinting : Bool
  view_line_options : ViewLineOptions
} derive(Eq, Debug)

///|
pub fn ViewLinesConfiguration::ViewLinesConfiguration(
  line_height? : Int = 20,
  typical_halfwidth_character_width? : Double = 7.2,
  is_viewport_wrapping? : Bool = false,
  can_use_layer_hinting? : Bool = true,
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
) -> ViewLinesConfiguration {
  {
    line_height,
    typical_halfwidth_character_width,
    is_viewport_wrapping,
    can_use_layer_hinting,
    view_line_options: ViewLineOptions::ViewLineOptions(
      line_height~,
      space_width~,
      middot_width~,
      wsmiddot_width~,
      use_monospace_optimizations~,
      can_use_halfwidth_rightwards_arrow~,
      stop_rendering_line_after~,
      render_whitespace~,
      render_control_characters~,
      font_ligatures~,
      vertical_scrollbar_size~,
    ),
  }
}

///|
priv struct LastRenderedData {
  mut current_visible_range : @base_common.Range
}

///|
fn LastRenderedData::LastRenderedData() -> LastRenderedData {
  { current_visible_range: Range(1, 1, 1, 1) }
}

///|
fn LastRenderedData::get_current_visible_range(
  self : LastRenderedData,
) -> @base_common.Range {
  self.current_visible_range
}

///|
fn LastRenderedData::set_current_visible_range(
  self : LastRenderedData,
  current_visible_range : @base_common.Range,
) -> Unit {
  self.current_visible_range = current_visible_range
}

///|
priv struct RunOnceScheduler {
  delay_ms : Int
  mut handle : Double?
  set_timeout : (() -> Unit, Int) -> Double
  clear_timeout : (Double) -> Unit
}

///|
fn RunOnceScheduler::RunOnceScheduler(delay_ms : Int) -> RunOnceScheduler {
  RunOnceScheduler::new_with_timer(
    delay_ms, view_lines_set_timeout, view_lines_clear_timeout,
  )
}

///|
/// A timer-capability constructor keeps the production scheduler identical to
/// `RunOnceScheduler` while making its cancel/reschedule contract observable
/// without sleeping in white-box tests.
fn RunOnceScheduler::new_with_timer(
  delay_ms : Int,
  set_timeout : (() -> Unit, Int) -> Double,
  clear_timeout : (Double) -> Unit,
) -> RunOnceScheduler {
  { delay_ms, handle: None, set_timeout, clear_timeout }
}

///|
fn RunOnceScheduler::is_scheduled(self : RunOnceScheduler) -> Bool {
  self.handle is Some(_)
}

///|
fn RunOnceScheduler::schedule(
  self : RunOnceScheduler,
  callback : () -> Unit,
) -> Unit {
  // Source `RunOnceScheduler.schedule` always cancels the previous token and
  // starts a fresh delay window.
  self.cancel()
  self.handle = Some(
    (self.set_timeout)(
      () => {
        self.handle = None
        callback()
      },
      self.delay_ms,
    ),
  )
}

///|
fn RunOnceScheduler::cancel(self : RunOnceScheduler) -> Unit {
  match self.handle {
    Some(handle) => {
      (self.clear_timeout)(handle)
      self.handle = None
    }
    None => ()
  }
}

///|
fn RunOnceScheduler::dispose(self : RunOnceScheduler) -> Unit {
  self.cancel()
}

///|
/// `pub(all)`: the closed lifecycle handle in `browser/view` reads/writes
/// `should_render` and delegates source events into the retained collection.
pub(all) struct ViewLines {
  dom_node : @scrollbar.CachedDomNode
  lines_content : @scrollbar.CachedDomNode
  /// Monaco's `_textRangeRestingSpot` (viewLines.ts ctor): the detached node
  /// `DomReadingContext.endNode` parks DOM ranges on between reads.
  text_range_resting_spot : @rdom.Element
  mut window : @view_layout.LineWindow
  mut lines : Array[ViewLine]
  mut line_height : Int
  mut typical_halfwidth_character_width : Double
  mut is_viewport_wrapping : Bool
  mut can_use_layer_hinting : Bool
  priv mut view_line_options : ViewLineOptions
  priv view_line_options_ref : Ref[ViewLineOptions]
  priv mut read_configuration : () -> ViewLinesConfiguration
  priv mut view_line_to_model_line : (Int) -> Int
  priv mut model_line_text_direction : (Int) -> @view_layout.TextDirection
  priv line_factory : () -> ViewLine
  priv async_update_line_widths : RunOnceScheduler
  priv last_rendered_data : LastRenderedData
  priv mut max_line_width : Double
  priv mut last_layout : @view_layout.ViewLayout?
  mut should_render : Bool
}

///|
fn retained_view_line_factory(options : Ref[ViewLineOptions]) -> () -> ViewLine {
  () => ViewLine::ViewLine(options=options.val)
}

///|
pub fn ViewLines::ViewLines(
  document : @rdom.Document,
  lines_content : @scrollbar.CachedDomNode,
) -> ViewLines {
  let dom_element = document.create_element("div")
  dom_element.set_attribute("class", "view-lines")
  dom_element.set_attribute("data-view-part", "view-lines")
  let initial_configuration = ViewLinesConfiguration::ViewLinesConfiguration()
  let view_line_options_ref = Ref(initial_configuration.view_line_options)
  let line_factory = retained_view_line_factory(view_line_options_ref)
  {
    dom_node: @scrollbar.CachedDomNode::new(dom_element),
    lines_content,
    text_range_resting_spot: document.create_element("div"),
    // `RenderedLinesCollection` constructs through `_set(1, [])`.
    window: { start: 1, end: 1 },
    lines: [],
    line_height: initial_configuration.line_height,
    typical_halfwidth_character_width: initial_configuration.typical_halfwidth_character_width,
    is_viewport_wrapping: initial_configuration.is_viewport_wrapping,
    can_use_layer_hinting: initial_configuration.can_use_layer_hinting,
    view_line_options: initial_configuration.view_line_options,
    view_line_options_ref,
    read_configuration: () => initial_configuration,
    view_line_to_model_line: line_number => line_number,
    model_line_text_direction: _line_number => LTR,
    line_factory,
    async_update_line_widths: RunOnceScheduler::RunOnceScheduler(200),
    last_rendered_data: LastRenderedData::LastRenderedData(),
    max_line_width: 0.0,
    last_layout: None,
    should_render: true,
  }
}

///|
/// Installs the two model capabilities used by Monaco's
/// `linesVisibleRangesForRange`: view-position conversion at column 1 and
/// model-line text direction. Keeping these readers on ViewLines preserves
/// the source's converter progression without introducing a package cycle.
pub fn ViewLines::install_geometry_readers(
  self : ViewLines,
  view_line_to_model_line : (Int) -> Int,
  model_line_text_direction : (Int) -> @view_layout.TextDirection,
) -> Unit {
  self.view_line_to_model_line = view_line_to_model_line
  self.model_line_text_direction = model_line_text_direction
}

///|
/// Installs the model-scoped live `ViewContext.configuration` reader. A fresh
/// View calls this before adding or rendering rows, so the constructor snapshot
/// and the source-owned line factory both begin with current values.
pub fn ViewLines::install_live_configuration_reader(
  self : ViewLines,
  read_configuration : () -> ViewLinesConfiguration,
) -> Unit {
  self.read_configuration = read_configuration
  self.seed_configuration((self.read_configuration)())
}

///|
fn ViewLines::seed_configuration(
  self : ViewLines,
  configuration : ViewLinesConfiguration,
) -> Unit {
  self.line_height = configuration.line_height
  self.typical_halfwidth_character_width = configuration.typical_halfwidth_character_width
  self.is_viewport_wrapping = configuration.is_viewport_wrapping
  self.can_use_layer_hinting = configuration.can_use_layer_hinting
  self.view_line_options = configuration.view_line_options
  self.view_line_options_ref.val = configuration.view_line_options
  match self.last_layout {
    Some(layout) =>
      ignore(layout.set_is_viewport_wrapping(self.is_viewport_wrapping))
    None => ()
  }
}

///|
/// `ViewLines.onConfigurationChanged`'s cache reread followed by
/// `_onOptionsMaybeChanged`. The caller preserves the outer source order by
/// invoking the nested visible-collection handler before this method.
pub fn ViewLines::on_configuration_changed(
  self : ViewLines,
  wrapping_info_changed : Bool,
  layout_info_changed : Bool,
) -> Bool {
  if wrapping_info_changed {
    self.max_line_width = 0.0
  }
  let configuration = (self.read_configuration)()
  let wrapping_value_changed = self.is_viewport_wrapping !=
    configuration.is_viewport_wrapping
  self.line_height = configuration.line_height
  self.typical_halfwidth_character_width = configuration.typical_halfwidth_character_width
  self.is_viewport_wrapping = configuration.is_viewport_wrapping
  self.can_use_layer_hinting = configuration.can_use_layer_hinting
  if wrapping_value_changed {
    match self.last_layout {
      Some(layout) =>
        ignore(layout.set_is_viewport_wrapping(self.is_viewport_wrapping))
      None => ()
    }
  }
  self.on_options_maybe_changed(configuration.view_line_options) |> ignore
  if layout_info_changed {
    self.max_line_width = 0.0
  }
  // Source `ViewLines.onConfigurationChanged` always invalidates after the
  // nested layout handler and ordered configuration rereads.
  true
}

///|
fn ViewLines::on_options_maybe_changed(
  self : ViewLines,
  new_options : ViewLineOptions,
) -> Bool {
  if self.view_line_options.equals(new_options) {
    return false
  }
  self.view_line_options = new_options
  self.view_line_options_ref.val = new_options
  for line in self.lines {
    line.on_options_changed(new_options)
  }
  true
}

///|
pub fn ViewLines::get_dom_node(self : ViewLines) -> @rdom.Element {
  self.dom_node.element()
}

///|
/// Index of a one-based view-line number within the currently rendered
/// window, or `-1` when the line is outside the window.
fn ViewLines::window_index(self : ViewLines, view_line_number : Int) -> Int {
  let index = view_line_number - self.window.start
  if index >= 0 && index < self.lines.length() {
    index
  } else {
    -1
  }
}

///|
/// The retained column-to-DOM `CharacterMapping` for a one-based view-line
/// number, if in window.
pub fn ViewLines::mapping_at(
  self : ViewLines,
  view_line_number : Int,
) -> @view_layout.CharacterMapping? {
  let index = self.window_index(view_line_number)
  if index < 0 {
    None
  } else {
    self.lines[index].mapping()
  }
}

///|
/// The rendered line node for a one-based view-line number, if in window. Used
/// by selection measurement to read DOM client rects off the live line DOM.
pub fn ViewLines::line_node_at(
  self : ViewLines,
  view_line_number : Int,
) -> @rdom.Element? {
  let index = self.window_index(view_line_number)
  if index < 0 {
    None
  } else {
    self.lines[index].get_dom_node()
  }
}

///|
/// `RenderedLinesCollection.flush` (`viewLayer.ts:53-55`): the empty
/// collection retains the source's one-based start. Ordinary CPU rendering
/// deliberately leaves old DOM in place until the next no-overlap batch
/// replaces `innerHTML`; only the source's excluded GPU arm removes on flush.
pub fn ViewLines::flush_retained_lines(self : ViewLines) -> Unit {
  self.lines = []
  self.window = { start: 1, end: 1 }
  self.max_line_width = 0.0
}

///|
/// `VisibleLinesCollection.onConfigurationChanged` (`viewLayer.ts:277-282`).
/// Layout-info changes dirty visible layout but never flush retained rows.
pub fn ViewLines::on_visible_configuration_changed(
  _self : ViewLines,
  layout_info_changed : Bool,
) -> Bool {
  if layout_info_changed {
    return true
  }
  false
}

///|
/// `VisibleLinesCollection.onScrollChanged` (`viewLayer.ts:331-333`). The
/// nested collection reacts to vertical position only; outer ViewLines adds
/// its independent horizontal branch.
pub fn ViewLines::on_visible_scroll_changed(
  _self : ViewLines,
  scroll_top_changed : Bool,
) -> Bool {
  scroll_top_changed
}

///|
/// `VisibleLinesCollection.onZonesChanged` (`viewLayer.ts:339-341`).
pub fn ViewLines::on_visible_zones_changed(self : ViewLines) -> Bool {
  match self.last_layout {
    Some(layout) => ignore(layout.set_max_line_width(self.max_line_width))
    None => ()
  }
  true
}

///|
/// `RenderedLinesCollection.onLinesChanged` (`viewLayer.ts:156-177`). Notify
/// every retained line in the inclusive changed interval, and report whether
/// at least one line was notified.
pub fn ViewLines::on_lines_changed(
  self : ViewLines,
  change_from_line_number : Int,
  change_count : Int,
) -> Bool {
  let change_to_line_number = change_from_line_number + change_count - 1
  if self.lines.length() == 0 {
    return false
  }
  let start_line_number = self.window.start
  let end_line_number = self.window.start + self.lines.length() - 1
  let mut someone_notified = false
  for changed_line_number in change_from_line_number..<=change_to_line_number {
    if changed_line_number >= start_line_number &&
      changed_line_number <= end_line_number {
      self.lines[changed_line_number - self.window.start].on_content_changed()
      someone_notified = true
    }
  }
  someone_notified
}

///|
/// `RenderedLinesCollection.onLinesDeleted` (`viewLayer.ts:98-154`) plus
/// `VisibleLinesCollection.onLinesDeleted`'s ordered optional-DOM removal
/// (`:305-316`). Control flow and inclusive bounds match the pinned source.
pub fn ViewLines::on_lines_deleted(
  self : ViewLines,
  delete_from_line_number : Int,
  delete_to_line_number : Int,
) -> Unit {
  if self.lines.length() == 0 {
    return
  }
  let start_line_number = self.window.start
  let end_line_number = self.window.start + self.lines.length() - 1
  if delete_to_line_number < start_line_number {
    let delete_count = delete_to_line_number - delete_from_line_number + 1
    self.set_retained_start(start_line_number - delete_count)
    return
  }
  if delete_from_line_number > end_line_number {
    return
  }
  let mut delete_start_index = 0
  let mut delete_count = 0
  for line_number in start_line_number..<=end_line_number {
    let line_index = line_number - self.window.start
    if delete_from_line_number <= line_number &&
      line_number <= delete_to_line_number {
      if delete_count == 0 {
        delete_start_index = line_index
        delete_count = 1
      } else {
        delete_count += 1
      }
    }
  }
  if delete_from_line_number < start_line_number {
    let delete_above_count = if delete_to_line_number < start_line_number {
      // Source-unreachable after the disjoint-above early return, retained to
      // keep the pinned branch shape literal.
      delete_to_line_number - delete_from_line_number + 1
    } else {
      start_line_number - delete_from_line_number
    }
    self.set_retained_start(self.window.start - delete_above_count)
  }
  let deleted = self.remove_retained_slice(delete_start_index, delete_count)
  remove_retained_line_dom_nodes(deleted)
  self.sync_retained_end()
}

///|
/// `RenderedLinesCollection.onLinesInserted` (`viewLayer.ts:179-219`) plus
/// `VisibleLinesCollection.onLinesInserted`'s ordered removal of displaced
/// tail DOM (`:318-329`).
pub fn ViewLines::on_lines_inserted(
  self : ViewLines,
  insert_from_line_number : Int,
  insert_to_line_number : Int,
) -> Unit {
  if self.lines.length() == 0 {
    return
  }
  let insert_count = insert_to_line_number - insert_from_line_number + 1
  let start_line_number = self.window.start
  let end_line_number = self.window.start + self.lines.length() - 1
  if insert_from_line_number <= start_line_number {
    self.set_retained_start(start_line_number + insert_count)
    return
  }
  if insert_from_line_number > end_line_number {
    return
  }
  if insert_count + insert_from_line_number > end_line_number {
    let deleted = self.remove_retained_slice(
      insert_from_line_number - self.window.start,
      end_line_number - insert_from_line_number + 1,
    )
    remove_retained_line_dom_nodes(deleted)
    self.sync_retained_end()
    return
  }
  let insert_index = insert_from_line_number - self.window.start
  let original_length = self.lines.length()
  let new_lines : Array[ViewLine] = []
  for index in 0..<insert_index {
    new_lines.push(self.lines[index])
  }
  for _ in 0..<insert_count {
    new_lines.push((self.line_factory)())
  }
  for index in insert_index..<(original_length - insert_count) {
    new_lines.push(self.lines[index])
  }
  let deleted_lines : Array[ViewLine] = []
  for index in (original_length - insert_count)..<original_length {
    deleted_lines.push(self.lines[index])
  }
  self.lines = new_lines
  remove_retained_line_dom_nodes(deleted_lines)
  self.sync_retained_end()
}

///|
/// `RenderedLinesCollection.onTokensChanged` (`viewLayer.ts:221-250`). Local
/// callers convert the source's inclusive token payloads to one-based
/// half-open `LineRange`s, then this method clips and notifies line by line.
pub fn ViewLines::on_token_ranges_changed(
  self : ViewLines,
  ranges : Array[@base_common.LineRange],
) -> Bool {
  if self.lines.length() == 0 {
    return false
  }
  let start_line_number = self.window.start
  let end_line_number = self.window.start + self.lines.length() - 1
  let mut notified_someone = false
  for range in ranges {
    let range_to_line_number = range.end_line_number_exclusive - 1
    if range_to_line_number < start_line_number ||
      range.start_line_number > end_line_number {
      continue
    }
    let from_line_number = start_line_number.max(range.start_line_number)
    let to_line_number = end_line_number.min(range_to_line_number)
    for line_number in from_line_number..<=to_line_number {
      self.lines[line_number - self.window.start].on_tokens_changed()
      notified_someone = true
    }
  }
  notified_someone
}

///|
/// `ViewLines.onCursorStateChanged` (`viewLines.ts:238-246`). Preserve the
/// source's right-to-left sticky OR: every retained line is visited even after
/// one returns true.
pub fn ViewLines::on_selection_changed(self : ViewLines) -> Bool {
  let mut should_render = false
  for line in self.lines {
    should_render = line.on_selection_changed() || should_render
  }
  should_render
}

///|
/// `ViewLines.onDecorationsChanged` (`viewLines.ts:247-254`).
pub fn ViewLines::on_decorations_changed(self : ViewLines) -> Unit {
  for line in self.lines {
    line.on_decorations_changed()
  }
}

///|
fn ViewLines::set_retained_start(self : ViewLines, start : Int) -> Unit {
  self.window = { start, end: start + self.lines.length() }
}

///|
fn ViewLines::sync_retained_end(self : ViewLines) -> Unit {
  self.window = {
    start: self.window.start,
    end: self.window.start + self.lines.length(),
  }
}

///|
fn ViewLines::remove_retained_slice(
  self : ViewLines,
  start : Int,
  count : Int,
) -> Array[ViewLine] {
  let removed : Array[ViewLine] = []
  for _ in 0..<count {
    removed.push(self.lines.remove(start))
  }
  removed
}

///|
fn remove_retained_line_dom_nodes(lines : Array[ViewLine]) -> Unit {
  for line in lines {
    match line.get_dom_node() {
      Some(node) => remove_retained_line_dom_node(node)
      None => ()
    }
  }
}

///|
extern "js" fn remove_retained_line_dom_node(node : @rdom.Element) -> Unit =
  #| (node) => {
  #|   if (typeof node.remove === "function") node.remove();
  #|   else if (node.parentNode) node.parentNode.removeChild(node);
  #| }

///|
/// Monaco `ViewLines.renderText` (`viewLines.ts:613-677`): reconcile the
/// retained rows through the shared `ViewLayerRenderer`, size the row layer,
/// then move the single lines-content rail for both axes.
pub fn ViewLines::render_text(
  self : ViewLines,
  viewport : @view_layout.ViewportData,
  layout : @view_layout.ViewLayout,
  selection_view_range : @base_common.Range?,
) -> Unit {
  self.last_layout = Some(layout)
  ignore(layout.set_is_viewport_wrapping(self.is_viewport_wrapping))
  let target = viewport_window(viewport)
  let renderer = ViewLayerRenderer::ViewLayerRenderer(
    self.dom_node.element(),
    self.line_factory,
    line => line.get_dom_node(),
    (line, node) => line.set_dom_node(node),
    (line, line_number, delta_top, line_height) => {
      line.layout_line(line_number, delta_top, line_height)
    },
    (line, line_number, delta_top, line_height, viewport, builder) => {
      let index = line_number - viewport.start_line_number
      let input = render_line_input_for_viewport(
        viewport,
        index,
        line.option_snapshot(),
        selection_view_range~,
      )
      line.render_line(line_number, input, delta_top, line_height, builder)
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
  self.window = target
  self.last_rendered_data.set_current_visible_range(viewport.visible_range)
  let dimensions = layout.dimensions()
  self.dom_node.set_width(Pixels(dimensions.scroll_width))
  self.dom_node.set_height(Pixels(dimensions.scroll_height.min(1000000.0)))
  if !self.update_line_widths_fast() {
    self.async_update_line_widths.schedule(() => self.update_line_widths_slow())
  } else {
    self.async_update_line_widths.cancel()
  }
  self.lines_content.set_layer_hinting(self.can_use_layer_hinting)
  self.lines_content.set_contain("strict")
  let position = layout.position()
  let adjusted_scroll_top = position.scroll_top -
    viewport.big_numbers_delta.to_double()
  self.lines_content.set_top(Pixels(-adjusted_scroll_top))
  self.lines_content.set_left(Pixels(-position.scroll_left))
}

///|
/// `pub`: called cross-package by `browser/view`'s `ViewOverlays` row
/// recycler, which windows its rows the same way `ViewLines::render_text`
/// windows text lines.
pub fn viewport_window(
  viewport : @view_layout.ViewportData,
) -> @view_layout.LineWindow {
  // ViewportData is a 1-based inclusive range `[start, end]`; the render window
  // is the equivalent 1-based half-open `[start, end + 1)`.
  { start: viewport.start_line_number, end: viewport.end_line_number + 1 }
}

///|
/// `pub`: also called directly by `render_whitespace_options_test.mbt`'s
/// (root `viewer` package) integration test proving `ViewerOptions` flow into
/// the per-line render input, the same wiring `flush_render` performs.
pub fn render_line_input_for_viewport(
  viewport : @view_layout.ViewportData,
  index : Int,
  options : ViewLineOptions,
  selection_view_range~ : @base_common.Range?,
) -> @view_layout.RenderLineInput {
  let line_number = viewport.start_line_number + index
  let line_data = viewport.lines[index]
  @view_layout.RenderLineInput::from_view_line(
    line_data,
    line_decorations=viewport.decorations_for_line(line_number),
    use_monospace_optimizations=options.use_monospace_optimizations,
    can_use_halfwidth_rightwards_arrow=options.can_use_halfwidth_rightwards_arrow,
    space_width=options.space_width,
    middot_width=options.middot_width,
    wsmiddot_width=options.wsmiddot_width,
    stop_rendering_line_after=options.stop_rendering_line_after,
    render_whitespace=options.render_whitespace,
    render_control_characters=options.render_control_characters,
    font_ligatures=options.font_ligatures,
    selections_on_line=selections_on_line_for(
      line_number,
      line_data,
      options.render_whitespace,
      selection_view_range,
    ),
    vertical_scrollbar_size=options.vertical_scrollbar_size,
  )
}

///|
/// Per-line selected-column offsets for `RenderWhitespace::Selection`, the port
/// of `viewLine.ts:122-149`. The whitespace renderer only paints dots inside a
/// selection in this mode, so it needs the columns the selection covers on this
/// line. Empty in every other mode and when the selection misses the line.
///
/// Deviations from the source: the high-contrast `inline-selected-text` push
/// (`viewLine.ts:137-139`) is dropped — the viewer has no high-contrast theme,
/// so the gather condition reduces to `render_whitespace == Selection`; and the
/// viewer carries a single `selection_view_range`, not Monaco's `selections`
/// array, so the loop is over zero-or-one selection.
fn selections_on_line_for(
  line_number : Int,
  line_data : @view_layout.ViewLineRenderingData,
  render_whitespace : @view_layout.RenderWhitespace,
  selection_view_range : @base_common.Range?,
) -> Array[@base_common.OffsetRange] {
  let result : Array[@base_common.OffsetRange] = []
  guard render_whitespace == Selection else { return result }
  guard selection_view_range is Some(selection) else { return result }
  // Selection does not intersect this line.
  if selection.end_line_number < line_number ||
    selection.start_line_number > line_number {
    return result
  }
  // On a non-anchor line the selection spans the line's full column extent;
  // only the anchor lines clip to the selection's own start/end column.
  let start_column = if selection.start_line_number == line_number {
    selection.start_column
  } else {
    line_data.min_column
  }
  let end_column = if selection.end_line_number == line_number {
    selection.end_column
  } else {
    line_data.max_column
  }
  if start_column < end_column {
    result.push(OffsetRange(start_column - 1, end_column - 1))
  }
  result
}

///|
/// `getPositionFromDOMInfo` (viewLines.ts:337-372): resolves a browser caret
/// answer (token span node + character offset) to a view `Position`, walking
/// the span up to its `.view-line` node, scanning the rendered window for the
/// line number, and mapping the span/offset through the line's
/// `CharacterMapping`. `view_model` is passed per call — this recycler has no
/// `ViewContext` (the port's standing deviation).
pub fn ViewLines::get_position_from_dom_info(
  self : ViewLines,
  view_model : @view_model.ViewModel,
  span_node : @rdom.Element,
  offset : Int,
) -> @base_common.Position? {
  guard get_view_line_dom_node(span_node) is Some(view_line_dom_node) else {
    // Couldn't find view line node
    return None
  }
  let line_number = self.get_line_number_for(view_line_dom_node)
  if line_number == -1 {
    // Couldn't find view line node
    return None
  }
  if line_number < 1 || line_number > view_model.line_count() {
    // lineNumber is outside range
    return None
  }
  if view_model.get_line_max_column(line_number) == 1 {
    // Line is empty
    return Some(Position(line_number, 1))
  }
  guard self.mapping_at(line_number) is Some(mapping) else {
    // Couldn't find line
    return None
  }
  let mut column = get_column_of_node_offset(mapping, span_node, offset)
  let min_column = view_model.get_line_min_column(line_number)
  if column < min_column {
    column = min_column
  }
  Some(Position(line_number, column))
}

///|
/// `_getViewLineDomNode` (viewLines.ts:375-384): the enclosing `.view-line`
/// node of a DOM node, or `None`.
fn get_view_line_dom_node(node : @rdom.Element) -> @rdom.Element? {
  for current = Some(node)
      current is Some(el)
      current = view_lines_parent_element(el) {
    if element_class_name(el) == VIEW_LINE_CLASS_NAME {
      return Some(el)
    }
  } nobreak {
    None
  }
}

///|
/// `_getLineNumberFor` (viewLines.ts:388-398): the view-line number of a
/// rendered `.view-line` node, by scanning the window; `-1` when not found.
fn ViewLines::get_line_number_for(
  self : ViewLines,
  dom_node : @rdom.Element,
) -> Int {
  for index, line in self.lines {
    if line.get_dom_node().map(node => node.is_same_node(dom_node.as_node())) ==
      Some(true) {
      return self.window.start + index
    }
  }
  -1
}

///|
/// `getLineWidth` (viewLines.ts:400-413): the rendered width of a view line
/// in pixels, `-1` when the line is outside the rendered window. The read
/// includes CSS-generated content because it is the reading target's
/// `offsetWidth`.
pub fn ViewLines::get_line_width(self : ViewLines, line_number : Int) -> Double {
  let index = self.window_index(line_number)
  if index < 0 {
    // Couldn't find line
    return -1.0
  }
  let context = DomReadingContext::DomReadingContext(
    self.dom_node.element(),
    self.text_range_resting_spot,
  )
  let result = self.lines[index].get_width(Some(context))
  self.update_line_widths_slow_if_dom_did_layout(context)
  result
}

///|
pub fn ViewLines::reset_line_width_caches(self : ViewLines) -> Unit {
  for line in self.lines {
    line.reset_cached_width()
  }
}

///|
/// Raw, unrounded visible ranges for one rendered view line.
pub fn ViewLines::visible_ranges_for_line_range(
  self : ViewLines,
  line_number : Int,
  start_column : Int,
  end_column : Int,
) -> (Bool, Array[(Double, Double)])? {
  let index = self.window_index(line_number)
  if index < 0 {
    return None
  }
  let context = DomReadingContext::DomReadingContext(
    self.dom_node.element(),
    self.text_range_resting_spot,
  )
  let result = self.lines[index].get_visible_ranges_for_range(
    line_number, start_column, end_column, context,
  )
  self.update_line_widths_slow_if_dom_did_layout(context)
  result
}

///|
/// Source `linesVisibleRangesForRange` boundary using raw tuples to avoid a
/// package cycle with `browser/view`'s RenderingContext carriers. Horizontal
/// values are rounded independently only at this source boundary.
pub fn ViewLines::raw_lines_visible_ranges_for_range(
  self : ViewLines,
  requested_range : @base_common.Range,
  include_new_lines : Bool,
) -> Array[(Bool, Int, Array[(Int, Int)], Bool)]? {
  let original_end_line_number = requested_range.end_line_number
  guard requested_range.intersect_ranges(
      self.last_rendered_data.get_current_visible_range(),
    )
    is Some(visible_range) else {
    return None
  }
  let result : Array[(Bool, Int, Array[(Int, Int)], Bool)] = []
  let context = DomReadingContext::DomReadingContext(
    self.dom_node.element(),
    self.text_range_resting_spot,
  )
  let mut next_line_model_line_number = 0
  if include_new_lines {
    next_line_model_line_number = (self.view_line_to_model_line)(
      visible_range.start_line_number,
    )
  }
  for
    line_number in visible_range.start_line_number..<=visible_range.end_line_number {
    let index = self.window_index(line_number)
    if index < 0 {
      continue
    }
    let start_column = if line_number == visible_range.start_line_number {
      visible_range.start_column
    } else {
      1
    }
    let continues_on_next_line = line_number != original_end_line_number
    guard self.lines[index].render_input() is Some(render_input) else {
      continue
    }
    let end_column = if continues_on_next_line {
      render_input.line_content.length() + 1
    } else {
      visible_range.end_column
    }
    guard self.lines[index].get_visible_ranges_for_range(
        line_number, start_column, end_column, context,
      )
      is Some((outside_rendered_line, float_ranges)) else {
      continue
    }
    if include_new_lines && line_number < original_end_line_number {
      let current_line_model_line_number = next_line_model_line_number
      next_line_model_line_number = (self.view_line_to_model_line)(
        line_number + 1,
      )
      if current_line_model_line_number != next_line_model_line_number {
        let last_index = float_ranges.length() - 1
        let (left, width) = float_ranges[last_index]
        let width = width + self.typical_halfwidth_character_width
        float_ranges[last_index] = if (self.model_line_text_direction)(
            current_line_model_line_number,
          ) ==
          RTL {
          (left - self.typical_halfwidth_character_width, width)
        } else {
          (left, width)
        }
      }
    }
    let rounded_ranges : Array[(Int, Int)] = []
    for range in float_ranges {
      rounded_ranges.push(
        (
          view_lines_js_math_round_to_int(range.0),
          view_lines_js_math_round_to_int(range.1),
        ),
      )
    }
    result.push(
      (
        outside_rendered_line, line_number, rounded_ranges, continues_on_next_line,
      ),
    )
  }
  self.update_line_widths_slow_if_dom_did_layout(context)
  if result.is_empty() {
    return None
  }
  Some(result)
}

///|
pub fn ViewLines::raw_visible_range_for_position(
  self : ViewLines,
  line_number : Int,
  column : Int,
) -> (Bool, Double)? {
  guard self.visible_ranges_for_line_range(line_number, column, column)
    is Some((outside_rendered_line, ranges)) &&
    !ranges.is_empty() else {
    return None
  }
  Some((outside_rendered_line, ranges[0].0))
}

///|
pub fn ViewLines::update_line_widths(self : ViewLines) -> Unit {
  ignore(self.update_line_widths_internal(false))
}

///|
fn ViewLines::update_line_widths_fast(self : ViewLines) -> Bool {
  self.update_line_widths_internal(true)
}

///|
fn ViewLines::update_line_widths_slow(self : ViewLines) -> Unit {
  ignore(self.update_line_widths_internal(false))
}

///|
fn ViewLines::update_line_widths_slow_if_dom_did_layout(
  self : ViewLines,
  context : DomReadingContext,
) -> Unit {
  if !context.did_dom_layout() {
    return
  }
  if !self.async_update_line_widths.is_scheduled() {
    return
  }
  self.async_update_line_widths.cancel()
  self.update_line_widths_slow()
}

///|
fn ViewLines::update_line_widths_internal(
  self : ViewLines,
  fast : Bool,
) -> Bool {
  let mut local_max_line_width = 1.0
  let mut all_widths_computed = true
  for line in self.lines {
    if fast && !line.get_width_is_fast() {
      all_widths_computed = false
      continue
    }
    local_max_line_width = local_max_line_width.max(line.get_width(None))
  }
  match self.last_layout {
    Some(layout) =>
      if all_widths_computed &&
        self.window.start == 1 &&
        self.window.end == layout.line_count() + 1 {
        self.max_line_width = 0.0
      }
    None => ()
  }
  self.ensure_max_line_width(local_max_line_width)
  all_widths_computed
}

///|
fn ViewLines::ensure_max_line_width(
  self : ViewLines,
  line_width : Double,
) -> Unit {
  let integer_line_width = line_width.ceil()
  if self.max_line_width < integer_line_width {
    self.max_line_width = integer_line_width
    match self.last_layout {
      Some(layout) => ignore(layout.set_max_line_width(self.max_line_width))
      None => ()
    }
  }
}

///|
pub fn ViewLines::dispose(self : ViewLines) -> Unit {
  self.async_update_line_widths.dispose()
}

///|
/// FFI gap-fills for the `.view-line` ancestor walk (element-typed
/// `parentElement` / `className` are not bound in the vendored `@rdom`).
extern "js" fn element_class_name(el : @rdom.Element) -> String =
  #| (el) => el.className || ""

///|
extern "js" fn view_lines_parent_element_raw(
  el : @rdom.Element,
) -> @rdom.Element =
  #| (el) => el.parentElement

///|
extern "js" fn has_parent_element(el : @rdom.Element) -> Bool =
  #| (el) => el.parentElement !== null && el.parentElement.nodeType === 1

///|
fn view_lines_parent_element(el : @rdom.Element) -> @rdom.Element? {
  if has_parent_element(el) {
    Some(view_lines_parent_element_raw(el))
  } else {
    None
  }
}

///|
extern "js" fn view_lines_set_timeout(
  callback : () -> Unit,
  delay_ms : Int,
) -> Double = "(callback, delayMs) => globalThis.setTimeout(callback, delayMs)"

///|
extern "js" fn view_lines_clear_timeout(handle : Double) -> Unit = "(handle) => globalThis.clearTimeout(handle)"

///|
/// JavaScript `Math.round` for finite DOM geometry. In particular, negative
/// half values round toward positive infinity (`Math.round(-7.5) === -7`),
/// unlike the usual ties-away-from-zero rule on some MoonBit backends.
fn view_lines_js_math_round_to_int(value : Double) -> Int {
  (value + 0.5).floor().to_int()
}
