///|
pub(all) struct DocumentUri {
  value : String
} derive(Eq, Debug)

///|
pub(all) struct SourcePath {
  value : String
} derive(Eq, Debug)

///|
pub(all) struct SourceDocument {
  uri : DocumentUri
  display_name : String
  language_id : String
  version : Int
  revision : String
  text : String
} derive(Debug)

///|
pub(all) enum SourceError {
  MissingPath
  InvalidPath
  SourceInvalidUri
} derive(Eq, Debug)

///|
pub fn SourceError::to_string(self : SourceError) -> String {
  match self {
    MissingPath => "MissingPath"
    InvalidPath => "InvalidPath"
    SourceInvalidUri => "InvalidUri"
  }
}

///|
pub(all) enum DocumentUriResult {
  ParsedDocumentUri(DocumentUri)
  DocumentUriError(SourceError)
} derive(Eq, Debug)

///|
pub(all) enum SourcePathResult {
  ParsedSourcePath(SourcePath)
  SourcePathError(SourceError)
} derive(Eq, Debug)

///|
pub fn DocumentUri::parse(value : String) -> DocumentUriResult {
  match value.find("://") {
    Some(index) =>
      if is_valid_uri_scheme(value, index) && index + 3 < value.length() {
        ParsedDocumentUri({ value, })
      } else {
        DocumentUriError(SourceInvalidUri)
      }
    None => DocumentUriError(SourceInvalidUri)
  }
}

///|
pub fn DocumentUri::memory(name : String) -> DocumentUri {
  let name = if name == "" {
    "document"
  } else {
    name.replace_all(old="\\", new="/")
  }
  { value: "memory://" + name }
}

///|
pub fn DocumentUri::to_string(self : DocumentUri) -> String {
  self.value
}

///|
pub fn DocumentUri::scheme(self : DocumentUri) -> String {
  match self.value.find("://") {
    Some(index) => self.value[0:index].to_owned()
    None => ""
  }
}

///|
pub fn DocumentUri::path(self : DocumentUri) -> String {
  match self.value.find("://") {
    Some(index) => {
      let rest = self.value[index + 3:]
      match rest.find("/") {
        Some(path_index) => rest[path_index + 1:].to_owned()
        None => ""
      }
    }
    None => ""
  }
}

///|
pub fn DocumentUri::display_name(self : DocumentUri) -> String {
  let path = self.path()
  if path == "" {
    self.to_string()
  } else {
    let segments = path.split("/")
    let mut found = path
    for segment_view in segments {
      let segment = segment_view.to_owned()
      if segment != "" {
        found = segment
      }
    }
    found
  }
}

///|
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
pub fn SourcePath::to_string(self : SourcePath) -> String {
  self.value
}

///|
pub fn SourcePath::display_name(self : SourcePath) -> String {
  self.value
}

///|
pub fn SourcePath::file_uri(self : SourcePath) -> DocumentUri {
  { value: "file://local/" + self.value }
}

///|
pub fn SourceDocument::SourceDocument(
  uri : DocumentUri,
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
pub fn SourceDocument::snapshot(
  self : SourceDocument,
) -> @core.DocumentSnapshot {
  DocumentSnapshot(
    self.text,
    language_id=self.language_id,
    version=self.version,
  )
}

///|
pub fn SourceDocument::to_json(self : SourceDocument) -> String {
  let mut out = "{"
  out = out + "\"uri\":" + json_string(self.uri.to_string())
  out = out + ",\"displayName\":" + json_string(self.display_name)
  out = out + ",\"languageId\":" + json_string(self.language_id)
  out = out + ",\"version\":" + self.version.to_string()
  out = out + ",\"revision\":" + json_string(self.revision)
  out = out + ",\"text\":" + json_string(self.text)
  out + "}"
}

///|
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
fn is_valid_uri_scheme(value : String, end : Int) -> Bool {
  if end == 0 || !is_ascii_alpha(value[0].to_int()) {
    return false
  }
  for i in 1..<end {
    let unit = value[i].to_int()
    if !is_ascii_alpha(unit) &&
      !is_digit(unit) &&
      unit != 43 &&
      unit != 45 &&
      unit != 46 {
      return false
    }
  }
  true
}

///|
fn is_ascii_alpha(unit : Int) -> Bool {
  (65 <= unit && unit <= 90) || (97 <= unit && unit <= 122)
}

///|
fn is_digit(unit : Int) -> Bool {
  48 <= unit && unit <= 57
}

///|
fn json_string(value : String) -> String {
  let mut out = "\""
  for i in 0..<value.length() {
    let unit = value[i].to_int()
    if unit == 34 {
      out = out + "\\\""
    } else if unit == 92 {
      out = out + "\\\\"
    } else if unit == 10 {
      out = out + "\\n"
    } else if unit == 13 {
      out = out + "\\r"
    } else if unit == 9 {
      out = out + "\\t"
    } else {
      out = out + value[i:i + 1].to_owned()
    }
  }
  out + "\""
}
