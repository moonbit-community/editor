// The viewer core's side of the comments contrib — the editor lifecycle of
// `vscode/src/vs/workbench/contrib/comments/browser/commentsController.ts`
// (`CommentController`): service subscriptions, the commenting-range/thread
// glyph decorations, gutter mouse handling (`onEditorMouseDown/Up` →
// `addOrToggleCommentAtLine`), hover updates, widget open/close/re-anchor,
// and the reserved lane width (`tryUpdateReservedSpace`). The DOM-free gates
// and decoration builders live in `viewer/contrib/comments`; the widget in
// `viewer/contrib/comments/browser`. Kept here per the foreign-method rule
// (every `Viewer::` method lives in `Viewer`'s own package).

///|
/// The lane width the comments contrib reserves while a resource has comment
/// data — `updateEditorLayoutOptions`'s `+24` over the base
/// `lineDecorationsWidth` (`commentsController.ts:1309-1315`), collapsed to a
/// fixed lane (the viewer's base is `0`).
let comment_lane_width_px : Int = 24

///|
/// Subscribes the viewer to its comment service (constructor-time, like the
/// marker-decorations subscription): thread and commenting-range changes on
/// the current resource re-sync decorations, widgets, and the reserved lane.
fn Viewer::hook_comment_service(self : Viewer) -> Unit {
  self.services.comments.on_did_update_comment_threads(event => {
    if self.is_current_resource(event.resource) {
      self.sync_comments()
    }
  })
  |> ignore
  self.services.comments.on_did_change_commenting_ranges(resource => {
    if self.is_current_resource(resource) {
      self.sync_comments()
    }
  })
  |> ignore
}

///|
fn Viewer::is_current_resource(
  self : Viewer,
  resource : @base_common.Uri,
) -> Bool {
  match self.text_model {
    Some(model) => model.uri.to_string() == resource.to_string()
    None => false
  }
}

///|
/// Full comment re-sync for the current resource: lane reservation,
/// decorations, and widget reconciliation against the service state
/// (`CommentController.setComments` + `display` flow).
fn Viewer::sync_comments(self : Viewer) -> Unit {
  guard self.text_model is Some(model) else { return }
  let service = self.services.comments
  let threads = service.threads(model.uri)
  let ranges = service.commenting_ranges(model.uri)
  self.sync_comment_lane_reservation(threads, ranges)
  self.sync_comment_decorations()
  guard self.view is Some(_) else { return }
  // Close widgets whose threads are gone (deleted last comment, discarded
  // template, host replace).
  let stale : Array[String] = []
  for thread_id, _ in self.open_comment_widgets {
    if threads.search_by(t => t.thread_id == thread_id) is None {
      stale.push(thread_id)
    }
  }
  for thread_id in stale {
    match self.open_comment_widgets.get(thread_id) {
      Some(widget) => widget.hide()
      None => ()
    }
    self.open_comment_widgets.remove(thread_id)
  }
  for thread in threads {
    match self.open_comment_widgets.get(thread.thread_id) {
      Some(widget) => {
        widget.update(thread)
        if thread.collapsible_state == Expanded {
          match self.comment_anchor_view_line(thread) {
            Some(anchor) =>
              if widget.is_visible() {
                widget.update_anchor(anchor)
              } else {
                widget.display(anchor)
              }
            None => widget.hide()
          }
        } else {
          widget.hide()
        }
      }
      None =>
        if thread.collapsible_state == Expanded {
          let widget = self.create_comment_widget(thread)
          self.open_comment_widgets.set(thread.thread_id, widget)
          match self.comment_anchor_view_line(thread) {
            Some(anchor) => widget.display(anchor)
            None => ()
          }
        }
    }
  }
}

///|
/// Reserves the line-decorations lane while the resource has comment data
/// and restores the host's base width when it no longer does —
/// `tryUpdateReservedSpace` (`commentsController.ts:1319-1348`) reduced to
/// the fixed comment lane. A host `update_options` while reserved wins (the
/// stored base is only re-applied on release).
fn Viewer::sync_comment_lane_reservation(
  self : Viewer,
  threads : Array[@comments_common.CommentThread],
  ranges : Array[@base_common.Range],
) -> Unit {
  let needed = threads.length() > 0 || ranges.length() > 0
  match (needed, self.comments_lane_base_width) {
    (true, None) => {
      let base = self.options.line_decorations_width
      if base < comment_lane_width_px {
        self.comments_lane_base_width = Some(base)
        self.update_options({
          ..self.options,
          line_decorations_width: comment_lane_width_px,
        })
      }
    }
    (false, Some(base)) => {
      self.comments_lane_base_width = None
      self.update_options({ ..self.options, line_decorations_width: base })
    }
    _ => ()
  }
}

