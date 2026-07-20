# Whole-Line Markdown Comment Rendering and Prerequisite Cleanup

Status: proposed
Date: 2026-07-20
Oracle: the `vscode` gitlink recorded by the commit carrying this plan

## Outcome

Render whole-line and consecutive whole-line source comments as safe Markdown
DOM in the code flow. The original comment lines leave the view projection and
one measured ViewZone occupies the same model location. Model text, selections,
copy-from-code, tokens, decorations, URIs, and provider inputs remain unchanged.

Before adding the contribution, close the directly related editor debts that
would otherwise force the feature to duplicate infrastructure or expose broken
DOM interaction:

1. remove the resolved ViewZone `afterLineNumber` divergence note;
2. add the comments slice of Monaco's language configuration;
3. add the public hidden-area changed event with source ordering;
4. centralize safe Markdown rendering and migrate the two current consumers;
5. keep copy and keyboard ownership on the editor input surface instead of
   intercepting caller-owned ViewZone DOM;
6. add the provider, block detector, contribution, ViewZone reconciliation,
   measurement, and browser proof for whole-line Markdown comments.

The plan is complete only when another engineer can enable the feature for a
language without hard-coding its comment delimiters in the contribution and
without creating a third private `cmark -> HTML -> innerHTML` path.

## Scope and Port Modes

### Behavior ports

- `LanguageConfiguration.comments` and its line/block comment data contract:
  `vscode/src/vs/editor/common/languages/languageConfiguration.ts`.
- public `onDidChangeHiddenAreas` behavior:
  `vscode/src/vs/monaco.d.ts`,
  `vscode/src/vs/editor/browser/widget/codeEditor/codeEditorWidget.ts`, and
  `vscode/src/vs/editor/common/viewModel/viewModelImpl.ts`.
- safe reusable Markdown DOM rendering, link activation, disposal, and size
  notification:
  `vscode/src/vs/base/browser/markdownRenderer.ts`.
- edit-context input ownership:
  `vscode/src/vs/editor/browser/controller/editContext/textArea/textAreaEditContextInput.ts`
  and
  `vscode/src/vs/editor/browser/controller/editContext/native/nativeEditContext.ts`.

### Algorithm-fidelity slices

- hidden-area event ordering: merge sources, update projected lines, reproject
  cursor/decorations, flush layout, recover the stable viewport, then publish
  the outgoing hidden-area event only when the view-line mapping changed;
- Markdown block normalization and reconciliation: sorted, non-overlapping
  line ranges, deterministic stable keys, one hidden-area transaction, and one
  ViewZone transaction per refresh;
- measured-height updates: coalesced measurement, changed-height gate, mutable
  `height_in_px`, and `layout_zone` without ResizeObserver feedback loops.

### Product-specific behavior

Monaco does not provide inline Markdown-comment rendering. Detection,
source-aware hidden-area visibility, DOM/CSS, block identity, and fallback
semantics are local product behavior. Monaco remains the oracle only for the
language, event, Markdown-renderer, input, projection, and ViewZone primitives
listed above.

### Explicitly out of scope

- inline or trailing comments after code;
- comments that occupy only part of a physical line;
- editable-source replacement, WYSIWYG editing, or round-tripping HTML edits;
- arbitrary raw HTML from Markdown;
- custom per-code-line heights, block decorations, or a general
  `LineHeightsManager` port;
- arbitrary-object hidden-area source identity; the current string source key
  remains the local contract;
- CodeEditorWidget's shared cross-event delivery queue;
- incremental text edit machinery and `ViewLinesInserted`/`ViewLinesDeleted`;
- a full Monaco Markdown renderer source audit, theme-icon syntax, trust
  policy, remote-media policy framework, or asynchronous code-block provider;
- making ViewZones accessible to assistive technology in this slice. Both the
  local viewer and Monaco currently mark the ViewZone containers
  `aria-hidden=true`; changing that requires a separate product decision;
- hiding every model line. Both projections intentionally reveal all lines if
  every line is hidden. A no-trailing-newline file consisting entirely of one
  Markdown comment block therefore falls back to source rendering in this
  plan instead of introducing a synthetic model/view line.

