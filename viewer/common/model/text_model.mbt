///|
/// Readonly editor model identity plus immutable text snapshot, plus the
/// Monaco decoration storage cluster (`decorations_state` — the one mutable
/// part; see `text_model_decorations.mbt`).
pub(all) struct TextModel {
  uri : @base_common.Uri
  display_name : String
  language_id : String
  version : Int
  revision : String
  snapshot : TextSnapshot
  decorations_state : DecorationsState
} derive(Debug)

///|
/// Builds a readonly text model.
///
/// `version` is the editor-model freshness guard: hosts should increment it
/// whenever they install new content for the same URI. `revision` is optional
/// source metadata such as a remote provider revision or content hash.
/// Empty display name and language id are normalized; non-positive versions
/// become version 1.
pub fn TextModel::TextModel(
  uri : @base_common.Uri,
  display_name : String,
  language_id : String,
  version : Int,
  revision : String,
  text : String,
  log_service? : @log.LogService = @log.LogService::new(),
) -> TextModel {
  let display_name = if display_name == "" {
    uri.to_string()
  } else {
    display_name
  }
  let language_id = if language_id == "" { "moonbit" } else { language_id }
  let version = if version < 1 { 1 } else { version }
  let snapshot = TextSnapshot(text, language_id~, version~)
  {
    uri,
    display_name,
    language_id,
    version,
    revision,
    snapshot,
    decorations_state: DecorationsState::new(log_service),
  }
}

///|
/// Returns the immutable snapshot consumed by tokenization, providers, and
/// rendering.
pub fn TextModel::snapshot(self : TextModel) -> TextSnapshot {
  self.snapshot
}

///|
/// Stable current-model identity guard used to drop stale async work.
/// URI and model version decide freshness; source revisions are metadata.
pub fn TextModel::same_identity_and_version(
  self : TextModel,
  other : TextModel,
) -> Bool {
  self.uri.to_string() == other.uri.to_string() && self.version == other.version
}