///|
/// Rewrites the commenting-range + thread-glyph decorations
/// (`CommentingRangeDecorator._doUpdate`'s `deltaDecorations` +
/// `CommentGlyphWidget`'s collection), owner-scoped like the hover highlight
/// (`sync_hover_decorations`).
fn Viewer::sync_comment_decorations(self : Viewer) -> Unit {
  guard self.text_model is Some(model) else { return }
  let service = self.services.comments
  let threads = service.threads(model.uri)
  let ranges = service.commenting_ranges(model.uri)
  if threads.is_empty() &&
    ranges.is_empty() &&
    self.comments_range_decoration_ids.is_empty() &&
    self.comments_glyph_decoration_ids.is_empty() {
    return
  }
  self.comments_range_decoration_ids = model.delta_decorations(
    self.comments_range_decoration_ids,
    @comments.commenting_range_decorations(
      ranges,
      self.comments.hover_line,
      @comments.thread_lines(threads),
    ),
    owner_id=self.editor_id,
  )
  self.comments_glyph_decoration_ids = model.delta_decorations(
    self.comments_glyph_decoration_ids,
    @comments.thread_glyph_decorations(threads),
    owner_id=self.editor_id,
  )
}

///|
/// Drops all open thread widgets (model swap/detach).
fn Viewer::close_all_comment_widgets(self : Viewer) -> Unit {
  for _, widget in self.open_comment_widgets {
    widget.hide()
  }
  self.open_comment_widgets.clear()
}

///|
/// Re-anchors open widgets after folding/wrapping changed the view-line
/// mapping (the zone API is view-addressed — D8); a widget whose anchor is
/// hidden inside a folded region hides until the region unfolds.
fn Viewer::reanchor_comment_widgets(self : Viewer) -> Unit {
  let service = self.services.comments
  for thread_id, widget in self.open_comment_widgets {
    match service.thread_by_id(thread_id) {
      Some(thread) =>
        if thread.collapsible_state == Expanded {
          match self.comment_anchor_view_line(thread) {
            Some(anchor) =>
              if widget.is_visible() {
                widget.update_anchor(anchor)
              } else {
                widget.display(anchor)
              }
            None => widget.hide()
          }
        }
      None => ()
    }
  }
}

///|
/// The view line a thread's widget anchors after: the thread's end line at
/// its max column (so a soft-wrapped line anchors after its last segment,
/// like Monaco's `_computeWhitespaceProps`), `None` while the line is hidden
/// inside a folded region.
fn Viewer::comment_anchor_view_line(
  self : Viewer,
  thread : @comments_common.CommentThread,
) -> Int? {
  guard self.text_model is Some(model) else { return None }
  let line_count = model.snapshot.line_count()
  let line = @base_common.clamp_int(thread.range.end_line_number, 1, line_count)
  for folded in self.folded_ranges {
    if line > folded.start_line_number && line <= folded.end_line_number {
      return None
    }
  }
  let max_column = model.snapshot.line_text(line - 1).length() + 1
  match self.model_to_view_position(line, max_column) {
    Some(position) => Some(position.line_number)
    None => Some(line)
  }
}

///|
fn Viewer::create_comment_widget(
  self : Viewer,
  thread : @comments_common.CommentThread,
) -> @comments_browser.ReviewZoneWidget {
  let thread_id = thread.thread_id
  let service = self.services.comments
  @comments_browser.ReviewZoneWidget::new(
    self.comment_zone_widget_host(),
    thread,
    {
      on_submit_new: body => service.submit_new_comment(thread_id, body),
      on_save_edit: (unique_id, body) => {
        service.update_comment(thread_id, unique_id, body)
      },
      on_delete: unique_id => service.delete_comment(thread_id, unique_id),
      on_collapse: () => self.collapse_comment_thread(thread_id),
    },
  )
}

///|
/// The `ICodeEditor` surface a zone widget consumes, closed over this viewer
/// (`ZoneWidgetHost` — the `PointerHandlerHelper` seam style).
fn Viewer::comment_zone_widget_host(
  self : Viewer,
) -> @zone_widget.ZoneWidgetHost {
  {
    add_zone: (id, anchor_view_line, height_px, node, on_top, on_height) => {
      self.change_view_zones(accessor => {
        accessor.add_zone(
          id,
          anchor_view_line,
          height_px,
          node,
          on_dom_node_top=on_top,
          on_computed_height=on_height,
        )
      })
    },
    remove_zone: id => {
      self.change_view_zones(accessor => accessor.remove_zone(id))
    },
    add_overlay_widget: (id, node) => self.add_overlay_widget(id, node),
    remove_overlay_widget: id => self.remove_overlay_widget(id),
    layout_width: () => self.get_layout_info().width,
    viewport_height: () => self.view_layout.dimensions().height,
    line_height: () => @core.editor_line_height,
  }
}

