///| Stateful and background grammar tokenization machinery.
///
/// Source: `vscode/src/vs/editor/common/model/textModelTokens.ts` at
/// `b18492a288de038fbc7643aae6de8247029d11bd`, lines 23-558. Incremental-edit
/// members are intentionally absent for readonly Viewer; immutable
/// `TokenizerState`, raw arrays, direct live model-state fields, `0x7FFFFFFF`, and the
/// cancellable injected scheduler are the Gate-B-approved adaptations.

///|
/// Strict UTF-16 line-length bound for cheap demand tokenization.
const CHEAP_TOKENIZATION_LENGTH_LIMIT : Int = 2048

///|
/// Private maximum-line sentinel used only when no invalid frontier exists.
const MAX_LINE_NUMBER_SENTINEL : Int = 0x7FFFFFFF

///|
/// One source-shaped syntactic font token returned beside encoded words.
#warnings("-struct_never_constructed-unused_value")
priv struct FontToken {
  start_index : Int
  end_index : Int
  font_family : String?
  font_size_multiplier : Double?
  line_height_multiplier : Double?
} derive(Eq, Debug)

///|
/// Raw start-offset token words, optional font information, and carried state.
#warnings("-unused_field")
priv struct EncodedTokenizationResult {
  tokens : Array[UInt]
  font_info : Array[FontToken]?
  end_state : @syntax.TokenizerState
}

///|
/// Internal source-shaped tokenization adapter. Unlike public
/// `syntax.LineTokenizer`, callbacks can fail and receive `has_eol`; tests may
/// inject those behaviors without widening the public syntax API.
priv struct InternalTokenizationSupportAdapter {
  get_initial_state : () -> @syntax.TokenizerState raise
  tokenize_encoded : (String, Bool, @syntax.TokenizerState) -> EncodedTokenizationResult raise
}

///|
/// Creates an internal adapter from source-shaped callbacks.
fn InternalTokenizationSupportAdapter::InternalTokenizationSupportAdapter(
  initial_state~ : () -> @syntax.TokenizerState raise,
  tokenize_encoded~ : (String, Bool, @syntax.TokenizerState) -> EncodedTokenizationResult raise,
) -> InternalTokenizationSupportAdapter {
  { get_initial_state: initial_state, tokenize_encoded }
}

///|
/// Acquires the initial carried state.
fn InternalTokenizationSupportAdapter::initial_state(
  self : InternalTokenizationSupportAdapter,
) -> @syntax.TokenizerState raise {
  (self.get_initial_state)()
}

///|
/// Tokenizes raw start-offset words while retaining the exact `has_eol` fact.
fn InternalTokenizationSupportAdapter::tokenize(
  self : InternalTokenizationSupportAdapter,
  text : String,
  has_eol : Bool,
  state : @syntax.TokenizerState,
) -> EncodedTokenizationResult raise {
  (self.tokenize_encoded)(text, has_eol, state)
}

///|
/// Wraps the reduced public tokenizer; `has_eol` is intentionally ignored only here.
fn public_tokenizer_adapter(
  tokenizer : &@syntax.LineTokenizer,
  codec : @services.LanguageIdCodec,
  language_id : String,
) -> InternalTokenizationSupportAdapter {
  InternalTokenizationSupportAdapter(
    initial_state=() => tokenizer.initial_state(),
    tokenize_encoded=(text, _has_eol, state) => {
      let (tokens, end_state) = tokenizer.tokenize_line(text, state)
      let encoded_language_id = codec.register(language_id)
      {
        tokens: encode_raw_start_offsets(
          tokens,
          text.length(),
          language_id=encoded_language_id,
        ),
        font_info: None,
        end_state,
      }
    },
  )
}

///|
/// Dense one-based line-end-state storage.
priv struct TokenizationStateStore {
  line_end_states : Array[@syntax.TokenizerState?]
}

///|
/// Creates an empty state store.
fn TokenizationStateStore::TokenizationStateStore() -> TokenizationStateStore {
  { line_end_states: [] }
}

