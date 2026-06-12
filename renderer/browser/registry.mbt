///|
/// Ordered providers per feature. The registry starts empty; the host
/// registers its providers at startup (the workbench registers its remote
/// language client, an embedder registers in-memory ones or none).
priv struct ProviderRegistry {
  hover : Array[&@language.HoverProvider]
  diagnostics : Array[&@language.DiagnosticsProvider]
  symbols : Array[&@language.DocumentSymbolProvider]
  semantic_tokens : Array[&@language.SemanticTokensProvider]
}

///|
let provider_registry : ProviderRegistry = {
  hover: [],
  diagnostics: [],
  symbols: [],
  semantic_tokens: [],
}

///|
/// Tokenization support by language id, the Monaco
/// `TokenizationRegistry` singleton: starts empty, and the host
/// registers the language packages it composed in at startup (the
/// workbench and embedders register `syntax/lang_*` lexers; this
/// package itself imports none). Unregistered languages render through
/// the plain fallback.
let tokenizer_registry : @syntax.TokenizerRegistry = @syntax.TokenizerRegistry::new()

///|
pub fn register_tokenizer(
  language_id : String,
  tokenizer : &@syntax.LineTokenizer,
) -> Unit {
  tokenizer_registry.register(language_id, tokenizer)
}

///|
pub fn register_hover_provider(provider : &@language.HoverProvider) -> Unit {
  provider_registry.hover.push(provider)
}

///|
pub fn register_diagnostics_provider(
  provider : &@language.DiagnosticsProvider,
) -> Unit {
  provider_registry.diagnostics.push(provider)
}

///|
pub fn register_document_symbol_provider(
  provider : &@language.DocumentSymbolProvider,
) -> Unit {
  provider_registry.symbols.push(provider)
}

///|
pub fn register_semantic_tokens_provider(
  provider : &@language.SemanticTokensProvider,
) -> Unit {
  provider_registry.semantic_tokens.push(provider)
}

///|
async fn ProviderRegistry::hover_at(
  self : ProviderRegistry,
  document : @workspace.SourceDocument,
  offset : Int,
) -> @language.Hover? noraise {
  for provider in self.hover {
    match (provider.hover_at(document, offset) catch { _ => None }) {
      Some(hover) => return Some(hover)
      None => ()
    }
  }
  None
}

///|
/// Commands controllers use to resolve features through the registry; each
/// tags its result with the requesting document version so stale responses
/// are dropped at handling in addition to id correlation.
fn hover_provider_cmd(
  emit : @rabbita.Emit[ViewerMsg],
  document : @workspace.SourceDocument?,
  offset : Int,
  token : Int,
) -> @rabbita.Cmd {
  match document {
    Some(document) => {
      let version = document.version
      @cmd.perform(result => emit(HoverResolved(version, token, result)), async fn() noraise {
        provider_registry.hover_at(document, offset)
      })
    }
    None => @rabbita.none
  }
}

///|
/// Document-level features requested after a fresh render: diagnostics,
/// symbols, and semantic tokens, each resolving independently.
fn language_feature_cmds(
  emit : @rabbita.Emit[ViewerMsg],
  document : @workspace.SourceDocument,
) -> @rabbita.Cmd {
  let version = document.version
  @rabbita.batch([
    @cmd.perform(result => emit(DiagnosticsResolved(version, result)), async fn() noraise {
      match provider_registry.diagnostics.get(0) {
        Some(provider) =>
          provider.diagnostics_for_document(document) catch {
            _ => []
          }
        None => []
      }
    }),
    @cmd.perform(result => emit(SymbolsResolved(version, result)), async fn() noraise {
      match provider_registry.symbols.get(0) {
        Some(provider) => provider.document_symbols(document) catch { _ => [] }
        None => []
      }
    }),
    @cmd.perform(result => emit(SemanticTokensResolved(version, result)), async fn() noraise {
      match provider_registry.semantic_tokens.get(0) {
        Some(provider) =>
          provider.semantic_tokens_for_document(document) catch {
            _ => []
          }
        None => []
      }
    }),
  ])
}
