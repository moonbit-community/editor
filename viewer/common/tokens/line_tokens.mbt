///| Faithful 1:1 port of vscode's `LineTokens` / `SliceLineTokens`.
///
/// Source: `src/vs/editor/common/tokens/lineTokens.ts` (pinned `vscode/`
/// submodule). The binary token store is a flat `Array[UInt]` mirroring
/// Monaco's `Uint32Array`: even slots hold a token's exclusive end offset,
/// odd slots its packed metadata word (see `encoded_token_attributes.mbt`).
/// The codec parameter is `@services.LanguageIdCodec`
/// (`services/languages_registry.mbt`), the `ILanguageIdCodec` role
/// `lineTokens.ts` takes.
///
/// Deviations from the source, none of which the conformance suite exercises:
///   - The `IViewLineTokens` trait omits `equals` (needs concrete-type
///     discrimination), the `languageIdCodec` field accessor, and `getInlineStyle`
///     stays via `color_map : Array[String]`.
///   - `LineTokens` omits `getTokensInRange` / `toString` (these pull in the
///     unported `TokenArray` family).
///   - The constructor skips Monaco's soft token-length/text-length mismatch
///     warning (`onUnexpectedError`); the readonly viewer has no such reporter.
///   - `with_inserted` guards the middle-insert metadata read against a
///     past-end token index (Monaco reads `undefined`); the read is unreachable
///     for valid in-bounds insert offsets.
///   - MoonBit's scalar-validating `StringView` cannot represent Monaco's raw
///     UTF-16 slices at lone-surrogate or pair-interior boundaries, so every
///     token-content slice uses `String::unsafe_substring`.

///|
/// A line's tokens, viewed as a sequence with per-token end offset and
/// metadata. Both `LineTokens` and `SliceLineTokens` implement it.
pub trait IViewLineTokens {
  fn get_count(Self) -> Int
  fn get_standard_token_type(Self, Int) -> Int
  fn get_foreground(Self, Int) -> Int
  fn get_end_offset(Self, Int) -> Int
  fn get_class_name(Self, Int) -> String
  fn get_inline_style(Self, Int, Array[String]) -> String
  fn get_presentation(Self, Int) -> TokenPresentation
  fn find_token_index_at_offset(Self, Int) -> Int
  fn get_line_content(Self) -> String
  fn get_metadata(Self, Int) -> UInt
  fn get_language_id(Self, Int) -> String
  fn get_token_text(Self, Int) -> String
  fn for_each(Self, (Int) -> Unit) -> Unit
}

///|
/// A token sequence backed by a flat metadata array. `tokens[i << 1]` is the
/// exclusive end offset of token `i`; `tokens[(i << 1) + 1]` its metadata.
pub struct LineTokens {
  tokens : Array[UInt]
  tokens_count : Int
  text : String
  language_id_codec : @services.LanguageIdCodec
}

///|
pub fn LineTokens::new(
  tokens : Array[UInt],
  text : String,
  decoder : @services.LanguageIdCodec,
) -> LineTokens {
  {
    tokens,
    tokens_count: tokens.length() >> 1,
    text,
    language_id_codec: decoder,
  }
}

///|
/// The default metadata word (no font style, default fg/bg colors).
pub fn LineTokens::default_token_metadata() -> UInt {
  ((FONT_STYLE_NONE << METADATA_FONT_STYLE_OFFSET) |
  (COLOR_ID_DEFAULT_FOREGROUND << METADATA_FOREGROUND_OFFSET) |
  (COLOR_ID_DEFAULT_BACKGROUND << METADATA_BACKGROUND_OFFSET)).reinterpret_as_uint()
}

///|
pub fn LineTokens::create_empty(
  line_content : String,
  decoder : @services.LanguageIdCodec,
) -> LineTokens {
  let tokens : Array[UInt] = [
    line_content.length().reinterpret_as_uint(),
    LineTokens::default_token_metadata(),
  ]
  LineTokens::new(tokens, line_content, decoder)
}

///|
pub fn LineTokens::create_from_text_and_metadata(
  data : Array[(String, UInt)],
  decoder : @services.LanguageIdCodec,
) -> LineTokens {
  let mut offset = 0
  let mut full_text = ""
  let tokens : Array[UInt] = []
  for item in data {
    let (text, metadata) = item
    offset = offset + text.length()
    tokens.push(offset.reinterpret_as_uint())
    tokens.push(metadata)
    full_text = full_text + text
  }
  LineTokens::new(tokens, full_text, decoder)
}

