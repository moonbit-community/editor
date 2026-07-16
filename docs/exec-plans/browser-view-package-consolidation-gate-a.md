# Browser View Package Consolidation — Gate A

Status: inventory ready — STOP FOR REVIEW; no implementation has started

Date: 2026-07-14

Parent plan: `browser-view-package-consolidation.md`

Oracle: checked-in reference tree

This is a documentation-only pre-implementation snapshot. No browser product
source, test, manifest, generated interface, README, CSS asset, build script,
or generated web output changed while producing it. The local browser tree is
the state at parent milestone.

## Scope and Counting Rule

The closed upstream denominator is complete `browser/view.ts`, the six
`browser/view` TypeScript units named by the parent plan, and every TypeScript
and CSS unit under `browser/viewParts`: 41 TypeScript files and 18 CSS files,
59 files total. The source contains 13,623 TypeScript lines and 505 CSS lines.
`view.ts` was added to the original plan's minimum set because scoped local
headers cite its DOM, registration, render-order, and disposal clusters.

One upstream row owns one top-level declaration; class/interface field,
property, constructor, method, getter, or setter; enum value; independently
meaningful constant; behavior-changing loop/branch/early transfer;
source-authored callback; or owned DOM node, attribute, class, CSS selector,
property, animation, or custom property. A terminal file-level `N-A` reason
does not erase its members: unsupported files retain member rows. Straight-line
assignments and loop bookkeeping stay on their owning member row.

The local declaration denominator comes from `moon ide outline` over every
production `.mbt` file. One row owns one top-level MoonBit declaration; fields
and enum cases stay with their owning declaration because the structural move
does not rewrite those bodies. Tests are a separate exact-name denominator.

| Denominator | Files/items | Lines/count |
|---|---:|---:|
| pinned upstream TypeScript | 41 | 13,623 lines |
| pinned upstream CSS | 18 | 505 lines |
| upstream parity ledger | 4,154 rows | 1,536 `TESTED` + 143 `PORTED` + 231 `N-A` + 2,244 `DEFERRED` |
| local JS-only packages | 12 | 12 manifests |
| local production MoonBit | 30 current / 31 target files | 9,323 lines |
| local production declarations | 536 | 241 public + 295 nonpublic |
| local MoonBit tests | 16 files | 118 unique tests |
| local CSS | 14 files | 2 root + 12 leaf assets |
| local package contracts | 12 READMEs | 12 generated interfaces |
| other scoped binary asset | 1 | `codicon.ttf` |

## Pinned Source Evidence

The ordered `src`-relative path, `wc -l`, and SHA-256 tab-separated manifest
below hashes to
`0a4962eaa7e96c724520c7d9c0c862981cb8d218767712b36f1fb8b82912b535`.
Every listed file was read from the checked-in submodule; directory
discovery was used only to close the file set.

