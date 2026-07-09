// The folding-rules slice of Monaco's language configuration
// (`vs/editor/common/languages/languageConfiguration.ts` +
// `languageConfigurationRegistry.ts`, vscode submodule commit
// 294fb350837dbaee37b949533fead4df4e0e8971): `FoldingMarkers`,
// `FoldingRules`, and a per-language registration on `Languages` standing in
// for `ILanguageConfigurationService.getLanguageConfiguration(languageId)`.
// Only the folding rules are in scope — brackets, comments, auto-closing
// pairs and the rest of `LanguageConfiguration` have no consumer in the
// readonly viewer.

///|
/// Describes start/end markers of language-specific folding regions (e.g.
/// `#region` / `#endregion`) — Monaco's `FoldingMarkers`
/// (`languageConfiguration.ts`). Monaco's fields are `RegExp`s; MoonBit has
/// no regex in scope, so a marker is a whole-line predicate.
pub(all) struct FoldingMarkers {
  start : (String) -> Bool
  end : (String) -> Bool
}

///|
/// Describes language-specific folding rules — Monaco's `FoldingRules`
/// (`languageConfiguration.ts`): `off_side` marks off-side-rule languages
/// (Python-like; empty lines belong to the previous block), `markers` the
/// optional region markers.
pub(all) struct FoldingRules {
  off_side : Bool
  markers : FoldingMarkers?
}

///|
/// The folding-rules subset of Monaco's `LanguageConfiguration`.
pub(all) struct LanguageConfiguration {
  folding_rules : FoldingRules?
}

///|
/// Registers or replaces `language_id`'s configuration — Monaco's
/// `languages.setLanguageConfiguration` reduced to the folding rules.
pub fn Languages::set_language_configuration(
  self : Languages,
  language_id : String,
  configuration : LanguageConfiguration,
) -> Unit {
  self.language_configurations[language_id] = configuration
}

///|
/// The configuration registered for `language_id` — Monaco's
/// `ILanguageConfigurationService.getLanguageConfiguration(languageId)`,
/// with an empty configuration for unregistered languages.
pub fn Languages::get_language_configuration(
  self : Languages,
  language_id : String,
) -> LanguageConfiguration {
  self.language_configurations
  .get(language_id)
  .unwrap_or({ folding_rules: None })
}
