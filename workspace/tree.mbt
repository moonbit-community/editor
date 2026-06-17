///|
/// Kind of a workspace tree entry, in place of `IFileStat`'s
/// `isFile`/`isDirectory` booleans.
pub(all) enum WorkspaceEntryKind {
  File
  Directory
} derive(Eq, Debug)

///|
/// One node of the workspace tree, mirroring VS Code's `IFileStat`: every
/// stat carries its full provider-minted `uri`, and `children` is `None`
/// until a provider resolves that directory level (the
/// `IFileStat.children: undefined` convention). Depth is tree structure,
/// not an annotation.
pub(all) struct WorkspaceStat {
  uri : DocumentUri
  name : String
  kind : WorkspaceEntryKind
  children : Array[WorkspaceStat]?
} derive(Debug)

///|
/// Result of resolving a workspace tree node through a tree provider.
pub(all) enum WorkspaceResolveResult {
  WorkspaceResolved(WorkspaceStat)
  WorkspaceResolveError(FileSystemProviderError)
} derive(Debug)

///|
/// The `IFileService.resolve` analog. `root` names the workspace root URI;
/// `resolve` returns the stat for a directory URI with exactly one level
/// of `children` resolved. Requests are pull-based; providers never push
/// tree data.
pub(open) trait WorkspaceTreeProvider {
  fn root(Self) -> DocumentUri
  async fn resolve(Self, DocumentUri) -> WorkspaceResolveResult
}

///|
/// Client-side mirror of the server document surface, in `SourceDocument`
/// terms. `FileSystemProvider` is the content-level contract (raw file
/// reads and change pings); `DocumentSource` is document-level: opens
/// resolve to versioned `SourceDocument`s and watches push fully loaded
/// documents (or load errors) for the watched URI.
pub(open) trait DocumentSource {
  async fn open_document(Self, DocumentUri) -> SourceDocumentLoadResult
  fn watch_document(Self, DocumentUri, (SourceDocumentLoadResult) -> Unit) -> FileWatch
  fn close_document(Self, DocumentUri) -> Unit
}

///|
/// Wire label for workspace tree entry kinds.
pub fn WorkspaceEntryKind::to_string(self : WorkspaceEntryKind) -> String {
  match self {
    File => "file"
    Directory => "directory"
  }
}

///|
/// Decodes a workspace tree entry kind from its wire label.
pub fn WorkspaceEntryKind::from_string(kind : String) -> WorkspaceEntryKind? {
  match kind {
    "file" => Some(File)
    "directory" => Some(Directory)
    _ => None
  }
}
