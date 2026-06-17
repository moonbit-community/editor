///|
/// Ordered registry for one family of language providers.
pub(all) struct LanguageFeatureRegistry[T] {
  entries : Array[T]
}

///|
/// Creates an empty provider registry.
pub fn[T] LanguageFeatureRegistry::new() -> LanguageFeatureRegistry[T] {
  { entries: [] }
}

///|
/// Adds a provider to the end of the registry.
pub fn[T] LanguageFeatureRegistry::register(
  self : LanguageFeatureRegistry[T],
  entry : T,
) -> Unit {
  self.entries.push(entry)
}

///|
/// Viewer-owned language feature broker. Provider failures are logged and
/// degraded to empty results so one provider cannot break rendering.
pub(all) struct LanguageFeaturesService {
  hover_provider : LanguageFeatureRegistry[&@language.HoverProvider]
  diagnostics_provider : LanguageFeatureRegistry[&@language.DiagnosticsProvider]
  document_symbol_provider : LanguageFeatureRegistry[
    &@language.DocumentSymbolProvider,
  ]
  semantic_tokens_provider : LanguageFeatureRegistry[
    &@language.SemanticTokensProvider,
  ]
  folding_range_provider : LanguageFeatureRegistry[
    &@language.FoldingRangeProvider,
  ]
  inlay_hints_provider : LanguageFeatureRegistry[&@language.InlayHintsProvider]
  log_service : @log.LogService
}

///|
/// Creates a language feature broker with empty registries.
pub fn LanguageFeaturesService::new(
  log_service? : @log.LogService = @log.LogService::new(),
) -> LanguageFeaturesService {
  {
    hover_provider: LanguageFeatureRegistry::new(),
    diagnostics_provider: LanguageFeatureRegistry::new(),
    document_symbol_provider: LanguageFeatureRegistry::new(),
    semantic_tokens_provider: LanguageFeatureRegistry::new(),
    folding_range_provider: LanguageFeatureRegistry::new(),
    inlay_hints_provider: LanguageFeatureRegistry::new(),
    log_service,
  }
}

///|
/// Registers an ordered hover provider.
pub fn LanguageFeaturesService::register_hover_provider(
  self : LanguageFeaturesService,
  provider : &@language.HoverProvider,
) -> Unit {
  self.hover_provider.register(provider)
}

///|
/// Registers an ordered diagnostics provider.
pub fn LanguageFeaturesService::register_diagnostics_provider(
  self : LanguageFeaturesService,
  provider : &@language.DiagnosticsProvider,
) -> Unit {
  self.diagnostics_provider.register(provider)
}

///|
/// Registers an ordered document-symbol provider.
pub fn LanguageFeaturesService::register_document_symbol_provider(
  self : LanguageFeaturesService,
  provider : &@language.DocumentSymbolProvider,
) -> Unit {
  self.document_symbol_provider.register(provider)
}

///|
/// Registers an ordered semantic-token provider.
pub fn LanguageFeaturesService::register_semantic_tokens_provider(
  self : LanguageFeaturesService,
  provider : &@language.SemanticTokensProvider,
) -> Unit {
  self.semantic_tokens_provider.register(provider)
}

///|
/// Registers an ordered folding-range provider.
pub fn LanguageFeaturesService::register_folding_range_provider(
  self : LanguageFeaturesService,
  provider : &@language.FoldingRangeProvider,
) -> Unit {
  self.folding_range_provider.register(provider)
}

///|
/// Registers an ordered inlay-hints provider.
pub fn LanguageFeaturesService::register_inlay_hints_provider(
  self : LanguageFeaturesService,
  provider : &@language.InlayHintsProvider,
) -> Unit {
  self.inlay_hints_provider.register(provider)
}

