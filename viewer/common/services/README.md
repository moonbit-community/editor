# viewer/common/services

Editor-common services. Mirrors Monaco's `editor/common/services/` (the
ported slice).

## Responsibilities

- Own `LanguageIdCodec` (`services/languagesRegistry.ts`): the string↔numeric
  language-id registry whose numeric ids the token metadata word's low 8 bits
  carry, seeded with the viewer's built-in languages.
- Own the process-wide `language_id_codec` instance, the role of Monaco's
  `LanguageService.languageIdCodec` threading one codec through every model.
  Isolated codecs remain constructible for tests.

## Boundaries

- Leaf package: no imports beyond the core library.
- Must not depend on tokens, model, syntax, DOM, or host packages.

## Checks

- Covered through the `viewer/common/tokens` and `viewer/common/model/tokens`
  suites (every metadata round-trip decodes through the codec).
