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
/// `line_start_offset` is the line's document start offset. `language_id` is the
/// model's numeric language id (from the document's `LanguageIdCodec`); it is
/// packed into every token's metadata word — including the plain gap/trailing
/// fills — so each token reports the model's language. It defaults to `0` (the
/// null language) for callers that predate the codec, leaving their metadata
/// byte-identical to the legacy default.
pub fn line_tokens_from_syntax_tokens(
  line_text : String,
  line_start_offset : Int,
  tokens : Array[@syntax.Token],
  decoder : LanguageIdCodec,
  language_id? : Int = 0,
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
      data.push((substr(line_text, cursor, start), gap_metadata(language_id)))
    }
    if start < end {
      data.push(
        (
          substr(line_text, start, end),
          tag_to_metadata(token.tag, language_id~),
        ),
      )
      cursor = end
    }
  }
  if cursor < line_length {
    data.push(
      (substr(line_text, cursor, line_length), gap_metadata(language_id)),
    )
  }
  if data.is_empty() {
    // An empty line still needs one token covering its (zero-length) content.
    // Monaco's `LineTokens.createEmpty` packs the language-neutral default
    // metadata, but a real tokenizer tags even a blank line with the model's
    // language, so the gap word (which equals the default at `language_id = 0`)
    // is used here to keep `get_language_id` consistent across every line.
    data.push((line_text, gap_metadata(language_id)))
  }
  LineTokens::create_from_text_and_metadata(data, decoder)
}

///|
/// The metadata word for gap / trailing / blank segments: a `Plain` tag tagged
/// with the model's `language_id`. Equals `LineTokens::default_token_metadata`
/// for the fields the renderer reads (foreground + font style) and, at
/// `language_id = 0`, in the language field too.
fn gap_metadata(language_id : Int) -> UInt {
  tag_to_metadata(Plain, language_id~)
}
