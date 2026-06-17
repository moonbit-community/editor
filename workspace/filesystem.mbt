///|
/// Host-neutral error codes used by file providers and remote workspace
/// responses.
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
/// File-provider failure with optional URI context.
pub(all) struct FileSystemProviderError {
  code : FileSystemProviderErrorCode
  message : String
  uri : @base_common.Uri?
} derive(Debug)

///|
/// Raw file text plus metadata needed to construct a `SourceDocument`.
pub(all) struct FileContent {
  text : String
  display_name : String
  language_id : String
  revision : String
} derive(Debug)

///|
/// Provider read result without exceptions, so browser and native providers can
/// share the same contract.
pub(all) enum FileReadResult {
  FileReadOk(FileContent)
  FileReadError(FileSystemProviderError)
} derive(Debug)

///|
/// File-watch event kind. Providers may coalesce events before delivering
/// them.
pub(all) enum FileChangeType {
  Created
  Changed
  Deleted
} derive(Eq, Debug)

///|
/// One changed document URI reported by a file watch.
pub(all) struct FileChange {
  uri : @base_common.Uri
  change_type : FileChangeType
} derive(Debug)

///|
/// Watch behavior requested from a provider.
pub(all) struct WatchOptions {
  recursive : Bool
  excludes : Array[String]
} derive(Debug)

///|
/// Disposable watch handle. Calling `dispose` must stop future callbacks for
/// that watch when the provider can do so.
pub(all) struct FileWatch {
  dispose : () -> Unit
}

///|
/// Host filesystem abstraction for readonly document loading and file-change
/// notifications.
pub(open) trait FileSystemProvider {
  fn scheme(Self) -> String
  async fn read_file(Self, @base_common.Uri) -> FileReadResult
  fn watch(Self, @base_common.Uri, WatchOptions, (Array[FileChange]) -> Unit) -> FileWatch
}

///|
/// Document-level load result derived from file-provider reads.
pub(all) enum SourceDocumentLoadResult {
  SourceDocumentLoaded(SourceDocument)
  SourceDocumentLoadError(FileSystemProviderError)
} derive(Debug)

///|
/// Builds file content while allowing providers to omit derived metadata.
pub fn FileContent::FileContent(
  text : String,
  display_name? : String = "",
  language_id? : String = "",
  revision? : String = "",
) -> FileContent {
  { text, display_name, language_id, revision }
}

///|
/// Builds a provider error, defaulting an empty message to the stable code
/// label.
pub fn FileSystemProviderError::FileSystemProviderError(
  code : FileSystemProviderErrorCode,
  message : String,
  uri? : @base_common.Uri,
) -> FileSystemProviderError {
  let message = if message == "" { code.to_string() } else { message }
  { code, message, uri }
}

///|
/// Default non-recursive watch with no excludes.
pub fn WatchOptions::default() -> WatchOptions {
  { recursive: false, excludes: [] }
}

///|
/// Stops the watch through the provider-supplied disposer.
pub fn FileWatch::dispose(self : FileWatch) -> Unit {
  (self.dispose)()
}

///|
/// Reads and converts a file-provider result into a versioned
/// `SourceDocument`, failing closed when the URI scheme does not match.
pub async fn read_source_document(
  provider : &FileSystemProvider,
  uri : @base_common.Uri,
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
/// Starts a default file watch only when the provider owns the URI scheme.
pub fn watch_file(
  provider : &FileSystemProvider,
  uri : @base_common.Uri,
  listener : (Array[FileChange]) -> Unit,
) -> FileWatch {
  if uri.scheme() == provider.scheme() {
    provider.watch(uri, WatchOptions::default(), listener)
  } else {
    { dispose: () => () }
  }
}

///|
/// Derives a `SourceDocument` from provider content, filling display name,
/// language id, and revision when they are absent.
pub fn SourceDocument::from_file_content(
  uri : @base_common.Uri,
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
/// JSON shape consumed by browser harnesses and remote protocol adapters.
pub impl ToJson for SourceDocumentLoadResult with fn to_json(self) {
  match self {
    SourceDocumentLoaded(document) =>
      { "ok": true, "document": document.to_json() }
    SourceDocumentLoadError(error) => { "ok": false, "error": error.to_json() }
  }
}

///|
/// JSON shape for provider errors, including HTTP-like status for the native
/// reference server.
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
/// HTTP-like status used by the reference server when serializing provider
/// failures.
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
/// Stable string label for wire format and JSON diagnostics.
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
/// Decodes both this package's labels and browser File System Access API names.
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
/// JSON shape for watch events.
pub impl ToJson for FileChange with fn to_json(self) {
  {
    "uri": self.uri.to_string().to_json(),
    "type": self.change_type.to_string().to_json(),
  }
}

///|
/// Lowercase watch-event label used in JSON payloads.
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