///|
/// Collapse from the widget (✕ / Escape): a still-empty template thread is
/// discarded (`ReviewZoneWidget.hide` deletes an empty thread); a real
/// thread collapses and keeps its glyph.
fn Viewer::collapse_comment_thread(self : Viewer, thread_id : String) -> Unit {
  match self.services.comments.thread_by_id(thread_id) {
    Some(thread) =>
      if thread.is_template && thread.comments.is_empty() {
        self.services.comments.discard_template(thread_id)
      } else {
        thread.collapsible_state = Collapsed
        self.sync_comments()
      }
    None => ()
  }
}

// --- mouse glue -----------------------------------------------------------

///|
/// The model line under a mouse target, for the comment gates (gutter
/// targets carry view lines).
fn Viewer::comments_target_model_line(
  self : Viewer,
  target : @viewer_common.MouseTarget,
) -> Int {
  guard target.line_number >= 1 else { return 0 }
  match self.view_model {
    Some(view_model) =>
      view_model.lines().model_line_number_of_view_line(target.line_number)
    None => target.line_number
  }
}

///|
/// `CommentController.onEditorMouseDown` (`commentsController.ts:1107`).
fn Viewer::on_comments_mouse_down(
  self : Viewer,
  target : @viewer_common.MouseTarget,
) -> Unit {
  guard self.text_model is Some(model) else { return }
  let service = self.services.comments
  let line = self.comments_target_model_line(target)
  self.comments.on_mouse_down(
    target.kind,
    target.gutter_offset_x,
    line,
    @comments.line_in_commenting_context(
      service.commenting_ranges(model.uri),
      service.threads(model.uri),
      line,
    ),
  )
}

///|
/// `CommentController.onEditorMouseUp` (`commentsController.ts:1111`) →
/// `addOrToggleCommentAtLine`.
fn Viewer::on_comments_mouse_up(
  self : Viewer,
  target : @viewer_common.MouseTarget,
) -> Unit {
  guard self.text_model is Some(model) else { return }
  let service = self.services.comments
  let line = self.comments_target_model_line(target)
  match
    self.comments.on_mouse_up(
      target.kind,
      line,
      @comments.line_in_commenting_context(
        service.commenting_ranges(model.uri),
        service.threads(model.uri),
        line,
      ),
    ) {
    Some(matched_line) => self.add_or_toggle_comment_at_line(matched_line)
    None => ()
  }
}

///|
/// `addOrToggleCommentAtLine` (`commentsController.ts:1151-1176`): a thread
/// at the line toggles expanded/collapsed; a bare commenting-range line
/// creates a template thread and focuses its form.
fn Viewer::add_or_toggle_comment_at_line(self : Viewer, line : Int) -> Unit {
  guard self.text_model is Some(model) else { return }
  let service = self.services.comments
  let threads = service.threads(model.uri)
  match threads.search_by(t => t.range.end_line_number == line) {
    Some(index) => {
      let thread = threads[index]
      if thread.collapsible_state == Expanded {
        self.collapse_comment_thread(thread.thread_id)
      } else {
        thread.collapsible_state = Expanded
        self.sync_comments()
      }
    }
    None => {
      let mut in_range = false
      for range in service.commenting_ranges(model.uri) {
        if range.start_line_number <= line && line <= range.end_line_number {
          in_range = true
          break
        }
      }
      if in_range {
        // Fires the threads-changed event; the subscription opens the widget
        // synchronously, so the form is focusable right after.
        let thread = service.create_thread_template(model.uri, line)
        match self.open_comment_widgets.get(thread.thread_id) {
          Some(widget) => widget.focus_form()
          None => ()
        }
      }
    }
  }
}

///|
/// `CommentController.onEditorMouseMove` → `updateHover`
/// (`commentsController.ts:626-633`): tracks the hovered model line and
/// re-syncs the range decorations when it changed (the "+" affordance).
fn Viewer::update_comment_hover(
  self : Viewer,
  target : @viewer_common.MouseTarget,
) -> Unit {
  let line = match target.kind {
    GutterLineNumbers | GutterLineDecorations | ContentText | ContentEmpty =>
      self.comments_target_model_line(target)
    _ => -1
  }
  if self.comments.update_hover(line) {
    self.sync_comment_decorations()
  }
}

///|
/// `CommentController.onEditorMouseLeave` (`commentsController.ts:622-624`).
fn Viewer::clear_comment_hover(self : Viewer) -> Unit {
  if self.comments.update_hover(-1) {
    self.sync_comment_decorations()
  }
}
