///|
/// Which side of its anchor range an inlay hint attaches to.
pub(all) enum InlayHintAnchorDirection {
  Before
  After
} derive(Eq, Debug)

///|
/// Stable model range and direction used to reattach an inlay hint after a
/// model-scoped request completes.
pub struct InlayHintAnchor {
  range : @base_common.Range
  direction : InlayHintAnchorDirection
} derive(Eq, Debug)

///|
/// Builds an inlay-hint anchor.
pub fn InlayHintAnchor::new(
  range : @base_common.Range,
  direction : InlayHintAnchorDirection,
) -> InlayHintAnchor {
  { range, direction }
}

///|
/// One retained hint together with its derived anchor and owning provider.
pub struct InlayHintItem {
  hint : @language.InlayHint
  anchor : InlayHintAnchor
  provider : &@language.InlayHintsProvider
}

///|
/// Builds a retained inlay-hint item.
pub fn InlayHintItem::new(
  hint : @language.InlayHint,
  anchor : InlayHintAnchor,
  provider : &@language.InlayHintsProvider,
) -> InlayHintItem {
  { hint, anchor, provider }
}

///|
/// Complete result of one range/provider request. Items are position-sorted;
/// `provider` is identity-deduplicated in provider-completion order.
pub struct InlayHintsFragments {
  items : Array[InlayHintItem]
  ranges : Array[@base_common.Range]
  provider : Array[&@language.InlayHintsProvider]
}

///|
/// Internal cancellation signal matching the pinned source's post-settlement
/// `CancellationError`. The public async request remains generally raising;
/// callers own the token and therefore already know why it was cancelled.
priv suberror InlayHintsRequestCancelled {
  InlayHintsRequestCancelled
}

///|
/// One fully captured provider/range request. No task indexes the live
/// registry or caller-owned ranges array after suspension.
priv struct InlayHintsProviderRequest {
  provider : &@language.InlayHintsProvider
  registration_active : Ref[Bool]
  provider_index : Int
  range : @base_common.OffsetRange
}

///|
/// A nonempty provider result retained in completion order. The registration
/// reference is checked again after every request settles so an early result
/// is still rejected if its registration is disposed while a sibling request
/// remains pending.
priv struct InlayHintsProviderData {
  hints : Array[@language.InlayHint]
  provider : &@language.InlayHintsProvider
  registration_active : Ref[Bool]
}

///|
/// Requests every captured provider/range pair. Matching active registrations
/// and input ranges are snapshotted before the first await;
/// tasks are constructed in the pinned reversed-registry order and every call
/// receives the exact caller-owned cancellation token. The default runner is
/// runtime-neutral and sequential; browser hosts may inject a concurrent
/// runner without coupling this package to their coroutine implementation.
pub async fn Languages::inlay_hints_for_ranges(
  self : Languages,
  model : @model.TextModel,
  ranges : Array[@base_common.Range],
  token : @language.CancellationToken,
  log_service : @log.LogService,
  run_tasks? : async (Array[async () -> Unit]) -> Unit = @base_common.run_async_tasks_sequentially,
) -> InlayHintsFragments {
  let captured_ranges = ranges.copy()
  let providers = self.inlay_hints_provider.snapshot_matching(model).rev()
  let requests : Array[InlayHintsProviderRequest] = []
  for captured in providers {
    for range in captured_ranges {
      requests.push({
        provider: captured.entry.provider,
        registration_active: captured.entry.active,
        provider_index: captured.provider_index,
        range: OffsetRange(
          model.get_offset_at(range.get_start_position()),
          model.get_offset_at(range.get_end_position()),
        ),
      })
    }
  }
  let data : Array[InlayHintsProviderData] = []
  let tasks : Array[async () -> Unit] = requests.map(request => {
    () => {
      let hints = request.provider.provide_inlay_hints(
        model,
        request.range,
        token,
      ) catch {
        _ => {
          if !token.is_cancellation_requested() {
            log_provider_failure(
              log_service,
              "language.inlayHints",
              model,
              request.provider_index,
            )
          }
          []
        }
      }
      if request.registration_active.val && hints.length() > 0 {
        data.push({
          hints,
          provider: request.provider,
          registration_active: request.registration_active,
        })
      }
    }
  })
  run_tasks(tasks)
  if token.is_cancellation_requested() || model.is_disposed() {
    raise InlayHintsRequestCancelled
  }
  let retained = data.filter(item => item.registration_active.val)
  InlayHintsFragments::from_provider_data(captured_ranges, retained, model)
}

