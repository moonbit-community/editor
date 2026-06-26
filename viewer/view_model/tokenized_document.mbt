///|
/// Per-version tokenized document, the Monaco `TextModel` tokens role: the
/// document snapshot plus syntax tokens bucketed per line, built once per
/// document version with a single forward sweep over the sorted token
/// array. Frame builds read line buckets, so a window build costs
/// O(window) instead of O(document x tokens).
pub struct TokenizedDocument {
  snapshot : @model.TextSnapshot
  token_count : Int
  // Faithful per-line binary token store (Monaco's `TextModel` line tokens),
  // the production token model. Per-line so a wrapped view line can later slice
  // it through `SliceLineTokens` (word wrap is out of scope here, but this is
  // the storage shape it needs).
  line_tokens : Array[LineTokens]
}

///|
/// Buckets the whole-document tokens per line and encodes each line's bucket
/// into a faithful `LineTokens` (the MoonBit lexers stay the sole token source;
/// only the on-line encoding is Monaco's binary store). The simplified
/// `@syntax.Token` buckets are a transient local, not retained.
pub fn TokenizedDocument::build(
  snapshot : @model.TextSnapshot,
  tokens : Array[@syntax.Token],
) -> TokenizedDocument {
  let buckets = bucket_by_line(snapshot, tokens, token => token.range)
  let decoder = LanguageIdCodec::new()
  let line_tokens : Array[LineTokens] = []
  for line in 0..<snapshot.line_count() {
    line_tokens.push(
      line_tokens_from_syntax_tokens(
        snapshot.line_text(line),
        snapshot.line_start_offset(line),
        buckets[line],
        decoder,
      ),
    )
  }
  { snapshot, token_count: tokens.length(), line_tokens }
}

///|
/// The faithful `LineTokens` for a zero-based model line. Out-of-range lines
/// answer an empty token line instead of trapping.
pub fn TokenizedDocument::line_tokens_for_line(
  self : TokenizedDocument,
  line : Int,
) -> LineTokens {
  match self.line_tokens.get(line) {
    Some(line_tokens) => line_tokens
    None => LineTokens::create_empty("", LanguageIdCodec::new())
  }
}

///|
/// Everything needed to emit viewport-scoped frames for one document
/// version: the tokenized document plus feature data bucketed per line
/// when it arrives. Provider pushes build a new source from the cached
/// tokenized document; window shifts reuse the source unchanged. Building
/// a frame from a source never re-tokenizes and never scans
/// whole-document feature arrays.
pub struct FrameSource {
  tokenized : TokenizedDocument
  providers : @language.ProviderResult
  decorations : Array[@decorations.Decoration]
}

///|
/// Builds a frame source by retaining decorations (converted to view
/// coordinates lazily by the view model).
pub fn FrameSource::FrameSource(
  tokenized : TokenizedDocument,
  decoration_set : @decorations.DecorationSet,
  providers : @language.ProviderResult,
) -> FrameSource {
  { tokenized, providers, decorations: decoration_set.items }
}

///|
/// Buckets ranged items per line. An item lands in the bucket of every
/// line whose text range it intersects, so newline-only ranges land
/// nowhere — exactly the items a whole-document intersection scan would
/// keep per line, in the same order. Sorted inputs (syntax tokens) place
/// each item with a forward sweep; out-of-order items (feature data makes
/// no ordering promise) restart the cursor through a binary search.
fn[T] bucket_by_line(
  snapshot : @model.TextSnapshot,
  items : Array[T],
  range_of : (T) -> @base_common.OffsetRange,
) -> Array[Array[T]] {
  let line_count = snapshot.line_count()
  let buckets : Array[Array[T]] = []
  for _ in 0..<line_count {
    buckets.push([])
  }
  let mut line = 0
  for item in items {
    let range = range_of(item)
    if range.start < snapshot.line_start_offset(line) {
      line = line_at_offset_binary(snapshot, range.start)
    }
    while line + 1 < line_count &&
          range.start >= snapshot.line_start_offset(line + 1) {
      line = line + 1
    }
    let mut covered = line
    while covered < line_count &&
          snapshot.line_start_offset(covered) < range.end_exclusive {
      let line_range = @base_common.OffsetRange(
        snapshot.line_start_offset(covered),
        snapshot.line_end_offset(covered),
      )
      if range.intersects(line_range) {
        buckets[covered].push(item)
      }
      covered = covered + 1
    }
  }
  buckets
}

///|
fn line_at_offset_binary(snapshot : @model.TextSnapshot, offset : Int) -> Int {
  let starts = snapshot.line_starts
  for low = 0, high = starts.length() - 1; low < high; {
    let mid = low + (high - low + 1) / 2
    if starts[mid] <= offset {
      continue mid, high
    } else {
      continue low, mid - 1
    }
  } nobreak {
    low
  } where {
    proof_invariant: 0 <= low && low <= high,
    proof_reasoning: (
      #|Upper-biased midpoint with `starts[mid] <= offset ? low=mid : high=mid-1`
      #|keeps the loop converging on the last line start at or before `offset`;
      #|`starts[0] == 0 <= offset` anchors the lower bound.
      #|
    ),
  }
}
