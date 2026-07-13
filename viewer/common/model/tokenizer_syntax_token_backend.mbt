///| Concrete stateful grammar backend over shared live model state.
///
/// Source: `vscode/src/vs/editor/common/model/tokens/tokenizerSyntaxTokenBackend.ts`
/// at `b18492a288de038fbc7643aae6de8247029d11bd`, lines 26-322. The live
/// `TokenizationModelState`, absent custom/verifier worker arms, and optional
/// epoch scheduler are the reviewed deviations; reset/event/store/refresh
/// ordering and branch constants follow the source.

///|
/// Store delta returned by a syntactic batch write.
pub(all) struct TokenStoreChange {
  changes : Array[ModelTokensChangedRange]
}

///|
/// Per-view handler ownership entry.
priv struct AttachedViewHandlerEntry {
  view : AttachedViewImpl
  handler : AttachedViewHandler
}

///|
/// Concrete TextMate-style syntactic backend.
pub struct TokenizerSyntaxTokenBackend {
  priv shared : AbstractSyntaxTokenBackend
  priv model_state : TokenizationModelState
  priv resolve_support : (String) -> InternalTokenizationSupportAdapter?
  priv mut tokenizer : TokenizerWithStateStoreAndTextModel?
  priv mut background_tokenization_state_value : BackgroundTokenizationState
  priv mut default_background_tokenizer : DefaultBackgroundTokenizer?
  priv tokens : @common_tokens.ContiguousTokensStore
  priv attached_view_states : Array[AttachedViewHandlerEntry]
  priv mut registry_subscription : @base_common.Disposable?
  priv mut attached_subscription : @base_common.Disposable?
  priv mut disposed : Bool
}

///|
/// Constructs the backend from the registry-backed production resolver or a
/// failing/`has_eol`-aware white-box resolver.
fn TokenizerSyntaxTokenBackend::new_with_support_resolver(
  model_state : TokenizationModelState,
  attached_views : AttachedViews,
  resolve_support : (String) -> InternalTokenizationSupportAdapter?,
  subscribe_registry? : Bool = false,
) -> TokenizerSyntaxTokenBackend {
  let backend : TokenizerSyntaxTokenBackend = {
    shared: AbstractSyntaxTokenBackend::new(),
    model_state,
    resolve_support,
    tokenizer: None,
    background_tokenization_state_value: InProgress,
    default_background_tokenizer: None,
    tokens: @common_tokens.ContiguousTokensStore::new(
      @services.language_id_codec,
    ),
    attached_view_states: [],
    registry_subscription: None,
    attached_subscription: None,
    disposed: false,
  }
  if subscribe_registry {
    backend.registry_subscription = Some(
      @syntax.tokenization_registry.on_did_change(event => {
        let language_id = backend.model_state.language_id
        if event.changed_languages.contains(language_id) {
          backend.reset_tokenization()
        }
      }),
    )
  }
  backend.reset_tokenization()
  backend.attached_subscription = Some(
    attached_views.on_did_change_visible_ranges(change => {
      backend.handle_attached_view_state_change(change)
    }),
  )
  backend
}

///|
/// Handles create/reuse/update and explicit detach disposal in source order.
fn TokenizerSyntaxTokenBackend::handle_attached_view_state_change(
  self : TokenizerSyntaxTokenBackend,
  change : AttachedViewStateChange,
) -> Unit {
  match change.state {
    Some(state) => {
      let mut index = -1
      for i, entry in self.attached_view_states {
        if entry.view.same(change.view) {
          index = i
          break
        }
      }
      let handler = if index >= 0 {
        self.attached_view_states[index].handler
      } else {
        let holder : Ref[AttachedViewHandler?] = Ref(None)
        let handler = AttachedViewHandler::new(
          () => {
            match holder.val {
              Some(current) => self.refresh_ranges(current.line_ranges())
              None => ()
            }
          },
          () => self.model_state.scheduler.val,
        )
        holder.val = Some(handler)
        self.attached_view_states.push({ view: change.view, handler })
        handler
      }
      handler.handle_state_change(state)
    }
    None => {
      let mut index = -1
      for i, entry in self.attached_view_states {
        if entry.view.same(change.view) {
          index = i
          break
        }
      }
      if index >= 0 {
        self.attached_view_states[index].handler.dispose()
        self.attached_view_states.remove(index) |> ignore
      }
    }
  }
}

