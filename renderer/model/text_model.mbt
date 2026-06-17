///|
/// Readonly editor model identity plus immutable text snapshot.
pub(all) struct TextModel {
  uri : @base_common.Uri
  display_name : String
  language_id : String
  version : Int
  revision : String
  snapshot : TextSnapshot
} derive(Debug)

///|
/// Builds a readonly text model and normalizes empty display name, language id,
/// and non-positive version inputs.
pub fn TextModel::TextModel(
  uri : @base_common.Uri,
  display_name : String,
  language_id : String,
  version : Int,
  revision : String,
  text : String,
) -> TextModel {
  let display_name = if display_name == "" {
    uri.to_string()
  } else {
    display_name
  }
  let language_id = if language_id == "" { "moonbit" } else { language_id }
  let version = if version < 1 { 1 } else { version }
  let snapshot = TextSnapshot(text, language_id~, version~)
  { uri, display_name, language_id, version, revision, snapshot }
}

///|
/// Returns the immutable snapshot consumed by tokenization, providers, and
/// rendering.
pub fn TextModel::snapshot(self : TextModel) -> TextSnapshot {
  self.snapshot
}

///|
/// Stable current-document identity guard used to drop stale async work.
pub fn TextModel::same_identity_and_version(
  self : TextModel,
  other : TextModel,
) -> Bool {
  self.uri.to_string() == other.uri.to_string() && self.version == other.version
}
