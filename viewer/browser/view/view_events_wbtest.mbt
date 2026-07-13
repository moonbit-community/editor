///|
fn view_event_test_name(event : ViewEvent) -> String {
  match event {
    ViewCompositionStart => "composition-start"
    ViewCompositionEnd => "composition-end"
    ViewConfigurationChanged(_) => "configuration"
    ViewCursorStateChanged(_) => "cursor"
    ViewDecorationsChanged(_) => "decorations"
    ViewFlushed => "flushed"
    ViewFocusChanged(_) => "focus"
    ViewLineMappingChanged => "line-mapping"
    ViewLinesChanged(_) => "lines-changed"
    ViewLinesDeleted(_) => "lines-deleted"
    ViewLinesInserted(_) => "lines-inserted"
    ViewScrollChanged(_) => "scroll"
    ViewThemeChanged(_) => "theme"
    ViewTokensChanged(_) => "tokens"
    ViewZonesChanged => "zones"
  }
}

///|
fn view_event_test_batch_name(events : Array[ViewEvent]) -> String {
  let result = StringBuilder()
  for index, event in events {
    if index > 0 {
      result.write_char('|')
    }
    result.write_string(view_event_test_name(event))
  }
  result.to_string()
}

///|
test "source-shaped payloads retain independent fields and array identity" {
  let configuration = ViewConfigurationChangedEvent::from_changed_options([
    LayoutInfo,
    FontInfo,
    LayoutInfo,
  ])
  assert_eq(configuration.changed_options.length(), 2)
  assert_true(configuration.has_changed(LayoutInfo))
  assert_true(configuration.has_changed(FontInfo))
  assert_false(configuration.has_changed(RenderWhitespace))

  let decorations = ViewDecorationsChangedEvent::all()
  assert_true(decorations.affects_minimap)
  assert_true(decorations.affects_overview_ruler)
  assert_true(decorations.affects_glyph_margin)
  assert_true(decorations.affects_line_number)

  let scroll = ViewScrollChangedEvent::new(
    700.0, 11.0, 900.0, 23.0, true, false, false, true,
  )
  assert_true(scroll.scroll_width == 700.0)
  assert_true(scroll.scroll_left == 11.0)
  assert_true(scroll.scroll_height == 900.0)
  assert_true(scroll.scroll_top == 23.0)
  assert_true(scroll.scroll_width_changed)
  assert_false(scroll.scroll_left_changed)
  assert_false(scroll.scroll_height_changed)
  assert_true(scroll.scroll_top_changed)

  let ranges = [ViewTokenChangeRange::new(4, 6)]
  let tokens = ViewTokensChangedEvent::new(ranges)
  ranges.push(ViewTokenChangeRange::new(9, 10))
  assert_eq(tokens.ranges.length(), 2)
  assert_eq(tokens.ranges[0].from_line_number, 4)
  assert_eq(tokens.ranges[0].to_line_number, 6)

  let selection = @core.Selection::new(Position(1, 1), Position(1, 1))
  let selections = [selection]
  let model_selections = [selection]
  let cursor = ViewCursorStateChangedEvent::new(
    selections,
    model_selections,
    NotSet,
  )
  selections.push(@core.Selection::new(Position(2, 1), Position(2, 1)))
  model_selections.clear()
  assert_eq(cursor.selections.length(), 2)
  assert_eq(cursor.model_selections.length(), 0)
}

///|
test "dispatcher gives every handler a whole batch before reentrant FIFO batch" {
  let deliveries : Array[String] = []
  let holder : Ref[ViewEventDispatcher?] = { val: None }
  let did_reenter = Ref(false)
  let dispatcher = ViewEventDispatcher::new(events => {
    let batch = view_event_test_batch_name(events)
    deliveries.push("h1:" + batch)
    if !did_reenter.val {
      did_reenter.val = true
      match holder.val {
        Some(dispatcher) =>
          dispatcher.emit_view_events([
            ViewCompositionEnd,
            ViewLineMappingChanged,
          ])
        None => abort("dispatcher test holder missing")
      }
    }
    deliveries.push("h2:" + batch)
  })
  holder.val = Some(dispatcher)
  dispatcher.emit_view_events([ViewFlushed, ViewZonesChanged])
  assert_eq(deliveries.length(), 4)
  assert_eq(deliveries[0], "h1:flushed|zones")
  assert_eq(deliveries[1], "h2:flushed|zones")
  assert_eq(deliveries[2], "h1:composition-end|line-mapping")
  assert_eq(deliveries[3], "h2:composition-end|line-mapping")
  assert_false(dispatcher.consuming)
  assert_true(dispatcher.pending_view_events is None)
}

///|
test "ViewZones outgoing continuation waits for reentrant internal delivery" {
  let deliveries : Array[String] = []
  let holder : Ref[ViewEventDispatcher?] = { val: None }
  let dispatcher = ViewEventDispatcher::new(events => {
    let batch = view_event_test_batch_name(events)
    deliveries.push("h1:" + batch)
    if batch == "line-mapping" {
      match holder.val {
        Some(dispatcher) =>
          dispatcher.emit_view_event_then(ViewZonesChanged, () => {
            deliveries.push("outgoing")
          })
        None => abort("dispatcher test holder missing")
      }
    }
    deliveries.push("h2:" + batch)
  })
  holder.val = Some(dispatcher)
  dispatcher.emit_view_event(ViewLineMappingChanged)
  assert_true(
    deliveries ==
    ["h1:line-mapping", "h2:line-mapping", "h1:zones", "h2:zones", "outgoing"],
  )
  assert_eq(dispatcher.after_view_events.length(), 0)
  assert_false(dispatcher.consuming)
}

///|
test "nested begin shares one collector and only outer end flushes" {
  let deliveries : Array[String] = []
  let dispatcher = ViewEventDispatcher::new(events => {
    deliveries.push(view_event_test_batch_name(events))
  })
  let outer = dispatcher.begin()
  outer.emit(ViewCompositionStart)
  let inner = dispatcher.begin()
  inner.emit(ViewCompositionEnd)
  dispatcher.end()
  assert_eq(deliveries.length(), 0)
  outer.emit(ViewZonesChanged)
  dispatcher.end()
  assert_eq(deliveries.length(), 1)
  assert_eq(deliveries[0], "composition-start|composition-end|zones")
  assert_eq(dispatcher.collector_depth, 0)
  assert_true(dispatcher.collector is None)
}

///|
test "hidden-area batch delivers mapping events before recovery scroll" {
  let deliveries : Array[String] = []
  let dispatcher = ViewEventDispatcher::new(events => {
    deliveries.push(view_event_test_batch_name(events))
  })
  let collector = dispatcher.begin()
  collector.emit(ViewFlushed)
  collector.emit(ViewLineMappingChanged)
  collector.emit(ViewDecorationsChanged(ViewDecorationsChangedEvent::all()))
  // The layout's synchronous recovery listener enters through the ordinary
  // dispatcher API while the ViewModel-owned outer collector is still open.
  dispatcher.emit_view_event(
    ViewScrollChanged(
      ViewScrollChangedEvent::new(
        400.0, 0.0, 1000.0, 25.0, false, false, false, true,
      ),
    ),
  )
  assert_eq(deliveries.length(), 0)
  dispatcher.end()
  assert_true(deliveries == ["flushed|line-mapping|decorations|scroll"])
}

///|
fn view_part_handle_test_name(part : ViewPartHandle) -> String {
  match part {
    ViewLinesPart(_) => "view-lines"
    ViewZonesPart(_) => "view-zones"
    ContentViewOverlaysPart(_) => "content-overlays"
    MarginViewOverlaysPart(_) => "margin-overlays"
    ContentWidgetsPart(_) => "content-widgets"
    ViewCursorsPart(_) => "view-cursors"
    OverlayWidgetsPart(_) => "overlay-widgets"
    EditorScrollbarPart(_) => "editor-scrollbar"
  }
}

