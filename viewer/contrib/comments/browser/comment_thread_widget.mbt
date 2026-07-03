// The comment thread's inner UI, a simplified port of
// `vscode/src/vs/workbench/contrib/comments/browser/commentThreadWidget.ts` +
// `commentThreadBody.ts` + `commentNode.ts`: a head (title, collapse), a body
// of comment nodes (author, timestamp, markdown body, edit/delete actions,
// edit mode as a textarea swap), and — only while the thread is a template —
// the new-comment form (`commentReply.ts`'s role for the *first* comment;
// threads with comments never offer a second one, replies are out of scope).
// Dropped: avatars, reactions, menus/context keys, the embedded
// SimpleCommentEditor (a plain `<textarea>` instead), ResizeObserver-driven
// resize (the widget reports `on_content_resized` after each content
// mutation instead — recorded deviation).

///|
/// The action closures the root glue wires to the comment service.
pub(all) struct CommentThreadWidgetHost {
  /// Submit the template thread's first comment (`CommentReply.submitComment`).
  on_submit_new : (String) -> Unit
  /// Save an edit: `(unique_id_in_thread, new_body)`.
  on_save_edit : (Int, String) -> Unit
  /// Delete a comment by `unique_id_in_thread`.
  on_delete : (Int) -> Unit
  /// Collapse the widget (head ✕ / Escape); on a template thread the glue
  /// discards it.
  on_collapse : () -> Unit
  /// Fired after every content re-render so the owner can re-measure and
  /// relayout the zone.
  on_content_resized : () -> Unit
}

///|
pub struct CommentThreadWidgetDom {
  host : CommentThreadWidgetHost
  root : @rdom.Element
  head : @rdom.Element
  body : @rdom.Element
  form : @rdom.Element
  mut thread : @comments_common.CommentThread
  mut editing_comment : Int?
  mut form_textarea : @rdom.Element?
  mut edit_textarea : @rdom.Element?
}

///|
pub fn CommentThreadWidgetDom::new(
  host : CommentThreadWidgetHost,
  thread : @comments_common.CommentThread,
) -> CommentThreadWidgetDom {
  let document = @rdom.document()
  let root = document.create_element("div")
  root.set_attribute("class", "review-widget")
  let head = document.create_element("div")
  head.set_attribute("class", "comment-thread-head")
  let body = document.create_element("div")
  body.set_attribute("class", "comment-thread-body")
  let form = document.create_element("div")
  form.set_attribute("class", "comment-thread-form")
  root.append_child(head.as_node())
  root.append_child(body.as_node())
  root.append_child(form.as_node())
  let widget : CommentThreadWidgetDom = {
    host,
    root,
    head,
    body,
    form,
    thread,
    editing_comment: None,
    form_textarea: None,
    edit_textarea: None,
  }
  widget.hook_containment()
  widget.render()
  widget
}

///|
pub fn CommentThreadWidgetDom::dom(
  self : CommentThreadWidgetDom,
) -> @rdom.Element {
  self.root
}

///|
/// Re-renders for an updated thread (service events drive this; in-progress
/// edit state survives when the edited comment still exists).
pub fn CommentThreadWidgetDom::update(
  self : CommentThreadWidgetDom,
  thread : @comments_common.CommentThread,
) -> Unit {
  self.thread = thread
  match self.editing_comment {
    Some(editing) =>
      if thread.comments.search_by(c => c.unique_id_in_thread == editing)
        is None {
        self.editing_comment = None
      }
    None => ()
  }
  self.render()
}

///|
/// Focuses the new-comment textarea (the glue calls this right after opening
/// a template thread, like VS Code focuses the reply editor).
pub fn CommentThreadWidgetDom::focus_form(
  self : CommentThreadWidgetDom,
) -> Unit {
  match self.form_textarea {
    Some(textarea) => focus_element(textarea)
    None => ()
  }
}

///|
/// Keeps widget interactions out of the editor: the root `mousedown` would
/// otherwise refocus the editor root and steal the textarea focus
/// (`input.mbt` root-refocus; folding-marker precedent), and every keystroke
/// while typing must not reach the editor's scroll/Escape keys. The hover
/// widget wires the same containment (`content_widgets.mbt`).
fn CommentThreadWidgetDom::hook_containment(
  self : CommentThreadWidgetDom,
) -> Unit {
  self.root.add_event_listener("mousedown", event => event.stop_propagation())
  self.root.add_event_listener("mouseup", event => event.stop_propagation())
  self.root.add_event_listener("click", event => event.stop_propagation())
  self.root.add_event_listener("contextmenu", event => event.stop_propagation())
  self.root.add_event_listener("keydown", event => {
    match event.to_keyboard_event() {
      Some(keyboard) => self.handle_keydown(event, keyboard)
      None => ()
    }
    event.stop_propagation()
  })
}