///|
/// Returns one exact one-based end state.
fn TokenizationStateStore::get_end_state(
  self : TokenizationStateStore,
  line_number : Int,
) -> @syntax.TokenizerState? {
  if line_number < 0 || line_number >= self.line_end_states.length() {
    None
  } else {
    self.line_end_states[line_number]
  }
}

///|
/// Stores a changed state; equal values preserve the prior cell and return false.
fn TokenizationStateStore::set_end_state(
  self : TokenizationStateStore,
  line_number : Int,
  state : @syntax.TokenizerState,
) -> Bool {
  match self.get_end_state(line_number) {
    Some(old_state) => if old_state == state { return false }
    None => ()
  }
  while self.line_end_states.length() <= line_number {
    self.line_end_states.push(None)
  }
  self.line_end_states[line_number] = Some(state)
  true
}

///|
/// Sorted disjoint invalid-line priority queue.
priv struct RangePriorityQueueImpl {
  ranges : Array[@base_common.OffsetRange]
}

///|
/// Creates an empty queue.
fn RangePriorityQueueImpl::RangePriorityQueueImpl() -> RangePriorityQueueImpl {
  { ranges: [] }
}

///|
/// Returns the backing ranges in queue order.
#warnings("-unused_value")
fn RangePriorityQueueImpl::get_ranges(
  self : RangePriorityQueueImpl,
) -> Array[@base_common.OffsetRange] {
  self.ranges
}

///|
/// Smallest queued line, or `None`.
fn RangePriorityQueueImpl::min(self : RangePriorityQueueImpl) -> Int? {
  if self.ranges.is_empty() {
    None
  } else {
    Some(self.ranges[0].start)
  }
}

///|
/// Removes and returns the smallest line, advancing or deleting its range.
#warnings("-unused_value")
fn RangePriorityQueueImpl::remove_min(self : RangePriorityQueueImpl) -> Int? {
  if self.ranges.is_empty() {
    return None
  }
  let range = self.ranges[0]
  if range.start + 1 == range.end_exclusive {
    self.ranges.remove(0) |> ignore
  } else {
    self.ranges[0] = OffsetRange(range.start + 1, range.end_exclusive)
  }
  Some(range.start)
}

///|
/// Deletes one queued line, trimming/removing/splitting its containing range.
fn RangePriorityQueueImpl::delete(
  self : RangePriorityQueueImpl,
  value : Int,
) -> Unit {
  let mut index = -1
  for i, range in self.ranges {
    if range.contains(value) {
      index = i
      break
    }
  }
  if index == -1 {
    return
  }
  let range = self.ranges[index]
  if range.start == value {
    if range.end_exclusive == value + 1 {
      self.ranges.remove(index) |> ignore
    } else {
      self.ranges[index] = OffsetRange(value + 1, range.end_exclusive)
    }
  } else if range.end_exclusive == value + 1 {
    self.ranges[index] = OffsetRange(range.start, value)
  } else {
    self.ranges[index] = OffsetRange(range.start, value)
    self.ranges.insert(index + 1, OffsetRange(value + 1, range.end_exclusive))
  }
}

///|
/// Unions one half-open range into the queue.
fn RangePriorityQueueImpl::add_range(
  self : RangePriorityQueueImpl,
  range : @base_common.OffsetRange,
) -> Unit {
  @base_common.OffsetRange::add_range(range, self.ranges)
}