///|
test "View dispatcher retains eight handlers in source order and gives each the full batch" {
  install_view_lifecycle_test_browser()
  let view = View::new()
  let names = view.view_parts.map(view_part_handle_test_name)
  assert_true(
    names ==
    [
      "view-lines", "view-zones", "content-overlays", "margin-overlays", "content-widgets",
      "view-cursors", "overlay-widgets", "editor-scrollbar",
    ],
  )
  for part in view.view_parts {
    part.on_did_render()
    assert_false(part.should_render())
  }
  view.emit_view_events([
    ViewFocusChanged(ViewFocusChangedEvent::new(true)),
    ViewConfigurationChanged(
      ViewConfigurationChangedEvent::from_changed_options([]),
    ),
  ])
  for part in view.view_parts {
    assert_true(part.should_render())
  }
  // The first event is not lost after a later event dirties every handler.
  assert_true(view.view_cursors.editor_has_focus)
  view.dispose()
  restore_view_lifecycle_test_browser()
}

///|
priv struct CountingViewPart {
  mut dirty : Bool
  mut force_count : Int
  seen : Array[String]
}

///|
impl ViewPart for CountingViewPart with fn on_view_event(self, event) {
  self.seen.push(view_event_test_name(event))
  match event {
    ViewFlushed | ViewZonesChanged => true
    _ => false
  }
}

///|
impl ViewPart for CountingViewPart with fn should_render(self) {
  self.dirty
}

///|
impl ViewPart for CountingViewPart with fn force_should_render(self) {
  self.dirty = true
  self.force_count = self.force_count + 1
}

///|
impl ViewPart for CountingViewPart with fn prepare_render(_self, _context) {

}

///|
impl ViewPart for CountingViewPart with fn render(_self, _context) {

}

///|
impl ViewPart for CountingViewPart with fn on_did_render(self) {
  self.dirty = false
}

///|
test "ViewPart visits the full batch and accumulates sticky dirty once" {
  let part : CountingViewPart = { dirty: true, force_count: 0, seen: [] }
  assert_true(ViewPart::should_render(part))
  ViewPart::on_did_render(part)
  assert_false(ViewPart::should_render(part))
  handle_view_part_events(part, [
    ViewCompositionStart,
    ViewFlushed,
    ViewZonesChanged,
  ])
  assert_eq(part.seen.length(), 3)
  assert_true(ViewPart::should_render(part))
  assert_eq(part.force_count, 1)
  ViewPart::on_did_render(part)
  handle_view_part_events(part, [ViewCompositionStart, ViewCompositionEnd])
  assert_false(ViewPart::should_render(part))
  assert_eq(part.force_count, 1)
}

///|
suberror ViewEventBatchTestError {
  ViewEventBatchTestError(String)
}

///|
fn fail_view_event_batch(collector : ViewEventCollector) -> Int raise {
  collector.emit(ViewCompositionStart)
  raise ViewEventBatchTestError("expected")
}

///|
test "generic View batch returns a value and always closes on error" {
  install_view_lifecycle_test_browser()
  let view = View::new()
  let result = view.with_view_event_batch(collector => {
    collector.emit(ViewCompositionStart)
    collector.emit(ViewCompositionEnd)
    42
  })
  assert_eq(result, 42)
  assert_eq(view.event_dispatcher.collector_depth, 0)
  let failed = Some(view.with_view_event_batch(fail_view_event_batch)) catch {
    _ => None
  }
  assert_true(failed is None)
  assert_eq(view.event_dispatcher.collector_depth, 0)
  assert_true(view.event_dispatcher.collector is None)
  view.dispose()
  restore_view_lifecycle_test_browser()
}

///|
extern "js" fn view_event_test_attribute(
  element : @rdom.Element,
  name : String,
) -> String =
  #| (element, name) => element.getAttribute(name) || ""

///|
extern "js" fn view_event_test_attribute_write_count(
  element : @rdom.Element,
  name : String,
) -> Int =
  #| (element, name) => element.attributeWriteCount?.get(name) ?? 0

///|
extern "js" fn view_event_test_style_width(element : @rdom.Element) -> String =
  #| (element) => String(element.style.width || "")

///|
extern "js" fn view_event_test_has_parent(
  child : @rdom.Element,
  parent : @rdom.Element,
) -> Bool =
  #| (child, parent) => child.parentNode === parent

///|
extern "js" fn view_event_test_same_node(
  left : @rdom.Element,
  right : @rdom.Element,
) -> Bool =
  #| (left, right) => left === right

///|
extern "js" fn view_event_test_reset_dom_metrics() -> Unit =
  #| () => {
  #|   globalThis.__moonbitViewerScrollMetrics = {
  #|     styleWrites: 0,
  #|     viewLayer: {},
  #|   };
  #| }

///|
extern "js" fn view_event_test_style_write_count() -> Int =
  #| () => globalThis.__moonbitViewerScrollMetrics?.styleWrites ?? 0

///|
extern "js" fn view_event_test_view_layer_mutation_count() -> Int =
  #| () => Object.values(globalThis.__moonbitViewerScrollMetrics?.viewLayer ?? {})
  #|   .reduce((total, value) => total + Number(value), 0)

///|
extern "js" fn view_event_test_clear_dom_metrics() -> Unit =
  #| () => { delete globalThis.__moonbitViewerScrollMetrics; }

///|
fn view_event_test_line_input(
  content : String,
  render_whitespace : @view_layout.RenderWhitespace,
  space_width? : Double = 7.2,
  middot_width? : Double = 7.2,
  wsmiddot_width? : Double = 7.2,
  use_monospace_optimizations? : Bool = true,
) -> @view_layout.RenderLineInput {
  @view_layout.RenderLineInput::from_view_line(
    {
      min_column: 1,
      max_column: content.length() + 1,
      content,
      continues_with_wrapped_line: false,
      contains_rtl: false,
      is_basic_ascii: true,
      tokens: [],
      inline_decorations: [],
      tab_size: 2,
      start_visible_column: 0,
      text_direction: LTR,
      has_variable_fonts: false,
    },
    space_width~,
    middot_width~,
    wsmiddot_width~,
    use_monospace_optimizations~,
    render_whitespace~,
  )
}

///|
fn view_event_test_retained_line(
  parent : @rdom.Element,
  input : @view_layout.RenderLineInput,
) -> (@view_lines.ViewLine, @rdom.Element) raise {
  let line = @view_lines.ViewLine::new()
  assert_true(line.render_line(1, input, 0, 20, StringBuilder()))
  let node = @rdom.document().create_element("div")
  parent.append_child(node.as_node())
  line.set_dom_node(node)
  (line, node)
}

