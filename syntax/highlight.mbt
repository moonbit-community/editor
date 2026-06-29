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
/// Tokenizes the whole document with the generic fallback lexer. Render
/// paths resolve a language tokenizer through `TokenizerRegistry` and use
/// `tokenize_document` directly; registry misses stay un-tokenized so the
/// renderer emits plain/default text.
pub fn highlight(doc : @model.TextSnapshot) -> Array[Token] {
  tokenize_document(doc, PlainTokenizer::new())
}
