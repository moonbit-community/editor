///|
pub(all) struct Selection {
  anchor : @core.Position
  focus : @core.Position
} derive(Eq, Debug)

///|
pub fn Selection::Selection(
  anchor : @core.Position,
  focus : @core.Position,
) -> Selection {
  { anchor, focus }
}

///|
pub fn Selection::from_offsets(
  snapshot : @core.DocumentSnapshot,
  anchor_offset : Int,
  focus_offset : Int,
) -> Selection {
  Selection(
    snapshot.position_at_offset(anchor_offset),
    snapshot.position_at_offset(focus_offset),
  )
}

///|
pub fn Selection::normalized_range(
  self : Selection,
  snapshot : @core.DocumentSnapshot,
) -> @core.Range {
  let anchor = snapshot.offset_at_position(self.anchor)
  let focus = snapshot.offset_at_position(self.focus)
  if anchor <= focus {
    Range(anchor, focus)
  } else {
    Range(focus, anchor)
  }
}

///|
pub fn Selection::is_empty(
  self : Selection,
  snapshot : @core.DocumentSnapshot,
) -> Bool {
  self.normalized_range(snapshot).is_empty()
}

///|
pub fn Selection::get_plain_text_to_copy(
  self : Selection,
  snapshot : @core.DocumentSnapshot,
) -> String {
  snapshot.slice(self.normalized_range(snapshot))
}

///|
pub fn Selection::get_rich_text_to_copy(
  self : Selection,
  snapshot : @core.DocumentSnapshot,
) -> String {
  "<pre class=\"readonly-editor-copy\">" +
  escape_copy_html(self.get_plain_text_to_copy(snapshot)) +
  "</pre>"
}

///|
fn escape_copy_html(text : String) -> String {
  let out = StringBuilder()
  for ch in text {
    match ch {
      '<' => out.write_string("&lt;")
      '>' => out.write_string("&gt;")
      '&' => out.write_string("&amp;")
      '"' => out.write_string("&quot;")
      _ => out.write_char(ch)
    }
  }
  out.to_string()
}
