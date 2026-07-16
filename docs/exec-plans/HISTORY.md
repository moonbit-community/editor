# Execution Plan History

This is the compressed index of completed execution plans and removed obsolete
plans. The full plan text remains available in Git history:

```sh
git log --all --full-history -- docs/exec-plans/<plan>.md
git show <revision>:docs/exec-plans/<plan>.md
```

Current behavior and ownership live in `docs/architecture.md`, `docs/harness.md`,
`docs/quality.md`, package READMEs, generated interfaces, source, and tests.
Historical plans are evidence of how a change landed, not current contracts.

As of 2026-07-16 there are no active checked-in execution plans.

## Completed Work

### Reference shell, remote protocol, and embedding

The browser shell moved to MoonBit/Rabbita, the native host serves the app and
semantic remote protocol, the explorer became a provider-backed optional
widget, and the embedded example proves the viewer can run without the shell.

Former artifacts: `browser-remote-renderer.md`, `rabbita-browser-backend.md`,
`native-hosted-readonly-editor.md`, `remove-local-dom-package.md`,
`pluggable-viewer-and-file-tree.md`.

### Viewer model, provider, and public naming foundations

The reusable boundary converged on `TextModel`, semantic language providers,
host-owned composition, compile-time tokenization registration, and the
`viewer/*` namespace. Several of these files retained stale proposed/no-status
headers after the implementation landed; source and current contracts confirm
the completed outcome.

Former artifacts: `viewer-input-providers-and-virtualization.md`,
`lexmatch-tokenization-registry.md`, `monaco-model-viewer-api.md`,
`viewer-languages-api.md`, `vscode-shaped-editor-feature-services.md`,
`viewer-package-namespace-rename.md`.

### Rendering and package architecture foundations

The renderer moved to a MoonBit-owned imperative view, source-shaped render-line
IR, Monaco-role package tiers, concrete view-part ownership, and the enforced
common/browser/contribution directory split.

Former artifacts: `monaco-ir-and-imperative-view.md`,
`monaco-render-line-ir-layer.md`, `monaco-role-aligned-viewer-architecture.md`,
`monaco-renderer-model-structure.md`,
`monaco-view-part-ownership-architecture.md`,
`viewer-browser-package-decomposition.md`, `viewer-directory-mirror.md`.

### Harness and reference-test structure

Browser suites were split by purpose, a real headless Viewer harness was added,
and the selected readonly Monaco reference suites were ported or explicitly
bounded.

Former artifacts: `browser-test-harness-split.md`,
`headless-viewer-test-harness.md`, `monaco-test-conformance-port.md`.

### DOM and hover foundations

The browser DOM became Monaco-shaped, the content-hover subtree and sizing
lifecycle were implemented, and scrollbar behavior received focused
conformance coverage.

Former artifacts: `monaco-shaped-dom-rendering.md`,
`monaco-exact-hover-widget.md`, `monaco-hover-scrollbar-conformance.md`.

### Rendering, selection, decoration, and scrolling parity

The viewer landed selection hit testing, production line-token rendering,
whitespace/control-character options, marker decorations, current-line/cursor
rendering, model decorations, and scroll render/animation behavior.

Former artifacts: `monaco-faithful-selection-hit-testing.md`,
`production-line-tokens-pipeline.md`,
`faithful-view-line-tokens-render-span-removal.md`,
`monaco-render-whitespace-control-options-port.md`,
`monaco-marker-render-port.md`, `monaco-view-cursors-current-line-port.md`,
`monaco-decoration-system-port.md`,
`monaco-scroll-render-and-animation-parity.md`.

### Public editor and base APIs

The readonly public surface gained Monaco-shaped read, reveal, selection,
set-value/flush, and URI/path behavior with focused tests at the appropriate
layers.

Former artifacts: `monaco-public-read-api-port.md`,
`monaco-reveal-range-api-port.md`, `monaco-set-selection-api-port.md`,
`monaco-uri-system-port.md`, `monaco-set-value-api-port.md`.

### Architecture and deviation closeouts

These reviews removed duplicated helpers and dead surface, reconciled package
and ownership deviations, aligned import rules, and recorded the remaining
intentional readonly-product boundaries.

Former artifacts: `std-dedup-and-divergence-review.md`,
`monaco-port-fidelity-and-deadcode-review.md`,
`monaco-port-fidelity-and-deadcode-review-findings.md`,
`monaco-arch-divergence-closeout.md`, `monaco-port-deviations-closeout.md`,
`viewer-import-rule-monaco-alignment.md`,
`monaco-ownership-divergence-closeout.md`.

### Viewer–Monaco parity remediation program

The coordinated P1 program closed async freshness, cursor/input events, render
invalidation, browser geometry, model/service ownership, ViewZones, normalized
text-buffer behavior, and tokenization lifecycle. Deferred rows remain product
scope decisions, not unfinished execution of these frozen plans.

Former artifacts: `viewer-monaco-parity-remediation.md`,
`viewer-async-model-features-parity.md`,
`viewer-cursor-input-events-parity.md`,
`viewer-render-invalidation-parity.md`, `viewer-browser-geometry-parity.md`,
`viewer-model-lifecycle-ownership-parity.md`, `viewer-view-zones-parity.md`,
`viewer-text-buffer-eol-parity.md`, `viewer-tokenization-parity.md`.

### MoonBit-native representation cleanup