///|
test "ViewLines propagates changed token decoration option and selection invalidators per retained row" {
  install_view_lifecycle_test_browser()
  let view = View::new()
  let lines = view.view_lines
  let live_configuration = Ref(@view_lines.ViewLinesConfiguration::new())
  lines.install_live_configuration_reader(() => live_configuration.val)
  let parent = lines.get_dom_node()
  let input_a = view_event_test_line_input("alpha", None)
  let input_b = view_event_test_line_input("bravo", Selection)
  let input_c = view_event_test_line_input("charlie", None)
  let (line_a, _) = view_event_test_retained_line(parent, input_a)
  let (line_b, _) = view_event_test_retained_line(parent, input_b)
  let (line_c, _) = view_event_test_retained_line(parent, input_c)
  lines.window = { start: 10, end: 13 }
  lines.lines = [line_a, line_b, line_c]

  // Nested VisibleLinesCollection predicates stay independently observable:
  // layout info does not flush, scroll is top-only, and zones always dirty.
  assert_false(lines.on_visible_configuration_changed(false))
  assert_true(lines.on_visible_configuration_changed(true))
  assert_eq(lines.lines.length(), 3)
  assert_false(lines.on_visible_scroll_changed(false))
  assert_true(lines.on_visible_scroll_changed(true))
  assert_true(lines.on_visible_zones_changed())

  // Changed lines notify each intersecting retained row, not just the outer
  // part. An unnotified row ignores even a different candidate input.
  assert_false(
    ViewPart::on_view_event(
      lines,
      ViewLinesChanged(ViewLinesChangedEvent::new(13, 1)),
    ),
  )
  assert_true(
    ViewPart::on_view_event(
      lines,
      ViewLinesChanged(ViewLinesChangedEvent::new(11, 1)),
    ),
  )
  let input_b2 = view_event_test_line_input("bravo changed", Selection)
  assert_true(line_b.render_line(11, input_b2, 20, 20, StringBuilder()))
  assert_false(
    line_a.render_line(
      10,
      view_event_test_line_input("alpha ignored", None),
      0,
      20,
      StringBuilder(),
    ),
  )

  // Token ranges clip inclusively and invalidate only retained endpoints.
  assert_false(
    ViewPart::on_view_event(
      lines,
      ViewTokensChanged(
        ViewTokensChangedEvent::new([ViewTokenChangeRange::new(1, 9)]),
      ),
    ),
  )
  assert_true(
    ViewPart::on_view_event(
      lines,
      ViewTokensChanged(
        ViewTokensChangedEvent::new([ViewTokenChangeRange::new(9, 10)]),
      ),
    ),
  )
  let input_a2 = view_event_test_line_input("alpha tokenized", None)
  assert_true(line_a.render_line(10, input_a2, 0, 20, StringBuilder()))
  assert_false(
    line_c.render_line(
      12,
      view_event_test_line_input("charlie ignored", None),
      40,
      20,
      StringBuilder(),
    ),
  )

  // Decorations visit every retained row. Consume the sticky bits with the
  // unchanged normalized inputs, proving DOM replacement is still gated.
  assert_true(
    ViewPart::on_view_event(
      lines,
      ViewDecorationsChanged(ViewDecorationsChangedEvent::all()),
    ),
  )
  assert_false(line_a.render_line(10, input_a2, 0, 20, StringBuilder()))
  assert_false(line_b.render_line(11, input_b2, 20, 20, StringBuilder()))
  assert_false(line_c.render_line(12, input_c, 40, 20, StringBuilder()))

  // Unrelated configuration still dirties the outer ViewPart, but exact
  // reduced ViewLineOptions equality does not latch retained rows.
  assert_true(
    ViewPart::on_view_event(
      lines,
      ViewConfigurationChanged(
        ViewConfigurationChangedEvent::from_changed_options([ReadOnly]),
      ),
    ),
  )
  let input_a3 = view_event_test_line_input("alpha option", None)
  assert_false(line_a.render_line(10, input_a3, 0, 20, StringBuilder()))
  live_configuration.val = @view_lines.ViewLinesConfiguration::new(
    render_whitespace=All,
  )
  assert_true(
    ViewPart::on_view_event(
      lines,
      ViewConfigurationChanged(
        ViewConfigurationChangedEvent::from_changed_options([RenderWhitespace]),
      ),
    ),
  )
  assert_true(line_a.render_line(10, input_a3, 0, 20, StringBuilder()))
  assert_false(line_b.render_line(11, input_b2, 20, 20, StringBuilder()))
  assert_false(line_c.render_line(12, input_c, 40, 20, StringBuilder()))

  // Cache-only changes are reread in source order but do not masquerade as a
  // `ViewLineOptions.equals` change.
  live_configuration.val = @view_lines.ViewLinesConfiguration::new(
    typical_halfwidth_character_width=8.0,
    is_viewport_wrapping=true,
    can_use_layer_hinting=false,
    render_whitespace=All,
  )
  assert_true(
    ViewPart::on_view_event(
      lines,
      ViewConfigurationChanged(
        ViewConfigurationChangedEvent::from_changed_options([
          FontInfo,
          WrappingInfo,
        ]),
      ),
    ),
  )
  assert_true(lines.typical_halfwidth_character_width == 8.0)
  assert_true(lines.is_viewport_wrapping)
  assert_false(lines.can_use_layer_hinting)
  assert_false(
    line_a.render_line(
      10,
      view_event_test_line_input("cache-only ignored", None),
      0,
      20,
      StringBuilder(),
    ),
  )

  // Line height belongs to the retained option identity and therefore latches
  // every row even when the event payload is otherwise minimal.
  live_configuration.val = @view_lines.ViewLinesConfiguration::new(
    line_height=21,
    typical_halfwidth_character_width=8.0,
    is_viewport_wrapping=true,
    can_use_layer_hinting=false,
    render_whitespace=All,
  )
  assert_true(
    ViewPart::on_view_event(
      lines,
      ViewConfigurationChanged(
        ViewConfigurationChangedEvent::from_changed_options([LineHeight]),
      ),
    ),
  )
  assert_eq(lines.line_height, 21)
  let line_height_input = view_event_test_line_input("line-height", None)
  assert_true(line_a.render_line(10, line_height_input, 0, 21, StringBuilder()))
  assert_false(line_b.render_line(11, input_b2, 21, 21, StringBuilder()))
  assert_false(line_c.render_line(12, input_c, 42, 21, StringBuilder()))

  // Selection walks all rows but returns true only from a row whose own last
  // rendered input used Selection whitespace.
  assert_true(ViewPart::on_view_event(lines, view_event_test_cursor([])))
  assert_false(
    line_a.render_line(
      10,
      view_event_test_line_input("alpha selection ignored", None),
      0,
      20,
      StringBuilder(),
    ),
  )
  assert_true(
    line_b.render_line(
      11,
      view_event_test_line_input("bravo selection", Selection),
      20,
      20,
      StringBuilder(),
    ),
  )

  let width_only = ViewScrollChangedEvent::new(
    420.0, 0.0, 800.0, 0.0, true, false, false, false,
  )
  assert_false(ViewPart::on_view_event(lines, ViewScrollChanged(width_only)))
  assert_eq(view_event_test_style_width(parent), "420px")
  view.dispose()
  restore_view_lifecycle_test_browser()
}

///|
test "ViewLines changed range notifies every retained row through the inclusive endpoint" {
  install_view_lifecycle_test_browser()
  let view = View::new()
  let lines = view.view_lines
  let parent = lines.get_dom_node()
  let input = view_event_test_line_input("retained", None)
  let (line_a, _) = view_event_test_retained_line(parent, input)
  let (line_b, _) = view_event_test_retained_line(parent, input)
  let (line_c, _) = view_event_test_retained_line(parent, input)
  lines.window = { start: 10, end: 13 }
  lines.lines = [line_a, line_b, line_c]
  assert_true(
    ViewPart::on_view_event(
      lines,
      ViewLinesChanged(ViewLinesChangedEvent::new(10, 3)),
    ),
  )
  assert_true(
    line_a.render_line(
      10,
      view_event_test_line_input("changed-a", None),
      0,
      20,
      StringBuilder(),
    ),
  )
  assert_true(
    line_b.render_line(
      11,
      view_event_test_line_input("changed-b", None),
      20,
      20,
      StringBuilder(),
    ),
  )
  assert_true(
    line_c.render_line(
      12,
      view_event_test_line_input("changed-c", None),
      40,
      20,
      StringBuilder(),
    ),
  )
  view.dispose()
  restore_view_lifecycle_test_browser()
}

