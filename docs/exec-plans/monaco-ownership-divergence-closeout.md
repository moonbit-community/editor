# Closing the Monaco Object-Ownership Divergences

Status: implemented — Date: 2026-07-08 (all four tracks landed the same
day, A → B → C → D). Oracle: checked-in `vscode` submodule.

A review of the viewer's assembly path (`Viewer::Viewer` → `attach` →
`set_model` → `flush_render`) against Monaco's
(`codeEditorWidget.ts` construction → `setModel` → `_attachModel` →
`_createView`) found that the step *sequence* is faithful but the **object
graph is not**: three ownership relationships are inverted or flattened
relative to the source. This plan closes all three. It follows the track
format of `monaco-arch-divergence-closeout.md` and the rules of
`_PORT_PLAYBOOK.md` (source-cited inventory per track, no invention, no
backcompat shims — consumers are updated in the same change).

The three structural deviations, and the tracks that close them:

1. **`ViewLayout` ownership** — Monaco's `ViewModel` owns `viewLayout`
   (`viewModelImpl.ts:64,126`); the viewer's `view_layout` is a long-lived
   `Viewer` field (`viewer/viewer.mbt:39,298`) that survives model swaps and
   is manually reset to the origin on `set_model`. → **Track A**.
2. **`CursorsController` ownership** — Monaco's `ViewModel` owns `_cursor`
   (`viewModelImpl.ts:65,124`); the viewer's `cursor` is a `Viewer` field
   (`viewer/viewer.mbt:48`) re-pointed by hand after every reflow
   (`refresh_cursor_context`, `viewer/selection.mbt:151`). The same
   flattening applies to the hover, agent-feedback, and inlay-hint feature
   state, which Monaco keeps as members of per-editor contribution
   controllers but the viewer spreads across ~30 `Viewer` fields.
   → **Track B** (cursor) and **Track C** (feature controllers).
3. **`View` lifecycle** — Monaco creates the `View` per model attach
   (`_attachModel` → `_createView`, `codeEditorWidget.ts:1889,1923`) and
   destroys its DOM on detach (`_detachModel`, `:2012-2032`), bundling
   `model + viewModel + view + listeners` into one `ModelData`
   (`:2123-2143`) behind a single nullable field. The viewer builds its
   `View` once in `attach` (`viewer/viewer.mbt:515`), keeps it across model
   swaps, and holds `text_model` / `view_model` / `view` as three
   independent options. → **Track D**.

Explicitly **out of scope** (adjacent deviations reviewed and deliberately
left open; do not drift into them):

- The **render-snapshot event seam** (per-frame snapshot diff in
  `View::render` instead of Monaco's push `ViewModelEventDispatcher`) —
  the recorded "plan Deviation 3". Every track below keeps the diff seam;
  ownership moves must not smuggle in an event-dispatcher rewrite.
- `onDidScrollChange` timing (coalesced onto the render flush).
- Lazy contribution instantiation modes (`instantiate_all` stays eager).
- The `EditorConfiguration` object / `onDidChangeFast` (options stay a
  value snapshot on `Viewer`).
- The keyboard path (root `keydown` listener stays; no hidden textarea).
- The construct/`attach` split itself (Monaco takes the container at
  construction). Track D changes what `attach` *owns*, not the split.
- Injected-text reprojection granularity (whole-document reproject stays).
- `CursorContext`'s member shape (Monaco carries
  `{model, viewModel, coordinatesConverter, cursorConfig}`,
  `cursorContext.ts:13-24`; the viewer's carries only the converter). Track
  B moves ownership only; the context-shape gap stays recorded here.

Recommended landing order: **A → B → C → D**. A and B are DOM-free
ownership moves fully validated by the existing js+native suites; C is a
large but behavior-preserving state relocation; D is the only track with
observable DOM behavior change (the view is rebuilt per model) and lands
last on a stable base. Each track is independently `just check` /
`just test` / `just test-browser` green.

---

## Track A — `ViewLayout` moves into `ViewModel`

### The divergence

`viewModelImpl.ts:126` creates the layout inside the `ViewModel`
constructor — `this.viewLayout = this._register(new ViewLayout(...))` —
so "new model ⇒ fresh scroll state" is structural. The viewer constructs
`ViewLayout` in `Viewer::Viewer` (`viewer.mbt:298`) before any model
exists, keeps it forever, and *simulates* Monaco's semantics by manually
scrolling to the origin in `set_current_model` (`viewer.mbt:628-630`).
Every scroll/reveal/read API reads `self.view_layout` directly (~78
references across `viewer.mbt`, `public_read_api.mbt` (16),
`reveal.mbt` (13), `input.mbt` (8), `view_host.mbt` (6),
`viewer_options.mbt`, `view_zones_host.mbt`, `controller_host.mbt`,
`content_hover_widget_host.mbt`, `editor_events.mbt`,
`attach_model.mbt`, plus tests).

### Goal

`ViewModel` owns a `pub view_layout : @view_layout.ViewLayout` field
created in `ViewModel::with_options` (mirroring
`public readonly viewLayout`, `viewModelImpl.ts:64`), constructed in
Monaco's member order (after `_lines`/converter and the cursor —
`viewModelImpl.ts:122-126`). The `Viewer.view_layout` field is deleted;
access becomes `view_model.view_layout`, and every viewer API that touches
layout adopts Monaco's **no-model behavior** instead of relying on an
always-present layout.