///|
/// Replaces/resizes an edit range and shifts every later queued range.
#warnings("-unused_value")
fn RangePriorityQueueImpl::add_range_and_resize(
  self : RangePriorityQueueImpl,
  range : @base_common.OffsetRange,
  new_length : Int,
) -> Unit {
  let mut first_might_intersect = 0
  while !(first_might_intersect >= self.ranges.length() ||
        range.start <= self.ranges[first_might_intersect].end_exclusive) {
    first_might_intersect += 1
  }
  let mut first_after = first_might_intersect
  while !(first_after >= self.ranges.length() ||
        range.end_exclusive < self.ranges[first_after].start) {
    first_after += 1
  }
  let delta = new_length - range.length()
  for i in first_after..<self.ranges.length() {
    self.ranges[i] = self.ranges[i].delta(delta)
  }
  if first_might_intersect == first_after {
    let replacement = @base_common.OffsetRange(
      range.start,
      range.start + new_length,
    )
    if !replacement.is_empty() {
      self.ranges.insert(first_might_intersect, replacement)
    }
  } else {
    let start = range.start.min(self.ranges[first_might_intersect].start)
    let end_exclusive = range.end_exclusive.max(
        self.ranges[first_after - 1].end_exclusive,
      ) +
      delta
    let replacement = @base_common.OffsetRange(start, end_exclusive)
    let delete_count = first_after - first_might_intersect
    for _ in 0..<delete_count {
      self.ranges.remove(first_might_intersect) |> ignore
    }
    if !replacement.is_empty() {
      self.ranges.insert(first_might_intersect, replacement)
    }
  }
}

///|
/// Joins each range representation with the literal source separator.
#warnings("-unused_value")
fn RangePriorityQueueImpl::to_string(self : RangePriorityQueueImpl) -> String {
  self.ranges.map(range => range.to_string()).join(" + ")
}

///|
/// Invalid-line record with its required carried start state.
priv struct FirstInvalidLine {
  line_number : Int
  start_state : @syntax.TokenizerState
}

///|
/// End-state storage plus invalid-line queue invariant.
priv struct TrackingTokenizationStateStore {
  tokenization_state_store : TokenizationStateStore
  invalid_end_states_line_numbers : RangePriorityQueueImpl
  line_count : Int
}

///|
/// Seeds every one-based line invalid as `[1,line_count+1)`.
fn TrackingTokenizationStateStore::TrackingTokenizationStateStore(
  line_count : Int,
) -> TrackingTokenizationStateStore {
  let invalid = RangePriorityQueueImpl()
  invalid.add_range(OffsetRange(1, line_count + 1))
  {
    tokenization_state_store: TokenizationStateStore(),
    invalid_end_states_line_numbers: invalid,
    line_count,
  }
}

///|
/// Returns one exact line end state.
fn TrackingTokenizationStateStore::get_end_state(
  self : TrackingTokenizationStateStore,
  line_number : Int,
) -> @syntax.TokenizerState? {
  self.tokenization_state_store.get_end_state(line_number)
}

///|
/// Commits a state and invalidates only its successor when changed and nonfinal.
fn TrackingTokenizationStateStore::set_end_state(
  self : TrackingTokenizationStateStore,
  line_number : Int,
  state : @syntax.TokenizerState,
) -> Bool {
  self.invalid_end_states_line_numbers.delete(line_number)
  let changed = self.tokenization_state_store.set_end_state(line_number, state)
  if changed && line_number < self.line_count {
    self.invalid_end_states_line_numbers.add_range(
      OffsetRange(line_number + 1, line_number + 2),
    )
  }
  changed
}

///|
/// Adds an exact invalid half-open line range.
fn TrackingTokenizationStateStore::invalidate_end_state_range(
  self : TrackingTokenizationStateStore,
  range : @base_common.LineRange,
) -> Unit {
  self.invalid_end_states_line_numbers.add_range(
    OffsetRange(range.start_line_number, range.end_line_number_exclusive),
  )
}

///|
/// Smallest invalid line or `None`.
fn TrackingTokenizationStateStore::get_first_invalid_end_state_line_number(
  self : TrackingTokenizationStateStore,
) -> Int? {
  self.invalid_end_states_line_numbers.min()
}

///|
/// Smallest invalid line or the private maximum-line sentinel.
fn TrackingTokenizationStateStore::get_first_invalid_end_state_line_number_or_max(
  self : TrackingTokenizationStateStore,
) -> Int {
  match self.get_first_invalid_end_state_line_number() {
    Some(line) => line
    None => MAX_LINE_NUMBER_SENTINEL
  }
}

