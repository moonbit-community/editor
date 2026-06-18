///|
/// Per-version tokenized document, the Monaco `TextModel` tokens role: the
/// document snapshot plus syntax tokens bucketed per line, built once per
/// document version with a single forward sweep over the sorted token
/// array. Frame builds read line buckets, so a window build costs
/// O(window) instead of O(document x tokens).
pub struct TokenizedDocument {
  snapshot : @model.TextSnapshot
  token_count : Int
  line_tokens : Array[Array[@syntax.Token]]
}

///|
/// Builds line buckets from a document snapshot and whole-document token list.
pub fn TokenizedDocument::build(
  snapshot : @model.TextSnapshot,
  tokens : Array[@syntax.Token],
) -> TokenizedDocument {
  {
    snapshot,
    token_count: tokens.length(),
    line_tokens: bucket_by_line(snapshot, tokens, token => token.range),
  }
}

///|
/// Tokens intersecting a zero-based model line.
pub fn TokenizedDocument::tokens_for_line(
  self : TokenizedDocument,
  line : Int,
) -> Array[@syntax.Token] {
  match self.line_tokens.get(line) {
    Some(bucket) => bucket
    None => []
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
  line_decorations : Array[Array[@decorations.Decoration]]
  line_semantic_tokens : Array[Array[@language.SemanticToken]]
}

///|
/// Builds a frame source by bucketing decorations and semantic tokens per line.
pub fn FrameSource::FrameSource(
  tokenized : TokenizedDocument,
  decoration_set : @decorations.DecorationSet,
  providers : @language.ProviderResult,
) -> FrameSource {
  let snapshot = tokenized.snapshot
  {
    tokenized,
    providers,
    line_decorations: bucket_by_line(snapshot, decoration_set.items, decoration => {
      decoration.range
    }),
    line_semantic_tokens: bucket_by_line(snapshot, providers.semantic_tokens, token => {
      token.range
    }),
  }
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
  range_of : (T) -> @base_common.Range,
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
          snapshot.line_start_offset(covered) < range.end {
      let line_range = @base_common.Range(
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
