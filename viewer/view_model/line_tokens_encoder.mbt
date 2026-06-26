///| Encodes the MoonBit lexers' per-line output into Monaco's faithful
/// `LineTokens`. This is the viewer-side adapter the plan calls for: the
/// `syntax` layer keeps producing `@syntax.Token`s and never learns about the
/// view model, while production rendering consumes the ported binary token
/// store.
///
/// The encoding mirrors the legacy `spans_for_line` segmentation exactly — a
/// token segment per intersecting `@syntax.Token` (clipped to the line and made
/// line-local), with inter-token gaps and trailing text filled by a
/// default-metadata token (Monaco tokens cover the whole line). The only change
/// is the *encoding*: a tag's color/type becomes a packed metadata word
/// (`tag_to_metadata`) instead of a `tok-*` class string, so the rendered
/// boundaries are unchanged up to the `tok-* -> mtk<n>` remap.

///|
/// Builds the faithful `LineTokens` for one model line from the syntax tokens
/// that intersect it (in document offsets, as bucketed by `TokenizedDocument`).
/// `line_start_offset` is the line's document start offset.
pub fn line_tokens_from_syntax_tokens(
  line_text : String,
  line_start_offset : Int,
  tokens : Array[@syntax.Token],
  decoder : LanguageIdCodec,
) -> LineTokens {
  let line_length = line_text.length()
  let line_end_offset = line_start_offset + line_length
  let data : Array[(String, UInt)] = []
  let mut cursor = 0
  for token in tokens {
    // The bucket holds exactly the tokens intersecting this line; clip each to
    // the line text range and rebase to line-local offsets.
    let start = token.range.start.max(line_start_offset) - line_start_offset
    let end = token.range.end_exclusive.min(line_end_offset) - line_start_offset
    if cursor < start {
      data.push((substr(line_text, cursor, start), default_token_metadata()))
    }
    if start < end {
      data.push((substr(line_text, start, end), tag_to_metadata(token.tag)))
      cursor = end
    }
  }
  if cursor < line_length {
    data.push((substr(line_text, cursor, line_length), default_token_metadata()))
  }
  if data.is_empty() {
    // An empty line still needs one token covering its (zero-length) content,
    // matching Monaco's `LineTokens.createEmpty`.
    return LineTokens::create_empty(line_text, decoder)
  }
  LineTokens::create_from_text_and_metadata(data, decoder)
}

///|
/// The default-metadata word for gap / trailing segments, named locally for
/// readability. Equivalent to `tag_to_metadata(Plain)` for the fields the
/// renderer reads (foreground + font style).
fn default_token_metadata() -> UInt {
  LineTokens::default_token_metadata()
}