///|
/// Whether every line end state is valid.
fn TrackingTokenizationStateStore::all_states_valid(
  self : TrackingTokenizationStateStore,
) -> Bool {
  self.invalid_end_states_line_numbers.min() is None
}

///|
/// Initial state for line one, predecessor end state otherwise.
fn TrackingTokenizationStateStore::get_start_state(
  self : TrackingTokenizationStateStore,
  line_number : Int,
  initial_state : @syntax.TokenizerState,
) -> @syntax.TokenizerState? {
  if line_number == 1 {
    Some(initial_state)
  } else {
    self.get_end_state(line_number - 1)
  }
}

///|
/// Resolves the first invalid line and asserts its predecessor-state invariant.
fn TrackingTokenizationStateStore::get_first_invalid_line(
  self : TrackingTokenizationStateStore,
  initial_state : @syntax.TokenizerState,
) -> FirstInvalidLine? {
  guard self.get_first_invalid_end_state_line_number() is Some(line_number) else {
    return None
  }
  guard self.get_start_state(line_number, initial_state) is Some(start_state) else {
    abort("Start state must be defined")
  }
  Some({ line_number, start_state })
}

///|
/// Tokenization support plus the initial/end-state tracker.
priv struct TokenizerWithStateStore {
  initial_state_value : @syntax.TokenizerState
  tokenization_support : InternalTokenizationSupportAdapter
  store : TrackingTokenizationStateStore
}

///|
/// Calls support initial-state acquisition and seeds the exact line count.
fn TokenizerWithStateStore::TokenizerWithStateStore(
  line_count : Int,
  tokenization_support : InternalTokenizationSupportAdapter,
) -> TokenizerWithStateStore raise {
  {
    initial_state_value: tokenization_support.initial_state(),
    tokenization_support,
    store: TrackingTokenizationStateStore(line_count),
  }
}

///|
/// Start state for an exact one-based line.
fn TokenizerWithStateStore::get_start_state(
  self : TokenizerWithStateStore,
  line_number : Int,
) -> @syntax.TokenizerState? {
  self.store.get_start_state(line_number, self.initial_state_value)
}

///|
/// First invalid line plus its start state.
fn TokenizerWithStateStore::get_first_invalid_line(
  self : TokenizerWithStateStore,
) -> FirstInvalidLine? {
  self.store.get_first_invalid_line(self.initial_state_value)
}

///|
/// Stateful tokenizer with live model state and a language-id codec.
priv struct TokenizerWithStateStoreAndTextModel {
  base : TokenizerWithStateStore
  model_state : TokenizationModelState
  language_id_codec : @services.LanguageIdCodec
}

///|
/// Preserves base initialization before retaining live model-state facts.
fn TokenizerWithStateStoreAndTextModel::TokenizerWithStateStoreAndTextModel(
  line_count : Int,
  tokenization_support : InternalTokenizationSupportAdapter,
  model_state : TokenizationModelState,
  language_id_codec : @services.LanguageIdCodec,
) -> TokenizerWithStateStoreAndTextModel raise {
  {
    base: TokenizerWithStateStore(line_count, tokenization_support),
    model_state,
    language_id_codec,
  }
}

///|
/// Exposes the live tracking store to backend scheduling.
fn TokenizerWithStateStoreAndTextModel::state_store(
  self : TokenizerWithStateStoreAndTextModel,
) -> TrackingTokenizationStateStore {
  self.base.store
}

///|
/// First invalid line plus carried state.
fn TokenizerWithStateStoreAndTextModel::get_first_invalid_line(
  self : TokenizerWithStateStoreAndTextModel,
) -> FirstInvalidLine? {
  self.base.get_first_invalid_line()
}

