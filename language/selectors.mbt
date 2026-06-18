///|
/// Monaco-shaped language selector filter.
pub(all) struct LanguageFilter {
  language : String?
  scheme : String?
  pattern : String?
} derive(Debug)

///|
/// Monaco-shaped language selector used during provider dispatch.
pub(all) enum LanguageSelector {
  LanguageId(String)
  LanguageFilter(LanguageFilter)
  LanguageSelectorList(Array[LanguageSelector])
} derive(Debug)

///|
/// Builds a selector filter with optional fields.
pub fn LanguageFilter::LanguageFilter(
  language? : String,
  scheme? : String,
  pattern? : String,
) -> LanguageFilter {
  { language, scheme, pattern }
}

///|
/// Whether this selector accepts a document snapshot.
pub fn LanguageSelector::matches(
  self : LanguageSelector,
  document : @workspace.DocumentSnapshot,
) -> Bool {
  match self {
    LanguageId(language_id) => document.language_id == language_id
    LanguageFilter(filter) => filter.matches(document)
    LanguageSelectorList(selectors) => {
      for selector in selectors {
        if selector.matches(document) {
          return true
        }
      }
      false
    }
  }
}

///|
/// Whether this filter accepts a document snapshot.
pub fn LanguageFilter::matches(
  self : LanguageFilter,
  document : @workspace.DocumentSnapshot,
) -> Bool {
  match self.language {
    Some(language) => if language != document.language_id { return false }
    None => ()
  }
  match self.scheme {
    Some(scheme) => if scheme != document.uri.scheme() { return false }
    None => ()
  }
  match self.pattern {
    Some(pattern) => path_pattern_matches(pattern, document.uri.path())
    None => true
  }
}

///|
fn path_pattern_matches(pattern : String, path : String) -> Bool {
  if pattern == "" || pattern == "*" {
    return true
  }
  let path = if path.has_prefix("/") { path[1:].to_owned() } else { path }
  match pattern.find("*") {
    Some(index) => {
      let prefix = pattern[0:index].to_owned()
      let suffix = pattern[index + 1:].to_owned()
      path.has_prefix(prefix) && path.has_suffix(suffix)
    }
    None => path == pattern
  }
}
