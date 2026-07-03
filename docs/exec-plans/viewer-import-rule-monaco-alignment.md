# Aligning the External-Consumer Import Rule with Monaco's Workbench Rules

Status: implemented — 2026-07-03 (proposed the same day).
Oracle pin: `vscode` submodule at `294fb350` (2026-06-02, `heads/main`).

## Context

`scripts/check-architecture.mbtx` (`check_external_viewer_imports`) forbids
every non-`viewer/` package from importing `viewer/browser/**` or
`viewer/contrib/**`: externals reach DOM/widget internals only through the
root `viewer` package (`viewer/common/**` stays importable). The rule treats
all consumers alike — the reference shell (`internal/shell/workbench`), the
external-embedding proof (`internal/shell/examples/embedded_viewer`), and
tests.

That is stricter than the source architecture. VS Code's *own* consumption of
the editor (the workbench — the direct analog of our `internal/shell`) imports
editor internals freely; its facade-only boundary exists solely at the
`monaco-editor` npm boundary (`editor.api.ts` → generated `monaco.d.ts`) for
third-party consumers. Our uniform rule has already produced a recorded
deviation — `monaco-port-deviations-closeout.md`'s "Deviations that stay"
table carries:

> `CommentService` in `viewer/common/comments` (Monaco: workbench contrib) |
> comments plan | check-architecture forbids host imports of `contrib/**`

— and it is the wall every future workbench-tier integration (find widget,
gotoError, stickyScroll wiring, comment persistence in the shell) will hit:
each host-facing capability must either grow the `Viewer::` facade past the
strict `IEditor`/`ICodeEditor` subset (the policy says no) or squeeze its
service into the host-importable common tier (the comments deviation).

This plan aligns the rule with Monaco's actual shape: **direction and
environment stay enforced; encapsulation applies only to genuinely external
consumers.**

## Monaco inventory (pasted 2026-07-03, at the pin)

What VS Code enforces, from `vscode/eslint.config.js` (`code-import-patterns`
+ `code-layering`, implemented in `.eslint-plugin-local/`):

- **Tier direction** (glob-granular allow lists):
  - `src/vs/editor/~` (`eslint.config.js:1669`) may import `vs/base/~`,
    `vs/platform/*/~`, `vs/editor/~`. Editor **core cannot import contribs**.
  - `src/vs/editor/contrib/*/~` (`:1680`) additionally allows
    `vs/editor/contrib/*/~` — **contribs cross-import freely** (`suggest` →
    `snippet`, `gotoSymbol` → `peekView`).
  - `src/vs/workbench/~` (`:1735`) and `src/vs/workbench/contrib/*/~`
    (`:1792`) allow `vs/editor/~` **and** `vs/editor/contrib/*/~` — the
    workbench reaches any file in editor common/browser/contrib directly.
- **Environment layering**: the `~` template expands to
  `common/browser/node/electron-*`; `common` cannot import `browser`. This is
  what our multi-target native check already enforces.
- **No package encapsulation for internal consumers.** Within an allowed
  glob, imports are file-granular. Measured at the pin: 43 workbench files
  import `editor/browser/widget/codeEditor/codeEditorWidget`, 56 import
  `editor/common/model/textModel`, 10 import
  `contrib/suggest/browser/suggestController`, 10
  `contrib/peekView/browser/peekView`, 5
  `contrib/hover/browser/contentHoverController`.
- **The facade boundary is a distribution artifact**:
  `src/vs/editor/{editor.api.ts,editor.main.ts}` (`:1723`) is the entry for
  the standalone npm package; `monaco.d.ts` binds third parties only. No
  repo-internal rule says "import the API surface, not the implementation".
- **Controller access mechanic**: `FoldingController.get(editor)`
  (`folding.ts:72`) → `editor.getContribution<T>(ID)`
  (`codeEditorWidget.ts`) — a TypeScript cast; commands bind via
  `bindToContribution` (`editorExtensions.ts`).