## Current Baseline

### Already complete and reused

- `viewer/browser/view_zones.mbt` exposes the complete mutable ViewZone
  descriptor and transaction-scoped `ViewZoneChangeAccessor`.
- `internal/viewer/browser/view/view_zones.mbt` validates model anchors,
  applies `after_column`/affinity, converts model to view coordinates, handles
  hidden areas, retains caller DOM, and rereads mutable height through
  `layout_zone`.
- `viewer/common/view_model/hidden_areas.mbt` owns
  `Map[String, Array[Range]]` and merges each source into sorted disjoint
  whole-line ranges while preserving stable viewport behavior.
- `viewer/hidden_areas_api.mbt` already applies hidden ranges through the
  root-owned browser/common event transaction.
- `suppress_mouse_down=false` already leaves ViewZone DOM mouse selection and
  clicks to the browser.

The ViewZone implementation is not reopened for a broad parity port. Focused
changes are limited to the source-aware visibility policy required by this
feature.

### Real prerequisite gaps

- `viewer/common/languages/language_configuration.mbt` stores only folding
  rules and explicitly omits comments.
- `viewer` has `on_did_change_view_zones` but no public
  `on_did_change_hidden_areas`.
- `internal/viewer/contrib/hover/hover_render.mbt` and
  `internal/viewer/contrib/agent_feedback/browser/agent_feedback_editor_widget.mbt`
  each own a private safe-cmark conversion.
- `viewer/input.mbt` attaches `copy` and `keydown` to the entire root. A native
  ViewZone selection can therefore be replaced by an old model selection, and
  a focused ViewZone link can bubble into editor keybindings.
- `docs/notes/view-zone-afterlinenumber-divergence.md` describes deleted
  `anchor_line`/view-addressed behavior even though current ViewZones already
  perform the model-to-view conversion.

## Target Architecture

```text
language.CommentRule / MarkdownCommentProvider
                    |
                    v
       normalized MarkdownCommentBlock[]
                    |
          +---------+----------+
          |                    |
          v                    v
HiddenAreasModel source     shared safe Markdown renderer
          |                    |
          v                    v
 model/view projection     retained DOM + disposer
          |                    |
          +---------+----------+
                    v
           Markdown ViewZone registry
                    |
                    v
        ResizeObserver -> layout_zone
```

Ownership follows the existing tiers:

- `language` owns the provider value contract;
- `viewer/common/languages` owns language configuration, provider
  registration, lookup, and a narrow `LanguageHandle` capability;
- a new DOM-free `internal/viewer/markdown` package owns safe cmark parsing,
  plaintext fallback, and code-block override composition;
- a new JS-only `internal/viewer/browser/markdown` package owns rendered DOM,
  link/media rewriting, listeners, size notifications, and disposal;
- a new `internal/viewer/contrib/markdown_comments` package owns block
  normalization and the configuration-backed default detector;
- its `browser` child owns rendered-block DOM state and height observation;
- root `viewer/*.mbt` glue owns the contribution entry, model-scoped
  subscriptions, hidden-area call, ViewZone transaction, and scheduling;
- CSS remains at
  `viewer/contrib/markdown_comments/browser/markdown_comments.css` so the
  existing asset builder can emit it from an owner-adjacent stable path.

No common package imports a browser or contribution package. No internal
browser/helper package imports the root `viewer` facade.

## Representation Decisions

### Language comment rules

Use concrete, normalized MoonBit records instead of TypeScript's
`string | object | null` union:

```text
LineCommentRule {
  comment: String
  no_indent: Bool
}

CharacterPair {
  open: String
  close: String
}

CommentRule {
  line_comment: LineCommentRule?
  block_comment: CharacterPair?
}

LanguageConfiguration {
  comments: CommentRule?
  folding_rules: FoldingRules?
}
```

`LineCommentRule(comment, no_indent=false)` is the convenience construction
path corresponding to Monaco's string form. Empty delimiters are rejected at
registration. Only comment and folding fields enter this plan; brackets,
auto-closing pairs, indentation rules, words, and electric characters remain
out of scope.

