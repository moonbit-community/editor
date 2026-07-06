///|
/// Carried lexer state between lines, the `IState` of Monaco's
/// tokenization contract. The representation is a single string (like
/// Monaco's interned Monarch stacks): languages encode their own state
/// stack or payload into it, and derived equality is what callers use to
/// detect re-tokenization convergence.
pub(all) struct TokenizerState(String) derive(Eq, Debug)

///|
/// Highlight classification, widened toward Monaco's standard token
/// types. Existing tags and class names are stable for specs; new tags
/// extend the set for the per-language lexers.
pub(all) enum HighlightTag {
  Keyword
  Identifier
  String
  Number
  Comment
  Punctuation
  Plain
  Operator
  Delimiter
  Type
  Function
  Variable
  Constant
  StringEscape
  CommentDoc
  Regexp
  Tag
  Attribute
  Invalid
} derive(Eq, Debug)

///|
/// Renders the tag's variant name. Used by the per-language lexer golden tests
/// to label each token; production styling is the view model's metadata
/// encoding (`mtk<colorId>`), not a per-tag string.
pub impl Show for HighlightTag with fn output(self, logger) {
  logger.write_string(
    match self {
      Keyword => "Keyword"
      Identifier => "Identifier"
      String => "String"
      Number => "Number"
      Comment => "Comment"
      Punctuation => "Punctuation"
      Plain => "Plain"
      Operator => "Operator"
      Delimiter => "Delimiter"
      Type => "Type"
      Function => "Function"
      Variable => "Variable"
      Constant => "Constant"
      StringEscape => "StringEscape"
      CommentDoc => "CommentDoc"
      Regexp => "Regexp"
      Tag => "Tag"
      Attribute => "Attribute"
      Invalid => "Invalid"
    },
  )
}

///|
/// One highlighted span within a single line, in line-local UTF-16
/// code-unit offsets. Token ranges must never split a surrogate pair: the
/// viewer slices the document text at these offsets.
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
/// Registration change notification, the ported subset of Monaco's
/// `ITokenizationSupportChangedEvent` (`changedColorMap` has no viewer
/// analog — the token color map is static).
pub(all) struct TokenizationChangedEvent {
  changed_languages : Array[String]
}

///|
priv struct TokenizationSupportEntry {
  id : Int
  tokenizer : &LineTokenizer
}

///|
/// Tokenization support keyed by language id, Monaco's
/// `TokenizationRegistry` (`common/languages.ts` /
/// `languages/tokenizationRegistry.ts`). The process-wide instance is
/// `tokenization_registry` below; isolated instances remain constructible
/// for tests.
pub struct TokenizationRegistry {
  priv tokenizers : Map[String, TokenizationSupportEntry]
  priv next_id : Ref[Int]
  priv did_change : @base_common.Emitter[TokenizationChangedEvent]
}

///|
/// Creates an empty tokenization registry.
pub fn TokenizationRegistry::new() -> TokenizationRegistry {
  { tokenizers: {}, next_id: Ref(0), did_change: @base_common.Emitter::new() }
}

///|
/// Registers or replaces the tokenization support for a language id and
/// fires `on_did_change`. Mirrors `TokenizationRegistry.register`; disposing
/// the returned handle removes the support only if it is still the active
/// registration (Monaco's `=== support` identity check, kept as a
/// registration id so trait objects need no identity comparison).
pub fn TokenizationRegistry::register(
  self : TokenizationRegistry,
  language_id : String,
  tokenizer : &LineTokenizer,
) -> @base_common.Disposable {
  let id = self.next_id.val
  self.next_id.val = id + 1
  self.tokenizers[language_id] = { id, tokenizer }
  self.did_change.fire({ changed_languages: [language_id] })
  @base_common.Disposable::from(() => {
    match self.tokenizers.get(language_id) {
      Some(entry) =>
        if entry.id == id {
          self.tokenizers.remove(language_id)
          self.did_change.fire({ changed_languages: [language_id] })
        }
      None => ()
    }
  })
}

///|
/// The tokenization support for `language_id`, or `None` when unregistered
/// (Monaco's null tokenization fallback is the caller's choice). Mirrors
/// `TokenizationRegistry.get`.
pub fn TokenizationRegistry::get(
  self : TokenizationRegistry,
  language_id : String,
) -> &LineTokenizer? {
  match self.tokenizers.get(language_id) {
    Some(entry) => Some(entry.tokenizer)
    None => None
  }
}

///|
/// Subscribes to registration changes. Mirrors
/// `TokenizationRegistry.onDidChange`.
pub fn TokenizationRegistry::on_did_change(
  self : TokenizationRegistry,
  listener : (TokenizationChangedEvent) -> Unit,
) -> @base_common.Disposable {
  self.did_change.event(listener)
}

///|
/// The process-wide registry, Monaco's `export const TokenizationRegistry`
/// singleton (`common/languages.ts`). `Languages::set_tokens_provider`
/// (the `monaco.languages.setTokensProvider` analog) registers into it.
pub let tokenization_registry : TokenizationRegistry = TokenizationRegistry::new()

///|
/// Whether `word` begins with an uppercase ASCII letter (`A`–`Z`), the shared
/// lexer heuristic for classifying an identifier as a type. Shared by the
/// language lexers (`lang_*`), which otherwise carry identical copies.
pub fn is_capitalized(word : StringView) -> Bool {
  let unit = word[0].to_int()
  65 <= unit && unit <= 90
}
