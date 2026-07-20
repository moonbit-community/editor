///|
/// Hover's fenced-code override for the shared Markdown renderer. The shared
/// DOM-free package owns cmark parsing and translates its syntax tree into this
/// MoonBit-owned value; hover owns only language selection and editor-token
/// rendering. The optional second argument is the active model language used
/// when the fence has no language info string.
pub fn render_hover_code_block(
  code_block : @markdown.MarkdownCodeBlock,
  active_language_id : String?,
) -> String {
  let language_id = hover_code_language(code_block, active_language_id)
  let code = code_block.code
  // Monaco's markdown code blocks render through `tokenizeToString` +
  // `TokenizationRegistry` (`markdownRenderer.ts`). The fenced language's
  // tokenizer state threads line to line inside the closure, the way
  // `_tokenizeToString` carries `currentState`; a registry miss falls back
  // to language-tagged plain lines (Monaco's null tokenization).
  let codec = @services.language_id_codec
  let encoded_language_id = codec.register(language_id)
  let tokenizer = @syntax.tokenization_registry.get(language_id)
  let mut state = tokenizer.map(tokenizer => tokenizer.initial_state())
  @languages.tokenize_to_string(code, codec, line => {
    let lexer_tokens = match (tokenizer, state) {
      (Some(tokenizer), Some(current)) => {
        let (tokens, next) = tokenizer.tokenize_line(line, current)
        state = Some(next)
        tokens
      }
      _ => []
    }
    let line_tokens = @model.line_tokens_from_lexer_tokens(
      line,
      lexer_tokens,
      codec,
      language_id=encoded_language_id,
    )
    // `tokenize_to_string`'s seam takes raw start-offset token pairs.
    let pairs : Array[UInt] = []
    for index in 0..<line_tokens.get_count() {
      pairs.push(line_tokens.get_start_offset(index).reinterpret_as_uint())
      pairs.push(line_tokens.get_metadata(index))
    }
    pairs
  })
}

///|
fn hover_code_language(
  code_block : @markdown.MarkdownCodeBlock,
  active_language_id : String?,
) -> String {
  let language = match code_block.language_id {
    Some(language) => language
    None =>
      match active_language_id {
        Some(language) => language
        None => ""
      }
  }
  normalize_hover_language_id(language)
}

///|
fn normalize_hover_language_id(language : String) -> String {
  match language {
    "mbt" => "moonbit"
    "js" => "javascript"
    "ts" => "typescript"
    _ => language
  }
}