///|
/// Rewrites `tokens` start-offset slots in place to be end offsets.
pub fn LineTokens::convert_to_end_offset(
  tokens : Array[UInt],
  line_text_length : Int,
) -> Unit {
  let token_count = tokens.length() >> 1
  let last_token_index = token_count - 1
  for token_index in 0..<last_token_index {
    tokens[token_index << 1] = tokens[(token_index + 1) << 1]
  }
  tokens[last_token_index << 1] = line_text_length.reinterpret_as_uint()
}

///|
/// Binary-searches the token containing `desired_index`. Mirrors Monaco's
/// static `findIndexInTokensArray`.
pub fn LineTokens::find_index_in_tokens_array(
  tokens : Array[UInt],
  desired_index : Int,
) -> Int {
  if tokens.length() <= 2 {
    return 0
  }
  let mut low = 0
  let mut high = (tokens.length() >> 1) - 1
  while low < high {
    let mid = low + (high - low) / 2
    let end_offset = tokens[mid << 1].reinterpret_as_int()
    if end_offset == desired_index {
      return mid + 1
    } else if end_offset < desired_index {
      low = mid + 1
    } else {
      high = mid
    }
  }
  low
}

///|
pub fn LineTokens::get_text_length(self : LineTokens) -> Int {
  self.text.length()
}

///|
pub fn LineTokens::get_start_offset(
  self : LineTokens,
  token_index : Int,
) -> Int {
  if token_index > 0 {
    self.tokens[(token_index - 1) << 1].reinterpret_as_int()
  } else {
    0
  }
}

///|
/// `inflate()` returns the tokens unchanged — already a view.
pub fn LineTokens::inflate(self : LineTokens) -> &IViewLineTokens {
  self
}

///|
pub fn LineTokens::slice_and_inflate(
  self : LineTokens,
  start_offset : Int,
  end_offset : Int,
  delta_offset : Int,
) -> &IViewLineTokens {
  SliceLineTokens::new(self, start_offset, end_offset, delta_offset)
}

///|
pub fn LineTokens::slice_zero_copy(
  self : LineTokens,
  range : @base_common.OffsetRange,
) -> &IViewLineTokens {
  self.slice_and_inflate(range.start, range.end_exclusive, 0)
}

///|
/// A token to splice into the line. `insert_tokens` must be sorted by offset.
pub struct InsertedToken {
  offset : Int
  text : String
  token_metadata : UInt
}

///|
pub fn InsertedToken::new(
  offset : Int,
  text : String,
  token_metadata : UInt,
) -> InsertedToken {
  { offset, text, token_metadata }
}

///|
/// Returns a new `LineTokens` with `insert_tokens` spliced into the text and
/// token boundaries. Pure; the receiver is unchanged.
pub fn LineTokens::with_inserted(
  self : LineTokens,
  insert_tokens : Array[InsertedToken],
) -> LineTokens {
  if insert_tokens.length() == 0 {
    return self
  }
  let mut next_original_token_idx = 0
  let mut next_insert_token_idx = 0
  let mut text = ""
  let new_tokens : Array[UInt] = []
  let mut original_end_offset = 0
  while true {
    let next_original_token_end_offset = if next_original_token_idx <
      self.tokens_count {
      self.tokens[next_original_token_idx << 1].reinterpret_as_int()
    } else {
      -1
    }
    let has_insert = next_insert_token_idx < insert_tokens.length()
    if next_original_token_end_offset != -1 &&
      (
        !has_insert ||
        next_original_token_end_offset <=
        insert_tokens[next_insert_token_idx].offset
      ) {
      // original token ends before the next insert token
      text = text +
        substr(self.text, original_end_offset, next_original_token_end_offset)
      let metadata = self.tokens[(next_original_token_idx << 1) + 1]
      new_tokens.push(text.length().reinterpret_as_uint())
      new_tokens.push(metadata)
      next_original_token_idx = next_original_token_idx + 1
      original_end_offset = next_original_token_end_offset
    } else if has_insert {
      let next_insert_token = insert_tokens[next_insert_token_idx]
      if next_insert_token.offset > original_end_offset {
        // insert token is in the middle of the next token
        text = text +
          substr(self.text, original_end_offset, next_insert_token.offset)
        let metadata = if next_original_token_idx < self.tokens_count {
          self.tokens[(next_original_token_idx << 1) + 1]
        } else {
          LineTokens::default_token_metadata()
        }
        new_tokens.push(text.length().reinterpret_as_uint())
        new_tokens.push(metadata)
        original_end_offset = next_insert_token.offset
      }
      text = text + next_insert_token.text
      new_tokens.push(text.length().reinterpret_as_uint())
      new_tokens.push(next_insert_token.token_metadata)
      next_insert_token_idx = next_insert_token_idx + 1
    } else {
      break
    }
  }
  LineTokens::new(new_tokens, text, self.language_id_codec)
}