///|
/// Tokenizes invalid lines in order through the inclusive target.
fn TokenizerWithStateStoreAndTextModel::update_tokens_until_line(
  self : TokenizerWithStateStoreAndTextModel,
  builder : @common_tokens.ContiguousMultilineTokensBuilder,
  line_number : Int,
) -> Unit {
  for ;; {
    guard self.base.get_first_invalid_line() is Some(line_to_tokenize) &&
      line_to_tokenize.line_number <= line_number else {
      break
    }
    let text = self.model_state.snapshot.val.line_text(
      line_to_tokenize.line_number - 1,
    )
    let result = safe_tokenize(
      self.language_id_codec,
      self.model_state.language_id,
      Some(self.base.tokenization_support),
      text,
      true,
      line_to_tokenize.start_state,
      self.model_state,
    )
    builder.add(line_to_tokenize.line_number, result.tokens)
    self.base.store.set_end_state(
      line_to_tokenize.line_number,
      result.end_state,
    )
    |> ignore
  }
}

///|
/// Accurate iff the line lies strictly before the first invalid end state.
fn TokenizerWithStateStoreAndTextModel::has_accurate_tokens_for_line(
  self : TokenizerWithStateStoreAndTextModel,
  line_number : Int,
) -> Bool {
  line_number < self.base.store.get_first_invalid_end_state_line_number_or_max()
}

///|
/// Accurate lines are cheap; only a short first-invalid line is otherwise cheap.
fn TokenizerWithStateStoreAndTextModel::is_cheap_to_tokenize(
  self : TokenizerWithStateStoreAndTextModel,
  line_number : Int,
) -> Bool {
  let first_invalid = self.base.store.get_first_invalid_end_state_line_number_or_max()
  if line_number < first_invalid {
    return true
  }
  if line_number == first_invalid &&
    self.model_state.snapshot.val.get_line_length(line_number) <
    CHEAP_TOKENIZATION_LENGTH_LIMIT {
    return true
  }
  false
}

///|
/// Result flag distinguishing guessed-state viewport tokens from accurate demand.
priv struct HeuristicTokenizationResult {
  heuristic_tokens : Bool
}

///|
/// Chooses no-op, accurate-forward, or guessed-state viewport tokenization.
fn TokenizerWithStateStoreAndTextModel::tokenize_heuristically(
  self : TokenizerWithStateStoreAndTextModel,
  builder : @common_tokens.ContiguousMultilineTokensBuilder,
  start_line_number : Int,
  end_line_number : Int,
) -> HeuristicTokenizationResult {
  let first_invalid = self.base.store.get_first_invalid_end_state_line_number_or_max()
  if end_line_number <= first_invalid {
    return { heuristic_tokens: false }
  }
  if start_line_number <= first_invalid {
    self.update_tokens_until_line(builder, end_line_number)
    return { heuristic_tokens: false }
  }
  let mut state = self.guess_start_state(start_line_number)
  for line_number in start_line_number..<=end_line_number {
    let text = self.model_state.snapshot.val.line_text(line_number - 1)
    let result = safe_tokenize(
      self.language_id_codec,
      self.model_state.language_id,
      Some(self.base.tokenization_support),
      text,
      true,
      state,
      self.model_state,
    )
    builder.add(line_number, result.tokens)
    state = result.end_state
  }
  { heuristic_tokens: true }
}

///|
/// Finds likely indentation ancestors and replays them without EOL.
fn TokenizerWithStateStoreAndTextModel::guess_start_state(
  self : TokenizerWithStateStoreAndTextModel,
  line_number : Int,
) -> @syntax.TokenizerState {
  let relevant = find_likely_relevant_lines(
    self.model_state,
    line_number,
    Some(self.base),
  )
  let mut state = match relevant.initial_state {
    Some(initial_state) => initial_state
    None =>
      self.base.tokenization_support.initial_state() catch {
        error => {
          (self.model_state.report_unexpected_error)("\{to_repr(error)}")
          self.base.initial_state_value
        }
      }
  }
  for line in relevant.likely_relevant_lines {
    let result = safe_tokenize(
      self.language_id_codec,
      self.model_state.language_id,
      Some(self.base.tokenization_support),
      line,
      false,
      state,
      self.model_state,
    )
    state = result.end_state
  }
  state
}

