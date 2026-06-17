///|
/// Carried lexer state between lines, the `IState` of Monaco's
/// tokenization contract. The representation is a single string (like
/// Monaco's interned Monarch stacks): languages encode their own state
/// stack or payload into it, and derived equality is what callers use to
/// detect re-tokenization convergence.
pub(all) struct TokenizerState(String) derive(Eq, Debug)

///|
/// One highlighted span within a single line, in line-local UTF-16
/// code-unit offsets. Token ranges must never split a surrogate pair: the
/// renderer slices the document text at these offsets.
pub(all) struct LineToken {
  start : Int
  end : Int
  tag : HighlightTag
} derive(Eq, Debug)

///|
/// Line-at-a-time tokenization, Monaco's `ITokenizationSupport`: the
/// driver feeds lines in document order, threading the returned state
/// into the next call. Gaps between tokens render as plain text.
pub(open) trait LineTokenizer {
  fn initial_state(Self) -> TokenizerState
  fn tokenize_line(Self, line_text : String, state : TokenizerState) -> (
    Array[LineToken],
    TokenizerState,
  )
}

///|
/// Tokenization support keyed by language id, Monaco's
/// `TokenizationRegistry`. A plain value with no global instance here:
/// the embedding layer owns its singleton (`renderer/browser`, per the
/// module-`Ref` convention) and registers languages at startup.
pub struct TokenizerRegistry {
  priv tokenizers : Map[String, &LineTokenizer]
}

///|
/// Creates an empty tokenizer registry for host-side language composition.
pub fn TokenizerRegistry::new() -> TokenizerRegistry {
  { tokenizers: {} }
}

///|
/// Registers or replaces the tokenizer for a language id.
pub fn TokenizerRegistry::register(
  self : TokenizerRegistry,
  language_id : String,
  tokenizer : &LineTokenizer,
) -> Unit {
  self.tokenizers[language_id] = tokenizer
}

///|
/// Returns the tokenizer for `language_id`, leaving fallback choice to callers.
pub fn TokenizerRegistry::lookup(
  self : TokenizerRegistry,
  language_id : String,
) -> &LineTokenizer? {
  self.tokenizers.get(language_id)
}
