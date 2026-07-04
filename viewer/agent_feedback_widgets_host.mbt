// The viewer core's side of the feedback bubble contribution — the editor
// lifecycle of `AgentFeedbackEditorWidgetContribution`
// (`vscode/src/vs/sessions/contrib/agentFeedback/browser/
// agentFeedbackEditorWidgetContribution.ts:1034-1311`): the
// feedback-change/navigation subscriptions, the group → widget rebuild in
// reverse file order, the right-edge layout (`AgentFeedbackEditorWidget.
// layout`), the one-expanded-per-file rule, the navigation expand/reveal
// (`_handleNavigation`), the item-hover range highlight (the widget's
// `_highlightRange`, homed here because it touches the model), and the
// reply-draft capture/prune across rebuilds. The widget DOM lives in
// `viewer/contrib/agent_feedback/browser`. Kept here per the foreign-method
// rule. Deviations: the highlight skips the overview-ruler companion
// decoration (no overview ruler yet), `getMinContentWidthInPx` is not
// ported (overlay widgets don't feed the scroll width), and rebuilds ride
// the feedback-change event only (the upstream observable also re-read PR
// review state).

///|
/// `registerEditorContribution(AgentFeedbackEditorWidgetContribution.ID, …,
/// Eventually)`.
fn register_agent_feedback_widgets_contribution(
  registry : EditorContributionRegistry,
) -> Unit {
  registry.register_editor_contribution(
    "agentFeedback.editorWidgetContribution",
    Eventually,
    viewer => {
      let subscriptions = viewer.hook_agent_feedback_widgets()
      {
        id: "agentFeedback.editorWidgetContribution",
        dispose: () => {
          viewer.clear_agent_feedback_widgets() |> ignore
          for subscription in subscriptions {
            subscription.dispose()
          }
        },
      }
    },
  )
}

///|
/// The constructor-time wiring of `AgentFeedbackEditorWidgetContribution`:
/// rebuild on feedback/model changes, expand/reveal on navigation changes,
/// relayout on scroll.
fn Viewer::hook_agent_feedback_widgets(
  self : Viewer,
) -> Array[@base_common.Disposable] {
  self.rebuild_agent_feedback_widgets()
  [
    self.services.agent_feedback.on_did_change_feedback(event => {
      if self.is_current_resource(event.resource) {
        self.rebuild_agent_feedback_widgets()
        self.handle_agent_feedback_navigation()
      }
    }),
    self.services.agent_feedback.on_did_change_navigation(resource => {
      if self.is_current_resource(resource) {
        self.handle_agent_feedback_navigation()
      }
    }),
    self.on_did_change_model(_ => self.rebuild_agent_feedback_widgets()),
    self.on_did_scroll_change(_ => self.relayout_agent_feedback_widgets()),
  ]
}

///|
/// `_clearWidgets`: snapshot which reply composer holds focus (its blur
/// fires during teardown and would clear the state), then dispose every
/// widget. Returns the snapshot for the rebuild.
fn Viewer::clear_agent_feedback_widgets(self : Viewer) -> String? {
  let mut focused_reply : String? = None
  for widget in self.agent_feedback_widgets {
    if focused_reply is None {
      focused_reply = widget.focused_reply_comment_id()
    }
    widget.mark_disposed()
    self.remove_overlay_widget(widget.widget_id())
  }
  self.agent_feedback_widgets.clear()
  self.clear_agent_feedback_highlight()
  focused_reply
}

