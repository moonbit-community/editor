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
/// Whole-document highlight token in document-offset coordinates.
pub(all) struct Token {
  range : @base_common.OffsetRange
  tag : HighlightTag
  text : String
} derive(Debug)

///|
/// Tokenizes the whole document with the generic fallback lexer. Render
/// paths resolve a language tokenizer through `TokenizerRegistry` and use
/// `tokenize_document` directly; registry misses stay un-tokenized so the
/// renderer emits plain/default text.
pub fn highlight(doc : @model.TextSnapshot) -> Array[Token] {
  tokenize_document(doc, PlainTokenizer::new())
}

///|
/// CSS class emitted for this token tag by browser renderers.
pub fn HighlightTag::css_class(self : HighlightTag) -> String {
  match self {
    Keyword => "tok-keyword"
    Identifier => "tok-identifier"
    String => "tok-string"
    Number => "tok-number"
    Comment => "tok-comment"
    Punctuation => "tok-punctuation"
    Plain => "tok-plain"
    Operator => "tok-operator"
    Delimiter => "tok-delimiter"
    Type => "tok-type"
    Function => "tok-function"
    Variable => "tok-variable"
    Constant => "tok-constant"
    StringEscape => "tok-string-escape"
    CommentDoc => "tok-comment-doc"
    Regexp => "tok-regexp"
    Tag => "tok-tag"
    Attribute => "tok-attribute"
    Invalid => "tok-invalid"
  }
}