The current replace-by-language configuration map remains sufficient for the
selected behavior. Disposable configuration stacking is not introduced merely
for structural similarity. The contribution reads configuration when a model
is attached or refreshed; callers must install language configuration before
attaching the model.

### Markdown comment provider

This is a real open registration surface, so a trait is justified:

```text
MarkdownCommentBlock {
  line_range: LineRange
  markdown: String
}

trait MarkdownCommentProvider {
  provide_markdown_comments(TextModel) -> Array[MarkdownCommentBlock]
}
```

`LineRange` is 1-based and half-open. Provider results are synchronous because
they inspect the already available snapshot and must complete before one
hidden-area/ViewZone transaction. `Languages` stores ordered disposable
registrations selected by `LanguageSelector`; the first matching provider is
authoritative, including an empty result. If no provider matches, the
configuration-backed detector is used when `LanguageConfiguration.comments`
exists. No provider and no comment configuration means no rendered blocks.

The `LanguageHandle` gains only the capability needed by the contribution:
query normalized Markdown comment blocks for one model. It does not expose the
mutable registry.

### Shared Markdown renderer

Keep pure conversion separate from browser lifetime:

```text
MarkdownRenderOptions {
  language_id: String?
  base_uri: Uri?
  action_handler: ((String) -> Unit)?
  code_block_renderer: ((CodeBlock, String?) -> String)?
  on_size_changed: (() -> Unit)?
  allow_remote_images: Bool
}

RenderedMarkdown {
  element: Element
  dispose: Disposable
}
```

The DOM-free layer returns safe HTML plus render facts such as
`has_code_block`. The browser layer can render into a caller-provided target so
reconciliation retains the ViewZone node. Disposal removes every listener and
makes late image-load/size callbacks inert.

Required security behavior:

- cmark HTML rendering always uses `safe=true`;
- parse failure renders escaped plaintext in a paragraph;
- raw HTML and unsafe URI schemes never become active DOM;
- when an action handler is present, links activate only through it and never
  also perform browser navigation;
- without an action handler, only sanitized `http`, `https`, and `mailto`
  targets remain native links; they open outside the editor document with
  `rel="noopener noreferrer"`. Relative, `file`, command, and unknown schemes
  are inert;
- remote images are disabled by default; an allowed image is rewritten before
  insertion and reports its load-driven size change;
- non-checkbox inputs are removed and task-list checkboxes, if retained, are
  disabled.

Hover supplies its existing tokenized fenced-code renderer. Agent feedback and
Markdown comments use the same renderer without reimplementing cmark parsing.

### Hidden-area outgoing event

Add a dedicated `HiddenAreasChangedOutgoingEvent` to the existing ViewModel
outgoing dispatcher and a root `Emitter[Unit]` exposed as
`Viewer::on_did_change_hidden_areas`.

The event fires exactly once when `ViewModelLines::set_hidden_areas` reports a
changed line mapping, after internal View events, cursor/decorations, layout,
and stable-viewport recovery have completed. Equal ranges, a force-update that
does not change the mapping, and a missing model do not fire it. A headless
Viewer with a real model/ViewModel does fire when its mapping changes. The
existing absence of a shared cross-event delivery queue remains a recorded
representation seam, not a reason to delay the dedicated event.

### Native DOM input ownership

The editor owns keyboard commands only when the key event originates from the
root input surface. A key event whose target is a focusable descendant or a
caller-owned ViewZone/widget DOM subtree remains native.

Copy uses both event origin and the browser Selection. If a non-collapsed DOM
selection has either endpoint inside a caller-owned ViewZone/widget subtree,
the root copy handler returns without writing clipboard data or preventing the
default event, even when the model selection is non-empty. Otherwise existing
model-selection rich/plain copy behavior is unchanged.

Put the DOM-origin/selection probes in `base/browser` or the browser controller
layer, not in the Markdown-comment contribution. Existing widget-local
`stopPropagation` workarounds may be removed only after browser evidence proves
the generic rule.

### Source-aware ViewZone visibility

