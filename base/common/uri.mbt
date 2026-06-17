///|
/// Provider-minted absolute URI. The viewer treats the string as an opaque
/// identity except for scheme, path, and display-name extraction.
pub(all) struct Uri {
  value : String
} derive(Eq, Debug)

///|
/// Validation failures for URI parsing.
pub(all) enum UriError {
  InvalidUri
} derive(Eq, Debug)

///|
/// Result wrapper used instead of raising while parsing document URIs.
pub(all) enum UriResult {
  ParsedUri(Uri)
  UriError(UriError)
} derive(Eq, Debug)

///|
/// Stable protocol/debug label for URI validation failures.
pub fn UriError::to_string(self : UriError) -> String {
  match self {
    InvalidUri => "InvalidUri"
  }
}

///|
/// Parses an absolute `scheme://...` URI and leaves the provider-owned
/// authority/path text otherwise untouched.
pub fn Uri::parse(value : String) -> UriResult {
  match value.find("://") {
    Some(index) =>
      if is_valid_uri_scheme(value, index) && index + 3 < value.length() {
        ParsedUri({ value, })
      } else {
        UriError(InvalidUri)
      }
    None => UriError(InvalidUri)
  }
}

///|
/// Creates an in-memory URI for demos, tests, or embedders without filesystem
/// identity.
pub fn Uri::memory(name : String) -> Uri {
  let name = if name == "" {
    "document"
  } else {
    name.replace_all(old="\\", new="/")
  }
  { value: "memory://" + name }
}

///|
/// Returns the provider-owned URI string.
pub fn Uri::to_string(self : Uri) -> String {
  self.value
}

///|
/// URI scheme before `://`, or an empty string for malformed values.
pub fn Uri::scheme(self : Uri) -> String {
  match self.value.find("://") {
    Some(index) => self.value[0:index].to_owned()
    None => ""
  }
}

///|
/// Path part after the authority, without a leading slash.
pub fn Uri::path(self : Uri) -> String {
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
/// Best-effort file name for labels; falls back to the full URI when no path is
/// present.
pub fn Uri::display_name(self : Uri) -> String {
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
fn is_valid_uri_scheme(value : String, end : Int) -> Bool {
  if end == 0 {
    return false
  }
  let first = value[0].to_int()
  if !is_ascii_alpha(first) {
    return false
  }
  for i in 1..<end {
    let code = value[i].to_int()
    if !is_ascii_alpha(code) &&
      !is_ascii_digit(code) &&
      code != 43 &&
      code != 45 &&
      code != 46 {
      return false
    }
  }
  true
}

///|
fn is_ascii_alpha(code : Int) -> Bool {
  (65 <= code && code <= 90) || (97 <= code && code <= 122)
}

///|
fn is_ascii_digit(code : Int) -> Bool {
  48 <= code && code <= 57
}