The coordinates converter became a closed concrete enum and the browser `View`
lifecycle moved from awkward trait-object seams to concrete handles, enums, and
responsibility-split lifecycle files.

Former artifacts: `coordinates-converter-concrete-enum-refactor.md`,
`moonbit-idiomatic-view-lifecycle-refactor.md`.

### Browser view package consolidation

The implementation-only browser view packages were consolidated into
`viewer/browser/view` while preserving source-unit files, CSS paths, render
order, and browser behavior. The Gate A ledgers were folded into this record.

Former artifacts: `browser-view-package-consolidation.md`,
`browser-view-package-consolidation-gate-a.md`,
`browser-view-package-consolidation-gate-a-local.md`,
`browser-view-package-consolidation-gate-a-tests.md`,
`browser-view-package-consolidation-gate-a-upstream.md`.

### Editor contribution single ownership

Five contribution instances moved to the one per-Viewer
`EditorContributions.instances` map with two-phase construction and explicit
model/disposal lifetimes. The Gate A ledgers were folded into this record.

Former artifacts: `editor-contribution-single-ownership.md`,
`editor-contribution-single-ownership-gate-a.md`,
`editor-contribution-single-ownership-gate-a-local.md`,
`editor-contribution-single-ownership-gate-a-upstream.md`,
`editor-contribution-single-ownership-gate-a-lifetime.md`.

### Inline-decoration and tokenization package merges

Inline-decoration resolution was folded into `viewer/common/view_model`, and
the model-owned tokenization subtree was folded into
`viewer/common/model`. Generated interfaces, tests, and dependency rules were
validated after both moves.

Former artifacts: `inline-decorations-view-model-package-merge.md`,
`inline-decorations-view-model-package-merge-gate-a.md`,
`inline-decorations-view-model-package-merge-2026-07-14-test-addendum.md`,
`text-model-tokenization-package-merge.md`,
`text-model-tokenization-package-merge-gate-a.md`,
`text-model-tokenization-package-merge-2026-07-14-addendum.md`.

### Public editor API boundary

The root `viewer` facade became opaque and deliberate, shared public values
moved to canonical common/browser owners, concrete services became capability
handles, and test/debug seams moved out of the external API. The Gate A public,
upstream, dependency, and review ledgers were folded into this record.

Former artifacts: `viewer-public-editor-api-boundary.md`,
`viewer-public-editor-api-boundary-gate-a.md`,
`viewer-public-editor-api-boundary-gate-a-public.md`,
`viewer-public-editor-api-boundary-gate-a-upstream.md`,
`viewer-public-editor-api-boundary-gate-a-dependencies.md`.

### Final warning, FFI, dead-surface, and Viewer-state cleanup

Browser FFI was centralized, warning-only/dead production seams were removed,
and the root `Viewer` state was split into lifecycle-domain owners without
changing its public interface or browser behavior.

Former artifacts: `warning-ffi-dead-surface-cleanup-2026-07-15-addendum.md`,
`viewer-lifecycle-domain-aggregates.md`,
`viewer-lifecycle-domain-aggregates-gate-a.md`.

### MoonBit-native API and internal Viewer boundary

The reviewed visibility ledger narrowed 116 public representations and made
five implementation carriers private while preserving ten caller-constructed
contracts and two open provider traits. Mouse-target factories became
package-private local methods on the foreign browser target type, and the
controller's test-only boundary became white-box.

Ninety product constructors plus the internal browser-test context now use
canonical `Type(...)` construction with compatible `#alias(new)` entry points.
The two prefix-sum implementations use `ArrayView[Int]` primary constructors,
copy their inputs, and retain `new(Array[Int])` compatibility wrappers;
selected private read-only helpers also accept views without broad public
signature churn.

Twelve concrete browser runtime, scrollbar, testing, and contribution packages
moved below `internal/viewer/**`. Root `viewer`, public `viewer/browser`, and
the public common/capability packages remain the supported embedding surface.
All twenty CSS/font assets retained their original paths and hashes. Final
validation passed 1,438 JS tests, 1,011 native tests, all 83 Playwright tests,
the production build, generated-interface review, and the module-internal
package checks.

Former artifacts:
`moonbit-native-api-visibility-and-internal-boundary-refactor.md`,
`moonbit-native-api-visibility-and-internal-boundary-refactor-gate-a.md`.

## Removed Obsolete Incomplete Plans

These plans were not compressed as completed work. Their original scopes no
longer match the current package graph, public boundary, or porting policy. If
the underlying feature is requested again, write a new plan from current source
instead of reviving the old file.

- `document-snapshot-viewer-api.md`: superseded by the model-based viewer API
  and the later public API boundary.
- `monaco-core-viewer-api-and-docs.md`: superseded by the model-based viewer API
  and current package contracts.
- `monaco-hover-logic-chain-port.md`: partially executed; the remaining
  verbosity, glyph-hover, sash, and focus scopes were overtaken by later hover
  ownership and behavior work.
- `monaco-one-to-one-port.md`: broad source-shaped umbrella superseded by the
  behavior-first port playbook and focused remediation plans.
- `monaco-view-part-render-architecture.md`: partially implemented and
  superseded by the landed role-aligned architecture, lifecycle refactor, and
  browser-view consolidation.
- `production-lsp-client.md`: its old renderer/dom/package assumptions are
  obsolete. The current native host uses semantic remote protocol boundaries
  and `moon ide hover`/`moon check`; a general LSP client needs a fresh plan.