///|
pub fn LineTokens::get_count(self : LineTokens) -> Int {
  self.tokens_count
}

///|
impl IViewLineTokens for LineTokens with fn get_count(self) {
  LineTokens::get_count(self)
}

///|
pub fn LineTokens::get_line_content(self : LineTokens) -> String {
  self.text
}

///|
impl IViewLineTokens for LineTokens with fn get_line_content(self) {
  LineTokens::get_line_content(self)
}

///|
pub fn LineTokens::get_end_offset(self : LineTokens, token_index : Int) -> Int {
  self.tokens[token_index << 1].reinterpret_as_int()
}

///|
impl IViewLineTokens for LineTokens with fn get_end_offset(self, token_index) {
  LineTokens::get_end_offset(self, token_index)
}

///|
pub fn LineTokens::get_metadata(self : LineTokens, token_index : Int) -> UInt {
  self.tokens[(token_index << 1) + 1]
}

///|
impl IViewLineTokens for LineTokens with fn get_metadata(self, token_index) {
  LineTokens::get_metadata(self, token_index)
}

///|
pub fn LineTokens::get_language_id(
  self : LineTokens,
  token_index : Int,
) -> String {
  let metadata = self.tokens[(token_index << 1) + 1]
  self.language_id_codec.decode_language_id(
    TokenMetadata::get_language_id(metadata),
  )
}

///|
impl IViewLineTokens for LineTokens with fn get_language_id(self, token_index) {
  LineTokens::get_language_id(self, token_index)
}

///|
pub fn LineTokens::get_standard_token_type(
  self : LineTokens,
  token_index : Int,
) -> Int {
  TokenMetadata::get_token_type(self.tokens[(token_index << 1) + 1])
}

///|
impl IViewLineTokens for LineTokens with fn get_standard_token_type(
  self,
  token_index,
) {
  LineTokens::get_standard_token_type(self, token_index)
}

///|
pub fn LineTokens::get_foreground(self : LineTokens, token_index : Int) -> Int {
  TokenMetadata::get_foreground(self.tokens[(token_index << 1) + 1])
}

///|
impl IViewLineTokens for LineTokens with fn get_foreground(self, token_index) {
  LineTokens::get_foreground(self, token_index)
}

///|
pub fn LineTokens::get_class_name(
  self : LineTokens,
  token_index : Int,
) -> String {
  TokenMetadata::get_class_name_from_metadata(
    self.tokens[(token_index << 1) + 1],
  )
}

///|
impl IViewLineTokens for LineTokens with fn get_class_name(self, token_index) {
  LineTokens::get_class_name(self, token_index)
}

///|
pub fn LineTokens::get_inline_style(
  self : LineTokens,
  token_index : Int,
  color_map : Array[String],
) -> String {
  TokenMetadata::get_inline_style_from_metadata(
    self.tokens[(token_index << 1) + 1],
    color_map,
  )
}

///|
impl IViewLineTokens for LineTokens with fn get_inline_style(
  self,
  token_index,
  color_map,
) {
  LineTokens::get_inline_style(self, token_index, color_map)
}

///|
pub fn LineTokens::get_presentation(
  self : LineTokens,
  token_index : Int,
) -> TokenPresentation {
  TokenMetadata::get_presentation_from_metadata(
    self.tokens[(token_index << 1) + 1],
  )
}

///|
impl IViewLineTokens for LineTokens with fn get_presentation(self, token_index) {
  LineTokens::get_presentation(self, token_index)
}

///|
pub fn LineTokens::find_token_index_at_offset(
  self : LineTokens,
  offset : Int,
) -> Int {
  LineTokens::find_index_in_tokens_array(self.tokens, offset)
}

///|
impl IViewLineTokens for LineTokens with fn find_token_index_at_offset(
  self,
  offset,
) {
  LineTokens::find_token_index_at_offset(self, offset)
}

///|
pub fn LineTokens::get_token_text(
  self : LineTokens,
  token_index : Int,
) -> String {
  substr(
    self.text,
    self.get_start_offset(token_index),
    self.get_end_offset(token_index),
  )
}

///|
impl IViewLineTokens for LineTokens with fn get_token_text(self, token_index) {
  LineTokens::get_token_text(self, token_index)
}

