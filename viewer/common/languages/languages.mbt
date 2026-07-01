///|
struct TokenProviderEntry {
  id : Int
  tokenizer : &@syntax.LineTokenizer
}

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
  priv tokenizers : Map[String, TokenProviderEntry]
  priv token_provider_generation : Ref[Int]
  priv hover_provider : LanguageFeatureRegistry[&@language.HoverProvider]
  priv diagnostics_provider : LanguageFeatureRegistry[
    &@language.DiagnosticsProvider,
  ]
  priv document_symbol_provider : LanguageFeatureRegistry[
    &@language.DocumentSymbolProvider,
  ]
  priv folding_range_provider : LanguageFeatureRegistry[
    &@language.FoldingRangeProvider,
  ]
  priv inlay_hints_provider : LanguageFeatureRegistry[
    &@language.InlayHintsProvider,
  ]
}

///|
/// Creates an isolated language registry.
pub fn Languages::new() -> Languages {
  {
    tokenizers: {},
    token_provider_generation: Ref(0),
    hover_provider: LanguageFeatureRegistry::new(),
    diagnostics_provider: LanguageFeatureRegistry::new(),
    document_symbol_provider: LanguageFeatureRegistry::new(),
    folding_range_provider: LanguageFeatureRegistry::new(),
    inlay_hints_provider: LanguageFeatureRegistry::new(),
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
/// Registers or replaces the tokenizer for `language_id`.
///
/// Disposing the returned handle clears the provider only if it is still the
/// active registration for that language, so disposing an older registration
/// cannot remove a newer replacement.
pub fn Languages::set_tokens_provider(
  self : Languages,
  language_id : String,
  tokenizer : &@syntax.LineTokenizer,
) -> @base_common.Disposable {
  let id = self.token_provider_generation.val
  self.token_provider_generation.val = id + 1
  self.tokenizers[language_id] = { id, tokenizer }
  @base_common.Disposable::from(() => {
    match self.tokenizers.get(language_id) {
      Some(entry) => if entry.id == id { self.tokenizers.remove(language_id) }
      None => ()
    }
  })
}

///|
pub fn Languages::lookup_tokens_provider(
  self : Languages,
  language_id : String,
) -> &@syntax.LineTokenizer? {
  match self.tokenizers.get(language_id) {
    Some(entry) => Some(entry.tokenizer)
    None => None
  }
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
/// Registers an ordered diagnostics provider.
pub fn Languages::register_diagnostics_provider(
  self : Languages,
  selector : @language.LanguageSelector,
  provider : &@language.DiagnosticsProvider,
) -> @base_common.Disposable {
  self.diagnostics_provider.register(selector, provider)
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
/// Registers an ordered folding-range provider.
pub fn Languages::register_folding_range_provider(
  self : Languages,
  selector : @language.LanguageSelector,
  provider : &@language.FoldingRangeProvider,
) -> @base_common.Disposable {
  self.folding_range_provider.register(selector, provider)
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
  let position = model.snapshot.position_at_offset(offset)
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
/// Refreshes diagnostics from every provider, passing each provider's owner id
/// to the caller so marker ownership can be replaced independently.
pub async fn Languages::diagnostics_for_model(
  self : Languages,
  model : @model.TextModel,
  apply : (String, Array[@language.Diagnostic]) -> Unit,
  log_service : @log.LogService,
) -> Unit noraise {
  let token = @language.CancellationToken::none()
  for index in 0..<self.diagnostics_provider.entries.length() {
    let entry = self.diagnostics_provider.entries[index]
    if !entry.active.val || !entry.selector.matches(model) {
      continue
    }
    let owner = "diagnostics:" + index.to_string()
    let diagnostics = entry.provider.provide_diagnostics(model, token) catch {
      _ => {
        log_provider_failure(log_service, "language.diagnostics", model, index)
        []
      }
    }
    apply(owner, diagnostics)
  }
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
/// Concatenates folding-range results, falling back to MoonBit indentation
/// ranges when no provider answers.
pub async fn Languages::folding_ranges_for_model(
  self : Languages,
  model : @model.TextModel,
  log_service : @log.LogService,
) -> Array[@language.FoldingRange] noraise {
  let ranges : Array[@language.FoldingRange] = []
  let token = @language.CancellationToken::none()
  for index in 0..<self.folding_range_provider.entries.length() {
    let entry = self.folding_range_provider.entries[index]
    if !entry.active.val || !entry.selector.matches(model) {
      continue
    }
    let result = entry.provider.provide_folding_ranges(model, token) catch {
      _ => {
        log_provider_failure(
          log_service, "language.foldingRanges", model, index,
        )
        []
      }
    }
    ranges.append(result)
  }
  // Provider results only. The indent-based fallback (Monaco's
  // `indentRangeProvider`) is applied by the folding controller (the caller),
  // not the provider registry, so this common-tier package does not depend on
  // the `contrib/folding` tier.
  ranges
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
  let full_range = @base_common.OffsetRange(0, model.snapshot.length())
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