Monaco's `showInHiddenAreas` is a single Bool, so it cannot distinguish a
feature's own hidden source from folding. Add a local optional policy without
changing the default Monaco behavior:

```text
ViewZone {
  ...
  ignore_hidden_area_source: String?
}
```

Visibility precedence is:

1. `show_in_hidden_areas == true` means visible;
2. otherwise `ignore_hidden_area_source=Some(source)` means visible only when
   the anchor-side model position is not hidden by any other source;
3. otherwise use the current merged model-position visibility.

`HiddenAreasModel` therefore gains a membership query over all source arrays
except one key. It must not rebuild or mutate the cached merged union. The
Markdown contribution uses one stable source string for both its hidden ranges
and its ViewZones. Folding continues to suppress Markdown zones, while a zone
at end-of-file can ignore the block that it replaces.

### Contribution state

The root contribution registry gains one exhaustive variant. The concrete
state is Viewer-lived and its rendered entries are model-scoped:

```text
MarkdownCommentContributionState {
  generation: Int
  rendered: Map[String, RenderedMarkdownComment]
  listeners: Array[Disposable]
}

RenderedMarkdownComment {
  key: String
  block: MarkdownCommentBlock
  zone: ViewZone
  zone_id: String
  rendered_markdown: RenderedMarkdown
  size_observer: Disposable
  measured_height: Double
}
```

The stable key is `start_line:end_line_exclusive`. Same-key content updates
reuse the ViewZone DOM target, replace the renderer/disposer, and retain the
zone id. Removed blocks dispose renderer/observer before removing their zone.
Added blocks create DOM and a provisional one-line height before registration.

## Detection and Normalization Algorithm

The configuration-backed detector scans the immutable `TextSnapshot` once,
left to right. Its cost is O(total UTF-16 source length); the current model has
only whole-document `set_value`, so no incremental interval index is added.

### Line comments

A physical line qualifies when, after leading whitespace, it starts with the
configured line delimiter. Remove the delimiter and at most one following
ASCII space. Consecutive qualifying physical lines form one block; a comment
line containing only the delimiter contributes an empty Markdown line. A blank
non-comment physical line terminates the block.

### Block comments

A block qualifies only when:

- its opening delimiter is the first non-whitespace text on its first line;
- its closing delimiter is the last non-whitespace text on its final line;
- there is no source text outside the delimiters on either boundary line; and
- every intervening line belongs to the same configured block comment.

Single-line whole-line block comments are allowed. Strip the opening/closing
delimiters, common indentation, and the conventional optional interior
`*` plus one following space. Preserve remaining line breaks. Nested block
comment semantics and language-specific doc-comment prefixes are delegated to
a registered `MarkdownCommentProvider`.

### Provider result normalization

For either source:

1. discard empty, out-of-model, or reversed `LineRange` values and report the
   provider failure through the existing log capability;
2. sort by start line, then end-exclusive line;
3. discard later overlapping ranges; touching ranges stay separate unless the
   detector itself grouped them;
4. discard blocks whose Markdown body is empty after delimiter removal;
5. if the union covers every model line, return no renderable blocks and keep
   source text visible under the documented all-hidden fallback.

The normalized output is the sole input to hidden-area and zone
reconciliation.

## Refresh and Reconciliation Algorithm

Refresh on initial model attachment, model replacement, and every
`on_did_change_model_content` flush. A model flush must call
`set_hidden_areas(..., force_update=true)` even when the recomputed ranges equal
the previous cache, because the projected line collection was rebuilt.

For generation `g`:

1. increment the contribution generation and snapshot the current model;
2. obtain and normalize blocks;
3. build the new stable-key map;
4. in one `change_view_zones` callback:
   - remove entries absent from the new map;
   - update same-key DOM whose Markdown changed;
   - add new zones anchored after `end_line_number_exclusive - 1`, with
     `suppress_mouse_down=false`,
     `ignore_hidden_area_source=Some(MARKDOWN_COMMENT_SOURCE)`, and a
     provisional height;
5. convert each `LineRange [start,end)` to the inclusive whole-line `Range`
   expected by `set_hidden_areas` and replace the contribution's one source;
