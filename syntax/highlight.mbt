///|
pub(all) enum HighlightTag {
  Keyword
  Identifier
  String
  Number
  Comment
  Punctuation
  Plain
} derive(Eq, Debug)

///|
pub(all) struct Token {
  range : @core.Range
  tag : HighlightTag
  text : String
} derive(Debug)

///|
pub fn highlight(doc : @core.DocumentSnapshot) -> Array[Token] {
  let tokens = []
  let mut offset = 0
  while offset < doc.length() {
    let unit = doc.text[offset].to_int()
    if is_space(unit) {
      offset = offset + 1
    } else if unit == 47 &&
      offset + 1 < doc.length() &&
      doc.text[offset + 1].to_int() == 47 {
      let start = offset
      offset = consume_until_line_end(doc.text, offset)
      tokens.push({
        range: Range(start, offset),
        tag: Comment,
        text: doc.text[start:offset].to_owned(),
      })
    } else if unit == 34 {
      let start = offset
      offset = consume_string(doc.text, offset)
      tokens.push({
        range: Range(start, offset),
        tag: String,
        text: doc.text[start:offset].to_owned(),
      })
    } else if is_digit(unit) {
      let start = offset
      offset = consume_while(doc.text, offset, is_digit)
      tokens.push({
        range: Range(start, offset),
        tag: Number,
        text: doc.text[start:offset].to_owned(),
      })
    } else if is_ident_start(unit) {
      let start = offset
      offset = consume_while(doc.text, offset, is_ident_continue)
      let text = doc.text[start:offset].to_owned()
      tokens.push({
        range: Range(start, offset),
        tag: if is_keyword(text) {
          Keyword
        } else {
          Identifier
        },
        text,
      })
    } else {
      let start = offset
      offset = offset + 1
      tokens.push({
        range: Range(start, offset),
        tag: Punctuation,
        text: doc.text[start:offset].to_owned(),
      })
    }
  }
  tokens
}

///|
pub fn HighlightTag::css_class(self : HighlightTag) -> String {
  match self {
    Keyword => "tok-keyword"
    Identifier => "tok-identifier"
    String => "tok-string"
    Number => "tok-number"
    Comment => "tok-comment"
    Punctuation => "tok-punctuation"
    Plain => "tok-plain"
  }
}

///|
fn consume_until_line_end(text : String, offset : Int) -> Int {
  let mut at = offset
  while at < text.length() && text[at].to_int() != 10 {
    at = at + 1
  }
  at
}

///|
fn consume_string(text : String, offset : Int) -> Int {
  let mut at = offset + 1
  let mut escaped = false
  while at < text.length() {
    let unit = text[at].to_int()
    if escaped {
      escaped = false
    } else if unit == 92 {
      escaped = true
    } else if unit == 34 {
      at = at + 1
      return at
    }
    at = at + 1
  }
  at
}

///|
fn consume_while(text : String, offset : Int, pred : (Int) -> Bool) -> Int {
  let mut at = offset
  while at < text.length() && pred(text[at].to_int()) {
    at = at + 1
  }
  at
}

///|
fn is_space(unit : Int) -> Bool {
  unit == 9 || unit == 10 || unit == 13 || unit == 32
}

///|
fn is_digit(unit : Int) -> Bool {
  48 <= unit && unit <= 57
}

///|
fn is_ident_start(unit : Int) -> Bool {
  (65 <= unit && unit <= 90) || (97 <= unit && unit <= 122) || unit == 95
}

///|
fn is_ident_continue(unit : Int) -> Bool {
  is_ident_start(unit) || is_digit(unit)
}

///|
fn is_keyword(text : String) -> Bool {
  text == "fn" ||
  text == "let" ||
  text == "pub" ||
  text == "struct" ||
  text == "enum" ||
  text == "match" ||
  text == "if" ||
  text == "else" ||
  text == "while" ||
  text == "for" ||
  text == "return" ||
  text == "test" ||
  text == "import"
}
