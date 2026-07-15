# Warning, Browser-FFI, and Dead-Surface Cleanup — 2026-07-15 Addendum

Status: implemented and fully validated on 2026-07-15.

This is a cross-plan cleanup addendum. It supersedes only the current local
retention decisions listed below. The implemented plans and frozen ledgers in
`viewer-render-invalidation-parity.md`, `viewer-tokenization-parity.md`,
`text-model-tokenization-package-merge*.md`, and
`browser-view-package-consolidation-gate-a-*.md` remain immutable historical
evidence of what was reviewed and landed at the time.

## Decision Rule

A source-shaped member stays in product code only when it has a current
producer and consumer, owns retained behavior or state, crosses a supported
package boundary, or is the explicit implementation point for a deferred
feature. A member used only by white-box tests or protected only by a local
warning suppression is not a product contract.

Deleting such a member does not claim that the corresponding Monaco behavior
does not exist. Its status at the current readonly viewer seam becomes one of:

- `N-A (no current producer/consumer)` when the product has no applicable
  path for the behavior;
- `DEFERRED (named consumer absent)` when a known future feature would own the
  behavior.

Reintroducing one of these clusters requires landing its consumer and
branch-derived tests together; source shape alone is not sufficient.

## Warning Boundary

- Redundant MoonBit annotations are removed, including redundant constructor
  qualification reported by warning 73. Executable manifests use current
  `pkgtype(kind: "executable")` syntax.
- `unused_value`, `unused_field`, and `struct_never_constructed` suppressions
  are removed with the unconsumed declarations they protected. Tests that only
  manufactured consumers for those declarations are removed with them.
- The narrow suppression on
  `viewer/common/diff/default_lines_diff_computer.mbt` remains `N-A (compiler
  parser distinction)`: its qualified empty-struct constructor is required to
  distinguish the value from an empty `Map`, despite warning 73. It is not
  dead-code suppression.

## Canonical Browser FFI

`base/browser/{runtime,dom_primitives}.mbt` own browser primitives whose
semantics and signatures are identical across callers:

| Primitive | Current boundary | Disposition |
| --- | --- | --- |
| wall clock (`Date.now`) | mouse/controller/scrollbar timestamps | one `wall_clock_now_ms` owner in `base/browser` |
| monotonic clock (`performance.now`, wall-clock fallback) | root render scheduling | one `monotonic_now_ms` owner in `base/browser` |
| microtask scheduling | root services and workbench delivery | one `queue_microtask` owner in `base/browser` |
| cancellable timeout | root, scrollbar, font measurement, and deferred theme work | one disposable `schedule_timeout` owner in `base/browser`; raw handle ownership stays private |
| device-pixel ratio | browser font measurement and cursor snapping | one `device_pixel_ratio` owner in `base/browser` |
| layout size | plain `offsetWidth` / `offsetHeight` reads | `element_offset_width` / `element_offset_height`; transformed rectangle reads stay separate |
| inline style | plain `style.setProperty` writes | one `set_style_property` owner; cached/whole-style writers stay with their owners |
| element removal | idempotent attached-element removal | one `remove_element` owner with a narrow-DOM parent fallback |
| focus and containment | prevent-scroll focus, element containment, exact/descendant active-element checks | `focus_prevent_scroll`, `element_contains`, `element_has_focus`, and `element_contains_active_element` |

The consumer migration is bounded to `base/browser/mouse_event.mbt`, root
`viewer` scheduling/event/input files, `viewer/browser/{config,controller,view}`,
`viewer/ui/scrollbar`, the hover and agent-feedback browser contributions, and
`internal/shell/workbench`; package manifests change only to import that owner.

The following near-duplicates remain deliberately local:

- `requestAnimationFrame` and idle adapters are `N-A (different scheduling
  semantics)`, not timeout aliases;
- the idle fallback's `target.Date.now()` is `N-A (injected realm identity)`;
- rectangle, body/client-area, owner-window scroll, and page-position helpers
  are `N-A for consolidation (different geometry spaces and fallbacks)`;
- `CachedDomNode` keeps only its harness metrics recorder after delegating the
  actual property write; whole-style writers remain
  `N-A for consolidation (replacement semantics)`;
- `ViewLines` keeps an injectable disposable scheduler callback for focused
  tests, while its production default uses `base/browser.schedule_timeout`;
  this is a capability seam, not duplicate FFI.

## Browser View Surface

The browser `ViewEvent` union now contains only events emitted by the current
Viewer and consumed by at least one current view part:

```text
configuration, cursor-state, decorations, flush, focus,
line-mapping, scroll, tokens, zones
```

This supersedes the local retention claims for the following historical
`viewer-render-invalidation-parity.md` rows without rewriting them:

| Historical rows / local surface | Current disposition |
| --- | --- |
| `VE-001..002`, `VE-015..018` composition declarations | `N-A (no textarea/edit-context producer)` |
| `VE-009..011`, `VE-042..053` incremental line changed/deleted/inserted events and handlers | `N-A (readonly model exposes full flush/mapping, not incremental edit events)` |
| `VE-072..075` theme event | `N-A (no typed theme-event producer; current styling is direct CSS/root state)` |
| `VE-025..027` model selection and reason inside the browser view event | `N-A (root public cursor delivery owns them; view parts consume projected selections only)` |
| `VE-029..034` decoration detail flags | `N-A (implemented parts consume invalidation presence; minimap/overview/glyph-detail consumers are absent)` |
| `VE-056..058` scroll left/height/top values inside the browser view event | `N-A (root public scroll delivery owns full values; view parts consume width plus changed flags)` |