///|
test "ViewLines option equality catches same-space font render axes" {
  install_view_lifecycle_test_browser()
  let view = View::new()
  let lines = view.view_lines
  let live_configuration = Ref(@view_lines.ViewLinesConfiguration::new())
  lines.install_live_configuration_reader(() => live_configuration.val)
  let original_input = view_event_test_line_input("font axes", None)
  let (line, _) = view_event_test_retained_line(
    lines.get_dom_node(),
    original_input,
  )
  lines.window = { start: 1, end: 2 }
  lines.lines = [line]
  live_configuration.val = @view_lines.ViewLinesConfiguration::new(
    space_width=7.2,
    middot_width=8.0,
    wsmiddot_width=9.0,
    use_monospace_optimizations=false,
  )
  assert_true(
    ViewPart::on_view_event(
      lines,
      ViewConfigurationChanged(
        ViewConfigurationChangedEvent::from_changed_options([FontInfo]),
      ),
    ),
  )
  assert_true(
    line.render_line(
      1,
      view_event_test_line_input(
        "font axes",
        None,
        space_width=7.2,
        middot_width=8.0,
        wsmiddot_width=9.0,
        use_monospace_optimizations=false,
      ),
      0,
      20,
      StringBuilder(),
    ),
  )
  view.dispose()
  restore_view_lifecycle_test_browser()
}

///|
test "ViewLines deletion reconciles start rows and removes only evicted DOM nodes" {
  install_view_lifecycle_test_browser()
  let view = View::new()
  let lines = view.view_lines
  let parent = lines.get_dom_node()
  let input = view_event_test_line_input("retained", None)
  let (line_a, node_a) = view_event_test_retained_line(parent, input)
  let (line_b, node_b) = view_event_test_retained_line(parent, input)
  let (line_c, node_c) = view_event_test_retained_line(parent, input)
  let (line_d, node_d) = view_event_test_retained_line(parent, input)
  lines.window = { start: 10, end: 14 }
  lines.lines = [line_a, line_b, line_c, line_d]

  // Inside deletion records the first index and increments the covered count;
  // unaffected row objects keep identity while both deleted rows detach.
  assert_true(
    ViewPart::on_view_event(
      lines,
      ViewLinesDeleted(ViewLinesDeletedEvent::new(11, 12)),
    ),
  )
  assert_eq(lines.window.start, 10)
  assert_eq(lines.window.end, 12)
  assert_eq(lines.lines.length(), 2)
  assert_true(
    view_event_test_same_node(lines.lines[0].get_dom_node().unwrap(), node_a),
  )
  assert_true(
    view_event_test_same_node(lines.lines[1].get_dom_node().unwrap(), node_d),
  )
  assert_true(view_event_test_has_parent(node_a, parent))
  assert_false(view_event_test_has_parent(node_b, parent))
  assert_false(view_event_test_has_parent(node_c, parent))
  assert_true(view_event_test_has_parent(node_d, parent))

  // Disjoint-above shifts only the one-based start; disjoint-below is a no-op.
  assert_true(
    ViewPart::on_view_event(
      lines,
      ViewLinesDeleted(ViewLinesDeletedEvent::new(1, 2)),
    ),
  )
  assert_eq(lines.window.start, 8)
  assert_eq(lines.window.end, 10)
  assert_true(
    ViewPart::on_view_event(
      lines,
      ViewLinesDeleted(ViewLinesDeletedEvent::new(20, 21)),
    ),
  )
  assert_eq(lines.window.start, 8)
  assert_eq(lines.lines.length(), 2)

  // A deletion beginning above and ending inside adjusts start and splices the
  // first retained row in one source-ordered reconciliation.
  assert_true(
    ViewPart::on_view_event(
      lines,
      ViewLinesDeleted(ViewLinesDeletedEvent::new(7, 8)),
    ),
  )
  assert_eq(lines.window.start, 7)
  assert_eq(lines.window.end, 8)
  assert_eq(lines.lines.length(), 1)
  assert_false(view_event_test_has_parent(node_a, parent))
  assert_true(view_event_test_has_parent(node_d, parent))
  view.dispose()
  restore_view_lifecycle_test_browser()
}

///|
test "ViewLines insertion shifts or recycles rows and removes displaced tail DOM" {
  install_view_lifecycle_test_browser()
  let view = View::new()
  let lines = view.view_lines
  let parent = lines.get_dom_node()
  let input = view_event_test_line_input("retained", None)
  let (line_a, node_a) = view_event_test_retained_line(parent, input)
  let (line_b, node_b) = view_event_test_retained_line(parent, input)
  let (line_c, node_c) = view_event_test_retained_line(parent, input)
  lines.window = { start: 20, end: 23 }
  lines.lines = [line_a, line_b, line_c]

  // Equality belongs to the source's `insertFrom <= start` branch.
  assert_true(
    ViewPart::on_view_event(
      lines,
      ViewLinesInserted(ViewLinesInsertedEvent::new(20, 20)),
    ),
  )
  assert_eq(lines.window.start, 21)
  assert_eq(lines.window.end, 24)
  lines.window = { start: 20, end: 23 }

  assert_true(
    ViewPart::on_view_event(
      lines,
      ViewLinesInserted(ViewLinesInsertedEvent::new(18, 19)),
    ),
  )
  assert_eq(lines.window.start, 22)
  assert_eq(lines.window.end, 25)
  assert_true(
    ViewPart::on_view_event(
      lines,
      ViewLinesInserted(ViewLinesInsertedEvent::new(30, 30)),
    ),
  )
  assert_eq(lines.window.start, 22)
  assert_eq(lines.lines.length(), 3)

  // Restore the same retained logical window and exercise partial insertion:
  // A stays, a fresh row occupies the insertion slot, B stays, C is evicted.
  lines.window = { start: 20, end: 23 }
  assert_true(
    ViewPart::on_view_event(
      lines,
      ViewLinesInserted(ViewLinesInsertedEvent::new(21, 21)),
    ),
  )
  assert_eq(lines.window.start, 20)
  assert_eq(lines.window.end, 23)
  assert_eq(lines.lines.length(), 3)
  assert_true(
    view_event_test_same_node(lines.lines[0].get_dom_node().unwrap(), node_a),
  )
  assert_true(lines.lines[1].get_dom_node() is None)
  assert_true(
    view_event_test_same_node(lines.lines[2].get_dom_node().unwrap(), node_b),
  )
  assert_true(view_event_test_has_parent(node_a, parent))
  assert_true(view_event_test_has_parent(node_b, parent))
  assert_false(view_event_test_has_parent(node_c, parent))

  // A larger inside insertion pushes all remaining rows outside the window.
  assert_true(
    ViewPart::on_view_event(
      lines,
      ViewLinesInserted(ViewLinesInsertedEvent::new(21, 24)),
    ),
  )
  assert_eq(lines.window.start, 20)
  assert_eq(lines.window.end, 21)
  assert_eq(lines.lines.length(), 1)
  assert_true(view_event_test_has_parent(node_a, parent))
  assert_false(view_event_test_has_parent(node_b, parent))
  view.dispose()
  restore_view_lifecycle_test_browser()
}

