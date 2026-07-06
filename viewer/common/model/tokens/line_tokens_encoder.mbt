///| Encodes the MoonBit lexers' per-line output into Monaco's faithful
/// `LineTokens`, the `TokenizerSyntaxTokenBackend` role of turning
/// `ITokenizationSupport` output into the binary token store. The `syntax`
/// layer keeps producing line-local `@syntax.LineToken`s and never learns
/// about the store.
///
/// A token segment is emitted per lexer token (clamped to the line), with
/// inter-token gaps and trailing text filled by a default-metadata token
/// (Monaco tokens cover the whole line). A tag's color/type becomes a packed
/// metadata word (`tag_to_metadata`).

///|
/// Builds the faithful `LineTokens` for one model line from the lexer's
/// line-local tokens. `language_id` is the model's numeric language id (from
/// the codec); it is packed into every token's metadata word — including the
/// plain gap/trailing fills — so each token reports the model's language.
pub fn line_tokens_from_lexer_tokens(
  line_text : String,
  tokens : Array[@syntax.LineToken],
  decoder : @services.LanguageIdCodec,
  language_id? : Int = 0,
) -> @common_tokens.LineTokens {
  let line_length = line_text.length()
  let data : Array[(String, UInt)] = []
  let mut cursor = 0
  for token in tokens {
    let start = token.start.max(cursor)
    let end = token.end.min(line_length)
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
  @common_tokens.LineTokens::create_from_text_and_metadata(data, decoder)
}

///|
/// The metadata word for gap / trailing / blank segments: a `Plain` tag tagged
/// with the model's `language_id`. Equals `LineTokens::default_token_metadata`
/// for the fields the renderer reads (foreground + font style) and, at
/// `language_id = 0`, in the language field too.
fn gap_metadata(language_id : Int) -> UInt {
  tag_to_metadata(Plain, language_id~)
}

///|
/// Code-unit substring `[start, end)`. ASCII/BMP-safe; raises on a surrogate
/// boundary, matching the rest of the renderer's slicing.
fn substr(s : String, start : Int, end : Int) -> String {
  s.view(start_offset=start, end_offset=end).to_owned()
}