| Source file | Lines | SHA-256 |
|---|---:|---|
| `browser/view.ts` | 992 | `22edb04795705b7fc8675ba40d89c448a62141201f1a16b1f20d8b26e82771e2` |
| `browser/view/dynamicViewOverlay.ts` | 15 | `334b8d784b161661c8377773d9fe7f801449a01c657a6a927c695a19e0f5265c` |
| `browser/view/renderingContext.ts` | 217 | `1f10fa65e8235e03bfcb987cd19df7aaca34cac8d73b8be3bca31b8c556e47f9` |
| `browser/view/viewLayer.ts` | 630 | `8e8fc4f816931648bcae1ebb01cf8aa67d723311f2f78bd67b649c6ef74e92ca` |
| `browser/view/viewOverlays.ts` | 268 | `93dda802411e21e3c23a3db55e416d5f4942fdf2bcfadab79b95d3cedfd4cf5e` |
| `browser/view/viewPart.ts` | 82 | `920c845a3ce6016a36f2f4762e962d9fa22c31055d6a60e1639bba9f16cdc280` |
| `browser/view/viewUserInputEvents.ts` | 119 | `aa967f421f753eac20555515e15ea89a235c9c4052afe9c8b0b541690d637c2f` |
| `browser/viewParts/blockDecorations/blockDecorations.css` | 15 | `1517cd7e4aa0417d339a55de6a8568cff1d4340459306101ab4d6bb3c2948be3` |
| `browser/viewParts/blockDecorations/blockDecorations.ts` | 120 | `795543808d121a64a52ea106d8268ad0cf58747be43d46b4236b0eaec261e360` |
| `browser/viewParts/contentWidgets/contentWidgets.ts` | 633 | `e524a6baaf256fb8e8d427a76f217cd832954bdabaf11b73e1e066b6dd50f7a6` |
| `browser/viewParts/currentLineHighlight/currentLineHighlight.css` | 28 | `05fc7e6aa0110f6c255eb3b4d91be0fad0bb57608f2af14b06b82127b2dea9cd` |
| `browser/viewParts/currentLineHighlight/currentLineHighlight.ts` | 264 | `74e10848de7ea076230aef844110f7471326581178a4f56bab2792c9f5928596` |
| `browser/viewParts/decorations/decorations.css` | 13 | `910a1e95e672eb72395e5ebaa6bcff0a96898eba9125e94713f94762bdab7863` |
| `browser/viewParts/decorations/decorations.ts` | 240 | `d5b64d806e6a617fc51d93b79cf727a0bab1eba8947c775729ed6e42c34f7452` |
| `browser/viewParts/editorScrollbar/editorScrollbar.ts` | 189 | `a1e42dc51f9f3d414e3efec87f1fb5ca2c7e4b89733914c3897daed32fdb832d` |
| `browser/viewParts/glyphMargin/glyphMargin.css` | 32 | `42cb2658283487fee6b8a8b0808de696271a123b24f0d78521cfab71ec87d52f` |
| `browser/viewParts/glyphMargin/glyphMargin.ts` | 508 | `a72f4bdb0f64957acfd53acdbae5cb95f80ad8ec6ffe0b390f1ed651027cd697` |
| `browser/viewParts/gpuMark/gpuMark.css` | 20 | `5a007cc054f44def221191cc7716ba9796f99d72b17f78bea6ca0c2785ff643d` |
| `browser/viewParts/gpuMark/gpuMark.ts` | 97 | `00c87346cb4cc8a726c9019c1ddf428c83408c39929d1f3ebcefed20333d3e03` |
| `browser/viewParts/indentGuides/indentGuides.css` | 10 | `9e8534d3c91316a94bf4a161ae7308b0e9e6bf4294eeead83848825edc29ebc0` |
| `browser/viewParts/indentGuides/indentGuides.ts` | 345 | `448ae6478f56c13972ad29ad6f63cf84372a7af1953ee81c16352367f613d8c6` |
| `browser/viewParts/lineNumbers/lineNumbers.css` | 33 | `6f9e5f9247002ca7aaad8cc734261ef50379f3dd347947af7b77e4bd74e8b48f` |
| `browser/viewParts/lineNumbers/lineNumbers.ts` | 228 | `763cfc4dec89518c644336b0b552c4f825db644a67697078a729b090225a352a` |
| `browser/viewParts/linesDecorations/linesDecorations.css` | 17 | `b62019a94802b8cf42358168f2d30bf2b8283a84257419403dd6bdf12410d05f` |
| `browser/viewParts/linesDecorations/linesDecorations.ts` | 125 | `e5ada206f3ff572f396ee9396ffee756b56e432bbb333aabf2ba9354cc9ed13f` |
| `browser/viewParts/margin/margin.css` | 8 | `f314bdf68112babf43fd67e6ae51b40df3abcdb47c6cdbef478ed82e673798f7` |
| `browser/viewParts/margin/margin.ts` | 95 | `a9ef3fce2c283301a3379bdbca178a32325b29082ed8051752525ae48153a364` |
| `browser/viewParts/marginDecorations/marginDecorations.css` | 14 | `df329935ff57eea3d2dba1d3a923e29d72175a3ae03e6fb4385c709bf514221c` |
| `browser/viewParts/marginDecorations/marginDecorations.ts` | 98 | `3cd450bc3f17b6dd630c8592cde24f8c8ba8e9870e648545b95b762e8f74fc1e` |
| `browser/viewParts/minimap/minimap.css` | 67 | `eefcf323c75957e80fe6882d5d63186fb50769d4b1c4b61ae9fc8c6d944da54d` |
| `browser/viewParts/minimap/minimap.ts` | 2,237 | `272dbae8158a4c2b9712985029dec60244e094fb1a3ccdca0d48b7ac86f2778f` |
| `browser/viewParts/minimap/minimapCharRenderer.ts` | 134 | `c47711a3201ea2da99cc67355c8c1ed0350a5f9be3e6096a963ceefc873a0db4` |
| `browser/viewParts/minimap/minimapCharRendererFactory.ts` | 168 | `534c27267294ab3fbf3372a4bdc6fb14dbf89b30a245c4eed03fb18efef33272` |
| `browser/viewParts/minimap/minimapCharSheet.ts` | 43 | `b879857381c13a9103f026c74327c146e930c7411a4fc5fa0f186f3a347f55ac` |
| `browser/viewParts/minimap/minimapPreBaked.ts` | 63 | `cd0b7dcbb7277ba3ede8467c3b8814dcc8b31888a4a5c2f204c8bdfb54b04858` |
| `browser/viewParts/overlayWidgets/overlayWidgets.css` | 8 | `f114f69d3668c20319bbf412e2078ff060698f93829dd4b749c5c74ee60a988b` |
| `browser/viewParts/overlayWidgets/overlayWidgets.ts` | 233 | `6461d6ce5bebb14b9b70fa60355ad379ab3faa6623f6bd5dcdf5edaf5a9e63a1` |
| `browser/viewParts/overviewRuler/decorationsOverviewRuler.ts` | 520 | `a7421635199f80773a480072538d629f311ad9efdaf7305d2db580bbb148e01e` |
| `browser/viewParts/overviewRuler/overviewRuler.ts` | 172 | `ffa40316b051bd042edc1cd98bf538b79ff1ac268565b83e4656f48e73f2b4d2` |
| `browser/viewParts/rulers/rulers.css` | 11 | `1ba666a0c4c37bc5e46ca11fd3f0958682cceefd6b2dcdd408b9456647c8d378` |
| `browser/viewParts/rulers/rulers.ts` | 99 | `e646e58e345c59dd6d3e0b79edfb9677c0d9c1f2c3bc2a7a4a430d696485f472` |
| `browser/viewParts/rulersGpu/rulersGpu.ts` | 80 | `a63303b2df70589a26586f3b1367ab149b7037b0c9b66e1f9ce863db4b117aeb` |
| `browser/viewParts/scrollDecoration/scrollDecoration.css` | 12 | `3262d133f93599876978b77b8dbdbabd5dd9602d4f4517618966db8632b27626` |
| `browser/viewParts/scrollDecoration/scrollDecoration.ts` | 88 | `ff5c359956c25b0077ebd61e443cc85c39ee919611f20e31552d7f8142a2d99c` |
| `browser/viewParts/selections/selections.css` | 35 | `f18c599271f8e475cbcbd7baa1d2133f7925a4f2c1b5f71e7c3dcbacb20be4fe` |
| `browser/viewParts/selections/selections.ts` | 409 | `4c36aaa9ac0e7deca07a2f66576809013df2d4b0d02f0ada8dda03da91804be6` |
| `browser/viewParts/viewCursors/viewCursor.ts` | 283 | `d7642c6f6910ff64f1deba089c14c26dceea17abd00eb30695a0695f5d0382a5` |
| `browser/viewParts/viewCursors/viewCursors.css` | 85 | `61eb3783f991266e63f49401223d7ef1e6c389816b75b20cbd871df50733b994` |
| `browser/viewParts/viewCursors/viewCursors.ts` | 417 | `b4f2e15e8600c3cf188b35bd3f99a0c8912046dd7d538f3dbb2a22fa6ffee1eb` |
| `browser/viewParts/viewLines/domReadingContext.ts` | 51 | `4a11a0a5bc68b9e9f78ab8866030c3ae06db3316daa0119f2974592de60a5ff3` |
| `browser/viewParts/viewLines/rangeUtil.ts` | 144 | `00c9a24b56214d309b53cab54cff25fe44db0124f30e9e4e85a0ce5662c7039a` |
| `browser/viewParts/viewLines/viewLine.ts` | 734 | `8ab7866695ac0138524e2ce5d5f43abb377232b694bfd115e08dc81221bf3b8d` |
| `browser/viewParts/viewLines/viewLineOptions.ts` | 66 | `b7205d06dfe7b1918d798a3c7ef99968dfb63d6d4df224e7198fd3c5c3d9c619` |
| `browser/viewParts/viewLines/viewLines.css` | 88 | `af84715e87d636aadc82a0522b27ce59309f9d9ce4dc79a4438aebc9436a406e` |
| `browser/viewParts/viewLines/viewLines.ts` | 875 | `b312dba68bbf6ebfd33f90ad2c2d6ea403f595d80bc25f82999328153517df5a` |
| `browser/viewParts/viewLinesGpu/viewLinesGpu.ts` | 797 | `e20baba486832d24a6417700d934999dfd6275c7a368440494c68b107a9aa638` |
| `browser/viewParts/viewZones/viewZones.ts` | 423 | `9cb62bb235e89f9432515ff1739987a776f2bbcf4f7819087f01373a7f0e2c77` |
| `browser/viewParts/whitespace/whitespace.css` | 9 | `d5df5813cf9552bdacab93446e4063b210ee278d6bef678fb7711537ff9339a5` |
| `browser/viewParts/whitespace/whitespace.ts` | 322 | `5fc86d1ec699fef0240e11edc6df8297e7b4f110ff8ac16ae9122e7ce6218650` |