///|
/// Indentation-ancestor search result.
priv struct LikelyRelevantLines {
  likely_relevant_lines : Array[String]
  initial_state : @syntax.TokenizerState?
}

///|
/// Walks backward across strictly smaller non-whitespace indentation and
/// returns ancestors in forward order plus the first cached start state.
fn find_likely_relevant_lines(
  model_state : TokenizationModelState,
  line_number : Int,
  store : TokenizerWithStateStore?,
) -> LikelyRelevantLines {
  let mut non_whitespace_column = model_state.snapshot.val.get_line_first_non_whitespace_column(
    line_number,
  )
  let likely_relevant_lines : Array[String] = []
  let mut initial_state : @syntax.TokenizerState? = None
  let mut i = line_number - 1
  while non_whitespace_column > 1 && i >= 1 {
    let new_non_whitespace_column = model_state.snapshot.val.get_line_first_non_whitespace_column(
      i,
    )
    if new_non_whitespace_column != 0 &&
      new_non_whitespace_column < non_whitespace_column {
      likely_relevant_lines.push(model_state.snapshot.val.line_text(i - 1))
      non_whitespace_column = new_non_whitespace_column
      match store {
        Some(state_store) => {
          initial_state = state_store.get_start_state(i)
          if initial_state is Some(_) {
            break
          }
        }
        None => ()
      }
    }
    i -= 1
  }
  likely_relevant_lines.rev_in_place()
  { likely_relevant_lines, initial_state }
}

///|
/// Calls support with an immutable state value, reports failures, applies the
/// language-tagged null fallback, then converts start offsets to end offsets
/// exactly once using the raw UTF-16 line length.
fn safe_tokenize(
  language_id_codec : @services.LanguageIdCodec,
  language_id : String,
  support : InternalTokenizationSupportAdapter?,
  text : String,
  has_eol : Bool,
  state : @syntax.TokenizerState,
  model_state : TokenizationModelState,
) -> EncodedTokenizationResult {
  let mut result : EncodedTokenizationResult? = None
  match support {
    Some(tokenization_support) =>
      try tokenization_support.tokenize(text, has_eol, state) catch {
        error => (model_state.report_unexpected_error)("\{to_repr(error)}")
      } noraise {
        value => result = Some(value)
      }
    None => ()
  }
  let encoded_result = match result {
    Some(value) => value
    None => {
      let encoded_language_id = language_id_codec.register(language_id)
      {
        tokens: [0, tag_to_metadata(Plain, language_id=encoded_language_id)],
        font_info: None,
        end_state: state,
      }
    }
  }
  start_offsets_to_end_offsets(encoded_result.tokens, text.length())
  encoded_result
}

///|
/// Callback contract consumed by default/custom background tokenizers.
priv struct BackgroundTokenizationStore {
  apply_tokens : (Array[@common_tokens.ContiguousMultilineTokens]) -> Unit
  apply_font_info : (FontTokensUpdate) -> Unit
  finish : () -> Unit
  apply_end_state : (Int, @syntax.TokenizerState) -> Unit
}

///|
/// Creates a background output store from source-shaped callbacks.
fn BackgroundTokenizationStore::BackgroundTokenizationStore(
  set_tokens~ : (Array[@common_tokens.ContiguousMultilineTokens]) -> Unit,
  set_font_info~ : (FontTokensUpdate) -> Unit,
  background_tokenization_finished~ : () -> Unit,
  set_end_state~ : (Int, @syntax.TokenizerState) -> Unit,
) -> BackgroundTokenizationStore {
  {
    apply_tokens: set_tokens,
    apply_font_info: set_font_info,
    finish: background_tokenization_finished,
    apply_end_state: set_end_state,
  }
}

///|
/// Applies a contiguous batch array.
fn BackgroundTokenizationStore::set_tokens(
  self : BackgroundTokenizationStore,
  tokens : Array[@common_tokens.ContiguousMultilineTokens],
) -> Unit {
  (self.apply_tokens)(tokens)
}