///|
/// Ctrl/Cmd+Enter submits (VS Code's `comments.submitComment` keybinding);
/// Escape cancels an edit, else collapses/discards the thread
/// (`editor.cancelComment`).
fn CommentThreadWidgetDom::handle_keydown(
  self : CommentThreadWidgetDom,
  event : @rdom.Event,
  keyboard : @rdom.KeyboardEvent,
) -> Unit {
  match keyboard.key() {
    "Enter" =>
      if keyboard.ctrl_key() || keyboard.meta_key() {
        event.prevent_default()
        match self.editing_comment {
          Some(editing) => self.save_edit(editing)
          None => if self.thread.is_template { self.submit_form() }
        }
      }
    "Escape" => {
      event.prevent_default()
      match self.editing_comment {
        Some(_) => {
          self.editing_comment = None
          self.render()
        }
        None => (self.host.on_collapse)()
      }
    }
    _ => ()
  }
}

///|
fn CommentThreadWidgetDom::submit_form(self : CommentThreadWidgetDom) -> Unit {
  guard self.form_textarea is Some(textarea) else { return }
  let body = textarea_value(textarea)
  if is_blank(body) {
    return
  }
  (self.host.on_submit_new)(body)
}

///|
fn CommentThreadWidgetDom::save_edit(
  self : CommentThreadWidgetDom,
  unique_id : Int,
) -> Unit {
  guard self.edit_textarea is Some(textarea) else { return }
  let body = textarea_value(textarea)
  if is_blank(body) {
    return
  }
  self.editing_comment = None
  (self.host.on_save_edit)(unique_id, body)
}

///|
fn CommentThreadWidgetDom::render(self : CommentThreadWidgetDom) -> Unit {
  self.render_head()
  self.render_body()
  self.render_form()
  (self.host.on_content_resized)()
}

///|
/// `CommentThreadHeader`: participant title + collapse action.
fn CommentThreadWidgetDom::render_head(self : CommentThreadWidgetDom) -> Unit {
  self.head.set_inner_html("")
  let document = @rdom.document()
  let title = document.create_element("span")
  title.set_attribute("class", "comment-thread-title")
  let text = match self.thread.comments.get(0) {
    Some(first) => "Comment — " + first.user_name
    // `CommentThreadHeader.createThreadLabel` falls back to "Start discussion".
    None => "Start discussion"
  }
  title.set_inner_html(escape_html(text))
  let collapse = document.create_element("button")
  collapse.set_attribute("type", "button")
  collapse.set_attribute("class", "comment-thread-collapse")
  collapse.set_attribute("title", "Collapse")
  collapse.set_attribute("data-comment-action", "collapse")
  collapse.set_inner_html("✕")
  collapse.add_event_listener("click", event => {
    event.prevent_default()
    event.stop_propagation()
    (self.host.on_collapse)()
  })
  self.head.append_child(title.as_node())
  self.head.append_child(collapse.as_node())
}

///|
/// `CommentThreadBody`: one node per comment.
fn CommentThreadWidgetDom::render_body(self : CommentThreadWidgetDom) -> Unit {
  self.body.set_inner_html("")
  self.edit_textarea = None
  for comment in self.thread.comments {
    self.body.append_child(self.render_comment(comment).as_node())
  }
}

///|
/// `CommentNode`: author + timestamp + markdown body + actions; edit mode
/// swaps the body for a textarea with Save/Cancel
/// (`CommentNode.switchToEditMode`).
fn CommentThreadWidgetDom::render_comment(
  self : CommentThreadWidgetDom,
  comment : @comments_common.Comment,
) -> @rdom.Element {
  let document = @rdom.document()
  let node = document.create_element("div")
  node.set_attribute("class", "review-comment")
  node.set_attribute("data-comment-id", comment.unique_id_in_thread.to_string())
  let title = document.create_element("div")
  title.set_attribute("class", "comment-title")
  let author = document.create_element("span")
  author.set_attribute("class", "comment-author")
  author.set_inner_html(escape_html(comment.user_name))
  title.append_child(author.as_node())
  match comment.timestamp {
    Some(timestamp) => {
      let stamp = document.create_element("span")
      stamp.set_attribute("class", "comment-timestamp")
      stamp.set_inner_html(escape_html(timestamp))
      title.append_child(stamp.as_node())
    }
    None => ()
  }
  let editing = self.editing_comment == Some(comment.unique_id_in_thread)
  if !editing {
    let actions = document.create_element("div")
    actions.set_attribute("class", "comment-actions")
    let edit = self.action_button("Edit", "edit", () => {
      self.editing_comment = Some(comment.unique_id_in_thread)
      self.render()
      match self.edit_textarea {
        Some(textarea) => focus_element(textarea)
        None => ()
      }
    })
    let delete = self.action_button("Delete", "delete", () => {
      (self.host.on_delete)(comment.unique_id_in_thread)
    })
    actions.append_child(edit.as_node())
    actions.append_child(delete.as_node())
    title.append_child(actions.as_node())
  }
  node.append_child(title.as_node())
  if editing {
    let edit_area = document.create_element("div")
    edit_area.set_attribute("class", "comment-edit")
    let textarea = document.create_element("textarea")
    textarea.set_attribute("class", "comment-textarea")
    textarea.set_attribute("data-comment-edit", "true")
    set_textarea_value(textarea, comment.body)
    self.edit_textarea = Some(textarea)
    let actions = document.create_element("div")
    actions.set_attribute("class", "comment-form-actions")
    let save = self.primary_button("Save", "save", () => {
      self.save_edit(comment.unique_id_in_thread)
    })
    let cancel = self.action_button("Cancel", "cancel-edit", () => {
      self.editing_comment = None
      self.render()
    })
    actions.append_child(save.as_node())
    actions.append_child(cancel.as_node())
    edit_area.append_child(textarea.as_node())
    edit_area.append_child(actions.as_node())
    node.append_child(edit_area.as_node())
  } else {
    let body = document.create_element("div")
    body.set_attribute("class", "comment-body")
    body.set_inner_html(comment_markdown_html(comment.body))
    node.append_child(body.as_node())
  }
  node
}