///|
test "ViewLines empty flush resets to one and defers ordinary DOM replacement" {
  install_view_lifecycle_test_browser()
  let view = View::new()
  let lines = view.view_lines
  let parent = lines.get_dom_node()
  assert_eq(lines.window.start, 1)
  assert_eq(lines.window.end, 1)
  assert_eq(lines.lines.length(), 0)
  let input = view_event_test_line_input("stale", None)
  let (stale_line, stale_node) = view_event_test_retained_line(parent, input)
  lines.window = { start: 50, end: 51 }
  lines.lines = [stale_line]

  assert_true(ViewPart::on_view_event(lines, ViewFlushed))
  assert_eq(lines.lines.length(), 0)
  assert_eq(lines.window.start, 1)
  assert_eq(lines.window.end, 1)
  assert_true(view_event_test_has_parent(stale_node, parent))
  assert_false(
    ViewPart::on_view_event(
      lines,
      ViewLinesChanged(ViewLinesChangedEvent::new(1, 1)),
    ),
  )
  assert_true(
    ViewPart::on_view_event(
      lines,
      ViewLinesDeleted(ViewLinesDeletedEvent::new(1, 1)),
    ),
  )
  assert_true(
    ViewPart::on_view_event(
      lines,
      ViewLinesInserted(ViewLinesInsertedEvent::new(1, 1)),
    ),
  )
  assert_false(
    ViewPart::on_view_event(
      lines,
      ViewTokensChanged(
        ViewTokensChangedEvent::new([ViewTokenChangeRange::new(1, 1)]),
      ),
    ),
  )
  assert_eq(lines.window.start, 1)
  assert_eq(lines.window.end, 1)
  view.dispose()
  restore_view_lifecycle_test_browser()
}

///|
test "cursor state then focus uses new selection shape and focus returns false" {
  install_view_lifecycle_test_browser()
  let cursors = @view_cursors.ViewCursors::new(@rdom.document())
  cursors.render_data = Some(
    @view_cursors.prepare_cursor_render_data(10.0, 0, 18, 1.0),
  )
  cursors.last_position = Some(Position(1, 1))
  cursors.last_rendered_position = Some(Position(1, 1))
  let selection = @core.Selection::new(Position(1, 1), Position(1, 2))
  assert_true(
    ViewPart::on_view_event(
      cursors,
      ViewCursorStateChanged(
        ViewCursorStateChangedEvent::new([selection], [selection], NotSet),
      ),
    ),
  )
  assert_false(cursors.selection_is_empty)
  let painted = cursors.get_last_render_data()
  assert_eq(painted.length(), 1)
  assert_true(painted[0].position == Position(1, 1))
  assert_true(cursors.last_position == Some(Position(1, 2)))
  assert_eq(
    view_event_test_attribute(cursors.dom_node, "class"),
    "cursors-layer has-selection cursor-line-style cursor-solid",
  )
  let class_writes = view_event_test_attribute_write_count(
    cursors.dom_node,
    "class",
  )
  let moved_selection = @core.Selection::new(Position(2, 1), Position(2, 2))
  assert_true(
    ViewPart::on_view_event(
      cursors,
      ViewCursorStateChanged(
        ViewCursorStateChangedEvent::new(
          [moved_selection],
          [moved_selection],
          NotSet,
        ),
      ),
    ),
  )
  assert_eq(
    view_event_test_attribute_write_count(cursors.dom_node, "class"),
    class_writes,
  )
  assert_false(
    ViewPart::on_view_event(
      cursors,
      ViewFocusChanged(ViewFocusChangedEvent::new(true)),
    ),
  )
  assert_eq(
    view_event_test_attribute(cursors.dom_node, "class"),
    "cursors-layer has-selection cursor-line-style cursor-solid",
  )
  assert_true(
    view_event_test_attribute(cursors.cursor, "style").contains(
      "visibility:inherit",
    ),
  )
  cursors.should_render = false
  ViewPartHandle::handle_view_events(ViewCursorsPart(cursors), [
    ViewFocusChanged(ViewFocusChangedEvent::new(false)),
  ])
  assert_false(cursors.should_render)
  assert_true(
    view_event_test_attribute(cursors.cursor, "style").contains(
      "visibility:hidden",
    ),
  )
  restore_view_lifecycle_test_browser()
}

///|
fn view_event_test_configuration() -> ViewEvent {
  ViewConfigurationChanged(
    ViewConfigurationChangedEvent::from_changed_options([]),
  )
}

///|
fn view_event_test_scroll(
  width : Bool,
  left : Bool,
  height : Bool,
  top : Bool,
) -> ViewEvent {
  ViewScrollChanged(
    ViewScrollChangedEvent::new(
      700.0, 11.0, 900.0, 23.0, width, left, height, top,
    ),
  )
}

///|
fn view_event_test_cursor(selections : Array[@core.Selection]) -> ViewEvent {
  ViewCursorStateChanged(
    ViewCursorStateChangedEvent::new(selections, selections, NotSet),
  )
}

///|
priv struct ViewEventContentWidget {
  dom_node : @rdom.Element
}

///|
fn ViewEventContentWidget::content_widget_handle(
  self : ViewEventContentWidget,
) -> @content_widgets.ContentWidgetHandle {
  ContentWidgetHandle(() => "event-widget", () => self.dom_node, () => {
    Some({
      position: Some(Position(2, 3)),
      secondary_position: None,
      preference: Some([Below]),
      position_affinity: None,
    })
  })
}

///|
test "ContentWidgets handlers refresh layout and reproject every mapping event" {
  install_view_lifecycle_test_browser()
  let view = View::new()
  let widgets = view.content_widgets
  let layout_reads = Ref(0)
  let projections = Ref(0)
  widgets.install_live_view_context(
    () => {
      layout_reads.val += 1
      (14.0, 420.0)
    },
    position => {
      projections.val += 1
      Some(position)
    },
  )
  let widget : ViewEventContentWidget = {
    dom_node: @rdom.document().create_element("div"),
  }
  widgets.add_widget(widget.content_widget_handle())
  widgets.set_widget_position(widget.content_widget_handle())
  assert_eq(layout_reads.val, 1)
  assert_eq(projections.val, 1)

  // Outer Configuration always invalidates. Only its exact LayoutInfo bit is
  // forwarded to the retained widgets' cache-refresh branch.
  assert_true(
    ViewPart::on_view_event(
      widgets,
      ViewConfigurationChanged(
        ViewConfigurationChangedEvent::from_changed_options([FontInfo]),
      ),
    ),
  )
  assert_eq(layout_reads.val, 1)
  assert_true(
    ViewPart::on_view_event(
      widgets,
      ViewConfigurationChanged(
        ViewConfigurationChangedEvent::from_changed_options([LayoutInfo]),
      ),
    ),
  )
  assert_eq(layout_reads.val, 2)

  projections.val = 0
  for
    event in [
      ViewLineMappingChanged,
      ViewLinesChanged(ViewLinesChangedEvent::new(2, 1)),
      ViewLinesDeleted(ViewLinesDeletedEvent::new(2, 2)),
      ViewLinesInserted(ViewLinesInsertedEvent::new(2, 2)),
    ] {
    assert_true(ViewPart::on_view_event(widgets, event))
  }
  assert_eq(projections.val, 4)
  view.dispose()
  restore_view_lifecycle_test_browser()
}

