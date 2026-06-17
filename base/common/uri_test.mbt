///|
test "parses uris and extracts labels" {
  let memory = expect_uri("memory://main.mbt")
  assert_eq(memory.scheme(), "memory")
  assert_eq(memory.to_string(), "memory://main.mbt")

  let file = expect_uri("file://server/nested/file.mbt")
  assert_eq(file.scheme(), "file")
  assert_eq(file.path(), "nested/file.mbt")
  assert_eq(file.display_name(), "file.mbt")
  assert_eq(file.to_string(), "file://server/nested/file.mbt")
}

///|
test "creates memory uris" {
  assert_eq(Uri::memory("").to_string(), "memory://document")
  assert_eq(
    Uri::memory("nested\\file.mbt").to_string(),
    "memory://nested/file.mbt",
  )
}

///|
test "rejects invalid uris" {
  expect_uri_error("missing-scheme", InvalidUri)
  expect_uri_error("://missing-scheme", InvalidUri)
  expect_uri_error("file://", InvalidUri)
  expect_uri_error("1file://path", InvalidUri)
}

///|
fn expect_uri(raw_uri : String) -> Uri raise {
  match Uri::parse(raw_uri) {
    ParsedUri(uri) => uri
    UriError(error) => fail("unexpected uri error " + error.to_string())
  }
}

///|
fn expect_uri_error(raw_uri : String, expected : UriError) -> Unit raise {
  match Uri::parse(raw_uri) {
    UriError(error) => assert_true(error == expected)
    ParsedUri(uri) => fail("unexpected uri " + uri.to_string())
  }
}