///|
/// The new-comment form, rendered only while the thread is a template.
fn CommentThreadWidgetDom::render_form(self : CommentThreadWidgetDom) -> Unit {
  self.form.set_inner_html("")
  self.form_textarea = None
  if !self.thread.is_template {
    return
  }
  let document = @rdom.document()
  let textarea = document.create_element("textarea")
  textarea.set_attribute("class", "comment-textarea")
  textarea.set_attribute("placeholder", "Write a comment…")
  textarea.set_attribute("data-comment-form", "true")
  self.form_textarea = Some(textarea)
  let actions = document.create_element("div")
  actions.set_attribute("class", "comment-form-actions")
  let submit = self.primary_button("Comment", "submit", () => self.submit_form())
  actions.append_child(submit.as_node())
  self.form.append_child(textarea.as_node())
  self.form.append_child(actions.as_node())
}

///|
fn CommentThreadWidgetDom::action_button(
  self : CommentThreadWidgetDom,
  label : String,
  action : String,
  run : () -> Unit,
) -> @rdom.Element {
  ignore(self)
  let button = @rdom.document().create_element("button")
  button.set_attribute("type", "button")
  button.set_attribute("class", "comment-action")
  button.set_attribute("data-comment-action", action)
  button.set_inner_html(escape_html(label))
  button.add_event_listener("click", event => {
    event.prevent_default()
    event.stop_propagation()
    run()
  })
  button
}

///|
fn CommentThreadWidgetDom::primary_button(
  self : CommentThreadWidgetDom,
  label : String,
  action : String,
  run : () -> Unit,
) -> @rdom.Element {
  let button = self.action_button(label, action, run)
  button.set_attribute("class", "comment-action comment-action-primary")
  button
}

// --- markdown / text helpers ---------------------------------------------------

///|
/// Comment bodies render through the same safe cmark pipeline the hover
/// uses (`hover_render.mbt`), minus the tokenized code-block override (no
/// language registry down here).
fn comment_markdown_html(markdown : String) -> String {
  let doc = @cmark.Doc::from_string(markdown, strict=false)
  @cmark_html.renderer(safe=true).doc_to_string(doc) catch {
    _ => "<p>" + escape_html(markdown) + "</p>"
  }
}

///|
fn escape_html(text : String) -> String {
  let out = StringBuilder::new()
  for ch in text {
    match ch {
      '&' => out.write_string("&amp;")
      '<' => out.write_string("&lt;")
      '>' => out.write_string("&gt;")
      '"' => out.write_string("&quot;")
      _ => out.write_char(ch)
    }
  }
  out.to_string()
}

///|
fn is_blank(text : String) -> Bool {
  for ch in text {
    if ch != ' ' && ch != '\t' && ch != '\n' && ch != '\r' {
      return false
    }
  }
  true
}

///|
/// FFI gap-fills (no textarea value / focus bindings in the vendored
/// `@rdom`), following the `viewer/input.mbt` extern pattern.
extern "js" fn textarea_value(element : @rdom.Element) -> String = "(el) => el.value ?? ''"

///|
extern "js" fn set_textarea_value(
  element : @rdom.Element,
  value : String,
) -> Unit = "(el, v) => { el.value = v }"

///|
extern "js" fn focus_element(element : @rdom.Element) -> Unit =
  #| (el) => el.focus?.({ preventScroll: true })