///|
pub fn LineTokens::for_each(
  self : LineTokens,
  callback : (Int) -> Unit,
) -> Unit {
  for token_index in 0..<self.get_count() {
    callback(token_index)
  }
}

///|
impl IViewLineTokens for LineTokens with fn for_each(self, callback) {
  LineTokens::for_each(self, callback)
}

///|
/// A read-only window onto a `LineTokens`, offset by `delta_offset`. Mirrors
/// Monaco's `SliceLineTokens`.
priv struct SliceLineTokens {
  source : LineTokens
  start_offset : Int
  end_offset : Int
  delta_offset : Int
  first_token_index : Int
  tokens_count : Int
}

///|
fn SliceLineTokens::new(
  source : LineTokens,
  start_offset : Int,
  end_offset : Int,
  delta_offset : Int,
) -> SliceLineTokens {
  let first_token_index = source.find_token_index_at_offset(start_offset)
  let mut tokens_count = 0
  for i = first_token_index; i < source.get_count(); i = i + 1 {
    let token_start_offset = source.get_start_offset(i)
    if token_start_offset >= end_offset {
      break
    }
    tokens_count = tokens_count + 1
  }
  {
    source,
    start_offset,
    end_offset,
    delta_offset,
    first_token_index,
    tokens_count,
  }
}

///|
impl IViewLineTokens for SliceLineTokens with fn get_count(self) {
  self.tokens_count
}

///|
impl IViewLineTokens for SliceLineTokens with fn get_line_content(self) {
  substr(self.source.get_line_content(), self.start_offset, self.end_offset)
}

///|
impl IViewLineTokens for SliceLineTokens with fn get_metadata(self, token_index) {
  self.source.get_metadata(self.first_token_index + token_index)
}

///|
impl IViewLineTokens for SliceLineTokens with fn get_language_id(
  self,
  token_index,
) {
  self.source.get_language_id(self.first_token_index + token_index)
}

///|
impl IViewLineTokens for SliceLineTokens with fn get_standard_token_type(
  self,
  token_index,
) {
  self.source.get_standard_token_type(self.first_token_index + token_index)
}

///|
impl IViewLineTokens for SliceLineTokens with fn get_foreground(
  self,
  token_index,
) {
  self.source.get_foreground(self.first_token_index + token_index)
}

///|
impl IViewLineTokens for SliceLineTokens with fn get_end_offset(
  self,
  token_index,
) {
  let token_end_offset = self.source.get_end_offset(
    self.first_token_index + token_index,
  )
  self.end_offset.min(token_end_offset) - self.start_offset + self.delta_offset
}

///|
impl IViewLineTokens for SliceLineTokens with fn get_class_name(
  self,
  token_index,
) {
  self.source.get_class_name(self.first_token_index + token_index)
}

///|
impl IViewLineTokens for SliceLineTokens with fn get_inline_style(
  self,
  token_index,
  color_map,
) {
  self.source.get_inline_style(self.first_token_index + token_index, color_map)
}

///|
impl IViewLineTokens for SliceLineTokens with fn get_presentation(
  self,
  token_index,
) {
  self.source.get_presentation(self.first_token_index + token_index)
}

///|
impl IViewLineTokens for SliceLineTokens with fn find_token_index_at_offset(
  self,
  offset,
) {
  self.source.find_token_index_at_offset(
    offset + self.start_offset - self.delta_offset,
  ) -
  self.first_token_index
}

///|
impl IViewLineTokens for SliceLineTokens with fn get_token_text(
  self,
  token_index,
) {
  let adjusted_token_index = self.first_token_index + token_index
  let token_start_offset = self.source.get_start_offset(adjusted_token_index)
  let token_end_offset = self.source.get_end_offset(adjusted_token_index)
  let mut text = self.source.get_token_text(adjusted_token_index)
  if token_start_offset < self.start_offset {
    text = substr(text, self.start_offset - token_start_offset, text.length())
  }
  if token_end_offset > self.end_offset {
    text = substr(text, 0, text.length() - (token_end_offset - self.end_offset))
  }
  text
}

///|
impl IViewLineTokens for SliceLineTokens with fn for_each(self, callback) {
  for token_index in 0..<self.get_count() {
    callback(token_index)
  }
}

///|
/// Raw UTF-16 code-unit substring `[start, end)`. Unlike `StringView`, this
/// preserves lone surrogates and either half of a valid pair.
fn substr(s : String, start : Int, end : Int) -> String {
  s.unsafe_substring(start~, end~)
}