///|
/// Applies syntactic font updates.
#warnings("-unused_value")
fn BackgroundTokenizationStore::set_font_info(
  self : BackgroundTokenizationStore,
  changes : FontTokensUpdate,
) -> Unit {
  (self.apply_font_info)(changes)
}

///|
/// Publishes background completion.
fn BackgroundTokenizationStore::background_tokenization_finished(
  self : BackgroundTokenizationStore,
) -> Unit {
  (self.finish)()
}

///|
/// Applies one custom-worker end state.
#warnings("-unused_value")
fn BackgroundTokenizationStore::set_end_state(
  self : BackgroundTokenizationStore,
  line_number : Int,
  state : @syntax.TokenizerState,
) -> Unit {
  (self.apply_end_state)(line_number, state)
}

///|
/// Default cancellable idle/deadline grammar worker.
priv struct DefaultBackgroundTokenizer {
  tokenizer_with_state_store : TokenizerWithStateStoreAndTextModel
  background_token_store : BackgroundTokenizationStore
  mut is_disposed : Bool
  mut is_scheduled : Bool
  generation : Ref[Int]
  mut idle_handle : @base_common.Disposable?
  mut zero_handles : Array[@base_common.Disposable]
}

///|
/// Creates an unscheduled live worker.
fn DefaultBackgroundTokenizer::DefaultBackgroundTokenizer(
  tokenizer_with_state_store : TokenizerWithStateStoreAndTextModel,
  background_token_store : BackgroundTokenizationStore,
) -> DefaultBackgroundTokenizer {
  {
    tokenizer_with_state_store,
    background_token_store,
    is_disposed: false,
    is_scheduled: false,
    generation: Ref(0),
    idle_handle: None,
    zero_handles: [],
  }
}

///|
/// Invalidates and cancels every queued callback and resets the coalescing gate.
fn DefaultBackgroundTokenizer::cancel_pending(
  self : DefaultBackgroundTokenizer,
) -> Unit {
  self.generation.val += 1
  match self.idle_handle {
    Some(handle) => handle.dispose()
    None => ()
  }
  self.idle_handle = None
  for handle in self.zero_handles {
    handle.dispose()
  }
  self.zero_handles = []
  self.is_scheduled = false
}

///|
/// Terminal disposal makes every old-generation callback inert.
fn DefaultBackgroundTokenizer::dispose(
  self : DefaultBackgroundTokenizer,
) -> Unit {
  if !self.is_disposed {
    self.is_disposed = true
    self.cancel_pending()
  }
}

///|
/// Begins/restarts work. A final detach cancels the generation; a late first
/// scheduler installation while attached enters the ordinary begin path once.
fn DefaultBackgroundTokenizer::handle_changes(
  self : DefaultBackgroundTokenizer,
) -> Unit {
  if self.tokenizer_with_state_store.model_state.attached_count.val == 0 {
    self.cancel_pending()
    return
  }
  self.begin_background_tokenization()
}

///|
/// Coalesces idle scheduling and guards detached/finished/no-scheduler states.
fn DefaultBackgroundTokenizer::begin_background_tokenization(
  self : DefaultBackgroundTokenizer,
) -> Unit {
  if self.is_disposed ||
    self.is_scheduled ||
    self.tokenizer_with_state_store.model_state.attached_count.val == 0 ||
    !self.has_lines_to_tokenize() {
    return
  }
  guard self.tokenizer_with_state_store.model_state.scheduler.val
    is Some(scheduler) else {
    return
  }
  self.is_scheduled = true
  self.generation.val += 1
  let generation = self.generation.val
  self.idle_handle = Some(
    scheduler.idle(deadline => {
      if self.is_disposed || generation != self.generation.val {
        return
      }
      self.idle_handle = None
      self.is_scheduled = false
      self.background_tokenize_with_deadline(deadline, generation)
    }),
  )
}

