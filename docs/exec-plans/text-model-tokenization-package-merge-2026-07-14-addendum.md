# Text Model and Tokenization Package Merge — 2026-07-14 Addendum

Status: completed clarification — no product change

Parent history: `text-model-tokenization-package-merge.md`

This addendum preserves the implemented parent plan as immutable history and
corrects one closeout claim found by a requirement-level completion audit.

## Dynamic Language-Change Test

Milestone E asked for a test proving live tokenization reads across a dynamic
model-language change. That case was not implemented by the structural merge
and is terminally:

`DEFERRED (dynamic TextModel language ownership and mutation API are absent)`

The frozen `viewer-tokenization-parity.md` source ledger already records the
corresponding upstream behavior as deferred. Gate A reuses the relevant
package-merge subset from that shared ledger:

- `TPM-002..005`, `TPM-012`, `TPM-029..030`, `TPM-033..034`, and
  `TPM-077..079` cover language/configuration events, mutable language state,
  backend recomputation, and `setLanguageId` control flow;
- `ITM-016` covers the model-part language setter;
- `TMT-003..004`, `TMT-021`, `TMT-027`, and `TMT-047..048` cover model
  forwarding, live backend selection, configuration callbacks, and interface
  events;
- `UTM-015` is the deferred upstream dynamic-language regression test.

The landed `TokenizationModelState.language_id` is fixed when `TextModel` is
constructed. `TextModel` exposes no language-mutation operation. Existing
tests cover construction-language encoding, registry changes for that fixed
language, and tokenization with the construction language; they do not claim a
dynamic transition.

Adding mutable language state or a setter would broaden behavior beyond the
approved package-merge scope. It requires a separate 1:1 plan covering the
complete language-transition source cluster, its event order, backend
replacement, and branch-derived tests.

## Current Evidence

On 2026-07-14, the merged model package passed on both supported test targets:

```text
moon test viewer/common/model --target js      195/195
moon test viewer/common/model --target native  195/195
```

The package merge, direct private `TokenizationModelState` ownership, removal
of `TokenizationModelAccess`, API cleanup, and all other recorded exit criteria
remain unchanged.