///|
test "ContentWidgets and ViewZones source handler matrices" {
  install_view_lifecycle_test_browser()
  let view = View::new()
  let widgets = view.content_widgets
  assert_true(ViewPart::on_view_event(widgets, ViewFlushed))
  assert_true(ViewPart::on_view_event(widgets, view_event_test_configuration()))
  assert_true(
    ViewPart::on_view_event(
      widgets,
      ViewDecorationsChanged(ViewDecorationsChangedEvent::all()),
    ),
  )
  assert_true(ViewPart::on_view_event(widgets, ViewLineMappingChanged))
  assert_true(
    ViewPart::on_view_event(
      widgets,
      ViewLinesChanged(ViewLinesChangedEvent::new(1, 1)),
    ),
  )
  assert_true(
    ViewPart::on_view_event(
      widgets,
      ViewLinesDeleted(ViewLinesDeletedEvent::new(1, 2)),
    ),
  )
  assert_true(
    ViewPart::on_view_event(
      widgets,
      ViewLinesInserted(ViewLinesInsertedEvent::new(1, 2)),
    ),
  )
  assert_true(
    ViewPart::on_view_event(
      widgets,
      view_event_test_scroll(false, false, false, false),
    ),
  )
  assert_true(ViewPart::on_view_event(widgets, ViewZonesChanged))
  assert_false(ViewPart::on_view_event(widgets, view_event_test_cursor([])))
  assert_false(
    ViewPart::on_view_event(
      widgets,
      ViewTokensChanged(ViewTokensChangedEvent::new([])),
    ),
  )
  assert_false(
    ViewPart::on_view_event(
      widgets,
      ViewFocusChanged(ViewFocusChangedEvent::new(true)),
    ),
  )

  let zones = view.view_zones
  assert_true(ViewPart::on_view_event(zones, view_event_test_configuration()))
  // `viewZones.ts:122-124` returns the exact
  // `_recomputeWhitespacesProps()` result. With an empty zone registry there
  // is no changed whitespace, so the source handler is not dirty.
  assert_false(ViewPart::on_view_event(zones, ViewLineMappingChanged))
  assert_true(
    ViewPart::on_view_event(
      zones,
      ViewLinesDeleted(ViewLinesDeletedEvent::new(1, 1)),
    ),
  )
  assert_true(
    ViewPart::on_view_event(
      zones,
      ViewLinesInserted(ViewLinesInsertedEvent::new(1, 1)),
    ),
  )
  assert_true(
    ViewPart::on_view_event(
      zones,
      view_event_test_scroll(true, false, false, false),
    ),
  )
  assert_true(
    ViewPart::on_view_event(
      zones,
      view_event_test_scroll(false, false, false, true),
    ),
  )
  assert_false(
    ViewPart::on_view_event(
      zones,
      view_event_test_scroll(false, true, false, false),
    ),
  )
  assert_false(
    ViewPart::on_view_event(
      zones,
      view_event_test_scroll(false, false, true, false),
    ),
  )
  assert_true(ViewPart::on_view_event(zones, ViewZonesChanged))
  assert_false(ViewPart::on_view_event(zones, ViewFlushed))
  assert_false(
    ViewPart::on_view_event(
      zones,
      ViewLinesChanged(ViewLinesChangedEvent::new(1, 1)),
    ),
  )
  view.dispose()
  restore_view_lifecycle_test_browser()
}

///|
test "overlay aggregates, OverlayWidgets, and EditorScrollbar handler matrix" {
  install_view_lifecycle_test_browser()
  let view = View::new()
  let content = view.content_view_overlays
  let margin = view.margin_view_overlays
  for
    overlays in [
      ContentViewOverlaysPart(content),
      MarginViewOverlaysPart(margin),
    ] {
    assert_true(ViewPart::on_view_event(overlays, ViewFlushed))
    assert_true(
      ViewPart::on_view_event(overlays, view_event_test_configuration()),
    )
    assert_true(
      ViewPart::on_view_event(
        overlays,
        ViewDecorationsChanged(ViewDecorationsChangedEvent::all()),
      ),
    )
    assert_true(ViewPart::on_view_event(overlays, ViewLineMappingChanged))
    assert_true(
      ViewPart::on_view_event(
        overlays,
        ViewLinesChanged(ViewLinesChangedEvent::new(1, 1)),
      ),
    )
    assert_true(
      ViewPart::on_view_event(
        overlays,
        ViewLinesDeleted(ViewLinesDeletedEvent::new(1, 1)),
      ),
    )
    assert_true(
      ViewPart::on_view_event(
        overlays,
        ViewLinesInserted(ViewLinesInsertedEvent::new(1, 1)),
      ),
    )
    assert_true(
      ViewPart::on_view_event(
        overlays,
        ViewTokensChanged(
          ViewTokensChangedEvent::new([ViewTokenChangeRange::new(1, 1)]),
        ),
      ),
    )
    assert_true(ViewPart::on_view_event(overlays, view_event_test_cursor([])))
    assert_true(
      ViewPart::on_view_event(
        overlays,
        ViewFocusChanged(ViewFocusChangedEvent::new(true)),
      ),
    )
    assert_true(ViewPart::on_view_event(overlays, ViewZonesChanged))
    // Base `ViewOverlays.onScrollChanged` always invalidates the retained
    // visible rows.  Each independent flag therefore reaches both grouped
    // aggregates without being conflated.
    assert_true(
      ViewPart::on_view_event(
        overlays,
        view_event_test_scroll(true, false, false, false),
      ),
    )
    assert_true(
      ViewPart::on_view_event(
        overlays,
        view_event_test_scroll(false, true, false, false),
      ),
    )
    assert_true(
      ViewPart::on_view_event(
        overlays,
        view_event_test_scroll(false, false, true, false),
      ),
    )
    assert_true(
      ViewPart::on_view_event(
        overlays,
        view_event_test_scroll(false, false, false, true),
      ),
    )
  }

  let overlay_widgets = view.overlay_widgets
  assert_true(
    ViewPart::on_view_event(overlay_widgets, view_event_test_configuration()),
  )
  assert_true(
    ViewPart::on_view_event(
      overlay_widgets,
      view_event_test_scroll(true, false, false, false),
    ),
  )
  assert_true(
    ViewPart::on_view_event(
      overlay_widgets,
      view_event_test_scroll(false, false, true, false),
    ),
  )
  assert_false(
    ViewPart::on_view_event(
      overlay_widgets,
      view_event_test_scroll(false, true, false, false),
    ),
  )
  assert_false(
    ViewPart::on_view_event(
      overlay_widgets,
      view_event_test_scroll(false, false, false, true),
    ),
  )
  assert_false(ViewPart::on_view_event(overlay_widgets, ViewFlushed))

  let scrollbar = view.editor_scrollbar
  assert_true(
    ViewPart::on_view_event(scrollbar, view_event_test_configuration()),
  )
  assert_true(
    ViewPart::on_view_event(
      scrollbar,
      view_event_test_scroll(false, false, false, false),
    ),
  )
  assert_false(ViewPart::on_view_event(scrollbar, ViewFlushed))
  view.dispose()
  restore_view_lifecycle_test_browser()
}