### Why this is bounded

- `viewer/common/view_model` **already imports**
  `viewer/common/view_layout` (`view_model/moon.pkg`) — no new edge, no
  cycle. Both packages are multi-target; DOM-freeness is unaffected.
- `ViewLayout::new(line_height~, line_count?)` needs only values the
  `ViewModelOptions` already carry (`font_info.line_height`) plus the
  projected line count the `ViewModel` owns.
- The ~78 call sites are mechanical rewrites; the only *semantic* work is
  the no-model guards and the pre-model dimensions holder (below).

### Findings the plan relies on (verified)

- Monaco's no-model returns, to copy exactly: `getScrollTop()` → `-1`
  (`codeEditorWidget.ts:996-1000`), `setScrollTop()` → no-op
  (`:1014-1017`), `saveViewState()` → `null` (`:1038-1041`). Each ported
  getter/setter in `public_read_api.mbt` / `viewer.mbt` must be read from
  the widget source at execution time and given that exact no-model value —
  do not invent defaults. `save_view_state` changes signature to
  `ViewerViewState?` (public API; per the strict-Monaco-subset policy the
  nullable return *is* the faithful shape).
- Editor **dimensions** do not belong to Monaco's `ViewLayout`: it reads
  layout info from the configuration (`viewLayout.ts` pulls
  `EditorOption.layoutInfo`; the container observer lives in
  `editorConfiguration.ts`). The viewer currently stores the measured box
  in `view_layout.dimensions()` and reads it pre-model in `update_options`
  (`viewer.mbt:487-489`, soft-wrap column) and `measure`. Track A therefore
  adds a Viewer-owned measured-dimensions holder (the `layoutInfo` role) so
  measuring and wrap-column math work with no model; the per-model
  `ViewLayout` is seeded from it at construction and updated on measure.
- `set_current_model`'s manual origin scroll (`viewer.mbt:628-630`) and
  `clear_current_model`'s (`:874-876`) become dead once the layout is
  per-model — delete them and the "Monaco's `_attachModel` starts the
  fresh view at the origin" comment (resolved-deviation comments do not
  stay).

### Phases

