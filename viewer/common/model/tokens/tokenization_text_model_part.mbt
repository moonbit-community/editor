///| Faithful port of the readonly subset of vscode's tokenization model part:
/// `TokenizationTextModelPart` (`common/model/tokens/tokenizationTextModelPart.ts`)
/// merged with its grammar backend `TokenizerSyntaxTokenBackend`
/// (`common/model/tokens/tokenizerSyntaxTokenBackend.ts`) and the
/// state-threading sweep of `TokenizerWithStateStore`
/// (`common/model/textModelTokens.ts`).
///
/// Deviations, all consequences of the viewer's readonly `TextModel`:
///   - Constructed from the model's frozen line array instead of holding the
///     live `TextModel`: Monaco's backend reads the mutable model lazily, but
///     MoonBit's package-per-directory + no-cycle rules forbid `model/tokens`
///     importing `common/model` while `TextModel` owns the part.
///   - Tokenization is one lazy whole-document sweep memoized per part
///     (`force_tokenization` warms it, `reset_tokenization` clears it); with
///     no edits there is no role for the background tokenizer, its
///     `RangePriorityQueueImpl` scheduling (ported for conformance in
///     `common/model/text_model_tokens.mbt`), or per-line `forceTokenization`.
///   - The part does not subscribe to `tokenization_registry.on_did_change`
///     (Monaco's backend does): the readonly `TextModel` has no dispose, so a
///     per-model subscription would leak. The `Viewer` relays the event by
///     calling `reset_tokenization` on its current model.
///   - No semantic-token overlay (`SparseTokensStore` is not ported).

///|
/// The `model.tokenization` role: per-line grammar tokens for one document
/// version, encoded in Monaco's binary `LineTokens` store.
pub struct TokenizationTextModelPart {
  priv lines : Array[String]
  priv language_id : String
  priv mut line_tokens : Array[@common_tokens.LineTokens]?
}

///|
/// Builds the part for a document's lines (EOL excluded, one entry per
/// logical line) and language id. Tokenization runs lazily on first read.
pub fn TokenizationTextModelPart::new(
  lines : Array[String],
  language_id : String,
) -> TokenizationTextModelPart {
  { lines, language_id, line_tokens: None }
}

///|
/// The part's language id. Mirrors `getLanguageId` (`TextModel.getLanguageId`
/// delegates here in Monaco too).
pub fn TokenizationTextModelPart::get_language_id(
  self : TokenizationTextModelPart,
) -> String {
  self.language_id
}

///|
/// Grammar tokens for the one-based `line_number`, clamped into the document
/// (the viewer clamps where Monaco throws `Illegal value for lineNumber`).
/// Mirrors `TokenizationTextModelPart.getLineTokens` minus the semantic-token
/// overlay. Forces the whole-document sweep on first call.
pub fn TokenizationTextModelPart::get_line_tokens(
  self : TokenizationTextModelPart,
  line_number : Int,
) -> @common_tokens.LineTokens {
  let line_tokens = self.tokenized()
  let index = @base_common.clamp_int(
    line_number - 1,
    0,
    line_tokens.length() - 1,
  )
  line_tokens[index]
}

///|
/// Ensures the document is tokenized. Mirrors `forceTokenization`; the
/// viewer's sweep is whole-document, so there is no line argument.
pub fn TokenizationTextModelPart::force_tokenization(
  self : TokenizationTextModelPart,
) -> Unit {
  self.tokenized() |> ignore
}

///|
/// Whether the memoized sweep has run. Mirrors `hasTokens`.
pub fn TokenizationTextModelPart::has_tokens(
  self : TokenizationTextModelPart,
) -> Bool {
  self.line_tokens is Some(_)
}

///|
/// Drops the memoized tokens so the next read re-resolves the language
/// through `tokenization_registry` and re-tokenizes. Mirrors
/// `resetTokenization` (fired there by the registry-change subscription the
/// viewer relays instead — see the file header).
pub fn TokenizationTextModelPart::reset_tokenization(
  self : TokenizationTextModelPart,
) -> Unit {
  self.line_tokens = None
}

///|
/// Total binary token count across the document, the viewer's debug
/// telemetry for `ViewerFrameBuiltEvent.token_count` (no Monaco analog).
/// Counts every stored token, including the plain fill segments.
pub fn TokenizationTextModelPart::token_count(
  self : TokenizationTextModelPart,
) -> Int {
  let mut count = 0
  for line_tokens in self.tokenized() {
    count += line_tokens.get_count()
  }
  count
}

///|
fn TokenizationTextModelPart::tokenized(
  self : TokenizationTextModelPart,
) -> Array[@common_tokens.LineTokens] {
  match self.line_tokens {
    Some(line_tokens) => line_tokens
    None => {
      let line_tokens = self.tokenize_document()
      self.line_tokens = Some(line_tokens)
      line_tokens
    }
  }
}

///|
/// The whole-document sweep: resolves the tokenizer through the global
/// `tokenization_registry` (Monaco's `TokenizationRegistry.get`), threads
/// `TokenizerState` line to line (`TokenizerWithStateStore`), and encodes
/// each line's lexer tokens into the binary store. A registry miss produces
/// one language-tagged default token per line (Monaco's null tokenization).
fn TokenizationTextModelPart::tokenize_document(
  self : TokenizationTextModelPart,
) -> Array[@common_tokens.LineTokens] {
  let codec = @services.language_id_codec
  let encoded_language_id = codec.register(self.language_id)
  let line_tokens : Array[@common_tokens.LineTokens] = []
  match @syntax.tokenization_registry.get(self.language_id) {
    Some(tokenizer) => {
      let mut state = tokenizer.initial_state()
      for line in self.lines {
        let (lexer_tokens, next_state) = tokenizer.tokenize_line(line, state)
        line_tokens.push(
          line_tokens_from_lexer_tokens(
            line,
            lexer_tokens,
            codec,
            language_id=encoded_language_id,
          ),
        )
        state = next_state
      }
    }
    None =>
      for line in self.lines {
        line_tokens.push(
          line_tokens_from_lexer_tokens(
            line,
            [],
            codec,
            language_id=encoded_language_id,
          ),
        )
      }
  }
  line_tokens
}