///|
test "ViewLines and ViewCursors cover four scroll flags and token endpoints" {
  install_view_lifecycle_test_browser()
  let view = View::new()
  let lines = view.view_lines
  lines.window = { start: 10, end: 13 }
  lines.lines = [
    @view_lines.ViewLine::new(),
    @view_lines.ViewLine::new(),
    @view_lines.ViewLine::new(),
  ]
  assert_false(
    ViewPart::on_view_event(
      lines,
      view_event_test_scroll(true, false, false, false),
    ),
  )
  assert_true(
    ViewPart::on_view_event(
      lines,
      view_event_test_scroll(false, true, false, false),
    ),
  )
  assert_false(
    ViewPart::on_view_event(
      lines,
      view_event_test_scroll(false, false, true, false),
    ),
  )
  assert_true(
    ViewPart::on_view_event(
      lines,
      view_event_test_scroll(false, false, false, true),
    ),
  )
  assert_false(
    ViewPart::on_view_event(
      lines,
      ViewTokensChanged(
        ViewTokensChangedEvent::new([
          ViewTokenChangeRange::new(1, 9),
          ViewTokenChangeRange::new(13, 20),
        ]),
      ),
    ),
  )
  assert_true(
    ViewPart::on_view_event(
      lines,
      ViewTokensChanged(
        ViewTokensChangedEvent::new([
          ViewTokenChangeRange::new(1, 9),
          ViewTokenChangeRange::new(12, 20),
        ]),
      ),
    ),
  )
  assert_true(
    ViewPart::on_view_event(
      lines,
      ViewTokensChanged(
        ViewTokensChangedEvent::new([ViewTokenChangeRange::new(10, 10)]),
      ),
    ),
  )

  let cursors = view.view_cursors
  cursors.last_position = Some(Position(5, 2))
  assert_false(
    ViewPart::on_view_event(
      cursors,
      ViewTokensChanged(
        ViewTokensChangedEvent::new([
          ViewTokenChangeRange::new(1, 4),
          ViewTokenChangeRange::new(6, 9),
        ]),
      ),
    ),
  )
  assert_true(
    ViewPart::on_view_event(
      cursors,
      ViewTokensChanged(
        ViewTokensChangedEvent::new([
          ViewTokenChangeRange::new(1, 4),
          ViewTokenChangeRange::new(5, 5),
        ]),
      ),
    ),
  )
  assert_true(
    ViewPart::on_view_event(
      cursors,
      ViewTokensChanged(
        ViewTokensChangedEvent::new([ViewTokenChangeRange::new(5, 8)]),
      ),
    ),
  )
  assert_true(
    ViewPart::on_view_event(
      cursors,
      view_event_test_scroll(true, false, false, false),
    ),
  )
  assert_true(
    ViewPart::on_view_event(
      cursors,
      view_event_test_scroll(false, true, false, false),
    ),
  )
  assert_true(
    ViewPart::on_view_event(
      cursors,
      view_event_test_scroll(false, false, true, false),
    ),
  )
  assert_true(
    ViewPart::on_view_event(
      cursors,
      view_event_test_scroll(false, false, false, true),
    ),
  )
  view.dispose()
  restore_view_lifecycle_test_browser()
}

///|
test "current-line predicate ignores same-line column moves but tracks emptiness" {
  let state = @current_line_highlight.CurrentLineHighlightState::new()
  let collapsed_line_3_column_1 = @core.Selection::new(
    Position(3, 1),
    Position(3, 1),
  )
  assert_true(state.on_cursor_state_changed([collapsed_line_3_column_1]))
  let collapsed_line_3_column_9 = @core.Selection::new(
    Position(3, 9),
    Position(3, 9),
  )
  assert_false(state.on_cursor_state_changed([collapsed_line_3_column_9]))
  assert_true(state.selections[0] == collapsed_line_3_column_9)
  let selected_on_line_3 = @core.Selection::new(Position(3, 2), Position(3, 9))
  assert_true(state.on_cursor_state_changed([selected_on_line_3]))
  assert_false(state.selection_is_empty)
  let collapsed_line_4 = @core.Selection::new(Position(4, 1), Position(4, 1))
  assert_true(
    state.on_cursor_state_changed([
      collapsed_line_4, collapsed_line_3_column_9, collapsed_line_4,
    ]),
  )
  assert_true(state.cursor_line_numbers == [3, 4])
  assert_true(state.selection_is_empty)
  assert_false(
    state.on_cursor_state_changed([collapsed_line_3_column_9, collapsed_line_4]),
  )

  let configuration : Ref[
    (@view_layout.RenderLineHighlight, Bool, Bool, Double, Double),
  ] = Ref((Line, false, false, 10.0, 100.0))
  state.install_configuration_reader(() => configuration.val)
  assert_false(state.on_focus_changed(true))
  assert_false(state.focused)
  configuration.val = (All, true, true, 41.0, 520.0)
  state.on_configuration_changed()
  assert_true(state.render_line_highlight == All)
  assert_true(state.render_line_highlight_only_when_focus)
  assert_true(state.word_wrap)
  assert_true(state.content_left == 41.0)
  assert_true(state.content_width == 520.0)
  assert_true(state.on_focus_changed(true))
  assert_true(state.focused)
  configuration.val = (Gutter, false, false, 42.0, 530.0)
  state.on_configuration_changed()
  assert_false(state.on_focus_changed(false))
  assert_true(state.focused)
  assert_true(
    current_line_scroll_changed(
      match view_event_test_scroll(true, false, false, false) {
        ViewScrollChanged(event) => event
        _ => abort("scroll test helper returned non-scroll event")
      },
    ),
  )
  assert_false(
    current_line_scroll_changed(
      match view_event_test_scroll(false, true, true, false) {
        ViewScrollChanged(event) => event
        _ => abort("scroll test helper returned non-scroll event")
      },
    ),
  )
  assert_true(
    current_line_scroll_changed(
      match view_event_test_scroll(false, false, false, true) {
        ViewScrollChanged(event) => event
        _ => abort("scroll test helper returned non-scroll event")
      },
    ),
  )
}

///|
fn view_event_test_overlay_render_context(
  view_model : @view_model.ViewModel,
  layout : @view_layout.ViewLayout,
  view_lines : @view_lines.ViewLines,
  cursor_column : Int,
) -> (RenderingContext, RestrictedRenderingContext) {
  let selection = @core.Selection::new(
    Position(1, cursor_column),
    Position(1, cursor_column),
  )
  let input : ViewRenderInput = {
    window: { start: 1, end: 2 },
    view_model,
    layout,
    selection_view_range: None,
    view_selection: Some(selection),
    // Deliberately disagree with the retained layout caches. Render must use
    // contentLeft=40/contentWidth=120 installed below, not these frame facts.
    gutter_width: 99.0,
    line_decorations_width: 10.0,
    space_width: 8.0,
    typical_fullwidth_character_width: 16.0,
    // Deliberately false after the retained focus event has stored true.
    editor_has_focus: false,
    word_wrap: false,
    render_line_highlight: Line,
    render_line_highlight_only_when_focus: false,
    show_unused: true,
    show_deprecated: true,
  }
  let view_context : ViewContext = {
    measure_line_selection: (_line, _start, _end) => [],
    measure_line_decorations: (_line, _start, _end) => [],
    offset_for_column: (_line, _column) => 0.0,
    model_position_to_view_position: position => position,
  }
  let rendering = RenderingContext::from_viewport(
    view_context,
    input,
    view_lines,
    RenderingContext::viewport_from_input(input),
  )
  let restricted : RestrictedRenderingContext = {
    view_context: rendering.view_context,
    input: rendering.input,
    viewport: rendering.viewport,
    gutter_width: rendering.gutter_width,
    position: rendering.position,
    dimensions: {
      width: 80.0,
      scroll_width: 80.0,
      height: 20.0,
      // Exercise MarginViewOverlays' exact `Math.min(..., 1000000)` cap.
      scroll_height: 2000000.0,
    },
    translate_y: rendering.translate_y,
    margin_transform: rendering.margin_transform(),
    line_height: rendering.viewport.line_height,
  }
  (rendering, restricted)
}

///|
fn view_event_test_unsupported_view_lines_context() -> (
  View,
  RenderingContext,
  RestrictedRenderingContext,
) {
  let model = @model.TextModel(
    @base_common.Uri::file("/view-lines-unsupported-render-test.mbt"),
    "view-lines-unsupported-render-test.mbt",
    "moonbit",
    1,
    "rev-1",
    "alpha",
  )
  let view_model = @view_model.ViewModel(model)
  let layout = @view_layout.ViewLayout::new(line_height=20, line_count=1)
  layout.set_viewport_size(width=80.0, height=20.0) |> ignore
  let view = View::new()
  let (rendering, restricted) = view_event_test_overlay_render_context(
    view_model,
    layout,
    view.view_lines,
    1,
  )
  (view, rendering, restricted)
}

///|
test "panic ViewLines prepareRender is unsupported" {
  install_view_lifecycle_test_browser()
  defer restore_view_lifecycle_test_browser()
  let (view, rendering, _) = view_event_test_unsupported_view_lines_context()
  ViewPart::prepare_render(view.view_lines, rendering)
}