///|
/// Captures remaining time immediately, then computes the absolute end time.
fn DefaultBackgroundTokenizer::background_tokenize_with_deadline(
  self : DefaultBackgroundTokenizer,
  deadline : TokenizationIdleDeadline,
  generation : Int,
) -> Unit {
  let remaining = deadline.time_remaining()
  guard self.tokenizer_with_state_store.model_state.scheduler.val
    is Some(scheduler) else {
    return
  }
  let end_time = scheduler.now() + remaining
  self.execute_slice_until_deadline(end_time, generation)
}

///|
/// Runs one synchronous slice, then yields by zero timeout or requests a new idle turn.
fn DefaultBackgroundTokenizer::execute_slice_until_deadline(
  self : DefaultBackgroundTokenizer,
  end_time : Double,
  generation : Int,
) -> Unit {
  if self.is_disposed ||
    generation != self.generation.val ||
    self.tokenizer_with_state_store.model_state.attached_count.val == 0 ||
    !self.has_lines_to_tokenize() {
    return
  }
  self.background_tokenize_for_at_least_1ms()
  guard self.tokenizer_with_state_store.model_state.scheduler.val
    is Some(scheduler) else {
    return
  }
  if scheduler.now() < end_time {
    let handle = scheduler.zero_timeout(() => {
      self.execute_slice_until_deadline(end_time, generation)
    })
    self.zero_handles.push(handle)
  } else {
    self.begin_background_tokenization()
  }
}

///|
/// Tokenizes at least one invalid line unless elapsed time is already greater than 1 ms.
fn DefaultBackgroundTokenizer::background_tokenize_for_at_least_1ms(
  self : DefaultBackgroundTokenizer,
) -> Unit {
  let line_count = self.tokenizer_with_state_store.model_state.snapshot.val.line_count()
  let builder = @common_tokens.ContiguousMultilineTokensBuilder::new()
  let started = match
    self.tokenizer_with_state_store.model_state.scheduler.val {
    Some(scheduler) => scheduler.now()
    None => 0.0
  }
  for ;; {
    let elapsed = match
      self.tokenizer_with_state_store.model_state.scheduler.val {
      Some(scheduler) => scheduler.now() - started
      None => 2.0
    }
    if elapsed > 1.0 {
      break
    }
    let tokenized_line_number = self.tokenize_one_invalid_line(builder)
    if tokenized_line_number >= line_count || !self.has_lines_to_tokenize() {
      break
    }
  }
  self.background_token_store.set_tokens(builder.finalize())
  self.check_finished()
}

///|
/// Whether invalid state remains.
fn DefaultBackgroundTokenizer::has_lines_to_tokenize(
  self : DefaultBackgroundTokenizer,
) -> Bool {
  !self.tokenizer_with_state_store.base.store.all_states_valid()
}

///|
/// Tokenizes exactly the first invalid line, or returns `line_count + 1`.
fn DefaultBackgroundTokenizer::tokenize_one_invalid_line(
  self : DefaultBackgroundTokenizer,
  builder : @common_tokens.ContiguousMultilineTokensBuilder,
) -> Int {
  guard self.tokenizer_with_state_store.get_first_invalid_line()
    is Some(first_invalid) else {
    return self.tokenizer_with_state_store.model_state.snapshot.val.line_count() +
      1
  }
  self.tokenizer_with_state_store.update_tokens_until_line(
    builder,
    first_invalid.line_number,
  )
  first_invalid.line_number
}

///|
/// Publishes completion whenever live and all states are valid.
fn DefaultBackgroundTokenizer::check_finished(
  self : DefaultBackgroundTokenizer,
) -> Unit {
  if self.is_disposed {
    return
  }
  if self.tokenizer_with_state_store.base.store.all_states_valid() {
    self.background_token_store.background_tokenization_finished()
  }
}

///|
/// Marks the exact requested half-open range invalid; callers own scheduling.
fn DefaultBackgroundTokenizer::request_tokens(
  self : DefaultBackgroundTokenizer,
  start_line_number : Int,
  end_line_number_exclusive : Int,
) -> Unit {
  self.tokenizer_with_state_store.base.store.invalidate_end_state_range(
    LineRange(start_line_number, end_line_number_exclusive),
  )
}
