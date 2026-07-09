///|
struct LanguageFeatureRegistry[T] {
  entries : Array[LanguageFeatureEntry[T]]
}

///|
priv struct LanguageFeatureEntry[T] {
  selector : @language.LanguageSelector
  provider : T
  active : Ref[Bool]
}

///|
fn[T] LanguageFeatureRegistry::new() -> LanguageFeatureRegistry[T] {
  { entries: [] }
}

///|
fn[T] LanguageFeatureRegistry::register(
  self : LanguageFeatureRegistry[T],
  selector : @language.LanguageSelector,
  provider : T,
) -> @base_common.Disposable {
  let active = Ref(true)
  let entry : LanguageFeatureEntry[T] = { selector, provider, active }
  self.entries.push(entry)
  @base_common.Disposable::from(() => {
    active.val = false
    let retained = self.entries.filter(item => item.active.val)
    self.entries.clear()
    self.entries.append(retained)
  })
}

///|
/// Public language registry for tokenization and semantic language providers.
/// Hosts normally use the process-wide `@languages.languages` value; tests and
/// embedded viewers that need isolation can create a fresh registry and pass it
/// through `ViewerServices::new(languages~)`.
pub struct Languages {
  priv hover_provider : LanguageFeatureRegistry[&@language.HoverProvider]
  priv document_symbol_provider : LanguageFeatureRegistry[
    &@language.DocumentSymbolProvider,
  ]
  priv inlay_hints_provider : LanguageFeatureRegistry[
    &@language.InlayHintsProvider,
  ]
  /// Per-language configuration (folding rules) — the viewer's stand-in for
  /// Monaco's `ILanguageConfigurationService` registrations.
  priv language_configurations : Map[String, LanguageConfiguration]
}

///|
/// Creates an isolated language registry.
pub fn Languages::new() -> Languages {
  {
    hover_provider: LanguageFeatureRegistry::new(),
    document_symbol_provider: LanguageFeatureRegistry::new(),
    inlay_hints_provider: LanguageFeatureRegistry::new(),
    language_configurations: {},
  }
}

///|
/// Default process-wide language registry used by `ViewerServices::new()`.
pub let languages : Languages = Languages::new()

///|
pub fn default_languages() -> Languages {
  languages
}

///|
/// Registers or replaces the tokenizer for `language_id` in the process-wide
/// `@syntax.tokenization_registry`, exactly monaco-editor's standalone
/// `monaco.languages.setTokensProvider` forwarding into
/// `TokenizationRegistry.register`. Tokenizers are global even for isolated
/// `Languages` instances, as in Monaco; disposing the returned handle clears
/// the provider only if it is still the active registration.
pub fn Languages::set_tokens_provider(
  _self : Languages,
  language_id : String,
  tokenizer : &@syntax.LineTokenizer,
) -> @base_common.Disposable {
  @syntax.tokenization_registry.register(language_id, tokenizer)
}

///|
/// Registers an ordered hover provider.
pub fn Languages::register_hover_provider(
  self : Languages,
  selector : @language.LanguageSelector,
  provider : &@language.HoverProvider,
) -> @base_common.Disposable {
  self.hover_provider.register(selector, provider)
}

///|
/// Registers an ordered document-symbol provider.
pub fn Languages::register_document_symbol_provider(
  self : Languages,
  selector : @language.LanguageSelector,
  provider : &@language.DocumentSymbolProvider,
) -> @base_common.Disposable {
  self.document_symbol_provider.register(selector, provider)
}

///|
/// Registers an ordered inlay-hints provider.
pub fn Languages::register_inlay_hints_provider(
  self : Languages,
  selector : @language.LanguageSelector,
  provider : &@language.InlayHintsProvider,
) -> @base_common.Disposable {
  self.inlay_hints_provider.register(selector, provider)
}

///|
/// Returns the first non-empty hover answer in provider order.
pub async fn Languages::hover_at(
  self : Languages,
  model : @model.TextModel,
  offset : Int,
  log_service : @log.LogService,
) -> @language.Hover? noraise {
  let position = model.get_position_at(offset)
  let token = @language.CancellationToken::none()
  for index in 0..<self.hover_provider.entries.length() {
    let entry = self.hover_provider.entries[index]
    if !entry.active.val || !entry.selector.matches(model) {
      continue
    }
    match
      (entry.provider.provide_hover(model, position, token) catch {
        _ => {
          log_provider_failure(log_service, "language.hover", model, index)
          None
        }
      }) {
      Some(hover) => return Some(hover)
      None => ()
    }
  }
  None
}

///|
/// Concatenates document-symbol results from every provider.
pub async fn Languages::document_symbols(
  self : Languages,
  model : @model.TextModel,
  log_service : @log.LogService,
) -> Array[@language.DocumentSymbol] noraise {
  let symbols : Array[@language.DocumentSymbol] = []
  let token = @language.CancellationToken::none()
  for index in 0..<self.document_symbol_provider.entries.length() {
    let entry = self.document_symbol_provider.entries[index]
    if !entry.active.val || !entry.selector.matches(model) {
      continue
    }
    let result = entry.provider.provide_document_symbols(model, token) catch {
      _ => {
        log_provider_failure(
          log_service, "language.documentSymbols", model, index,
        )
        []
      }
    }
    symbols.append(result)
  }
  symbols
}

///|
/// Concatenates inlay-hint results from every provider.
pub async fn Languages::inlay_hints_for_model(
  self : Languages,
  model : @model.TextModel,
  log_service : @log.LogService,
) -> Array[@language.InlayHint] noraise {
  let hints : Array[@language.InlayHint] = []
  let token = @language.CancellationToken::none()
  let full_range = @base_common.OffsetRange(0, model.get_value_length())
  for index in 0..<self.inlay_hints_provider.entries.length() {
    let entry = self.inlay_hints_provider.entries[index]
    if !entry.active.val || !entry.selector.matches(model) {
      continue
    }
    let result = entry.provider.provide_inlay_hints(model, full_range, token) catch {
      _ => {
        log_provider_failure(log_service, "language.inlayHints", model, index)
        []
      }
    }
    hints.append(result)
  }
  hints
}

///|
fn log_provider_failure(
  log_service : @log.LogService,
  category : String,
  model : @model.TextModel,
  index : Int,
) -> Unit {
  log_service.warn(category, "provider failed", details=[
    ("model", model.uri.to_string()),
    ("revision", model.revision),
    ("providerIndex", index.to_string()),
  ])
}