///|
test "panic ViewLines render is unsupported" {
  install_view_lifecycle_test_browser()
  defer restore_view_lifecycle_test_browser()
  let (view, _, restricted) = view_event_test_unsupported_view_lines_context()
  ViewPart::render(view.view_lines, restricted)
}

///|
fn view_event_test_seed_overlay_row(
  overlays : ViewOverlays,
  viewport : @view_layout.ViewportData,
) -> @rdom.Element raise {
  let line = ViewOverlayLine::new(overlays.dynamic_overlays)
  let builder = StringBuilder()
  assert_true(
    line.render_line(
      viewport.start_line_number,
      viewport.relative_vertical_offset[0],
      viewport.line_height,
      viewport,
      builder,
    ),
  )
  let node = @rdom.document().create_element("div")
  overlays.dom_node.element().append_child(node.as_node())
  line.set_dom_node(node)
  overlays.lines = [line]
  overlays.window = {
    start: viewport.start_line_number,
    end: viewport.end_line_number + 1,
  }
  node
}

///|
test "grouped same-line cursor over-render retains caches and performs zero DOM writes" {
  install_view_lifecycle_test_browser()
  let model = @model.TextModel(
    @base_common.Uri::file("/view-overlays-retained-cache-test.mbt"),
    "view-overlays-retained-cache-test.mbt",
    "moonbit",
    1,
    "rev-1",
    "alpha",
  )
  let view_model = @view_model.ViewModel(model)
  let layout = @view_layout.ViewLayout::new(line_height=20, line_count=1)
  layout.set_viewport_size(width=80.0, height=20.0) |> ignore
  layout.set_content_width(80.0) |> ignore
  let view = View::new()
  let configuration : Ref[
    (@view_layout.RenderLineHighlight, Bool, Bool, Double, Double),
  ] = Ref((Line, false, false, 40.0, 120.0))
  view.install_current_line_configuration_reader(() => configuration.val)
  let content = view.content_view_overlays
  let margin = view.margin_view_overlays
  assert_true(content.content_width == 120.0)
  assert_true(margin.content_left == 40.0)

  // Configuration updates every aggregate cache at event time, independently
  // from the nested current-line states.
  configuration.val = (All, true, true, 41.0, 121.0)
  assert_true(ViewPart::on_view_event(content, view_event_test_configuration()))
  assert_true(ViewPart::on_view_event(margin, view_event_test_configuration()))
  assert_true(content.content_width == 121.0)
  assert_true(margin.content_left == 41.0)
  assert_true(content.current_line.state.content_width == 121.0)
  assert_true(margin.current_line_margin.state.content_left == 41.0)
  configuration.val = (Line, false, false, 40.0, 120.0)
  ViewPart::on_view_event(content, view_event_test_configuration()) |> ignore
  ViewPart::on_view_event(margin, view_event_test_configuration()) |> ignore

  // Base ViewOverlays retains focus even though CurrentLineHighlight's
  // focus-only early return deliberately leaves its own `_focused` unchanged.
  let focus_event = ViewFocusChanged(ViewFocusChangedEvent::new(true))
  assert_true(ViewPart::on_view_event(content, focus_event))
  assert_true(ViewPart::on_view_event(margin, focus_event))
  assert_true(content.overlays.is_focused)
  assert_true(margin.overlays.is_focused)
  assert_false(content.current_line.state.focused)
  assert_false(margin.current_line_margin.state.focused)

  let (first_rendering, first_restricted) = view_event_test_overlay_render_context(
    view_model,
    layout,
    view.view_lines,
    1,
  )
  ViewPart::prepare_render(content, first_rendering)
  ViewPart::prepare_render(margin, first_rendering)
  let content_row = view_event_test_seed_overlay_row(
    content.overlays,
    first_rendering.viewport,
  )
  let margin_row = view_event_test_seed_overlay_row(
    margin.overlays,
    first_rendering.viewport,
  )
  // Prime every retained DOM/style cache through the real ViewPart render.
  ViewPart::render(content, first_restricted)
  ViewPart::render(margin, first_restricted)
  ViewPart::on_did_render(content)
  ViewPart::on_did_render(margin)
  assert_eq(
    view_event_test_attribute(content.overlays.dom_node.element(), "class"),
    "view-overlays focused",
  )
  assert_eq(
    view_event_test_attribute(margin.overlays.dom_node.element(), "class"),
    "margin-view-overlays focused",
  )
  assert_eq(
    view_event_test_style_width(content.overlays.dom_node.element()),
    "120px",
  )
  assert_eq(view_event_test_attribute(margin.dom_node, "style"), "width:40px")
  assert_true(
    view_event_test_attribute(margin.overlays.dom_node.element(), "style").contains(
      "width:40px;height:1000000px",
    ),
  )

  let content_class_writes = view_event_test_attribute_write_count(
    content.overlays.dom_node.element(),
    "class",
  )
  let margin_class_writes = view_event_test_attribute_write_count(
    margin.overlays.dom_node.element(),
    "class",
  )
  let margin_style_writes = view_event_test_attribute_write_count(
    margin.overlays.dom_node.element(),
    "style",
  )
  let margin_outer_style_writes = view_event_test_attribute_write_count(
    margin.dom_node,
    "style",
  )
  view_event_test_reset_dom_metrics()

  // Absolute line numbers plus a current-line state whose line set and
  // emptiness are unchanged both return false in the pinned sources. The
  // grouped local handles intentionally still render; prove that bounded
  // overwork cannot replace a row or write any retained style/class.
  let column_only = @core.Selection::new(Position(1, 2), Position(1, 2))
  let cursor_event = view_event_test_cursor([column_only])
  handle_view_part_events(content, [cursor_event])
  handle_view_part_events(margin, [cursor_event])
  assert_true(ViewPart::should_render(content))
  assert_true(ViewPart::should_render(margin))
  assert_true(content.current_line.state.cursor_line_numbers == [1])
  assert_true(margin.current_line_margin.state.cursor_line_numbers == [1])
  assert_true(content.current_line.state.selection_is_empty)
  assert_true(margin.current_line_margin.state.selection_is_empty)
  let (second_rendering, second_restricted) = view_event_test_overlay_render_context(
    view_model,
    layout,
    view.view_lines,
    2,
  )
  ViewPart::prepare_render(content, second_rendering)
  ViewPart::prepare_render(margin, second_rendering)
  ViewPart::render(content, second_restricted)
  ViewPart::render(margin, second_restricted)
  ViewPart::on_did_render(content)
  ViewPart::on_did_render(margin)

  assert_eq(view_event_test_style_write_count(), 0)
  assert_eq(view_event_test_view_layer_mutation_count(), 0)
  assert_eq(
    view_event_test_attribute_write_count(
      content.overlays.dom_node.element(),
      "class",
    ),
    content_class_writes,
  )
  assert_eq(
    view_event_test_attribute_write_count(
      margin.overlays.dom_node.element(),
      "class",
    ),
    margin_class_writes,
  )
  assert_eq(
    view_event_test_attribute_write_count(
      margin.overlays.dom_node.element(),
      "style",
    ),
    margin_style_writes,
  )
  assert_eq(
    view_event_test_attribute_write_count(margin.dom_node, "style"),
    margin_outer_style_writes,
  )
  assert_true(
    view_event_test_same_node(
      content.overlays.lines[0].get_dom_node().unwrap(),
      content_row,
    ),
  )
  assert_true(
    view_event_test_same_node(
      margin.overlays.lines[0].get_dom_node().unwrap(),
      margin_row,
    ),
  )

  view_event_test_clear_dom_metrics()
  view.dispose()
  layout.dispose()
  view_model.dispose()
  model.dispose()
  restore_view_lifecycle_test_browser()
}