## Review Artifact Set

This entrypoint records the structural decisions. Three exhaustive companions
carry the large mechanical denominators:

- `browser-view-package-consolidation-gate-a-upstream.md`: every pinned
  upstream member/constant/branch/early transfer/DOM/CSS atom, with a terminal
  row-local disposition;
- `browser-view-package-consolidation-gate-a-local.md`: every current local
  production and test declaration, package artifact, dependency edge, caller,
  collision, and target file;
- `browser-view-package-consolidation-gate-a-tests.md`: all 118 exact local
  test labels, branch/configuration coverage, CSS assembly order, and baseline
  hashes.

The companions are part of this Gate A review. A summary here never replaces
their rows. There are no `TODO` or bare `PASS` dispositions in an approved
artifact.

## Current Ownership and Caller Graph

The scoped package graph is closed and small:

```text
viewer/browser/view
  -> viewer/browser/view_layer
  -> all ten viewer/browser/view_parts/* packages

viewer/browser/view_parts/margin
  -> viewer/browser/view_parts/current_line_highlight

viewer/browser/view_parts/view_lines
  -> viewer/browser/view_layer
```

Exactly four packages consume a moving package from outside the target:

| Caller category | Current moving imports | Approved target rewrite |
|---|---|---|
| root `viewer` | content widgets, editor scrollbar, view lines, view zones | import only `browser/view`; preserve root API names |
| `viewer/browser/controller` | view cursors, view lines | import `browser/view`; preserve controller contracts |
| `viewer/contrib/hover/browser` | content widgets | import `browser/view`; preserve widget value contracts |
| browser component tests | content widgets | import `browser/view`; preserve the direct fixture seam |

