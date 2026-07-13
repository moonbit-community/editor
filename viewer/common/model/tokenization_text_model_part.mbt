///| Readonly-applicable `TokenizationTextModelPart` over a live stateful backend.
///
/// Source: `vscode/src/vs/editor/common/model/tokens/tokenizationTextModelPart.ts`
/// and `vscode/src/vs/editor/common/tokenizationTextModelPart.ts` at
/// `b18492a288de038fbc7643aae6de8247029d11bd`. Semantic, dynamic-language,
/// embedded-language, bracket, and editable prediction arms remain the
/// explicitly deferred/N-A ledger rows; the syntactic lifecycle below keeps
/// source event order and per-line validation/demand.

///|
/// Exact syntactic/semantic token-change event payload.
pub(all) struct ModelTokensChangedEvent {
  semantic_tokens_applied : Bool
  ranges : Array[ModelTokensChangedRange]
}

///|
/// One inclusive changed line range.
pub(all) struct ModelTokensChangedRange {
  from_line_number : Int
  to_line_number : Int
}

///|
/// Public model tokenization part. Reads are passive; explicit/visible/background demand drives lexing.
pub struct TokenizationTextModelPart {
  priv model_state : TokenizationModelState
  priv backend : TokenizerSyntaxTokenBackend
  priv did_change_tokens : @base_common.Emitter[ModelTokensChangedEvent]
  priv first_font_emitter : @base_common.Emitter[ModelFontTokensChangedEvent]
  priv public_font_emitter : @base_common.Emitter[ModelFontTokensChangedEvent]
  priv mut backend_token_subscription : @base_common.Disposable?
  priv mut backend_font_subscription : @base_common.Disposable?
  priv mut disposed : Bool
}

///|
/// Constructs the registry-backed live backend and event forwarding in source order.
fn TokenizationTextModelPart::TokenizationTextModelPart(
  model_state : TokenizationModelState,
  attached_views : AttachedViews,
) -> TokenizationTextModelPart {
  TokenizationTextModelPart::new_with_support_resolver(
    model_state,
    attached_views,
    language_id => {
      match @syntax.tokenization_registry.get(language_id) {
        Some(tokenizer) =>
          Some(
            public_tokenizer_adapter(
              tokenizer, @services.language_id_codec, language_id,
            ),
          )
        None => None
      }
    },
    subscribe_registry=true,
  )
}

///|
/// Internal-support test seam preserving failing and `has_eol`-aware adapters.
fn TokenizationTextModelPart::new_with_support_resolver(
  model_state : TokenizationModelState,
  attached_views : AttachedViews,
  resolve_support : (String) -> InternalTokenizationSupportAdapter?,
  subscribe_registry? : Bool = false,
) -> TokenizationTextModelPart {
  let backend = TokenizerSyntaxTokenBackend::new_with_support_resolver(
    model_state,
    attached_views,
    resolve_support,
    subscribe_registry~,
  )
  let part : TokenizationTextModelPart = {
    model_state,
    backend,
    did_change_tokens: @base_common.Emitter::new(),
    first_font_emitter: @base_common.Emitter::new(),
    public_font_emitter: @base_common.Emitter::new(),
    backend_token_subscription: None,
    backend_font_subscription: None,
    disposed: false,
  }
  part.backend_token_subscription = Some(
    backend.on_did_change_tokens(event => {
      if !part.model_state.disposing.val {
        part.did_change_tokens.fire(event)
      }
    }),
  )
  part.backend_font_subscription = Some(
    backend.on_did_change_font_tokens(event => {
      if !part.model_state.disposing.val {
        part.public_font_emitter.fire(event)
      }
    }),
  )
  part
}

///|
/// Subscribes to exact changed token ranges.
fn TokenizationTextModelPart::on_did_change_tokens(
  self : TokenizationTextModelPart,
  listener : (ModelTokensChangedEvent) -> Unit,
) -> @base_common.Disposable {
  self.did_change_tokens.event(listener)
}

///|
/// Subscribes to exact child-owned font payloads. The source allocates two
/// registered emitters and exposes the second; both are disposed below.
#warnings("-unused_value")
fn TokenizationTextModelPart::on_did_change_font_tokens(
  self : TokenizationTextModelPart,
  listener : (ModelFontTokensChangedEvent) -> Unit,
) -> @base_common.Disposable {
  self.public_font_emitter.event(listener)
}

///|
/// Internal completion-state event, deliberately not forwarded by `TextModel`.
#warnings("-unused_value")
fn TokenizationTextModelPart::on_did_change_background_tokenization_state(
  self : TokenizationTextModelPart,
  listener : (Unit) -> Unit,
) -> @base_common.Disposable {
  self.backend.on_did_change_background_tokenization_state(listener)
}

///|
/// Construction-fixed language id read from the shared model state.
fn TokenizationTextModelPart::get_language_id(
  self : TokenizationTextModelPart,
) -> String {
  self.model_state.language_id
}

///|
/// Inherited `TextModelPart` liveness guard. Guarded work continues while live
/// and enters the exact failure arm after terminal disposal.
fn TokenizationTextModelPart::assert_not_disposed(
  self : TokenizationTextModelPart,
) -> Unit {
  if self.disposed {
    abort("TextModelPart is disposed!")
  }
}