Other removed browser-view shape is bounded as follows:

| Local surface | Current disposition |
| --- | --- |
| `ContentWidgetHandle.suppress_mouse_down`, `ContentWidgets::should_suppress_mouse_down_on_widget`, and the controller callback | `N-A (no content-widget mouse-suppression consumer)` |
| `ContentWidgets::remove_widget` | `N-A (registrations live for one View lifetime; disposing the View removes the complete subtree)` |
| `ViewLines::on_lines_{changed,deleted,inserted}` and corresponding `ViewZones` hooks | `N-A (incremental view-line event producer absent)` |
| `View::with_view_event_batch`, multi-event forwarding helpers, cache-reset wrappers, selection measurement compatibility wrapper, and test-only geometry carriers | `N-A (no production caller; retained paths call the owning primitive directly)` |
| duplicate `View.lines_content`, overlay child fields, cursor focus mirror, `ViewLines.line_height`, and write-context fields | `N-A (the authoritative owner is already retained)` |
| empty `PartFingerprints` namespace struct | `N-A (static operations belong on the closed `PartFingerprint` enum)` |

The fixed DOM, render order, event FIFO/reentrancy behavior, full root public
cursor/scroll events, and observable rendering behavior remain in scope and
must not change.

## Model and Tokenization Surface

The retained tokenization path is passive token reads plus attachment-driven
visible-range and bounded background work. The following source-shaped
surfaces had no production consumer:

| Historical rows / local surface | Current disposition |
| --- | --- |
| `FNT-001..015`, `ANI-057..059`, `ANI-064..068`, `LAN-009..013`, `LAN-016`, `LAN-018`, `LAN-022`, `LAN-050`, `TPM-008..009`, `TPM-026..027`, `TPM-031`, `ASB-062..063`, and `TSB-037`, `TSB-067..068` | `DEFERRED (FontTokenDecorationsProvider and dynamic font/line-height consumers are absent)` |
| `ITM-017..021`, `TPM-028`, `TPM-048`, `ASB-056..059`, `TSB-003..005`, `TSB-038..039`, `TSB-081`, `LAN-024`, and `TMS-154..156` completion state/events | `DEFERRED (bracket-pair/background-state consumer absent; worker execution itself follows pending ranges)` |
| background-store `set_end_state` callback (`TSB-040..042`) | `DEFERRED (custom background provider/update API absent)` |
| token-part explicit-demand/inspection facade (`ITM-007..010`, `TPM-046..047`, `TPM-049..052`: `has_tokens`, reset, force, accuracy/cheapness, and conditional-tokenize) plus test-only visible-refresh/subscription wrappers | `N-A (no production caller; lifecycle and passive reads use the backend-owned path)` |
| backend explicit-demand chain and cheap-tokenization limit (`ASB-070..074`, `TSB-082..088`, `TMS-027..030`) | `N-A (removed facade was its only caller)` |
| `RangePriorityQueueImpl::{get_ranges,remove_min,add_range_and_resize,to_string}` (`TMS-087`, `TMS-089`, `TMS-092`, `TMS-095`, `TMS-107..120`) | `N-A (only tests consumed them); `min`, `delete`, and `add_range` remain for background scheduling` |
| `AttachedViews::visible_line_ranges` aggregate accessor (`ASB-006`, `ASB-009..012`) | `N-A (only tests read the aggregate); per-view state, invalidation, joining, and refresh remain` |
| `token_theme_style_block` | `N-A (production token colors are delivered by `viewer/browser/view_parts/view_lines/tokens.css`)` |
| `ViewModelDecorations::get_decorations_on_line` | `N-A (viewport/range queries are the production consumers)` |

The exact-label `UTM-020` two-Viewer projection regression remains `TESTED`.
Its cursor callback now creates a temporary attached visible-range demand
instead of calling the removed `tokenize_if_cheap` facade; projection freshness
and passive-read assertions remain unchanged.

The three applicable `model.modes.test.ts` exact-label cases remain in the
reference suite through a white-box adapter composed from the retained
stateful-tokenizer and token-store primitives. The removed product facade is
not restored. `addRangeAndResize` and the eleven readonly-inapplicable model
edit cases remain explicit `SKIPPED` entries rather than disappearing from the
ported inventory.

`TrackingTokenizationStateStore::set_end_state`, attached-view lifecycle,
stale-generation cancellation, backend reset and visible-range refresh,
`update_tokens_until_line`, retained background range scheduling, token events,
passive line-token reads, and the static token-theme contract remain
implemented behavior. `BackgroundTokenizationStore` now carries only the
`set_tokens` capability consumed by the default worker.

## Validation Contract

The cleanup is complete only after:

```sh
moon fmt --check
moon check --target all --warn-list +73
moon info --target all
just check
just test
just build
just test-browser
```

Generated `pkg.generated.mbti` changes must contain only the intended removed
surface and the canonical `base/browser` primitives.

Landing validation completed with zero unsuppressed `+73` diagnostics:

- `just check` and `just build` passed;
- `just test` passed `1418/1418` JS and `1006/1006` native tests;
- `just test-browser` passed `83/83` Playwright tests;
- `moon info --target all` refreshed and reviewed the generated interfaces
  (with the expected notices for packages unsupported on wasm/wasm-gc and the
  native-only shell interfaces).