The complete symbol/reference evidence is in the local companion. No other
package is a genuine consumer. All remaining current public declarations are
either already owned by `browser/view`, cross-package implementation seams, or
test-only seams that become white-box local after flattening.

## Target Ownership and Atomic Move Protocol

The target contains one JS-only `viewer/browser/view/moon.pkg`. The union
manifest imports only non-scoped dependencies; every `view_layer` and
`view_parts/*` package import disappears. Monaco source-unit boundaries remain
separate `.mbt` files. The 30 current production files become 31 target files:
the existing `part_fingerprints.mbt` is renamed to the parent plan's
`view_part.mbt`, and the seven-declaration `MarginViewOverlays` owner cluster
is extracted from `view_overlays.mbt` into the parent plan's `margin.mbt`.
The declaration denominator remains 536; neither file is a wrapper.

Two moves are indivisible. A one-package-at-a-time interpretation of the
parent order would create a temporary cycle:

1. `browser/view_layer` and `view_parts/view_lines` move in one commit because
   `view_lines` imports the recycler while `browser/view` imports both.
2. `view_parts/current_line_highlight` and `view_parts/margin` move in one
   commit because margin imports the shared highlight state while
   `browser/view` imports both.

The other seven leaf packages have no leaf-to-leaf edge and may move as
coherent individually validated milestones: content widgets, decorations,
editor scrollbar, overlay widgets, selections, view cursors, and view zones.
Each move includes its tests and every external caller/import rewrite. No
compatibility package or re-export survives after the final caller moves.