## The rule after this plan

Three consumer classes replace today's uniform rule:

| Consumer class | Packages | May import | Monaco analog |
|---|---|---|---|
| viewer-internal | `viewer/**` | unchanged (tier targets + cycle checker) | editor tiers |
| workbench-tier | `internal/shell/**` **except** `internal/shell/examples/**`; `tests/**` | any `viewer/*` package: root, `common/**`, `browser/**`, `contrib/**` | `src/vs/workbench/~` allow list (`eslint.config.js:1735`) |
| external-host stand-ins | `internal/shell/examples/**` and every other non-shell product package (`web`, `app`, future hosts) | root `viewer` + `viewer/common/**` only (today's rule) | `monaco-editor` npm consumers behind `editor.api.ts` |

Invariants that do **not** move (each has a Monaco counterpart or a stronger
local reason):

- Product packages never import `internal/shell/*` (direction; Monaco:
  editor never imports workbench).
- No imports from `vscode/`/`codemirror/` reference trees.
- Rabbita bindings only (`rabbita/dom`, `rabbita/js`) in `viewer/*`.
- Tier targets: browser-tier packages js-only, common-tier and DOM-free
  contrib packages multi-target; `common → browser` still fails the native
  build (Monaco: `code-layering`).
- `viewer/common/**` never imports `viewer/contrib/**` (Monaco: editor core
  cannot import contribs; ours is enforced by the existing package-cycle +
  target discipline, re-stated in `architecture.md`).

The job the old rule was doing — *the shell proves the public facade is
sufficient* — moves to `internal/shell/examples/embedded_viewer`, which
already imports only `viewer`, `viewer/common/languages`, and
`viewer/common/model` (verified 2026-07-03), and now becomes the named
carrier of that property.

## Non-goals

- **No DI/services port.** `ViewerServices` stays; preconditions stay live
  predicates (deviations-closeout Track D structural deviation stands).
- **No `ICodeEditor` trait seam, no glue relocation.** The foreign-method
  rule keeps `Viewer::` methods and the `*_host.mbt` contribution ctors in
  the root package regardless of who may import what.
- **No new shell features.** Wiring comment persistence/protocol into the
  workbench is *unblocked* by this plan, not part of it.
- **No speculative `Controller.get` instance tables** (the
  avoid-facade-ceremony rule): the pattern is documented (Track C), code
  lands with its first real consumer.

## Track A — the check and the docs

1. **Rewrite `check_external_viewer_imports`** in
   `scripts/check-architecture.mbtx` to implement the three consumer
   classes. While editing: fix the stale doc comment — it still says the
   browser tier "lives behind the `viewer` facade (`export.mbt`)"; the
   facade file was cancelled (Decision D2-REVERSED,
   `viewer-directory-mirror.md`). Cite the Monaco rules
   (`eslint.config.js:1669/:1680/:1735/:1723`) in the new comment so the
   next reader knows the shape is copied, not invented.
2. **Negative/positive proof of the new check** (the script has no test
   suite): temporarily add a `viewer/contrib/comments` import to
   `internal/shell/examples/embedded_viewer/moon.pkg` — `just check` must
   fail naming the external-host class; revert. Track B's test-package
   import (below) is the standing positive case for the workbench-tier
   class.
3. **`docs/architecture.md`**: update the Viewer Three-Tier Mirror closing
   paragraph and the Dependency Rules bullet ("no external imports of the
   `viewer/browser/**` or `viewer/contrib/**` internals") to the
   three-class rule; name `embedded_viewer` as the facade-sufficiency
   proof; add the workbench-tier bullet ("`internal/shell` consumes viewer
   internals the way VS Code's workbench consumes `vs/editor/**`").
4. **Policy cross-ref**: extend the strict-Monaco-subset policy note (the
   `viewer-api-strict-monaco-subset` decision): host-facing feature
   capabilities beyond `IEditor`/`ICodeEditor` are reached by importing the
   feature package (Monaco's workbench shape), never by growing the
   `Viewer::` surface.

Gate: `just check` green; the step-2 dry-run observed failing then reverted.

## Track B — re-home `CommentService` (closes the deviation row)

The one landed deviation the old rule caused. Importers of
`viewer/common/comments` at the pin: root `viewer`,
`viewer/contrib/comments`, `viewer/contrib/comments/browser`,
`tests/browser/moonbit/comments` (inventoried 2026-07-03).

Monaco's filing at the pin: the **types** (`CommentThread` et al.) live in
`editor/common/languages.ts:2266` — a common-tier home, matching
`viewer/common/comments` today; the **service** (`ICommentService`) lives
with its feature in `workbench/contrib/comments/browser/commentService.ts`.

1. **Move `CommentService`** (+ its mutation events) from
   `viewer/common/comments` to `viewer/contrib/comments`. The thread/comment
   **types stay** in `viewer/common/comments` (that *is* Monaco's
   `languages.ts` filing). The service is DOM-free: the contrib package
   stays multi-target, so `moon check --target all` keeps proving it.
2. **Re-point consumers**: `ViewerServices.comments`
   (`viewer/services.mbt`) retypes to the contrib package's service (root
   already imports `viewer/contrib/comments`);
   `tests/browser/moonbit/comments` imports the contrib package for the
   service and the common package for types — the first legal
   workbench-tier import under Track A, in the same commit.
3. **Supersede the deviation row.** Per `docs/exec-plans/README.md`, do not
   rewrite the implemented closeout plan's table: add a dated addendum to
   `monaco-port-deviations-closeout.md` linking here. The residual
   deviation is re-justified: the service sits in `viewer/contrib/comments`
   rather than shell-side because comments ship as a *reusable viewer
   feature* (product scope, user decision of 2026-07-03), not because the
   import rule forces it; within the tree we own, the filing now mirrors
   Monaco's feature-owns-its-service shape.

Gate: `moon check --target all`, `just test`, `just test-browser` (the
comments scenario is the behavior coverage; zero behavior change expected —
this is a relocation).

## Track C — controller-access pattern (documented only)

Monaco's `FoldingController.get(editor)` is a cast through
`getContribution<T>(id)`; MoonBit cannot downcast a trait object, so the
faithful rendering is: **each contrib package owns an instance table keyed by
`editor_id`** (`Map[String, Controller]` — the WeakMap analog), populated by
its contribution ctor and cleared by its dispose; hosts call
`@<feature>.get(viewer.get_id())`. Today no host consumes a controller (the
shell drives features through `ViewerServices`), and most feature state still
lives as `Viewer` fields rather than controller values — so **no code lands
now**. Deliverable: a short "Controller access" paragraph in
`architecture.md` Placement Rules recording the pattern, so the first
consumer (shell folding toggles, comments persistence UI) copies it instead
of inventing, per the prefer-copying-Monaco rule.

## What stays deviant (re-affirmed, unrelated to the import rule)

- `*_host.mbt` glue in the root package (foreign-method rule).
- `ViewerServices` record instead of DI/service collection.
- DOM-free contrib halves hoisted to `viewer/contrib/<feature>/`
  (multi-target native check; Monaco files them under `contrib/*/browser`
  only because it has no native target).
- Eager-only contribution instantiation modes.

## Exit criteria

- `check-architecture.mbtx` enforces the three consumer classes; the stale
  `export.mbt` comment is gone; the dry-run negative test was observed
  failing.
- `architecture.md` (mirror section, Dependency Rules, Placement Rules
  controller-access paragraph) and the API-policy note describe the aligned
  rule; `embedded_viewer` is named as the facade-sufficiency proof.
- `CommentService` lives in `viewer/contrib/comments`;
  `tests/browser/moonbit/comments` imports it directly; the closeout plan
  carries the dated superseding addendum.
- `just check`, `moon check --target all`, `just test`, `just test-browser`
  all green.