1. **Inventory the 78 references.** Classify each `self.view_layout` site:
   *addressing* (reads/writes layout state — reroute through
   `view_model.view_layout` behind a model guard) vs *dimensions* (reads
   the measured box — reroute to the new Viewer-owned holder). Record the
   classification in this file before code moves. For every public API in
   the addressing class, paste Monaco's no-model return from
   `codeEditorWidget.ts` next to it.

   **Classification (recorded 2026-07-08, executed).** *Dimensions* sites
   (reroute to the Viewer-owned measured holder — Monaco keeps these in
   `EditorOption.layoutInfo`, not in `ViewLayout`):
   `viewer.mbt` `update_options` (`dimensions().width` → wrap column),
   `input.mbt` `measure` (`set_viewport_size` — writes the holder and the
   live per-model layout), `input.mbt` `sync_content_width` (soft-wrap
   branch reads the measured content width),
   `public_read_api.mbt` `get_layout_info` (width/height — Monaco's
   `getLayoutInfo` reads configuration and does not gate on a model),
   `test_viewer_wbtest.mbt` `test_set_viewport`. Every other production
   site is *addressing* and moved behind a `view_model` guard:
   - `viewer.mbt`: `save_view_state` → `null` (`cew:1038-1041`),
     `restore_view_state` → no-op (`cew:1052`), `set_scroll_top` /
     `set_scroll_left` / `set_scroll_position` → no-op
     (`cew:1014,1003,1025`), private `scroll_by_lines` /
     `scroll_by_pages` / `scroll_home` / `scroll_end` → no-op (keyboard
     scroll paths; Monaco's scroll commands require a view model),
     `set_current_model` / `clear_current_model` origin scrolls →
     **deleted** (per-model layout starts at the origin structurally).
   - `public_read_api.mbt`: `get_visible_ranges` → `[]` (`cew:563`),
     `get_visible_ranges_plus_viewport_above_below` → `[]` (`cew:570`;
     viewport height is layout state, `vmi` reads the view layout),
     `get_line_height_for_position` → `-1` (`cew:623`),
     `get_content_width` / `get_scroll_width` / `get_scroll_left` /
     `get_content_height` / `get_scroll_height` / `get_scroll_top` → `-1`
     (`cew:963-1001`), `get_vertical_offset_for_position` /
     `_after_position` → `-1` (`cew:593-621`),
     `get_scrolled_visible_position` → `null` (`cew:1668`).
   - `reveal.mbt`: `send_reveal_range` (already model-guarded, `cew:685`),
     `flush_horizontal_reveal` (guarded; a pending request cannot survive
     detach — `horizontal_reveal_request` is cleared with the model).
   - `input.mbt`: `refresh_font_info` line-height write,
     `sync_content_width` content-width write, `view_metrics` (signature
     now takes the `ViewModel`).
   - `view_host.mbt`: `flush_render` render args (inside the
     `Some(view_model)` arm), the coalesced scroll-event block (no event
     without a model — Monaco's `onDidScrollChange` relays the live
     view layout's events), `synced_window`.
   - `view_zones_host.mbt`: `normalize_browser_view_zones` (line count),
     `sync_view_zones_with_layout` (no-op without a model; zones re-sync
     at the next attach via `apply_view_model_layout`).
   - `controller_host.mbt`: the `PointerHandlerHelper.view_layout` closure
     becomes `() -> ViewLayout?` (`None` with no model — Monaco's pointer
     handler only exists while a view does); `hit_test_at`.
   - `content_hover_widget_host.mbt`: the widget-host `line_height`
     closure reads `font_info.line_height` (Monaco reads
     `EditorOption.lineHeight`, configuration not layout);
     `scrolled_visible_position_top` (guarded, `0.0` fallback preserved).
   - `attach_model.mbt`: `apply_view_model_layout` `set_line_count` (the
     view model is a parameter; `attach_model` now stores
     `view_model`/`text_model` before calling it so the guarded helpers
     see the new model).
2. **Add the dimensions holder.** `Viewer` gains the measured
   width/height (written by `measure`, read by
   `soft_wrap_column_for_content_width` and layout construction). No
   behavior change yet.
3. **Move construction.** `ViewModel::with_options` creates
   `view_layout` (Monaco order, `viewModelImpl.ts:122-126`); delete
   `Viewer.view_layout`; rewrite all sites; apply the no-model returns;
   delete the manual origin-scroll code and its comments.
4. **Update tests.** `public_read_api_wbtest` / `reveal_wbtest` /
   `test_viewer_wbtest` construct or read layout directly — update to the
   per-model shape and add no-model cases pinning the Monaco return values.

### Track A validation

- `just check` + `moon test --target all` green per phase;
  `just test-browser` after Phase 3 (scroll, reveal, wheel, and view-zone
  positions all flow through the moved layout — the view-axis regressions
  history says only the browser suite catches these).
- New no-model unit cases: `get_scroll_top` with no model returns Monaco's
  value; `set_scroll_top` no-ops; `save_view_state` returns `None`;
  `set_model` twice shows fresh origin scroll without the manual reset.

---

## Track B — `CursorsController` moves into `ViewModel`

### The divergence

`viewModelImpl.ts:124`:
`this._cursor = this._register(new CursorsController(model, this, this.coordinatesConverter, this.cursorConfig))` —
the cursor is a `ViewModel` member, created between the lines projection
and the layout, and re-pointed internally on reflow
(`this._cursor.onLineMappingChanged(...)`, `viewModelImpl.ts:287`). The
viewer holds `cursor : @cursor.CursorsController?` on `Viewer`
(`viewer.mbt:48`, 10 references across `viewer.mbt`, `selection.mbt`,
`public_read_api.mbt`) and re-points it by hand
(`refresh_cursor_context`, `selection.mbt:151`) from three call sites.

### The import cycle, and the faithful fix

`viewer/common/cursor` imports `viewer/common/view_model` today for
exactly two names: `@view_model.Selection` (5 uses) and
`@view_model.ProjectedCoordinatesConverter` (2 uses). Making `ViewModel`
own the cursor requires the reverse edge (`view_model → cursor`), so the
existing edge must break first. Monaco breaks the same cycle with
interface-only files, and both fixes are faithful *filing* corrections:

- **`Selection` is misfiled.** Monaco files it in
  `vs/editor/common/core/selection.ts`; the viewer keeps it in
  `view_model/selection.mbt`. Move `Selection` to `viewer/common/core`
  (the `core/` mirror package, which `cursor` may import cycle-free).
  All `@view_model.Selection` consumers (root viewer events, cursor,
  selections view part, tests — enumerate by grep at execution) switch to
  `@core.Selection`. No re-export facade (Decision precedent:
  D2-REVERSED / avoid facade ceremony).
- **The converter interface needs a home below both packages.** Monaco's
  `ICoordinatesConverter` is an interface-only file at
  `vs/editor/common/coordinatesConverter.ts`; the viewer already has the
  trait (`pub(open) trait CoordinatesConverter`, `view_model.mbt:8`) but
  in the wrong package. Move the trait to `viewer/common/core`, keep
  `ProjectedCoordinatesConverter` in `view_model` implementing it, and
  make `CursorContext` hold `&CoordinatesConverter`
  (`cursor_context.mbt:8` currently names the concrete type). *Deviation
  note:* Monaco files the interface at `editor/common/` root, but the
  directory-mirror's residual `viewer/common` package already imports
  `view_model` (`viewer/common/moon.pkg`) and so sits **above** it —
  `viewer/common/core` is the nearest package below both; record this as
  a filing deviation in the mirror docs.

After both moves: `cursor` imports `{base_common, core}` only;
`view_model` adds `{cursor, core}`; the cycle is gone and the ownership
edge matches Monaco's.

### Goal

`ViewModel` owns `cursor : @cursor.CursorsController`, created at
`viewModelImpl.ts:124`'s position in `with_options`. `Viewer.cursor` is
deleted; selection reads route through the view model
(`get_selections`, copy, selection glue). `refresh_cursor_context`
disappears: the `ViewModel` re-points its own cursor inside
`on_configuration_changed` / `on_did_change_content_or_injected_text`
(the `_cursor.onLineMappingChanged` analog, `viewModelImpl.ts:287`),
deleting all three manual call sites.

### What does not move

Public cursor **events** keep firing from the `Viewer` glue: Monaco routes
`CursorStateChanged` through the view-model event dispatcher up to the
widget (`codeEditorWidget.ts:1812-1858`), and the dispatcher is out of
scope. Only the state's *storage and re-pointing* move.

### Phases

1. **Break the cycle.** Move `Selection` → `viewer/common/core`
   (mechanical rename sweep), move the `CoordinatesConverter` trait →
   `viewer/common/core`, switch `CursorContext` to the trait. Green in
   isolation — no ownership change yet.
2. **Move the cursor.** `with_options` creates the controller
   (Monaco order); delete `Viewer.cursor` and `refresh_cursor_context`;
   `ViewModel`'s reflow paths re-point the cursor internally; rewrite the
   10 `self.cursor` sites (`match` on `view_model` instead).
3. **Tests.** `cursor_behavior_wbtest` / `selection_clipboard_wbtest` /
   selection browser smoke stay green unchanged (behavior-preserving);
   add one wbtest pinning that a wrapping-width change re-projects the
   selection *without* any Viewer-side re-point call.

### Track B validation

- `just check` + `moon test --target all` per phase (Phase 1 exercises the
  native build's cycle/target discipline);
  `just test-browser` after Phase 2 (mouse selection + copy flows).

---

## Track C — Feature state moves off `Viewer` into controller instances

### The divergence

Monaco keeps per-feature state inside per-editor contribution controllers
reached via `editor.getContribution(id)`; the widget itself holds only the
`_contributions` map. The viewer instantiates contributions
(`editor_extensions.mbt`, `instantiate_all`) but their state leaked onto
`Viewer` as ~30 flattened fields. `docs/architecture.md` ("Controller
access") already documents the target pattern — a per-contrib instance
table `Map[String, Controller]` keyed by `editor_id` (the WeakMap/
`getContribution` analog) — and names this exact situation: "most feature
state still lives as `Viewer` fields rather than controller values". This
track is that pattern's first real consumer.

### Inventory (fields leaving `Viewer`, with their Monaco homes)

Per the field comments in `viewer.mbt` (source mapping already recorded
there; re-verify against `contentHoverController.ts` at execution):

- **`ContentHoverController`** (new struct, filed in
  `viewer/contrib/hover/browser` — the mirror package for
  `editor/contrib/hover/browser`, js-only, newly populated; this revises
  the architecture note that hover's browser tier stays empty):
  `hover` (the shown-hover state), `hover_react_pending` /
  `hover_react_token` / `hover_pending_target`
  (`_reactToEditorMouseMoveRunner`), `hover_settings` (`_hoverSettings`),
  `hover_keep_open` (`shouldKeepOpenOnEditorMouseMoveOrLeave`),
  `hover_ignore_mouse_events` (`_ignoreMouseEvents`),
  `hover_mouse_posx` / `hover_mouse_posy` / `hover_last_modifiers`
  (`_mouseMoveEvent`), `hover_mouse_closer`
  (`RenderedContentHover.isMouseGettingCloser`), `hover_notified_token`,
  `hover_decoration_ids` / `hover_decoration_range` (the hover-owned
  decorations collection).
- **Agent-feedback controllers** (two structs in the existing
  `viewer/contrib/agent_feedback/browser`, named after their sources
  `agentFeedbackEditorInputContribution` /
  `AgentFeedbackEditorWidgetContribution`): the 13 `agent_feedback_*`
  fields (`viewer.mbt:114-133`), split per the two source contributions
  exactly as the existing field comments already group them.
- **`InlayHintsController`** (struct in the root package next to
  `inlay_hints_host.mbt` glue): `inlay_hints`,
  `inlay_hint_decoration_ids` ("Monaco `InlayHintsController`'s
  per-editor decoration collection" per the field comment).

**Stays on `Viewer`** (widget-owned in Monaco too): emitters, `services`,
`options`, `font_info`, `editor_id`, `contributions`, `container`,
`view`/`view_model`/`text_model` (Track D restructures these),
render-scheduling flags, `content_generation` /
`decorations_generation`, `editor_has_focus`, `mouse_handler`,
`last_mouse_buttons`, `last_scroll_event`, `view_zones`,
`horizontal_reveal_request` (a `ViewLines` field in Monaco — recorded as
a remaining filing gap, not moved here), `rendered_window`,
`model_decorations_subscription`.

### Mechanics (the MoonBit shape)

Each controller package owns a module-level instance table
`Map[String, <Controller>]` keyed by `viewer.get_id()` plus a
`get(editor_id)` accessor — copied from the architecture doc's documented
pattern, not invented. The contribution ctor (registered in
`hover_contribution.mbt` / the agent-feedback registration) constructs the
controller and inserts it; the contribution's `dispose` removes it. The
`Viewer::` glue methods in `editor_events.mbt` (75 references),
`content_hover_widget_host.mbt`, `agent_feedback_host.mbt`,
`agent_feedback_widgets_host.mbt`, and `inlay_hints_host.mbt` keep their
dispatch role (the foreign-method rule pins them to the root package) but
read/write state through the controller instance. Logic that touches no
`Viewer` capability moves onto controller methods in the controller's own
package; logic that needs `Viewer` stays as glue.

Model-swap resets currently inlined in `set_current_model` /
`clear_current_model` (hover ids, feedback ids, widget teardown —
`viewer.mbt:589-596,861-865`) become controller methods the swap path
calls — after Track D, via the detach/attach seam.

### Phases

1. **Hover.** Introduce `ContentHoverController` + instance table in
   `viewer/contrib/hover/browser`; move the 14 fields; rewrite the glue.
   Largest single step (75 refs in `editor_events.mbt`) but purely
   mechanical; land alone.
2. **Agent-feedback.** Two controller structs; move the 13 fields; the
   existing `rebuild_agent_feedback_widgets` / reset paths become
   controller methods.
3. **Inlay hints.** Move the 2 fields into an `InlayHintsController`.
4. **Docs.** Update `docs/architecture.md`'s "Controller access" paragraph
   (the pattern now has real consumers) and the three-tier-mirror note
   that `contrib/hover/browser` is now populated; delete the `viewer.mbt`
   field-block comments that described the flattening.

### Track C validation

- Behavior-preserving: the full hover wbtest battery
  (`hover_*_wbtest`), agent-feedback browser suite, and inlay-hint
  wbtests stay green **unchanged** — any test edit beyond import paths is
  a red flag that behavior moved.
- `just test-browser` after each phase (hover show/hide/sticky, feedback
  gutter + bubbles are browser-covered).
- `scripts/check-architecture.mbtx` passes: the new
  `viewer/contrib/hover/browser` package declares
  `supported_targets = "js"`.

---

## Track D — Per-model `View` lifecycle behind one `ModelData`

### The divergence

Monaco (`codeEditorWidget.ts`): `setModel` → `_detachModel()` then
`_attachModel(model)` (`:526-527`). `_attachModel(null)` just nulls
`_modelData` (`:1751-1754`). With a model it builds the `ViewModel`
(`:1764`), then the `View` (`_createView`, `:1889,1923-2006`), appends the
view's DOM (`:1891`), **re-adds every registered content/overlay/glyph
widget to the new view** (`:1893-1909`), forces a first render (`:1911`),
stamps `data-uri` (`:1912`) and `data-mode-id` (`:1758`), and bundles
everything into `ModelData { model, viewModel, view, hasRealView,
listenersToRemove, attachedView }` (`:2123`) whose `dispose()` removes the
listeners and disposes view then view model (`:2133-2141`).
`_detachModel` disposes the bundle and removes the view's DOM node
(`:2019,2025-2027`); `_postDetachModelCleanup` sweeps this editor's
decorations off the outgoing model by owner id (`:2008-2010`).

The viewer instead: one `View` built in `attach` (`viewer.mbt:515-542`),
input hooked once, and three independent options
(`text_model` / `view_model` / `view`) that can in principle disagree.

### Goal

- A `priv struct ModelData { model, view_model, view, listeners_to_remove }`
  replaces the separate `text_model` / `view_model` / `view` (+
  `rendered_window` stays alongside) — one nullable field, states legal by
  construction. `has_real_view` is N-A (the viewer has no
  shadow-widget mode); `attached_view` is N-A (no attached-view
  protocol).
- `set_model` becomes detach-then-attach: dispose listeners
  (`model_decorations_subscription` moves into `listeners_to_remove`),
  dispose the view (removing its DOM subtree from the container), drop the
  view model, sweep this editor's owner-id decorations off the outgoing
  model (the `_postDetachModelCleanup` analog — replacing today's
  piecemeal id clearing, which Track C already moved into controllers);
  then build the new `ViewModel`, build a new `View`, append, re-add
  widgets, hook input, render.
- `attach(host)` shrinks to: store `container`, own the no-model
  placeholder. *Deviation note:* Monaco has no no-model view at all (its
  `placeholder` option is the empty-*model* `PlaceholderTextContribution`);
  the viewer's no-model placeholder is an existing option whose behavior
  stays — only its DOM ownership moves from `View::render_empty` to a
  Viewer-owned element in the container. `View::render_empty` and
  `message_text` are then deleted from `View`.
- Faithful extras that become natural: `data-uri` (`:1912`) and
  `data-mode-id` (`:1758,2024`) attributes on the view root.

### Per-view wiring inventory (what must re-run per view creation)

From `viewer.mbt:515-542` and `input.mbt`: theme attribute + squiggly
theme, `apply_font_info_to_view`, `hook_view_input` (fresh
`MouseHandler` — Monaco's pointer handler is view-owned, so
per-view recreation is the faithful direction; the handler stays
Viewer-built because its helper closes over `Viewer` capabilities),
focus/blur listeners (reset `editor_has_focus` on detach),
`measure_requested = true`, widget re-adds (the `:1893-1909` loop):
overlay widgets from `overlay_widgets_host` state, agent-feedback bubbles
(`rebuild_agent_feedback_widgets` is the existing precedent), view zones
re-push into the new view. The `FontMeasurements.on_did_change`
subscription stays Viewer-level (it outlives any view).

### Behavior changes to pin (not regressions — Monaco's actual behavior)

- DOM node identity changes across `set_model`: the browser harness and
  any test holding element references across a model swap must re-query.
  Audit `tests/browser/moonbit/*` for cached-node patterns first.
- Focus across `set_model`: today focus trivially survives (root
  persists); with a per-model root it is lost unless restored. Read
  Monaco's behavior from the source at execution time and copy it (do not
  decide by taste); pin it with a browser test either way.
- Pre-model / detached API behavior is already Monaco-shaped after Track A
  (`ModelData` extends the same guard to view-dependent APIs like
  `get_dom_node` — Monaco returns the view's node only while attached… 
  verify against the widget source and copy).

### Phases

1. **Introduce `ModelData`.** Mechanical: fold the three options + the
   decorations subscription into the struct with a `dispose`; no lifecycle
   change yet (view still long-lived, stored outside the bundle
   temporarily). All `match (self.view_model, self.text_model)` sites
   collapse to one guard.
2. **Move the `View` into `ModelData`.** `set_model` detach/attach per the
   Monaco sequence above; `attach` shrinks to container + placeholder;
   per-view wiring runs in the attach path; owner-id decoration sweep on
   detach; `data-uri` / `data-mode-id` stamped.
3. **Browser-test pass.** Fix cached-node patterns; add the focus-across-
   swap spec; add a two-model swap spec asserting the old view's DOM is
   gone from the container and widgets/zones re-appear on the new view.
4. **Docs.** Update `docs/architecture.md` (assembly description, the
   root-package bullet), `viewer/pkg.generated.mbti` regeneration
   (`save_view_state` signature changed in Track A; anything Track D
   touches), and delete the now-stale lifecycle deviation comments
   (`get_container_dom_node`'s "Monaco receives the container at
   construction" note stays — that split is out of scope and still true).

### Track D validation

- `just test-browser` is the gate: full suite green, plus the new swap and
  focus specs. The perf browser package
  (`tests/browser/moonbit/perf`) runs before/after — `set_model` now pays
  a DOM rebuild (Monaco's cost model; confirm no pathological regression,
  not zero change).
- `just check` verifies no new architecture-rule violations
  (`browser/view` still does not import the root package — `ModelData`
  lives in the root package with the other `Viewer` glue).

---

## Combined Exit Criteria

- **Track A:** `ViewModel` owns `view_layout` (Monaco member order);
  `Viewer.view_layout` is gone; no-model API returns match
  `codeEditorWidget.ts` line-for-line; the manual origin-scroll reset and
  its comment are deleted; a fresh model starts at the origin
  structurally.
- **Track B:** `Selection` and the `CoordinatesConverter` trait live in
  `viewer/common/core`; `viewer/common/cursor` no longer imports
  `view_model`; `ViewModel` owns the cursor and re-points it internally on
  reflow; `refresh_cursor_context` and `Viewer.cursor` are gone.
- **Track C:** zero `hover_*` / `agent_feedback_*` / `inlay_hint*` state
  fields remain on `Viewer`; the instance-table pattern from
  `docs/architecture.md` has three real consumers;
  `viewer/contrib/hover/browser` exists, js-only, and the architecture
  doc's mirror section is updated.
- **Track D:** one `model_data : ModelData?` field; `set_model` is
  detach-then-attach with per-model `View` DOM; the widget re-add loop,
  owner-id decoration sweep, and `data-uri`/`data-mode-id` stamps exist;
  browser specs pin swap and focus behavior.
- All four: `just check` / `moon test --target all` /
  `just test-browser` green; every deleted deviation comment corresponds
  to a closed deviation (none deleted for still-open ones); the remaining
  *deliberate* divergences (the out-of-scope list above, the
  `horizontal_reveal_request` filing gap, the `CursorContext` shape, the
  `viewer/common/core` interface-filing note) are recorded, dated, and
  cited where they live.