6. let the resulting line-mapping event recompute all retained ViewZone
   anchors against the new projection;
7. schedule one render;
8. after DOM mount, observe the inner Markdown content size. A callback whose
   generation or zone id is stale is inert. A changed integer-pixel height
   mutates `zone.height_in_px` and calls `layout_zone(zone_id)` in one
   transaction.

No animation frame may observe hidden lines without their replacement zones,
or replacement zones while their source lines remain visible. Refresh stays
synchronous through step 7; measurement is the only later phase.

Use a ResizeObserver wrapper returning `Disposable`. Observe an inner
auto-height content element rather than the outer fixed-height zone. Coalesce
multiple notifications onto the shared animation-frame coordinator, compare
against the last applied height, and ignore zero height while disconnected.

## DOM and Styling Contract

Each zone owns this stable shape:

```html
<div class="moonbit-viewer-markdown-comment" data-start-line="..." data-end-line="...">
  <div class="moonbit-viewer-markdown-comment-content">...</div>
</div>
```

- the outer node is the caller-owned ViewZone DOM node;
- the inner node is the measured target and shared-renderer target;
- width follows the editor content width; horizontal padding is included in
  measured height;
- paragraphs, headings, lists, blockquotes, rules, inline code, and
  fenced code receive editor-theme variables;
- code blocks use the editor monospace font and existing token classes;
- no margin ViewZone is created;
- links receive normal mouse behavior through the shared action handler;
- CSS never hides or overlays the original model lines. Projection owns source
  removal.

## Execution Order and Milestone Commits

### Milestone 0 — refresh inventory and remove false documentation

- Re-read the current local files and the checked-in vscode sources named in
  this plan; record any changed package or public boundary before editing.
- Delete `docs/notes/view-zone-afterlinenumber-divergence.md` rather than
  rewriting resolved history as a current contract.
- Confirm no live documentation or code still references `anchor_line` or the
  deleted note.
- Commit the documentation cleanup independently.

Evidence:

- `rg` finds no stale note reference or obsolete ViewZone API name;
- `git diff --check` passes.

### Milestone 1 — language comment configuration

- Add the normalized comment-rule records and constructors to
  `viewer/common/languages`.
- Extend `LanguageConfiguration`, default lookup, tests, README, and every
  struct literal.
- Add `MarkdownCommentBlock` and `MarkdownCommentProvider` to `language` and
  the ordered provider registry/query to `viewer/common/languages`.
- Extend `LanguageHandle` with the narrow query capability.
- Implement and test the configuration-backed O(N) detector and provider
  normalization in `internal/viewer/contrib/markdown_comments`.
- Run `moon info --target all`; review generated public interfaces rather than
  editing them manually.
- Commit the language/detector milestone.

Focused evidence:

- comments absent/present; line only, block only, and both;
- indentation, optional post-delimiter space, blank comment line, and block
  interior `*` stripping;
- adjacent vs separated blocks, inline/trailing rejection, single-line block,
  multiline block, Unicode, LF/CRLF-normalized snapshots;
- provider selection, disposal, authoritative empty result, invalid range,
  overlap, sort order, and configuration fallback.

### Milestone 2 — hidden-area changed event

- Add the outgoing event value, dispatcher arm/listener, ViewModel emission,
  root model-scoped relay, public `Viewer` emitter/subscription, disposal, and
  generated interface.
- Preserve the exact changed-only and post-transaction ordering.
- Keep `Viewer::set_hidden_areas` package-private.
- Commit the event parity milestone.

Focused evidence:

- changed, unchanged, forced-but-unchanged, all-hidden normalization, headless,
  missing model, model swap, disposal, reentrant listener, and relative order
  against mapping/cursor/layout/scroll facts. Headless cases cover both a real
  mapping change and an unchanged update.

### Milestone 3 — shared safe Markdown renderer

- Add the DOM-free and JS-only shared Markdown packages.
- Port the selected safe rendering, link activation, URI rewriting, disabled
  input, load callback, target reuse, and disposal behaviors.
- Move hover's code-block override into the shared renderer option while
  preserving its current tokenized output and `has_code_block` behavior.
