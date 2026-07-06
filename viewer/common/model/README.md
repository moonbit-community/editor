# viewer/common/model

Readonly editor text model, immutable text snapshots, and model decorations.
Mirrors Monaco's `editor/common/model`.

## Responsibilities

- Own `TextSnapshot`, the immutable text buffer: the field pair mirrors the
  piece tree's leaf (`StringBuffer { buffer, lineStarts }`) and the 1-based
  methods mirror `IReadonlyTextBuffer`. Carries no document identity.
- Own `TextModel`, the URI-bearing readonly editor model with display name,
  language id, version, revision, and snapshot identity, plus the Monaco
  `textModel.ts` read API (value/line reads, validation, word lookup)
  delegating to the snapshot buffer.
- Own model decorations: interval-tree storage (a port of Monaco's
  `intervalTree.ts`) behind `TextModel::delta_decorations` and the
  range-query accessors, with `DeltaDecoration` / `ModelDecorationOptions` as
  the public shapes.
- Provide the current-document URI plus version comparison used by async
  feature freshness guards.

## Monaco parity — TextModel & TextSnapshot

Placement rule (pinned `vscode/` submodule, commit 294fb350): a member lives
where Monaco files it. `TextModel` ↔ `textModel.ts` (read section :737-1176,
word cluster :2085-2124 via `tokenizationTextModelPart.ts`); `TextSnapshot` ↔
`ITextBuffer`'s read surface (`model.ts` `IReadonlyTextBuffer` :1524) over the
piece tree's leaf chunk (`pieceTreeBase.ts` `StringBuffer` :147). The snapshot
is the degenerate never-edited piece tree — one chunk, its line-start table —
so the tree machinery above the leaf is N-A by the readonly design (edits
arrive as whole new models).

`TextModel` fields:

| viewer | Monaco | status |
| --- | --- | --- |
| `uri` | `_associatedResource` / `get uri` (:671) | PORTED |
| `version` | `_versionId` / `getVersionId()` (:737) | PORTED |
| `snapshot` | `_buffer : ITextBuffer` | PORTED — public (Monaco: private) so headless paths (`TokenizedDocument`, guides) can read the buffer without a model |
| `language_id` | `TokenizationTextModelPart._languageId`, read via `getLanguageId()` (:2085) | RELOCATED — no tokenization part; `get_language_id()` gives the Monaco read shape |
| `decorations_state` | decoration field cluster (:285-290) | PORTED — ledgered in `text_model_decorations.mbt` |
| `display_name`, `revision` | — | EXTRA — host metadata the provider payloads carry (`languages.mbt`, editor events, shell workbench); Monaco hosts get these from workbench services the viewer doesn't have |
| — | `id` (`'$model' + counter`) | N-A — model identity is uri+version by design (`same_identity_and_version`) |
| — | edit/undo/attach/dispose/options/too-large fields | N-A — readonly, no lifecycle |

`TextModel` methods: the read API is ported 1:1 as snake_case of the
`textModel.ts` names (`get_value*`, `get_line_*`, `get_offset_at` /
`get_position_at`, `get_full_model_range`, `validate_position` /
`validate_range` / `validate_range_relaxed` / `modify_position`,
`might_contain_rtl`, `get_word_at_position` / `get_word_until_position`,
`get_language_id`), each doc comment citing its source line. The viewer clamps
where Monaco throws `BugIndicatingError`, and `_assertNotDisposed` guards are
N-A. DEFERRED (no consumer yet): `findMatches`/`findNextMatch`/
`findPreviousMatch`, `getCharacterCountInRange`, `createSnapshot`,
`isValidRange`, `getLinesDecorations` beyond the ported decoration cluster.
N-A (readonly / LF-only): `setValue`, edits, undo/redo, `pushEOL`,
`getEOL`/`getEndOfLineSequence`, options/indentation
(`detectIndentation`/`normalizeIndentation`), attach/dispose,
`mightContainUnusualLineTerminators`/`NonBasicASCII`,
`isDominatedByLongLines`, tokenization/bracket delegates (guides is its own
`GuidesTextModelPart`).

`TextSnapshot` fields: `text`/`line_starts` ↔ `StringBuffer.buffer`/
`.lineStarts` 1:1. Its former `language_id`/`version` fields moved to
`TokenizedDocument` (the buffer carries no identity, matching Monaco).

`TextSnapshot` methods are two ledgered layers:

- `IReadonlyTextBuffer` surface (1-based): `get_length`, `get_line_count`,
  `get_line_content`, `get_line_length`, `get_line_max_column`,
  `get_line_first/last_non_whitespace_column`, `get_offset_at(line, column)`
  (buffer arity; the `Position`-taking form is `TextModel::get_offset_at`),
  `get_position_at`, `get_value`, `get_value_in_range`,
  `get_value_length_in_range`, `might_contain_rtl`.
- pieceTreeBase-internal analog (0-based lines, offset-centric), used by
  tokenizer/view-model loops: `line_text`, `line_start_offset`,
  `line_end_offset`, `line_at_offset`, `slice`, `range_of`,
  `offset_range_of`, `build_line_starts` (whose byte-identical twin in
  `internal/shell/workspace/document.mbt` must change in lockstep).

## Boundaries

- May depend on `base/common` for `Uri`, `Position`, `Range`, and clamping.
- Must not depend on workspace providers, language providers, syntax,
  viewer, DOM, server routing, or host effects.
- Does not expose edit, undo/redo, cursor, IME, or model event APIs.

## Checks

- Local tests plus `*_reference_test.mbt` / `*_reference_wbtest.mbt`
  conformance ports of Monaco's model and interval-tree suites.
- Run `moon test --target all viewer/common/model` for focused coverage.