Mechanical relocation preserves function bodies, source ordering, event/DOM
ordering, constants, signatures, and test labels. Package qualifiers become
local names; adapter removal and visibility minimization occur only after the
relocation baseline is green. A pre-existing behavior gap remains a ledgered
gap and is not filled inside a move commit.

## Collision Ledger

Flattening has exactly one production basename collision and two top-level
symbol collisions:

| Collision | Existing owners | Reviewed mechanical resolution |
|---|---|---|
| `current_line_highlight.mbt` | content highlight; margin highlight | keep the content filename; move the margin unit as `current_line_margin_highlight.mbt` |
| private `double_max` | content widgets; view zones | rename both to `content_widget_double_max` and `view_zone_double_max` during their moves |
| JS extern `set_style_property` | content widgets; view zones | rename both to `set_content_widget_style_property` and `set_view_zone_style_property` during their moves |

These are name-only changes with call-site renames in the same source unit.
They do not authorize arithmetic, FFI-body, or control-flow consolidation.
After all moves, a separate API/style milestone may deduplicate only if the
generated interface and branch tests prove it behavior-neutral.

## Visibility Rule

The current 536 production declarations include 241 public declarations and
295 nonpublic declarations. Publicity is not preserved merely because a child
package once required it.

- Declarations with a proved root-viewer, browser-controller, hover, or
  browser-component-test caller remain public for this structural plan.
- Values used only by moved source or moved tests become private.
- Public carriers retain only the construction/read access required by their
  proved external callers; representation changes are not part of relocation.
- Root `viewer.ViewZone` and `viewer.ViewZoneChangeAccessor` keep their public
  names while their owner qualification changes to `@view`.
- The later public-editor-API plan owns any further product-boundary move. This
  plan does not pre-empt it.

`moon ide analyze`, `moon ide find-references`, and the regenerated sole
`pkg.generated.mbti` are the Milestone-D gate. The complete keep/private map is
in the local companion. In particular, its literal root `View` ledger closes
21/21 methods: 18 retain proved external callers and three become private.

The same companion closes all 45 production primary `Type::new` declarations.
Each is the ordinary construction path and becomes `Type::Type` with all call
sites in the same coherent milestone. Distinct alternate factories
(`new_with_timer` and `from_*`) retain their names; this is a spelling-only API
cleanup and does not authorize constructor-body changes.

## CSS and Static-Asset Decision

`scripts/build-web.mbtx::css_sources` concatenates path-labelled sources in a
fixed order. The path is emitted into `web/dist/style.css` as a comment, so
moving identical CSS bytes would still change the generated artifact.