///|
/// `_rebuildWidgets`: group the resource's comments and mount one bubble per
/// group, in reverse file order so widgets further up the file render on
/// top. Widget DOM is only built while a real view is attached (the
/// comments contrib's `sync_comments` gate).
fn Viewer::rebuild_agent_feedback_widgets(self : Viewer) -> Unit {
  let focused_reply = self.clear_agent_feedback_widgets()
  guard self.view is Some(_) && self.text_model is Some(model) else { return }
  let comments = @agent_feedback.get_editor_comments(
    self.services.agent_feedback.get_feedback(model.uri),
  )
  if comments.is_empty() {
    self.prune_agent_feedback_reply_drafts()
    return
  }
  let groups = @agent_feedback.group_nearby_editor_comments(comments)
  for index = groups.length() - 1; index >= 0; index = index - 1 {
    let group = groups[index]
    let widget_id = "agent-feedback-widget-" +
      self.agent_feedback_widget_id_pool.to_string()
    self.agent_feedback_widget_id_pool += 1
    let widget = @agent_feedback_browser.AgentFeedbackEditorWidget::new(
      self.agent_feedback_widget_host(),
      widget_id,
      group,
      self.agent_feedback_reply_drafts,
      focused_reply?,
    )
    self.agent_feedback_widgets.push(widget)
    self.add_overlay_widget(widget_id, widget.dom())
    self.layout_agent_feedback_widget(widget, group[0].range.start_line_number)
  }
  self.prune_agent_feedback_reply_drafts()
}

///|
/// The widget-facing seam, closed over this viewer: service mutations plus
/// navigation/highlight/layout callbacks.
fn Viewer::agent_feedback_widget_host(
  self : Viewer,
) -> @agent_feedback_browser.AgentFeedbackEditorWidgetHost {
  let service = self.services.agent_feedback
  {
    on_remove: comment => {
      service.remove_feedback(comment.resource, comment.source_id)
    },
    on_accept: comment => {
      service.accept_feedback(comment.resource, comment.source_id)
      service.set_navigation_anchor(comment.resource, Some(comment.id))
    },
    on_edit: (comment, text) => {
      service.update_feedback(comment.resource, comment.source_id, text)
    },
    on_reply: (comment, text) => {
      service.add_reply(comment.resource, comment.source_id, text)
    },
    // The navigation event expands the containing widget and reveals the
    // range (`_handleNavigation`); the click itself only anchors.
    on_click: comment => {
      service.set_navigation_anchor(comment.resource, Some(comment.id))
    },
    on_hover: comment => self.highlight_agent_feedback_range(comment),
    on_hover_end: () => self.clear_agent_feedback_highlight(),
    // One expanded widget per file: expanding one collapses the others.
    on_did_expand: widget_id => {
      for other in self.agent_feedback_widgets {
        if other.widget_id() != widget_id && other.is_expanded() {
          other.collapse()
        }
      }
    },
    on_layout: widget_id => {
      for widget in self.agent_feedback_widgets {
        if widget.widget_id() == widget_id {
          self.layout_agent_feedback_widget(widget, widget.anchor_line())
          break
        }
      }
    },
  }
}

///|
/// `AgentFeedbackEditorWidget.layout`: align the header center with the
/// anchor line's center, clamp into the scrollable content, and pin to the
/// right edge of the content area (two scrollbar widths in from it).
fn Viewer::layout_agent_feedback_widget(
  self : Viewer,
  widget : @agent_feedback_browser.AgentFeedbackEditorWidget,
  start_line : Int,
) -> Unit {
  widget.set_anchor_line(start_line)
  let line_height = @core.editor_line_height.to_double()
  let layout = self.get_layout_info()
  let scroll_top = self.get_scroll_top()
  let scroll_height = self.get_scroll_height()
  let top_for_line = self.get_top_for_line_number(start_line)
  guard scroll_top >= 0.0 && scroll_height >= 0.0 && top_for_line >= 0.0 else {
    return
  }
  let widget_height = widget.measured_height()
  let mut header_height = widget.measured_header_height()
  if header_height <= 0.0 {
    header_height = line_height
  }
  let content_top = top_for_line + (line_height - header_height) / 2.0
  let mut max_top = scroll_height - widget_height
  if max_top < 0.0 {
    max_top = 0.0
  }
  let mut clamped_top = content_top
  if clamped_top < 0.0 {
    clamped_top = 0.0
  }
  if clamped_top > max_top {
    clamped_top = max_top
  }
  let left = layout.content_left +
    layout.content_width -
    (2.0 * @core.editor_vertical_scrollbar_size + widget.measured_width())
  widget.set_position(clamped_top - scroll_top, left)
}