///|
/// Converts completion-ordered provider data into sorted items and an
/// identity-deduplicated provider list. The sequence tiebreaker preserves the
/// pinned stable-sort behavior for hints at the same position.
fn InlayHintsFragments::from_provider_data(
  ranges : Array[@base_common.Range],
  data : Array[InlayHintsProviderData],
  model : @model.TextModel,
) -> InlayHintsFragments {
  let provider : Array[&@language.InlayHintsProvider] = []
  let indexed_items : Array[(Int, InlayHintItem)] = []
  let mut sequence = 0
  for result in data {
    let mut already_seen = false
    for retained_provider in provider {
      if physical_equal(retained_provider, result.provider) {
        already_seen = true
        break
      }
    }
    if !already_seen {
      provider.push(result.provider)
    }
    for hint in result.hints {
      let position = model.validate_position(hint.position)
      indexed_items.push(
        (
          sequence,
          InlayHintItem::new(
            hint,
            inlay_hint_anchor_at_position(model, position),
            result.provider,
          ),
        ),
      )
      sequence += 1
    }
  }
  indexed_items.sort_by((left, right) => {
    let (left_sequence, left_item) = left
    let (right_sequence, right_item) = right
    let position_order = @base_common.Position::compare(
      left_item.hint.position,
      right_item.hint.position,
    )
    if position_order != 0 {
      position_order
    } else {
      left_sequence - right_sequence
    }
  })
  let items = indexed_items.map(pair => {
    let (_, item) = pair
    item
  })
  { items, ranges, provider }
}

///|
/// Derives the source-shaped anchor for a validated hint position. A word
/// range wins without forcing tokenization; otherwise token bounds are read
/// and converted from zero-based offsets to one-based columns.
fn inlay_hint_anchor_at_position(
  model : @model.TextModel,
  position : @base_common.Position,
) -> InlayHintAnchor {
  let line = position.line_number
  match model.get_word_at_position(position) {
    Some(word) => {
      let word_range = @base_common.Range(
        line,
        word.start_column,
        line,
        word.end_column,
      )
      let word_start = word_range.get_start_position()
      if word_start.is_before(position) {
        InlayHintAnchor::new(
          @base_common.Range::from_positions(word_start, position),
          After,
        )
      } else {
        InlayHintAnchor::new(
          @base_common.Range::from_positions(
            position,
            word_range.get_end_position(),
          ),
          Before,
        )
      }
    }
    None => {
      let tokens = model.tokenization.get_line_tokens(line)
      let offset = position.column - 1
      let token_index = tokens.find_token_index_at_offset(offset)
      let (start, end) = adjusted_single_character_token_bounds(
        tokens, token_index, offset,
      )
      InlayHintAnchor::new(Range(line, start + 1, line, end + 1), Before)
    }
  }
}

///|
/// Preserves the pinned single-character leading/trailing adjustment exactly,
/// including the strict `index > 1` lower bound, the `else if` ordering, and
/// the `count - 1` upper bound.
fn adjusted_single_character_token_bounds(
  tokens : @tokens.LineTokens,
  token_index : Int,
  offset : Int,
) -> (Int, Int) {
  let mut start = tokens.get_start_offset(token_index)
  let mut end = tokens.get_end_offset(token_index)
  if end - start == 1 {
    if start == offset && token_index > 1 {
      start = tokens.get_start_offset(token_index - 1)
      end = tokens.get_end_offset(token_index - 1)
    } else if end == offset && token_index < tokens.get_count() - 1 {
      start = tokens.get_start_offset(token_index + 1)
      end = tokens.get_end_offset(token_index + 1)
    }
  }
  (start, end)
}