Gate A therefore keeps all twelve leaf CSS files at their current
`viewer/browser/view_parts/*` paths. After MoonBit source moves, those
directories are asset-only owners: their `moon.pkg`, `README.md`, generated
interface, source, and tests disappear, but CSS remains. The two root view CSS
files and `codicon.ttf` also stay at their existing paths. The build script's
ordered source list remains byte-for-byte unchanged.

Current generated baseline:

| Artifact | Lines | Bytes | SHA-256 |
|---|---:|---:|---|
| `web/dist/style.css` | 2,066 | 56,378 | `bcf27861211e6731f0208a756946f9d1f2110c1e8c24bc936cbe5d5d76d66599` |

Every CSS-affecting milestone runs the build and compares this exact hash,
line count, byte count, source-path comments, and `css_sources` order. A
difference stops the move; CSS parity work is outside this structural plan.

## Preserved Behavior and Terminal Deferrals

The consolidation preserves the current product, including its already
reviewed seam-based reductions. It does not add absent view parts or broaden
configuration:

- `view.ts` public widget contracts, controller/edit-context ownership, GPU
  rendering, accessibility/input, and unsupported-part construction remain
  row-local deferrals where the current readonly product lacks those owners;
- block decorations, GPU mark, indent guides, margin decorations, minimap,
  overview rulers, rulers/GPU rulers, scroll decoration, GPU view lines, and
  whitespace overlay remain `DEFERRED` source units; GlyphMargin widget/UI
  ownership is deferred while its margin-decoration data/dedup subset remains
  separately `TESTED` in `common/view_model`;
- GPU rendering/query paths, cursor blinking and multicursor, overlay-widget
  preference placement, non-`on` line-number modes, fixed/external-overflow
  content widgets, and WebKit/fast-line strategies remain their existing
  row-local deferrals;
- exact upstream CSS selectors/properties absent from local assets remain
  explicit CSS gaps; unchanged local CSS output is the relocation oracle;
- controller, mouse handler, model, view model, layout, and root public-editor
  ownership remain outside this move.

The upstream companion distinguishes present source-shaped behavior from
these gaps row by row. A represented filename alone is not parity evidence.

## Mechanical Validation Protocol

Before the first move, capture the complete current baselines from the tests
companion. After each coherent group:

```sh
moon check --target js
moon test --target js <moved white-box files>
just check
```

At CSS/closeout milestones, additionally run `just build` and compare the
exact generated CSS baseline. Final exit additionally requires:

```sh
moon check --target all
just test
just test-browser
```

The 118 exact local tests move without renaming or denominator loss. Branch
and behavior-variable coverage, browser scenarios, and known gaps are in the
tests companion. Green repository checks do not replace the upstream and
local row reconciliation.

## Gate A Review Decisions Requested

Approve or revise these decisions before any browser product/manifest move:

1. The complete scope is 59 upstream files / 4,154 parity rows plus 784 local
   declarations (536 production + 118 named tests + 130 test helpers), 14 CSS
   files, 36 package contract/artifact files, and the codicon font; the
   companion ledgers are the authoritative denominators.
2. The target is one JS-only `viewer/browser/view` MoonBit package with
   31 source-unit files, not wrapper packages or re-exports.
3. `view_layer + view_lines` and current-line highlight + margin are atomic
   groups; the seven other leaf owners may move separately with their callers.
4. The three flattening collisions use the source-shaped mechanical names
   above; no logic is consolidated during relocation.
5. Twelve leaf CSS paths remain asset-only directories so the build list and
   generated `style.css` stay byte-identical.
6. Only caller-proven external contracts remain public; all package-only and
   moved-test seams become private after a green relocation baseline.
7. All 45 primary `Type::new` constructors become `Type::Type`; the named
   alternate factories retain their distinct spellings and behavior.
8. Existing unsupported units and behavior/CSS gaps stay terminally deferred;
   this structural plan neither fills nor hides them.

**Review gate: stop here. Do not move, rename, rewrite, or delete browser
product code, tests, manifests, interfaces, READMEs, or assets until this
entrypoint and all three companion ledgers have been explicitly approved.**