- Migrate agent feedback to the same renderer and make its widget own the
  returned disposable for every replacement and teardown.
- Remove both private cmark conversion helpers and direct package dependencies
  that became redundant.
- Update package READMEs, `moon.pkg`, architecture ownership, and generated
  interfaces.
- Commit only after both existing consumers have focused green tests.

Focused evidence:

- safe raw HTML and unsafe-link rejection;
- plaintext fallback on parse failure;
- fenced-code language selection and tokenized hover output;
- target-node reuse;
- click, middle-click, Enter, and Space activation;
- relative base URI and remote-image denial;
- image-load size callback before and after disposal;
- repeated render replacement does not retain old listeners.

### Milestone 4 — native DOM input ownership

- Add generic browser probes for event target ancestry and native DOM
  selection containment.
- Gate root copy and keydown handling on the editor input surface.
- Remove widget-local propagation workarounds only where the new rule makes
  them redundant and tests prove identical behavior.
- Commit the input fix independently from the Markdown-comment contribution.

Focused browser evidence:

- ordinary model selection still copies plain and rich code;
- an empty model selection retains browser default behavior;
- a non-empty model selection plus native ViewZone text selection copies the
  ViewZone text and is not prevented;
- ViewZone link Enter/Space and navigation keys do not run editor commands;
- root-focused Arrow/Home/Page keys still run editor commands;
- `suppress_mouse_down=true/false` behavior stays unchanged.

### Milestone 5 — source-aware zone visibility

- Add the optional ViewZone ignore-source policy and HiddenAreasModel
  excluding-source membership query.
- Thread the policy only through ViewZones whitespace visibility computation;
  do not alter the merged projection or public hidden-area source key type.
- Add branch coverage for default, show-all, ignore-own, and another-source
  hidden combinations, including EOF.
- Regenerate and review `viewer/browser/pkg.generated.mbti` and root forwarding
  APIs.
- Commit the focused ViewZone extension.

### Milestone 6 — Markdown-comment contribution and height lifecycle

- Add the contribution packages, central registry variant/constructor/accessor,
  root lifecycle glue, CSS asset, stable-key reconciliation, hidden source,
  and size observer.
- Preserve model-swap and Viewer-disposal ownership: every renderer, listener,
  observer, zone, and hidden source is released exactly once.
- Use `force_update=true` after same-model content flush.
- Add a direct public-Viewer component scenario; do not route the proof through
  `internal/shell`.
- Commit the working feature with DOM-free, mounted, and browser evidence.

Focused evidence:

- block at start, middle, and EOF;
- several blocks and same-key body update;
- add/remove/move after `set_value`;
- soft-wrapped neighbors;
- folding hides the zone while its own source does not;
- same-model flush with unchanged ranges;
- model detach, replacement, reattach, and Viewer disposal;
- initial provisional height, text reflow after width change, fenced code,
  list/heading height, allowed image load, and observer coalescing;
- no provider/configuration, invalid provider result, empty Markdown body, and
  all-model-lines fallback;
- original model value, tokens, positions, selection, and code copy remain
  model-coordinate truth while the source lines are hidden only in the view.

### Milestone 7 — close contracts and full validation

- Update `docs/architecture.md` only for new durable package/ownership rules.
- Update owning package READMEs and `docs/harness.md` if a new browser scenario
  or command contract was introduced.
- Review every `moon.pkg` edge and every changed `pkg.generated.mbti`.
- Run the complete repository gates.
- Record the final behavior and deliberate deferrals in
  `docs/exec-plans/HISTORY.md`, then delete this detailed active plan in the
  same closing commit.

Required final commands:

```sh
moon info --target all
just check
just test
just build
just test-browser
git diff --check
```

## Evidence Map

