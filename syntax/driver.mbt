///|
/// Whole-document driver: feeds every line through a `LineTokenizer`
/// carrying state across lines, and converts line-local tokens to the
/// doc-offset `Token` shape `renderer.build_frame` consumes.
pub fn tokenize_document(
  doc : @model.TextSnapshot,
  tokenizer : &LineTokenizer,
) -> Array[Token] {
  tokenize_document_lines(doc, tokenizer).0
}

///|
/// Returns the doc-offset tokens plus one entry state per line. The entry
/// states are recorded from day one (kept internal for now) so a future
/// windowed or incremental pass (re-tokenize until the entry state
/// converges, the `IState.equals` idea) is a driver change, not a
/// contract change.
fn tokenize_document_lines(
  doc : @model.TextSnapshot,
  tokenizer : &LineTokenizer,
) -> (Array[Token], Array[TokenizerState]) {
  let tokens : Array[Token] = []
  let line_entry_states : Array[TokenizerState] = []
  let mut state = tokenizer.initial_state()
  for line in 0..<doc.line_count() {
    line_entry_states.push(state)
    let line_start = doc.line_start_offset(line)
    let (line_tokens, next_state) = tokenizer.tokenize_line(
      doc.line_text(line),
      state,
    )
    for line_token in line_tokens {
      let range = @core.Range(
        line_start + line_token.start,
        line_start + line_token.end,
      )
      tokens.push({ range, tag: line_token.tag, text: doc.slice(range) })
    }
    state = next_state
  }
  (tokens, line_entry_states)
}
