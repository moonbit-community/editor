///|
/// Root-relative source path accepted from UI or protocol input after
/// normalization rejects absolute paths, parent traversal, and NUL bytes.
pub(all) struct SourcePath {
  value : String
} derive(Eq, Debug)

///|
/// Versioned readonly document passed from workspace providers into renderer
/// and language-feature packages.
pub(all) struct SourceDocument {
  uri : @base_common.Uri
  display_name : String
  language_id : String
  version : Int
  revision : String
  text : String
} derive(Debug)

///|
/// Validation failures for user-facing source paths and document URIs.
pub(all) enum SourceError {
  MissingPath
  InvalidPath
} derive(Eq, Debug)

///|
/// Stable protocol/debug label for source validation failures.
pub fn SourceError::to_string(self : SourceError) -> String {
  match self {
    MissingPath => "MissingPath"
    InvalidPath => "InvalidPath"
  }
}

///|
/// Result wrapper used instead of raising while normalizing source paths.
pub(all) enum SourcePathResult {
  ParsedSourcePath(SourcePath)
  SourcePathError(SourceError)
} derive(Eq, Debug)

///|
/// Normalizes a user-provided workspace path into a safe root-relative path.
pub fn SourcePath::normalize_root_relative_path(
  raw_path : String,
) -> SourcePathResult {
  if raw_path == "" {
    return SourcePathError(MissingPath)
  }
  if contains_null(raw_path) {
    return SourcePathError(InvalidPath)
  }
  let slash_path = raw_path.replace_all(old="\\", new="/")
  if slash_path.has_prefix("/") ||
    slash_path.has_prefix("//") ||
    is_windows_drive_path(slash_path) {
    return SourcePathError(InvalidPath)
  }

  let segments = []
  for segment_view in slash_path.split("/") {
    let segment = segment_view.to_owned()
    if segment == ".." {
      return SourcePathError(InvalidPath)
    }
    if segment != "" && segment != "." {
      segments.push(segment)
    }
  }
  if segments.length() == 0 {
    return SourcePathError(InvalidPath)
  }

  let mut normalized = segments[0]
  for i in 1..<segments.length() {
    normalized = normalized + "/" + segments[i]
  }
  ParsedSourcePath({ value: normalized })
}

///|
/// Returns the normalized root-relative path string.
pub fn SourcePath::to_string(self : SourcePath) -> String {
  self.value
}

///|
/// Display label for a source path; currently the normalized path itself.
pub fn SourcePath::display_name(self : SourcePath) -> String {
  self.value
}

///|
/// Converts a normalized source path to the local file URI convention used by
/// simple embedders.
pub fn SourcePath::file_uri(self : SourcePath) -> @base_common.Uri {
  match @base_common.Uri::parse("file://local/" + self.value) {
    ParsedUri(uri) => uri
    UriError(_) => @base_common.Uri::memory(self.value)
  }
}

///|
/// Builds a document and normalizes empty display name, empty language id, and
/// non-positive version inputs.
pub fn SourceDocument::SourceDocument(
  uri : @base_common.Uri,
  display_name : String,
  language_id : String,
  version : Int,
  revision : String,
  text : String,
) -> SourceDocument {
  let display_name = if display_name == "" {
    uri.to_string()
  } else {
    display_name
  }
  let language_id = if language_id == "" {
    infer_language_id(display_name)
  } else {
    language_id
  }
  let version = if version < 1 { 1 } else { version }
  { uri, display_name, language_id, version, revision, text }
}

///|
/// Converts workspace document text into the model snapshot consumed by
/// renderer and language providers.
pub fn SourceDocument::snapshot(self : SourceDocument) -> @model.TextSnapshot {
  TextSnapshot(self.text, language_id=self.language_id, version=self.version)
}

///|
/// Converts workspace provider payload into the readonly editor model.
pub fn SourceDocument::text_model(self : SourceDocument) -> @model.TextModel {
  TextModel(
    self.uri,
    self.display_name,
    self.language_id,
    self.version,
    self.revision,
    self.text,
  )
}

///|
/// JSON shape emitted to browser harnesses and remote protocol adapters.
pub impl ToJson for SourceDocument with fn to_json(self) {
  {
    "uri": self.uri.to_string().to_json(),
    "displayName": self.display_name.to_json(),
    "languageId": self.language_id.to_json(),
    "version": self.version.to_json(),
    "revision": self.revision.to_json(),
    "text": self.text.to_json(),
  }
}

///|
/// Maps common source extensions to the language ids used by tokenizer and
/// feature registries.
pub fn infer_language_id(path_or_name : String) -> String {
  if path_or_name.has_suffix(".mbt") || path_or_name.has_suffix(".mbt.md") {
    "moonbit"
  } else if path_or_name.has_suffix(".js") || path_or_name.has_suffix(".mjs") {
    "javascript"
  } else if path_or_name.has_suffix(".ts") {
    "typescript"
  } else if path_or_name.has_suffix(".json") {
    "json"
  } else if path_or_name.has_suffix(".md") {
    "markdown"
  } else if path_or_name.has_suffix(".css") {
    "css"
  } else if path_or_name.has_suffix(".html") {
    "html"
  } else if path_or_name.has_suffix(".txt") {
    "plaintext"
  } else {
    "moonbit"
  }
}

///|
fn contains_null(value : String) -> Bool {
  for i in 0..<value.length() {
    if value[i].to_int() == 0 {
      return true
    }
  }
  false
}

///|
fn is_windows_drive_path(path : String) -> Bool {
  path.length() >= 2 &&
  is_ascii_alpha(path[0].to_int()) &&
  path[1].to_int() == 58
}

///|
fn is_ascii_alpha(unit : Int) -> Bool {
  (65 <= unit && unit <= 90) || (97 <= unit && unit <= 122)
}
