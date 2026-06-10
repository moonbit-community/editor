///|
test "normalizes accepted root relative paths" {
  let simple = expect_path("foo.mbt")
  assert_eq(simple.to_string(), "foo.mbt")
  assert_eq(simple.display_name(), "foo.mbt")
  assert_eq(simple.file_uri().to_string(), "file://local/foo.mbt")

  let nested = expect_path("nested/file.txt")
  assert_eq(nested.to_string(), "nested/file.txt")

  let backslash = expect_path("nested\\file.txt")
  assert_eq(backslash.to_string(), "nested/file.txt")
}

///|
test "rejects invalid root relative paths" {
  expect_path_error("", MissingPath)
  expect_path_error("/absolute.mbt", InvalidPath)
  expect_path_error("//host/file.mbt", InvalidPath)
  expect_path_error("../outside.mbt", InvalidPath)
  expect_path_error("a/../outside.mbt", InvalidPath)
  expect_path_error("C:\\outside.mbt", InvalidPath)
  expect_path_error("bad\u{0}path.mbt", InvalidPath)
}

///|
test "parses document uris" {
  let memory = expect_uri("memory://main.mbt")
  assert_eq(memory.scheme(), "memory")
  assert_eq(memory.to_string(), "memory://main.mbt")

  let file = expect_uri("file://server/nested/file.mbt")
  assert_eq(file.scheme(), "file")
  assert_eq(file.path(), "nested/file.mbt")
  assert_eq(file.display_name(), "file.mbt")
  assert_eq(file.to_string(), "file://server/nested/file.mbt")

  match @workspace.DocumentUri::parse("missing-scheme") {
    DocumentUriError(error) => assert_true(error == SourceInvalidUri)
    ParsedDocumentUri(uri) => fail("unexpected uri " + uri.to_string())
  }
}

///|
async test "filesystem provider reads source documents by uri" {
  let uri = expect_uri("file://local/main.mbt")
  let provider = TestFileSystemProvider::{  }

  match @workspace.read_source_document(provider, uri) {
    SourceDocumentLoaded(document) => {
      assert_eq(document.uri.to_string(), "file://local/main.mbt")
      assert_eq(document.display_name, "main.mbt")
      assert_eq(document.language_id, "moonbit")
      assert_eq(document.version, 1)
      assert_eq(document.revision, "rev-1")
      assert_eq(document.text, "pub fn main {}\n")
    }
    SourceDocumentLoadError(error) =>
      fail("unexpected provider error " + error.message)
  }
}

///|
async test "filesystem provider rejects mismatched schemes" {
  let uri = expect_uri("memory://main.mbt")
  let provider = TestFileSystemProvider::{  }

  match @workspace.read_source_document(provider, uri) {
    SourceDocumentLoadError(error) => assert_true(error.code == InvalidUri)
    SourceDocumentLoaded(document) =>
      fail("unexpected document " + document.uri.to_string())
  }
}

///|
test "infers language ids from source names" {
  assert_eq(@workspace.infer_language_id("main.mbt"), "moonbit")
  assert_eq(@workspace.infer_language_id("README.mbt.md"), "moonbit")
  assert_eq(@workspace.infer_language_id("main.js"), "javascript")
  assert_eq(@workspace.infer_language_id("main.mjs"), "javascript")
  assert_eq(@workspace.infer_language_id("main.ts"), "typescript")
  assert_eq(@workspace.infer_language_id("config.json"), "json")
  assert_eq(@workspace.infer_language_id("README.md"), "markdown")
  assert_eq(@workspace.infer_language_id("style.css"), "css")
  assert_eq(@workspace.infer_language_id("index.html"), "html")
  assert_eq(@workspace.infer_language_id("notes.txt"), "plaintext")
  assert_eq(@workspace.infer_language_id("unknown.source"), "moonbit")
}

///|
test "source document creates snapshots with identity metadata" {
  let document = @workspace.SourceDocument(
    @workspace.DocumentUri::memory("main.mbt"),
    "main.mbt",
    "",
    3,
    "rev-3",
    "pub fn main {}\n",
  )
  let snapshot = document.snapshot()
  assert_eq(document.revision, "rev-3")
  assert_eq(snapshot.text, "pub fn main {}\n")
  assert_eq(snapshot.language_id, "moonbit")
  assert_eq(snapshot.version, 3)
}

///|
fn expect_path(raw_path : String) -> @workspace.SourcePath raise {
  match @workspace.SourcePath::normalize_root_relative_path(raw_path) {
    ParsedSourcePath(path) => path
    SourcePathError(error) => fail("unexpected path error " + error.to_string())
  }
}

///|
fn expect_path_error(
  raw_path : String,
  expected : @workspace.SourceError,
) -> Unit raise {
  match @workspace.SourcePath::normalize_root_relative_path(raw_path) {
    SourcePathError(error) => assert_true(error == expected)
    ParsedSourcePath(path) => fail("unexpected path " + path.to_string())
  }
}

///|
fn expect_uri(raw_uri : String) -> @workspace.DocumentUri raise {
  match @workspace.DocumentUri::parse(raw_uri) {
    ParsedDocumentUri(uri) => uri
    DocumentUriError(error) => fail("unexpected uri error " + error.to_string())
  }
}

///|
struct TestFileSystemProvider {}

///|
impl @workspace.FileSystemProvider for TestFileSystemProvider with fn scheme(
  _self,
) {
  "file"
}

///|
impl @workspace.FileSystemProvider for TestFileSystemProvider with fn read_file(
  _self,
  _uri,
) {
  FileReadOk(
    FileContent("pub fn main {}\n", display_name="main.mbt", revision="rev-1"),
  )
}

///|
impl @workspace.FileSystemProvider for TestFileSystemProvider with fn watch(
  _self,
  _uri,
  _options,
  _listener,
) {
  { dispose: () => () }
}