///|
/// Resets stores/support/workers and refreshes current visible ranges.
pub fn TokenizerSyntaxTokenBackend::reset_tokenization(
  self : TokenizerSyntaxTokenBackend,
  fire_token_change_event? : Bool = true,
) -> Unit {
  self.tokens.flush()
  if fire_token_change_event && !self.model_state.disposing.val {
    self.shared.did_change_tokens.fire({
      semantic_tokens_applied: false,
      ranges: [
        {
          from_line_number: 1,
          to_line_number: self.model_state.snapshot.val.line_count(),
        },
      ],
    })
  }
  let mut support : InternalTokenizationSupportAdapter? = None
  if !self.model_state.too_large {
    match (self.resolve_support)(self.model_state.language_id) {
      Some(candidate) =>
        try candidate.initial_state() catch {
          error =>
            (self.model_state.report_unexpected_error)("\{to_repr(error)}")
        } noraise {
          _ => support = Some(candidate)
        }
      None => ()
    }
  }
  self.tokenizer = match support {
    Some(candidate) =>
      try
        TokenizerWithStateStoreAndTextModel::new(
          self.model_state.snapshot.val.line_count(),
          candidate,
          self.model_state,
          @services.language_id_codec,
        )
      catch {
        error => {
          (self.model_state.report_unexpected_error)("\{to_repr(error)}")
          None
        }
      } noraise {
        tokenizer => Some(tokenizer)
      }
    None => None
  }
  match self.default_background_tokenizer {
    Some(worker) => worker.dispose()
    None => ()
  }
  self.default_background_tokenizer = None
  match self.tokenizer {
    Some(tokenizer) => {
      let output = BackgroundTokenizationStore::new(
        set_tokens=batches => self.set_tokens(batches) |> ignore,
        set_font_info=changes => self.set_font_info(changes),
        background_tokenization_finished=() => {
          if self.background_tokenization_state_value == Completed {
            return
          }
          self.background_tokenization_state_value = Completed
          self.shared.did_change_background_state.fire(())
        },
        set_end_state=(line_number, state) => {
          match self.tokenizer {
            Some(current) =>
              match
                current.state_store().get_first_invalid_end_state_line_number() {
                Some(first_invalid) =>
                  if line_number >= first_invalid {
                    current.state_store().set_end_state(line_number, state)
                    |> ignore
                  }
                None => ()
              }
            None => ()
          }
        },
      )
      let worker = DefaultBackgroundTokenizer::new(tokenizer, output)
      self.default_background_tokenizer = Some(worker)
      worker.handle_changes()
    }
    None => ()
  }
  self.refresh_all_visible_line_tokens()
}

///|
/// Re-evaluates default work after an attached-count or scheduler transition.
pub fn TokenizerSyntaxTokenBackend::handle_did_change_attached(
  self : TokenizerSyntaxTokenBackend,
) -> Unit {
  match self.default_background_tokenizer {
    Some(worker) => worker.handle_changes()
    None => ()
  }
}

///|
/// Flush-only readonly content invalidation.
pub fn TokenizerSyntaxTokenBackend::handle_did_change_content(
  self : TokenizerSyntaxTokenBackend,
  is_flush~ : Bool,
) -> Unit {
  if is_flush {
    self.reset_tokenization(fire_token_change_event=false)
  }
}

///|
/// Writes batches, emits only nonempty exact changes, and returns the same set.
pub fn TokenizerSyntaxTokenBackend::set_tokens(
  self : TokenizerSyntaxTokenBackend,
  batches : Array[@common_tokens.ContiguousMultilineTokens],
) -> TokenStoreChange {
  let update = self.tokens.set_multiline_tokens(
    batches,
    self.model_state.language_id,
    line_number => self.model_state.snapshot.val.get_line_length(line_number),
  )
  let changes = update.changes.map(change => ModelTokensChangedRange::{
    from_line_number: change.from_line_number,
    to_line_number: change.to_line_number,
  })
  if !changes.is_empty() && !self.model_state.disposing.val {
    self.shared.did_change_tokens.fire({
      semantic_tokens_applied: false,
      ranges: changes,
    })
  }
  { changes, }
}

///|
/// Fires exact syntactic font changes while live.
pub fn TokenizerSyntaxTokenBackend::set_font_info(
  self : TokenizerSyntaxTokenBackend,
  changes : FontTokensUpdate,
) -> Unit {
  if !self.model_state.disposing.val {
    self.shared.did_change_font_tokens.fire({ changes, })
  }
}

///|
/// Joins every per-view latest range and refreshes it.
pub fn TokenizerSyntaxTokenBackend::refresh_all_visible_line_tokens(
  self : TokenizerSyntaxTokenBackend,
) -> Unit {
  let ranges : Array[@base_common.LineRange] = []
  for entry in self.attached_view_states {
    ranges.append(entry.handler.line_ranges())
  }
  self.refresh_ranges(join_line_ranges(ranges))
}

///|
/// Refreshes normalized ranges in order, converting exclusive end to inclusive.
pub fn TokenizerSyntaxTokenBackend::refresh_ranges(
  self : TokenizerSyntaxTokenBackend,
  ranges : Array[@base_common.LineRange],
) -> Unit {
  for range in ranges {
    self.refresh_range(
      range.start_line_number,
      range.end_line_number_exclusive - 1,
    )
  }
}

