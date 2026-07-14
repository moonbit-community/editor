// Event and render adapters stay in `browser/view` because the private event
// and rendering-context types belong here; moving them to concrete part
// packages would reverse the dependency graph.

///|
fn view_zones_on_view_event(part : ViewZones, event : ViewEvent) -> Bool {
  let self = part
  match event {
    ViewConfigurationChanged(e) =>
      self.on_configuration_changed(e.has_changed(LineHeight))
    ViewLineMappingChanged => self.on_line_mapping_changed()
    ViewLinesDeleted(_) => self.on_lines_deleted()
    ViewLinesInserted(_) => self.on_lines_inserted()
    ViewScrollChanged(e) =>
      self.on_scroll_changed(e.scroll_top_changed, e.scroll_width_changed)
    ViewZonesChanged => self.on_zones_changed()
    _ => false
  }
}

///|
fn view_zones_prepare_render(
  _part : ViewZones,
  _context : RenderingContext,
) -> Unit {
  // Monaco `ViewZones.prepareRender`: nothing to read.
}

///|
fn view_zones_render(
  part : ViewZones,
  context : RestrictedRenderingContext,
) -> Unit {
  let self = part
  self.render(
    context.viewport.view_zones,
    context.viewport.big_numbers_delta,
    context.position.scroll_top,
    context.dimensions.scroll_width,
  )
}

// `ViewLines` is an event handler but not an ordinary render part.

///|
fn view_lines_on_view_event(part : ViewLines, event : ViewEvent) -> Bool {
  let self = part
  match event {
    ViewFlushed => {
      self.flush_retained_lines()
      true
    }
    ViewLinesChanged(e) => self.on_lines_changed(e.from_line_number, e.count)
    ViewLinesDeleted(e) => {
      self.on_lines_deleted(e.from_line_number, e.to_line_number)
      true
    }
    ViewLinesInserted(e) => {
      self.on_lines_inserted(e.from_line_number, e.to_line_number)
      true
    }
    ViewDecorationsChanged(_) => {
      self.on_decorations_changed()
      true
    }
    ViewScrollChanged(e) => {
      // `ViewLines.onScrollChanged` writes the new scroll width even when it
      // does not invalidate text rows; only top/left require a render pass.
      self.dom_node.set_width(Pixels(e.scroll_width))
      self.on_visible_scroll_changed(e.scroll_top_changed) ||
      e.scroll_top_changed ||
      e.scroll_left_changed
    }
    ViewConfigurationChanged(e) => {
      self.on_visible_configuration_changed(e.has_changed(LayoutInfo)) |> ignore
      self.on_configuration_changed(
        e.has_changed(WrappingInfo),
        e.has_changed(LayoutInfo),
      )
      |> ignore
      // Source `ViewLines.onConfigurationChanged` always returns true after
      // the nested layout-info and option-equality checks.
      true
    }
    ViewCursorStateChanged(_) => self.on_selection_changed()
    ViewTokensChanged(e) => {
      let ranges : Array[@base_common.LineRange] = []
      for range in e.ranges {
        ranges.push(LineRange(range.from_line_number, range.to_line_number + 1))
      }
      self.on_token_ranges_changed(ranges)
    }
    ViewZonesChanged => self.on_visible_zones_changed()
    _ => false
  }
}
