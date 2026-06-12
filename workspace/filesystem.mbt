///|
pub(all) enum FileSystemProviderErrorCode {
  FileNotFound
  FileExists
  FileNotADirectory
  IsDirectory
  NoPermissions
  Unavailable
  InvalidUri
  InvalidData
} derive(Eq, Debug)

///|
pub(all) struct FileSystemProviderError {
  code : FileSystemProviderErrorCode
  message : String
  uri : DocumentUri?
} derive(Debug)

///|
pub(all) struct FileContent {
  text : String
  display_name : String
  language_id : String
  revision : String
} derive(Debug)

///|
pub(all) enum FileReadResult {
  FileReadOk(FileContent)
  FileReadError(FileSystemProviderError)
} derive(Debug)

///|
pub(all) enum FileChangeType {
  Created
  Changed
  Deleted
} derive(Eq, Debug)

///|
pub(all) struct FileChange {
  uri : DocumentUri
  change_type : FileChangeType
} derive(Debug)

///|
pub(all) struct WatchOptions {
  recursive : Bool
  excludes : Array[String]
} derive(Debug)

///|
pub(all) struct FileWatch {
  dispose : () -> Unit
}

///|
pub(open) trait FileSystemProvider {
  fn scheme(Self) -> String
  async fn read_file(Self, DocumentUri) -> FileReadResult
  fn watch(Self, DocumentUri, WatchOptions, (Array[FileChange]) -> Unit) -> FileWatch
}

///|
pub(all) enum SourceDocumentLoadResult {
  SourceDocumentLoaded(SourceDocument)
  SourceDocumentLoadError(FileSystemProviderError)
} derive(Debug)

///|
pub fn FileContent::FileContent(
  text : String,
  display_name? : String = "",
  language_id? : String = "",
  revision? : String = "",
) -> FileContent {
  { text, display_name, language_id, revision }
}

///|
pub fn FileSystemProviderError::FileSystemProviderError(
  code : FileSystemProviderErrorCode,
  message : String,
  uri? : DocumentUri,
) -> FileSystemProviderError {
  let message = if message == "" { code.to_string() } else { message }
  { code, message, uri }
}

///|
pub fn WatchOptions::default() -> WatchOptions {
  { recursive: false, excludes: [] }
}

///|
pub fn FileWatch::dispose(self : FileWatch) -> Unit {
  (self.dispose)()
}

///|
pub async fn read_source_document(
  provider : &FileSystemProvider,
  uri : DocumentUri,
) -> SourceDocumentLoadResult {
  if uri.scheme() != provider.scheme() {
    return SourceDocumentLoadError(
      FileSystemProviderError(
        InvalidUri,
        "No filesystem provider is registered for URI scheme " + uri.scheme(),
        uri~,
      ),
    )
  }
  match provider.read_file(uri) {
    FileReadOk(content) =>
      SourceDocumentLoaded(SourceDocument::from_file_content(uri, content))
    FileReadError(error) => SourceDocumentLoadError(error)
  }
}

///|
pub fn watch_file(
  provider : &FileSystemProvider,
  uri : DocumentUri,
  listener : (Array[FileChange]) -> Unit,
) -> FileWatch {
  if uri.scheme() == provider.scheme() {
    provider.watch(uri, WatchOptions::default(), listener)
  } else {
    { dispose: () => () }
  }
}

///|
pub fn SourceDocument::from_file_content(
  uri : DocumentUri,
  content : FileContent,
) -> SourceDocument {
  let display_name = if content.display_name == "" {
    uri.display_name()
  } else {
    content.display_name
  }
  let language_id = if content.language_id == "" {
    infer_language_id(display_name)
  } else {
    content.language_id
  }
  let revision = if content.revision == "" {
    revision_from_text(content.text)
  } else {
    content.revision
  }
  SourceDocument(uri, display_name, language_id, 1, revision, content.text)
}

///|
pub impl ToJson for SourceDocumentLoadResult with fn to_json(self) {
  match self {
    SourceDocumentLoaded(document) =>
      { "ok": true, "document": document.to_json() }
    SourceDocumentLoadError(error) => { "ok": false, "error": error.to_json() }
  }
}

///|
pub impl ToJson for FileSystemProviderError with fn to_json(self) {
  let fields : Map[String, Json] = {
    "code": self.code.to_string().to_json(),
    "message": self.message.to_json(),
    "status": self.status().to_json(),
  }
  match self.uri {
    Some(uri) => {
      fields["uri"] = uri.to_string().to_json()
      fields["displayName"] = uri.display_name().to_json()
    }
    None => ()
  }
  Json::object(fields)
}

///|
pub fn FileSystemProviderError::status(self : FileSystemProviderError) -> Int {
  match self.code {
    FileNotFound => 404
    FileExists => 409
    FileNotADirectory => 400
    IsDirectory => 400
    NoPermissions => 403
    Unavailable => 503
    InvalidUri => 400
    InvalidData => 415
  }
}

///|
pub fn FileSystemProviderErrorCode::to_string(
  self : FileSystemProviderErrorCode,
) -> String {
  match self {
    FileNotFound => "FileNotFound"
    FileExists => "FileExists"
    FileNotADirectory => "FileNotADirectory"
    IsDirectory => "IsDirectory"
    NoPermissions => "NoPermissions"
    Unavailable => "Unavailable"
    InvalidUri => "InvalidUri"
    InvalidData => "InvalidData"
  }
}

///|
pub fn FileSystemProviderErrorCode::from_string(
  code : String,
) -> FileSystemProviderErrorCode {
  match code {
    "FileNotFound" => FileNotFound
    "FileExists" => FileExists
    "FileNotADirectory" => FileNotADirectory
    "IsDirectory" => IsDirectory
    "NoPermissions" => NoPermissions
    "Unavailable" => Unavailable
    "InvalidUri" => InvalidUri
    "InvalidData" => InvalidData
    "NotFound" => FileNotFound
    "NotAllowedError" => NoPermissions
    "AbortError" => Unavailable
    _ => Unavailable
  }
}

///|
pub impl ToJson for FileChange with fn to_json(self) {
  {
    "uri": self.uri.to_string().to_json(),
    "type": self.change_type.to_string().to_json(),
  }
}

///|
pub fn FileChangeType::to_string(self : FileChangeType) -> String {
  match self {
    Created => "created"
    Changed => "changed"
    Deleted => "deleted"
  }
}

///|
fn revision_from_text(text : String) -> String {
  let mut hash = 2166136261L
  for i in 0..<text.length() {
    hash = (hash ^ text[i].to_int64()) * 16777619L
  }
  hash.to_string()
}