| Behavior or invariant | Source | MoonBit disposition | Evidence |
|---|---|---|---|
| line/block comment configuration | `languageConfiguration.ts` | normalized concrete records; comments slice only | language configuration and detector tests |
| ordered provider registration | local language-feature registry pattern | synchronous first-match provider plus config fallback | provider registry/normalization tests |
| hidden-area event changed-only ordering | `viewModelImpl.ts`, `codeEditorWidget.ts`, `monaco.d.ts` | dedicated outgoing event and root emitter | ViewModel/root event-order tests |
| safe Markdown conversion | `markdownRenderer.ts`; current cmark consumers | shared safe cmark core with plaintext fallback | multi-target renderer tests |
| DOM render lifetime and link activation | `markdownRenderer.ts` | rendered element plus disposable | JS/browser renderer tests |
| native copy/key ownership | textarea/native edit-context input sources | root-origin and native-selection gates | Playwright component tests |
| ViewZone model anchor and mutable height | `viewZones.ts` | reuse current implementation | existing ViewZones branch/browser suites |
| ignore only the contribution's hidden source | local feature requirement | optional source-exclusion policy | hidden-area/ViewZones interaction matrix |
| whole-line block detection | local feature requirement | O(N) snapshot scan plus provider override | detector matrix |
| block/zone reconciliation | local feature requirement | stable-key map and synchronous two-transaction refresh | mounted and browser lifecycle tests |
| DOM-driven height | `layoutZone` contract plus local requirement | coalesced ResizeObserver and changed-height gate | real-browser geometry tests |
| all-lines-hidden behavior | shared Monaco/local invariant | DEFERRED; keep source visible | explicit fallback test |
| ViewZone accessibility | shared Monaco/local `aria-hidden` behavior | DEFERRED pending product decision | explicit browser assertion |

## Behavioral Deviations

- Comment rules use normalized MoonBit records rather than TypeScript unions.
- Language configuration retains the current replace-by-language ownership;
  disposable configuration stacking is outside the selected behavior.
- Hidden-area sources remain string keyed.
- The dedicated hidden-area event does not join a CodeEditorWidget-wide shared
  cross-event queue.
- Source-excluding ViewZone visibility is an intentional local extension;
  Monaco exposes only `showInHiddenAreas`.
- Markdown-comment rendering itself is local product behavior, not a Monaco
  parity claim.
- Whole-model comment coverage and accessible ViewZone semantics remain
  explicit deferrals, not silent unsupported branches.

## Review Gates

### Gate A — before product edits

- [ ] refresh every named local and source path against the current gitlinks;
- [ ] confirm the port mode and exclusions still match current consumers;
- [ ] review public API additions in planned record/trait/handle form;
- [ ] review new package edges against `docs/architecture.md`;
- [ ] confirm the worktree contains no unrelated changes that overlap planned
  files.

This is an internal execution checkpoint. Record the result and continue unless
the current source exposes a material unresolved public API or behavior choice.

### Gate B — after prerequisite cleanup

- [ ] stale ViewZone documentation removed;
- [ ] comment configuration and provider surface focused tests green;
- [ ] hidden-area outgoing event ordering green;
- [ ] hover and agent feedback use the shared renderer with no private cmark
  conversion left;
- [ ] native ViewZone copy and keyboard behavior green;
- [ ] focused package checks and `just check` green.

Do not begin the Markdown-comment contribution until Gate B passes.

### Gate C — after feature implementation

- [ ] normalized blocks, hidden ranges, registered zones, rendered DOM, and
  observers have one owner each;
- [ ] folding, EOF, flush, model swap, and disposal matrices are green;
- [ ] browser-measured height converges without repeated unchanged layout;
- [ ] model text/coordinates/copy truth remains unchanged;
- [ ] no frame exposes duplicate source-plus-Markdown content;
- [ ] focused package, mounted Viewer, and browser component evidence is green.

### Exit Gate

- [ ] scope, source revision through the gitlink, modes, and exclusions are
  recorded;
- [ ] all prerequisite gaps in this plan are closed before contribution code;
- [ ] every behavior claim in the evidence map has focused proof or an explicit
  deferral;
- [ ] public interfaces and package dependencies are reviewed;
- [ ] `just check`, `just test`, `just build`, and `just test-browser` pass;
- [ ] durable architecture/package/harness documentation reflects the landed
  behavior;
- [ ] completion is compressed into `HISTORY.md` and this active plan is
  removed.