///|
/// Clamps source-asymmetrically, stores heuristic tokens, and requests accuracy.
pub fn TokenizerSyntaxTokenBackend::refresh_range(
  self : TokenizerSyntaxTokenBackend,
  start_line_number : Int,
  end_line_number : Int,
) -> Unit {
  guard self.tokenizer is Some(tokenizer) else { return }
  let line_count = self.model_state.snapshot.val.line_count()
  let clamped_start = start_line_number.max(1).min(line_count)
  let clamped_end = end_line_number.min(line_count)
  let builder = @common_tokens.ContiguousMultilineTokensBuilder::new()
  let result = tokenizer.tokenize_heuristically(
    builder, clamped_start, clamped_end,
  )
  let changed = self.set_tokens(builder.finalize())
  if result.heuristic_tokens {
    match self.default_background_tokenizer {
      Some(worker) =>
        for change in changed.changes {
          worker.request_tokens(
            change.from_line_number,
            change.to_line_number + 1,
          )
        }
      None => ()
    }
  }
  match self.default_background_tokenizer {
    Some(worker) => worker.check_finished()
    None => ()
  }
}

///|
/// Builds accurate state through the requested line and stores the batch.
pub fn TokenizerSyntaxTokenBackend::force_tokenization(
  self : TokenizerSyntaxTokenBackend,
  line_number : Int,
) -> Unit {
  let builder = @common_tokens.ContiguousMultilineTokensBuilder::new()
  match self.tokenizer {
    Some(tokenizer) => tokenizer.update_tokens_until_line(builder, line_number)
    None => ()
  }
  self.set_tokens(builder.finalize()) |> ignore
  match self.default_background_tokenizer {
    Some(worker) => worker.check_finished()
    None => ()
  }
}

///|
/// Missing support is accurate; live support delegates the invalid frontier.
pub fn TokenizerSyntaxTokenBackend::has_accurate_tokens_for_line(
  self : TokenizerSyntaxTokenBackend,
  line_number : Int,
) -> Bool {
  match self.tokenizer {
    Some(tokenizer) => tokenizer.has_accurate_tokens_for_line(line_number)
    None => true
  }
}

///|
/// Missing support is cheap; live support applies the 2048-unit rule.
pub fn TokenizerSyntaxTokenBackend::is_cheap_to_tokenize(
  self : TokenizerSyntaxTokenBackend,
  line_number : Int,
) -> Bool {
  match self.tokenizer {
    Some(tokenizer) => tokenizer.is_cheap_to_tokenize(line_number)
    None => true
  }
}

///|
/// Conditionally forces one line only when cheap.
pub fn TokenizerSyntaxTokenBackend::tokenize_if_cheap(
  self : TokenizerSyntaxTokenBackend,
  line_number : Int,
) -> Unit {
  if self.is_cheap_to_tokenize(line_number) {
    self.force_tokenization(line_number)
  }
}

///|
/// Passive stored/default token read; never invokes the lexer.
pub fn TokenizerSyntaxTokenBackend::get_line_tokens(
  self : TokenizerSyntaxTokenBackend,
  line_number : Int,
) -> @common_tokens.LineTokens {
  self.tokens.get_tokens(
    self.model_state.language_id,
    line_number - 1,
    self.model_state.snapshot.val.line_text(line_number - 1),
  )
}

///|
/// Whether any contiguous syntactic token state is stored.
pub fn TokenizerSyntaxTokenBackend::has_tokens(
  self : TokenizerSyntaxTokenBackend,
) -> Bool {
  self.tokens.has_tokens()
}

///|
/// Current background lifecycle state.
pub fn TokenizerSyntaxTokenBackend::background_tokenization_state(
  self : TokenizerSyntaxTokenBackend,
) -> BackgroundTokenizationState {
  self.background_tokenization_state_value
}

///|
/// Event subscriptions forwarded by the model part.
pub fn TokenizerSyntaxTokenBackend::on_did_change_tokens(
  self : TokenizerSyntaxTokenBackend,
  listener : (ModelTokensChangedEvent) -> Unit,
) -> @base_common.Disposable {
  self.shared.on_did_change_tokens(listener)
}

///|
/// Subscribes to exact child-owned syntactic font payloads.
pub fn TokenizerSyntaxTokenBackend::on_did_change_font_tokens(
  self : TokenizerSyntaxTokenBackend,
  listener : (ModelFontTokensChangedEvent) -> Unit,
) -> @base_common.Disposable {
  self.shared.on_did_change_font_tokens(listener)
}

///|
/// Subscribes to background completion transitions.
pub fn TokenizerSyntaxTokenBackend::on_did_change_background_tokenization_state(
  self : TokenizerSyntaxTokenBackend,
  listener : (Unit) -> Unit,
) -> @base_common.Disposable {
  self.shared.on_did_change_background_tokenization_state(listener)
}

///|
/// Releases registry/view subscriptions, handlers, worker, and shared emitters.
pub fn TokenizerSyntaxTokenBackend::dispose(
  self : TokenizerSyntaxTokenBackend,
) -> Unit {
  if self.disposed {
    return
  }
  self.disposed = true
  match self.registry_subscription {
    Some(subscription) => subscription.dispose()
    None => ()
  }
  match self.attached_subscription {
    Some(subscription) => subscription.dispose()
    None => ()
  }
  self.registry_subscription = None
  self.attached_subscription = None
  for entry in self.attached_view_states {
    entry.handler.dispose()
  }
  self.attached_view_states.clear()
  match self.default_background_tokenizer {
    Some(worker) => worker.dispose()
    None => ()
  }
  self.default_background_tokenizer = None
  self.tokenizer = None
  self.shared.dispose()
}