///|
/// Validates the inclusive one-based model-line domain.
fn TokenizationTextModelPart::validate_line_number(
  self : TokenizationTextModelPart,
  line_number : Int,
) -> Unit {
  if line_number < 1 || line_number > self.model_state.snapshot.val.line_count() {
    abort("Illegal value for lineNumber")
  }
}

///|
/// Passive stored/default syntactic tokens; never invokes the lexer.
pub fn TokenizationTextModelPart::get_line_tokens(
  self : TokenizationTextModelPart,
  line_number : Int,
) -> @common_tokens.LineTokens {
  self.validate_line_number(line_number)
  self.backend.get_line_tokens(line_number)
}

///|
/// Makes state accurate through one validated line.
#warnings("-unused_value")
fn TokenizationTextModelPart::force_tokenization(
  self : TokenizationTextModelPart,
  line_number : Int,
) -> Unit {
  self.validate_line_number(line_number)
  self.backend.force_tokenization(line_number)
}

///|
/// Forces only when the exact cheapness predicate succeeds.
#warnings("-unused_value")
fn TokenizationTextModelPart::tokenize_if_cheap(
  self : TokenizationTextModelPart,
  line_number : Int,
) -> Unit {
  self.validate_line_number(line_number)
  self.backend.tokenize_if_cheap(line_number)
}

///|
/// Whether the line's carried state is accurate.
#warnings("-unused_value")
fn TokenizationTextModelPart::has_accurate_tokens_for_line(
  self : TokenizationTextModelPart,
  line_number : Int,
) -> Bool {
  self.validate_line_number(line_number)
  self.backend.has_accurate_tokens_for_line(line_number)
}

///|
/// Whether explicit demand for the line is cheap.
#warnings("-unused_value")
fn TokenizationTextModelPart::is_cheap_to_tokenize(
  self : TokenizationTextModelPart,
  line_number : Int,
) -> Bool {
  self.validate_line_number(line_number)
  self.backend.is_cheap_to_tokenize(line_number)
}

///|
/// Whether the contiguous syntactic store contains any explicit tokens.
#warnings("-unused_value")
fn TokenizationTextModelPart::has_tokens(
  self : TokenizationTextModelPart,
) -> Bool {
  self.backend.has_tokens()
}

///|
/// Current background lifecycle state.
#warnings("-unused_value")
fn TokenizationTextModelPart::background_tokenization_state(
  self : TokenizationTextModelPart,
) -> BackgroundTokenizationState {
  self.backend.background_tokenization_state()
}

///|
/// Public reset announces one full range by default.
#warnings("-unused_value")
fn TokenizationTextModelPart::reset_tokenization(
  self : TokenizationTextModelPart,
  fire_token_change_event? : Bool = true,
) -> Unit {
  self.backend.reset_tokenization(fire_token_change_event~)
}

///|
/// Flush content handling; live lines were replaced before this call.
fn TokenizationTextModelPart::handle_did_change_content(
  self : TokenizationTextModelPart,
  is_flush~ : Bool,
) -> Unit {
  self.backend.handle_did_change_content(is_flush~)
}

///|
/// Re-evaluates scheduling after aggregate attach/scheduler transitions.
fn TokenizationTextModelPart::handle_did_change_attached(
  self : TokenizationTextModelPart,
) -> Unit {
  self.backend.handle_did_change_attached()
}

///|
/// Refreshes all currently requested attached-view ranges synchronously.
#warnings("-unused_value")
fn TokenizationTextModelPart::refresh_all_visible_line_tokens(
  self : TokenizationTextModelPart,
) -> Unit {
  self.backend.refresh_all_visible_line_tokens()
}

///|
/// Passive telemetry count. One stored/default read per model line and zero
/// lexer calls, including initial attach and token-change notification paths.
pub fn TokenizationTextModelPart::token_count(
  self : TokenizationTextModelPart,
) -> Int {
  self.assert_not_disposed()
  let mut count = 0
  for line_number in 1..<=self.model_state.snapshot.val.line_count() {
    count += self.backend.get_line_tokens(line_number).get_count()
  }
  count
}

///|
/// Token listeners participate in model listener ownership; font is intentionally excluded.
fn TokenizationTextModelPart::has_listeners(
  self : TokenizationTextModelPart,
) -> Bool {
  self.did_change_tokens.has_listeners()
}

///|
/// Releases every registered resource while the inherited disposed flag is
/// still false: forwarding subscriptions, registered emitters, then backend.
fn TokenizationTextModelPart::dispose_owned_resources(
  self : TokenizationTextModelPart,
) -> Unit {
  match self.backend_token_subscription {
    Some(subscription) => subscription.dispose()
    None => ()
  }
  match self.backend_font_subscription {
    Some(subscription) => subscription.dispose()
    None => ()
  }
  self.backend_token_subscription = None
  self.backend_font_subscription = None
  self.did_change_tokens.dispose()
  self.first_font_emitter.dispose()
  self.public_font_emitter.dispose()
  self.backend.dispose()
}

///|
/// Source-order teardown: registered resources first, terminal flag second.
fn TokenizationTextModelPart::dispose(self : TokenizationTextModelPart) -> Unit {
  if self.disposed {
    return
  }
  self.dispose_owned_resources()
  self.disposed = true
}