///|
fn Viewer::relayout_agent_feedback_widgets(self : Viewer) -> Unit {
  for widget in self.agent_feedback_widgets {
    self.layout_agent_feedback_widget(widget, widget.anchor_line())
  }
}

///|
/// `_handleNavigation`: expand the widget containing the anchored comment,
/// collapse the rest, focus the item, and reveal its range.
fn Viewer::handle_agent_feedback_navigation(self : Viewer) -> Unit {
  guard self.view is Some(_) && self.text_model is Some(model) else { return }
  let comments = @agent_feedback.get_editor_comments(
    self.services.agent_feedback.get_feedback(model.uri),
  )
  let bearing = self.services.agent_feedback.get_navigation_bearing(
    model.uri,
    comments.map(comment => comment.id),
  )
  guard bearing.active_idx >= 0 else { return }
  let active = comments[bearing.active_idx]
  for widget in self.agent_feedback_widgets {
    if widget.contains_feedback(active.id) {
      widget.expand()
      widget.focus_feedback(active.id)
    } else {
      widget.collapse()
    }
  }
  self.reveal_range_in_center_if_outside_viewport(
    Range(active.range.start_line_number, 1, active.range.end_line_number, 1),
  )
}

///|
/// The widget's `_highlightRange`: a whole-line `rangeHighlight` over the
/// comment's lines plus the modified-style gutter bar (the overview-ruler
/// companion decoration is skipped — no overview ruler).
fn Viewer::highlight_agent_feedback_range(
  self : Viewer,
  comment : @agent_feedback.EditorComment,
) -> Unit {
  guard self.text_model is Some(model) else { return }
  let line_count = model.snapshot.line_count()
  let end_line = @base_common.clamp_int(
    comment.range.end_line_number,
    1,
    line_count,
  )
  let start_line = @base_common.clamp_int(
    comment.range.start_line_number,
    1,
    end_line,
  )
  let max_column = model.snapshot.line_text(end_line - 1).length() + 1
  self.agent_feedback_highlight_decoration_ids = model.delta_decorations(
    self.agent_feedback_highlight_decoration_ids,
    [
      {
        range: Range(start_line, 1, end_line, max_column),
        options: Decoration(
          "rangeHighlight",
          is_whole_line=true,
          lines_decorations_class_name="agent-feedback-widget-range-glyph",
          description="agent-feedback-range-highlight",
        ),
      },
    ],
    owner_id=self.editor_id,
  )
}

///|
fn Viewer::clear_agent_feedback_highlight(self : Viewer) -> Unit {
  if self.agent_feedback_highlight_decoration_ids.is_empty() {
    return
  }
  guard self.text_model is Some(model) else {
    self.agent_feedback_highlight_decoration_ids = []
    return
  }
  self.agent_feedback_highlight_decoration_ids = model.delta_decorations(
    self.agent_feedback_highlight_decoration_ids,
    [],
    owner_id=self.editor_id,
  )
}

///|
/// `_pruneOrphanedReplyDrafts`: drop drafts for comments no widget renders.
fn Viewer::prune_agent_feedback_reply_drafts(self : Viewer) -> Unit {
  if self.agent_feedback_reply_drafts.is_empty() {
    return
  }
  let known : Map[String, Bool] = {}
  for widget in self.agent_feedback_widgets {
    for comment_id in widget.comment_ids() {
      known.set(comment_id, true)
    }
  }
  let orphaned : Array[String] = []
  for comment_id, _ in self.agent_feedback_reply_drafts {
    if known.get(comment_id) is None {
      orphaned.push(comment_id)
    }
  }
  for comment_id in orphaned {
    self.agent_feedback_reply_drafts.remove(comment_id)
  }
}
