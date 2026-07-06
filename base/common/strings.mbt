///| Faithful ports of a few `base/common/strings.ts` helpers (pinned `vscode/`
/// submodule, commit 294fb350) needed by the model read APIs. Kept here, the
/// lowest-level shared package, so model/view code shares one definition.

///|
/// `0xD800 <= charCode <= 0xDBFF`. Mirrors `strings.isHighSurrogate`; the std
/// `Int::is_leading_surrogate` is the identical range check.
pub fn is_high_surrogate(char_code : Int) -> Bool {
  char_code.is_leading_surrogate()
}

///|
/// `0xDC00 <= charCode <= 0xDFFF`. Mirrors `strings.isLowSurrogate`; the std
/// `Int::is_trailing_surrogate` is the identical range check.
pub fn is_low_surrogate(char_code : Int) -> Bool {
  char_code.is_trailing_surrogate()
}

///|
/// Whether `text` contains any right-to-left character. Mirrors
/// `strings.containsRTL` over the common BMP RTL blocks (Hebrew/Arabic
/// `U+0590..U+08FF`, Arabic Presentation Forms-A `U+FB1D..U+FDFF` and Forms-B
/// `U+FE70..U+FEFF`); supplementary-plane RTL is not detected, matching the
/// viewer's existing simplified port.
pub fn contains_rtl(text : String) -> Bool {
  for i in 0..<text.length() {
    let code = text[i].to_int()
    if (code >= 0x0590 && code <= 0x08ff) ||
      (code >= 0xfb1d && code <= 0xfdff) ||
      (code >= 0xfe70 && code <= 0xfeff) {
      return true
    }
  }
  false
}

///|
/// Index of the first non-whitespace (non-space, non-tab) character, or `-1`.
/// Mirrors `strings.firstNonWhitespaceIndex`.
pub fn first_non_whitespace_index(text : String) -> Int {
  for i in 0..<text.length() {
    let code = text[i].to_int()
    if code != 32 && code != 9 {
      return i
    }
  }
  -1
}

///|
/// Index of the last non-whitespace (non-space, non-tab) character, or `-1`.
/// Mirrors `strings.lastNonWhitespaceIndex`.
pub fn last_non_whitespace_index(text : String) -> Int {
  for i = text.length() - 1; i >= 0; i = i - 1 {
    let code = text[i].to_int()
    if code != 32 && code != 9 {
      return i
    }
  }
  -1
}

///|
/// Whether `char_code` is a full-width character (CJK and related blocks).
/// Mirrors `strings.isFullWidthCharacter`.
pub fn is_full_width_character(char_code : Int) -> Bool {
  (char_code >= 0x2E80 && char_code <= 0xD7AF) ||
  (char_code >= 0xF900 && char_code <= 0xFAFF) ||
  (char_code >= 0xFF01 && char_code <= 0xFF5E) ||
  (char_code >= 0xFFE0 && char_code <= 0xFFE6)
}

///|
/// Maps `n` to a single letter (`a..z` then `A..Z`, wrapping). Mirrors
/// `strings.singleLetterHash`; Monaco uses it to prefix per-instance id
/// namespaces (model decoration ids, whitespace ids).
pub fn single_letter_hash(n : Int) -> String {
  let letters_cnt = 'Z'.to_int() - 'A'.to_int() + 1
  let n = n % (2 * letters_cnt)
  if n < letters_cnt {
    Int::unsafe_to_char('a'.to_int() + n).to_string()
  } else {
    Int::unsafe_to_char('A'.to_int() + n - letters_cnt).to_string()
  }
}

///|
/// HTML-escapes `&`, `<`, `>`. Mirrors `strings.escape` (note: unlike the view's
/// `escape_html`, it does not escape `"`, matching Monaco's `_tokenizeToString`).
pub fn escape(text : String) -> String {
  let sb = StringBuilder::new()
  for ch in text {
    match ch {
      '&' => sb.write_string("&amp;")
      '<' => sb.write_string("&lt;")
      '>' => sb.write_string("&gt;")
      _ => sb.write_char(ch)
    }
  }
  sb.to_string()
}