///|
/// Returns the first non-empty hover answer in provider order.
pub async fn LanguageFeaturesService::hover_at(
  self : LanguageFeaturesService,
  document : @model.TextModel,
  offset : Int,
) -> @language.Hover? noraise {
  for index in 0..<self.hover_provider.entries.length() {
    let provider = self.hover_provider.entries[index]
    match
      (provider.hover_at(document, offset) catch {
        _ => {
          self.log_provider_failure("language.hover", document, index)
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
pub async fn LanguageFeaturesService::diagnostics_for_document(
  self : LanguageFeaturesService,
  document : @model.TextModel,
  apply : (String, Array[@language.Diagnostic]) -> Unit,
) -> Unit noraise {
  for index in 0..<self.diagnostics_provider.entries.length() {
    let provider = self.diagnostics_provider.entries[index]
    let owner = "diagnostics:" + index.to_string()
    let diagnostics = provider.diagnostics_for_document(document) catch {
      _ => {
        self.log_provider_failure("language.diagnostics", document, index)
        []
      }
    }
    apply(owner, diagnostics)
  }
}

///|
/// Concatenates document-symbol results from every provider.
pub async fn LanguageFeaturesService::document_symbols(
  self : LanguageFeaturesService,
  document : @model.TextModel,
) -> Array[@language.DocumentSymbol] noraise {
  let symbols : Array[@language.DocumentSymbol] = []
  for index in 0..<self.document_symbol_provider.entries.length() {
    let provider = self.document_symbol_provider.entries[index]
    let result = provider.document_symbols(document) catch {
      _ => {
        self.log_provider_failure("language.documentSymbols", document, index)
        []
      }
    }
    symbols.append(result)
  }
  symbols
}

///|
/// Concatenates semantic-token results from every provider.
pub async fn LanguageFeaturesService::semantic_tokens_for_document(
  self : LanguageFeaturesService,
  document : @model.TextModel,
) -> Array[@language.SemanticToken] noraise {
  let tokens : Array[@language.SemanticToken] = []
  for index in 0..<self.semantic_tokens_provider.entries.length() {
    let provider = self.semantic_tokens_provider.entries[index]
    let result = provider.semantic_tokens_for_document(document) catch {
      _ => {
        self.log_provider_failure("language.semanticTokens", document, index)
        []
      }
    }
    tokens.append(result)
  }
  tokens
}

///|
/// Concatenates folding-range results, falling back to MoonBit indentation
/// ranges when no provider answers.
pub async fn LanguageFeaturesService::folding_ranges_for_document(
  self : LanguageFeaturesService,
  document : @model.TextModel,
) -> Array[@language.FoldingRange] noraise {
  let ranges : Array[@language.FoldingRange] = []
  for index in 0..<self.folding_range_provider.entries.length() {
    let provider = self.folding_range_provider.entries[index]
    let result = provider.folding_ranges(document) catch {
      _ => {
        self.log_provider_failure("language.foldingRanges", document, index)
        []
      }
    }
    ranges.append(result)
  }
  if ranges.length() > 0 {
    ranges
  } else {
    fallback_folding_ranges(document)
  }
}

///|
/// Concatenates inlay-hint results from every provider.
pub async fn LanguageFeaturesService::inlay_hints_for_document(
  self : LanguageFeaturesService,
  document : @model.TextModel,
) -> Array[@language.InlayHint] noraise {
  let hints : Array[@language.InlayHint] = []
  for index in 0..<self.inlay_hints_provider.entries.length() {
    let provider = self.inlay_hints_provider.entries[index]
    let result = provider.inlay_hints(document) catch {
      _ => {
        self.log_provider_failure("language.inlayHints", document, index)
        []
      }
    }
    hints.append(result)
  }
  hints
}

///|
fn LanguageFeaturesService::log_provider_failure(
  self : LanguageFeaturesService,
  category : String,
  document : @model.TextModel,
  index : Int,
) -> Unit {
  self.log_service.warn(category, "provider failed", details=[
    ("document", document.uri.to_string()),
    ("version", document.version.to_string()),
    ("providerIndex", index.to_string()),
  ])
}

///|
fn fallback_folding_ranges(
  document : @model.TextModel,
) -> Array[@language.FoldingRange] {
  if document.language_id == "moonbit" {
    moonbit_indentation_folding_ranges(document.snapshot)
  } else {
    []
  }
}

///|
fn moonbit_indentation_folding_ranges(
  snapshot : @model.TextSnapshot,
) -> Array[@language.FoldingRange] {
  let ranges : Array[@language.FoldingRange] = []
  for line_index in 0..<snapshot.line_count() {
    let line = snapshot.line_text(line_index)
    let trimmed = line.trim(char_set=" \t\r\n")
    if trimmed == "" {
      continue
    }
    let next = next_non_empty_line(snapshot, line_index + 1)
    match next {
      Some(next_line_index) => {
        let indent = line_indent(line)
        let next_indent = line_indent(snapshot.line_text(next_line_index))
        let mut end_line_index = -1
        if next_indent > indent {
          end_line_index = indentation_block_end(snapshot, line_index, indent)
        }
        if trimmed.has_suffix("{") {
          let brace_end = brace_block_end(snapshot, line_index, indent)
          if brace_end > end_line_index {
            end_line_index = brace_end
          }
        }
        if end_line_index > line_index {
          ranges.push(FoldingRange(line_index + 1, end_line_index + 1))
        }
      }
      None => ()
    }
  }
  ranges
}

///|
fn next_non_empty_line(
  snapshot : @model.TextSnapshot,
  start_index : Int,
) -> Int? {
  for index in start_index..<snapshot.line_count() {
    if snapshot.line_text(index).trim(char_set=" \t\r\n") != "" {
      return Some(index)
    }
  }
  None
}

///|
fn indentation_block_end(
  snapshot : @model.TextSnapshot,
  start_index : Int,
  indent : Int,
) -> Int {
  let mut end_line_index = start_index
  for index in (start_index + 1)..<snapshot.line_count() {
    let text = snapshot.line_text(index)
    let trimmed = text.trim(char_set=" \t\r\n")
    if trimmed == "" {
      continue
    }
    if line_indent(text) <= indent {
      return end_line_index
    }
    end_line_index = index
  }
  end_line_index
}

///|
fn brace_block_end(
  snapshot : @model.TextSnapshot,
  start_index : Int,
  indent : Int,
) -> Int {
  for index in (start_index + 1)..<snapshot.line_count() {
    let text = snapshot.line_text(index)
    let trimmed = text.trim(char_set=" \t\r\n")
    if trimmed == "" {
      continue
    }
    if line_indent(text) <= indent && trimmed.has_prefix("}") {
      return index
    }
  }
  -1
}

///|
fn line_indent(line : String) -> Int {
  let mut indent = 0
  for index in 0..<line.length() {
    let code = line[index].to_int()
    if code == 32 {
      indent += 1
    } else if code == 9 {
      indent += 2
    } else {
      return indent
    }
  }
  indent
}

///|
/// Ordered registry for hover participants. Participants with lower ordinals
/// render before later participants when ranges overlap.
pub(all) struct HoverParticipantRegistry {
  entries : Array[&HoverParticipant]
}

///|
/// Creates an empty hover participant registry.
pub fn HoverParticipantRegistry::new() -> HoverParticipantRegistry {
  { entries: [] }
}

///|
/// Adds a hover participant to the registry.
pub fn HoverParticipantRegistry::register(
  self : HoverParticipantRegistry,
  participant : &HoverParticipant,
) -> Unit {
  self.entries.push(participant)
}

///|
/// Services shared by the embeddable viewer and its feature controllers.
pub(all) struct ViewerServices {
  language_features : LanguageFeaturesService
  markers : MarkerService
  marker_decorations : MarkerDecorationsService
  hover_participants : HoverParticipantRegistry
  log_service : @log.LogService
}

///|
/// Creates the default viewer services, including marker, inlay-hint, and
/// markdown hover participants.
pub fn ViewerServices::new(
  log_service? : @log.LogService = @log.LogService::new(),
) -> ViewerServices {
  let markers = MarkerService::new()
  let hover_participants = HoverParticipantRegistry::new()
  hover_participants.register(MarkerHoverParticipant::new())
  hover_participants.register(InlayHintHoverParticipant::new())
  hover_participants.register(MarkdownHoverParticipant::new())
  {
    language_features: LanguageFeaturesService::new(log_service~),
    markers,
    marker_decorations: MarkerDecorationsService::new(markers),
    hover_participants,
    log_service,
  }
}
