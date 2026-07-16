# Editor Contribution Single Ownership — Gate A Local Inventory

Status: inventory ready — STOP FOR REVIEW; no product implementation has started
Date: 2026-07-14
Plan: `docs/exec-plans/editor-contribution-single-ownership.md`
Oracle: checked-in `vscode` submodule
Local baseline: recorded repository state

This companion is the complete local-state half of Gate A. It freezes the
current root registry, five registrations, four feature-local instance maps,
typed lookup graph, model/reset/disposal paths, directly relevant tests, and
package contracts. The upstream member/branch ledger and the full event-order
trace live in the sibling Gate A companions.

No product edit is authorized by this document. In particular, the two-phase
central initialization seam below must be reviewed before any global map is
removed.

## Counting boundary and reproduction

The local denominator deliberately distinguishes complete files from bounded
clusters in large files. This avoids claiming that unrelated methods in
`viewer.mbt`, `attach_model.mbt`, or `public_read_api.mbt` were inventoried for
this plan.

- Fourteen production files are read and inventoried completely: **3,621
  lines / 161 top-level declarations**.
- Six directly relevant white-box test files are read and inventoried
  completely: **1,094 lines / 52 top-level declarations = 34 tests + 18 test
  helpers**.
- Three larger production files contribute exactly **13 bounded top-level
  declarations/carriers**: eleven from `viewer.mbt`, one complete
  `Viewer::attach_model` method, and one complete
  `Viewer::get_contribution` method.
- The local structural denominator is therefore **174 production declarations
  or carriers + 52 test declarations = 226 rows**. The one `Viewer` row is
  scoped only to its `contributions` field; it is not a whole-`Viewer` field
  inventory.
- There are **5 contribution descriptions**, **5 per-Viewer central entries**,
  **4 process-global feature maps**, **12 public map API methods**
  (`attach/get/detach` × four), and **84 typed root-accessor call sites**.
- Package-contract scope is **8 package directories / 18 present artifacts**:
  eight `moon.pkg`, eight `pkg.generated.mbti`, and two READMEs. Six missing
  READMEs are recorded as absences rather than silently omitted.

The complete-file manifest hash is
`53c2651a75ebfe83a85bd494e46c6d808bd53437588b3758f96a9d9202b5d0f6`.
It is the SHA-256 of the ordered `shasum -a 256` output for the twenty complete
files listed below.

Reproduction commands:

```sh
moon ide outline <each-complete-production-or-test-file>
moon ide find-references ContentHoverController::attach
moon ide find-references ContentHoverController::get
moon ide find-references ContentHoverController::detach
# repeat for FoldingController and both AgentFeedback contribution types
moon ide find-references Viewer::get_contribution
moon ide find-references EditorContributionRegistry::instantiate_all
moon ide analyze viewer
moon ide analyze viewer/contrib/hover/browser
moon ide analyze viewer/contrib/folding/browser
moon ide analyze viewer/contrib/agent_feedback/browser
moon ide analyze viewer/contrib/quick_diff/browser
rg -n '\.(content_hover_controller|folding_controller|agent_feedback_(input|widget)_contribution)\(\)' \
  viewer tests -g '*.mbt'
rg -n '(ContentHoverController|FoldingController|AgentFeedbackEditor(Input|Widget)Contribution)::(attach|get|detach)' \
  viewer tests -g '*.mbt'
```

## Complete-file manifest

| File | Lines | SHA-256 | Scope |
|---|---:|---|---|
| `viewer/editor_extensions.mbt` | 362 | `6d8c4880d3f24807682ced0c80fade9130f8268f0edf7f114eec42bbf932cfe9` | complete production |
| `viewer/hover_contribution.mbt` | 110 | `5e75231da034ca71a7e4c0bada534ada81cf7e398d6c9370ad2712f395e49b71` | complete production |
| `viewer/folding_contribution.mbt` | 135 | `3e50eff7b5483caa0bc7bf1785da1b6afa6e5dbe3edd5c59a977ca16df006ac1` | complete production |
| `viewer/quick_diff_contribution.mbt` | 57 | `596262fe187a597f29681162293480c95733d928fc3483a53fd44cc62ac5c714` | complete production |
| `viewer/agent_feedback_host.mbt` | 699 | `e8cfd7c4b616cc135b7cc3c22e1f47543f1f152dbacb461139b841e4e213c4b8` | complete production |
| `viewer/agent_feedback_widgets_host.mbt` | 360 | `508d47a1115a2c8e677911867307f1e11a744854dfd02e29f69f905b8b737b60` | complete production |
| `viewer/editor_events.mbt` | 755 | `1f8d5320b6298303d314845c604cf24653b2d9a324cfc43136dfd29fbad709ff` | complete production |
| `viewer/folding_host.mbt` | 342 | `02dda9c96425c50b739bb25e462b3505e203862dc76fd2be047666ffec784a69` | complete production |
| `viewer/quick_diff_host.mbt` | 35 | `9b3d50ce9ab586ca77702f056c263182161163e02fae0da0538e3f33091773a3` | complete production |
| `viewer/content_hover_widget_host.mbt` | 191 | `152328ca2504bad58e5369542874ba9062a3d871e9edc841f526846b54e6720c` | complete production |
| `viewer/contrib/hover/browser/content_hover_controller.mbt` | 291 | `9e468b6d86f3f190f6d251ae1a2e61892ab2597795375aedc6908f61f0a30d0f` | complete production |
| `viewer/contrib/folding/browser/folding.mbt` | 141 | `fe52f0a4dd5df9817ece07df1b5f272fb38ba2cd5dba46fcf6c85cc3476a8103` | complete production |
| `viewer/contrib/agent_feedback/browser/agent_feedback_editor_input_contribution.mbt` | 82 | `3544ad7fb0dd86a998ad742aed7464a13fd01df0c3a916e39cdf18c664a3ffb6` | complete production |
| `viewer/contrib/agent_feedback/browser/agent_feedback_editor_widget_contribution.mbt` | 61 | `af154f38125a1d0985080d149b0e74409d4254b572b3c018f5845a31b790cd4e` | complete production |
| `viewer/editor_extensions_wbtest.mbt` | 122 | `5638c1b2f7418305adc4735363bb7d69cb2cd06ef4d5f9175907a4103e0adf3a` | complete test |
| `viewer/lifecycle_ownership_wbtest.mbt` | 187 | `fd3d588535be9ec06fb1af6709a90fe801504284920e7c200da50096b92da8e3` | complete test |
| `viewer/async_model_features_wbtest.mbt` | 476 | `2f32ceca4192ac4676ddc590aaff60d99cc275178d38d9806803b0776039ed66` | complete test |
| `viewer/agent_feedback_host_wbtest.mbt` | 107 | `d9b6d5b7de84ea6a076bfc5a9d507f5d9a7cfddc0d13b9f20cc758c828925a3a` | complete test |
| `viewer/folding_host_wbtest.mbt` | 101 | `43e727c031383729bab4c8259d7f75bf1fde05fb233ef8c78f99e15d2714ae96` | complete test |
| `viewer/quick_diff_host_wbtest.mbt` | 101 | `5268b1521a86f49934683c63c8a9b06eea25c49c6cd4aeb2f38320a3e1cb9ff4` | complete test |

The bounded-cluster carrier files are pinned separately:

| File | File lines | SHA-256 | Bounded scope only |
|---|---:|---|---|
| `viewer/viewer.mbt` | 1,103 | `cf63879fdd18a88f3c80ae0e3ff745981fb2b9ffea9dc5eb6ab1aa629eba9a83` | contribution field, construction/id/model/dispose declarations listed below |
| `viewer/attach_model.mbt` | 553 | `d2e9db61d5ab1b43e3366171a3d829c20073e95f562e354293a2ea56d6462b83` | complete `Viewer::attach_model`, lines 10–205 |
| `viewer/public_read_api.mbt` | 494 | `cd69b384d162d1b4e6a877eaf186b427c58cc42a2f0792c22acd097763a50bc2` | complete `Viewer::get_contribution`, lines 25–30 |

## Complete production declaration inventory — 161/161

Every item below is a top-level item reported by `moon ide outline`. All rows
end in one structural disposition: `PRESERVE`, `REWRITE`, `RENAME`, or
`DELETE`. Unnamed fields/variants are covered by their owning type and by the
visibility section.

### Root registry and registration files — 57 declarations

| Source file | Count | Exact outline members | Disposition |
|---|---:|---|---|
| `viewer/editor_extensions.mbt` | 19 | `:27 EditorContributionInstantiation`; `:38 EditorContribution`; `:46 EditorContributionDescription`; `:56 EditorCommand`; `:66 CoreEditorCommand`; `:80 RegisteredEditorCommand`; `:96 KeybindingRule`; `:108 EditorContributionRegistry`; `:116 register_editor_contribution`; `:128 register_editor_command`; `:167 register_core_editor_command`; `:203 CoreEditorCommand::run_editor_command`; `:227 run_core_editor_command`; `:256 run_editor_command`; `:282 instantiate_all`; `:300 dispatch_keybinding`; `:325 EditorRegistryHolder`; `:334 editor_registry_holder`; `:344 editor_registry` | `REWRITE` the contribution carrier/description/registration/instantiation clusters; `PRESERVE` all command/keybinding declarations |
| `viewer/hover_contribution.mbt` | 3 | `:14 register_hover_contribution`; `:92 Viewer::with_hover_widget`; `:105 Viewer::is_hover_focused` | registration `REWRITE`; two command helpers `PRESERVE` |
| `viewer/folding_contribution.mbt` | 6 | `:11 register_folding_contribution`; `:85 Viewer::folding_enabled`; `:93 Viewer::folding_selected_lines`; `:100 Viewer::folding_reveal_selection`; `:111 Viewer::folding_fold_action`; `:125 Viewer::folding_unfold_action` | registration `REWRITE`; action helpers `PRESERVE` |
| `viewer/quick_diff_contribution.mbt` | 1 | `:13 register_quick_diff_contribution` | `REWRITE` closure locals into one typed state |
| `viewer/agent_feedback_host.mbt` | 28 | `:27 agent_feedback_reserved_gutter_px`; `:32 agent_feedback_input_widget_id`; `:38 register_agent_feedback_contribution`; `:85 Viewer::hook_agent_feedback`; `:127 Viewer::is_current_resource`; `:141 Viewer::agent_feedback_input_contribution`; `:152 Viewer::agent_feedback_input_visible`; `:162 Viewer::agent_feedback_enabled`; `:172 Viewer::on_agent_feedback_model_changed`; `:189 Viewer::sync_agent_feedback_lane`; `:214 Viewer::on_agent_feedback_mouse_move`; `:235 Viewer::update_agent_feedback_hover_glyph`; `:287 agent_feedback_line_has_feedback`; `:301 Viewer::clear_agent_feedback_hover_glyph`; `:326 Viewer::is_agent_feedback_glyph_target`; `:339 element_class_list_contains`; `:350 Viewer::on_agent_feedback_mouse_down`; `:374 Viewer::on_agent_feedback_mouse_up`; `:392 Viewer::select_agent_feedback_line`; `:424 Viewer::on_agent_feedback_selection_changed`; `:457 Viewer::show_agent_feedback_input`; `:483 Viewer::ensure_agent_feedback_input`; `:524 Viewer::agent_feedback_has_draft`; `:534 Viewer::hide_agent_feedback_input`; `:560 Viewer::auto_hide_agent_feedback_input`; `:568 Viewer::focus_agent_feedback_input`; `:586 Viewer::add_agent_feedback_from_input`; `:625 Viewer::update_agent_feedback_input_position` | registration/hook/accessor `REWRITE`; remaining 25 declarations `PRESERVE` |

### Root typed host files — 63 declarations

| Source file | Count | Exact outline members | Disposition |
|---|---:|---|---|
| `viewer/agent_feedback_widgets_host.mbt` | 12 | `:21 register_agent_feedback_widgets_contribution`; `:53 Viewer::agent_feedback_widget_contribution`; `:65 Viewer::hook_agent_feedback_widgets`; `:94 Viewer::clear_agent_feedback_widgets`; `:116 Viewer::rebuild_agent_feedback_widgets`; `:151 Viewer::agent_feedback_widget_host`; `:207 Viewer::layout_agent_feedback_widget`; `:245 Viewer::relayout_agent_feedback_widgets`; `:255 Viewer::handle_agent_feedback_navigation`; `:286 Viewer::highlight_agent_feedback_range`; `:322 Viewer::clear_agent_feedback_highlight`; `:340 Viewer::prune_agent_feedback_reply_drafts` | registration/hook/accessor `REWRITE`; behavior helpers `PRESERVE` |
| `viewer/editor_events.mbt` | 33 | `:2 Viewer::editor_context`; `:32 Viewer::content_hover_controller`; `:46 Viewer::on_editor_mouse_move`; `:103 Viewer::react_to_editor_mouse_move`; `:127 Viewer::record_hover_pointer`; `:144 Viewer::run_hover_react`; `:163 Viewer::cancel_hover_react`; `:174 Viewer::keep_hover_open`; `:183 Viewer::dismiss_hover`; `:200 Viewer::hide_content_hover`; `:224 Viewer::mouse_on_hover_widget`; `:248 Viewer::hover_mouse_getting_closer`; `:267 Viewer::on_editor_mouse_down`; `:288 Viewer::on_editor_mouse_up`; `:300 Viewer::on_editor_mouse_leave`; `:328 Viewer::on_editor_scroll_changed`; `:345 Viewer::dispatch_editor_event`; `:378 Viewer::after_hover_transition`; `:396 new_hover_cancellation_source`; `:406 Viewer::apply_hover_effect`; `:473 Viewer::start_showing_hover_at_range`; `:509 Viewer::hover_trigger_async`; `:548 Viewer::hover_trigger_sync`; `:567 Viewer::hover_trigger_loading`; `:584 Viewer::make_hover_computer`; `:595 Viewer::compute_hover_sync`; `:623 Viewer::kick_hover_async`; `:653 Viewer::hover_async_item`; `:670 Viewer::hover_async_done`; `:686 Viewer::is_current_hover_request`; `:703 Viewer::maybe_notify_hover_resolved`; `:730 Viewer::sync_hover_decorations`; `:750 Viewer::is_current_model` | typed accessor `REWRITE`; all 32 behavior declarations `PRESERVE` |
| `viewer/folding_host.mbt` | 10 | `:16 Viewer::folding_controller`; `:24 Viewer::folding_on_model_changed`; `:55 Viewer::folding_on_configuration_changed`; `:87 Viewer::folding_range_provider`; `:113 Viewer::trigger_folding_model_changed`; `:132 Viewer::folding_on_hidden_ranges_changes`; `:157 Viewer::folding_on_cursor_position_changed`; `:188 Viewer::folding_reveal`; `:199 Viewer::folding_on_editor_mouse_down`; `:268 Viewer::folding_on_editor_mouse_up` | typed accessor `REWRITE`; behavior declarations `PRESERVE` |
| `viewer/quick_diff_host.mbt` | 1 | `:16 Viewer::quick_diff_update` | `PRESERVE` body; state argument remains the typed entry's collection |
| `viewer/content_hover_widget_host.mbt` | 7 | `:13 Viewer::sync_content_hover_widget`; `:52 Viewer::content_hover_visible`; `:58 Viewer::on_content_hover_widget_mouse_leave`; `:85 Viewer::rendered_content_hover`; `:128 Viewer::ensure_content_hover_widget`; `:170 Viewer::layout_content_hover_widget`; `:180 Viewer::scrolled_visible_position_top` | `PRESERVE`; lookup resolves through rewritten accessor |

### Feature controller files — 41 declarations

| Source file | Count | Exact outline members | Disposition |
|---|---:|---|---|
| `viewer/contrib/hover/browser/content_hover_controller.mbt` | 18 | `:8 ContentHoverController`; `:73 instances`; `:79 ContentHoverController::attach`; `:115 ::get`; `:123 ::detach`; `:137 ::begin_request`; `:153 ::cancel_request`; `:166 ::finish_request`; `:181 dispose_timer`; `:190 ::install_react_timer`; `:200 ::install_async_timer`; `:210 ::install_sync_timer`; `:220 ::install_loading_timer`; `:230 ::cancel_operation_timers`; `:246 ::cancel_all_timers`; `:257 ::cancel_react`; `:272 ::record_pointer`; `:286 ::reset_model_state` | map/get/detach `DELETE`; `attach` `RENAME` to primary constructor; remaining 14 `PRESERVE` |
| `viewer/contrib/folding/browser/folding.mbt` | 11 | `:23 FoldingLimitReporter`; `:33 SelectedLines`; `:39 to_selected_lines`; `:58 FOLDING_CONTROLLER_ID`; `:62 FoldingMouseDownInfo`; `:71 FoldingController`; `:84 folding_instances`; `:88 FoldingController::attach`; `:103 ::get`; `:109 ::detach`; `:119 ::clear_local` | map/get/detach `DELETE`; `attach` `RENAME`; remaining seven `PRESERVE` |
| `viewer/contrib/agent_feedback/browser/agent_feedback_editor_input_contribution.mbt` | 6 | `:12 AgentFeedbackEditorInputContribution`; `:40 input_instances`; `:43 ::attach`; `:63 ::get`; `:70 ::detach`; `:77 ::reset_model_state` | map/get/detach `DELETE`; `attach` `RENAME`; type/reset `PRESERVE` |
| `viewer/contrib/agent_feedback/browser/agent_feedback_editor_widget_contribution.mbt` | 6 | `:9 AgentFeedbackEditorWidgetContribution`; `:23 widget_instances`; `:27 ::attach`; `:41 ::get`; `:48 ::detach`; `:57 ::reset_model_state` | map/get/detach `DELETE`; `attach` `RENAME`; type/reset `PRESERVE` |

Reconciliation: `57 + 63 + 41 = 161`. The twelve disappearing declarations
are exactly four maps plus four `get` plus four `detach`; the four `attach`
declarations remain one-for-one as primary constructors.

## Bounded lifecycle declarations — 13/13

| Source member/cluster | Exact current responsibility | Target disposition |
|---|---|---|
| `viewer/viewer.mbt:13` `Viewer` — scoped field `:149-152 contributions` only | owns `Map[String, EditorContribution]` | `RETYPE` to the sole `Map[String, EditorContributionEntry]` instance map; no claim about the other `Viewer` fields |
| `viewer/viewer.mbt:180` `ModelData::dispose` | swap listeners → attached-view detach → View → ViewModel | `PRESERVE`; contribution reset remains before this call |
| `viewer/viewer.mbt:315` `Viewer::Viewer` | seeds empty map at `:376`, then assigns `instantiate_all` result at `:393` | `REWRITE` to two-phase insert-then-initialize |
| `viewer/viewer.mbt:451` `EditorIdCounter` | process-global monotonic integer carrier | `PRESERVE`; no feature store may rely on it after migration |
| `viewer/viewer.mbt:456` `editor_id_counter` | global counter cell | `PRESERVE` |
| `viewer/viewer.mbt:459` `next_editor_id` | increments and returns id | `PRESERVE` |
| `viewer/viewer.mbt:688` `Viewer::set_value` | same-model content update; contribution callbacks run from content event | `PRESERVE` |
| `viewer/viewer.mbt:702` `Viewer::set_model` | same-model no-op; detach → attach → focus → model event → owner-id sweep | `PRESERVE` control flow |
| `viewer/viewer.mbt:760` `Viewer::detach_model` | resets hover/input/widget state and clears widgets before `ModelData::dispose` | `REWRITE LOOKUPS ONLY`; order/body otherwise preserved |
| `viewer/viewer.mbt:877` `Viewer::get_id` | `vs.editor.ICodeEditor:<monotonic id>` key used by four globals | `PRESERVE` public id API; contribution storage stops consuming it |
| `viewer/viewer.mbt:961` `Viewer::dispose` | detach, fire `did_dispose`, dispose contributions in map order, clear map | `REWRITE DISPATCH ONLY`; order preserved |
| `viewer/attach_model.mbt:10` `Viewer::attach_model` | complete method; model/content listeners including hover invalidation | `REWRITE LOOKUP ONLY`; event order preserved |
| `viewer/public_read_api.mbt:25` `Viewer::get_contribution` | central id lookup/presence | `PRESERVE` behavior for this plan; facade decision deferred |

## Complete test declaration inventory — 52/52

These are the tests whose declarations directly exercise the registry,
controller accessors, contribution model state, or viewer lifetime. Broader
feature/reference/browser suites are enumerated in the Gate A behavior-matrix
companion; they are not falsely counted here.

| Test file | Declarations | Exact outline members | Evidence disposition |
|---|---:|---|---|
| `viewer/editor_extensions_wbtest.mbt` | 4 tests | `:6 contributions instantiate through the registry and dispose with the viewer`; `:23 keybinding dispatch honors preconditions`; `:51 keybinding rules match chords exactly`; `:70 cursor navigation registers exactly 16 primary rules after contributions` | first test `EXTEND`; other three `PRESERVE` |
| `viewer/lifecycle_ownership_wbtest.mbt` | 9 = 7 tests + 2 helpers | helpers `:4 seed_lifecycle_marker`, `:21 dispose_explicit_services`; tests `:28 preloaded markers survive detach and seed again on reattach`; `:47 set_value refresh does not acquire another shared-model lease`; `:68 distinct same-URI models retain independent decoration owners`; `:92 model disposal detaches two Viewers sharing one registration`; `:110 explicit services stay borrowed after Viewer disposal`; `:125 omitted services are owned and Viewer disposal is idempotent`; `:167 disposed headless Viewer ignores later model and callback work` | `PRESERVE`; `:125` already proves contribution-visible-during-`did_dispose` and Viewer idempotence |
| `viewer/async_model_features_wbtest.mbt` | 23 = 10 tests + 13 helpers | helpers `:2 async_test_model`, `:18 async_hover_anchor`, `:28 async_hover_mouse_target`, `:39 ManualHoverTimeout`, `:46 ManualHoverScheduler`, `:52 ManualHoverScheduler::new`, `:57 ::schedule`, `:72 ::next_due_index`, `:88 ::advance_to`, `:105 ::active_count`, `:116 arm_manual_hover`, `:269 hover_scroll_change`, `:335 shown_hover_controller`; tests `:127 live hover timers follow 150 300 900ms and cancel stale generations`; `:169 content and model invalidation clear a pending mouse-react handle`; `:205 hover widget mouseleave hides when the editor DOM is missing`; `:224 programmatic hover forwards immediate mode source focus and mouse state`; `:303 hover scroll handling covers neither top left both and ignored input`; `:353 invisible hover dismissal cancels work idempotently`; `:386 visible hover dismissal clears the shown view`; `:405 content invalidation cancels hover request but preserves shown view`; `:429 content invalidation removes loading visibility and permits same-anchor restart`; `:461 hover request stamp rejects version identity generation and token drift` | `PRESERVE`; ten typed accessor sites must continue to resolve the same instance |
| `viewer/agent_feedback_host_wbtest.mbt` | 7 = 5 tests + 2 helpers | helpers `:10 test_model_uri`, `:20 Viewer::test_feedback_input_contribution`; tests `:27 feedback lane reserves 18px while enabled and restores the base`; `:39 hover glyph follows non-empty lines of an enabled resource`; `:66 lines with unresolved feedback refuse the add glyph`; `:81 feedback landing on the glyph line clears the glyph`; `:94 selection changes without editor focus never open the input` | `PRESERVE`; helper lookup rewrites centrally |
| `viewer/folding_host_wbtest.mbt` | 4 tests | `:6 folding: contribution computes indent regions on model attach`; `:20 folding: toggling a region folds its lines out of the view axis`; `:68 folding: fold and unfold actions work off the selection`; `:86 folding: disabling the option clears folds and detaches the model state` | `PRESERVE`; three typed accessor sites rewrite centrally |
| `viewer/quick_diff_host_wbtest.mbt` | 5 = 4 tests + 1 helper | helper `:8 quick_diff_gutter_decorations`; tests `:24 quick diff: stored original decorates the gutter on model attach`; `:48 quick diff: original arriving after attach updates, clearing removes`; `:74 quick diff: an original for another resource does not decorate`; `:89 quick diff: identical original decorates nothing` | `PRESERVE` |

Reconciliation: `4 + 9 + 23 + 7 + 4 + 5 = 52`; test/helper split
is `34 + 18`.

Current evidence does **not** prove duplicate-id rejection, all-five known-id
lookup, construction order, two-Viewer state isolation, exactly-once
construction/disposal, or callback behavior while an individual contribution
is being disposed. Those are required new/extended tests, not `PASS` rows.

## Package contracts and artifacts

The root package already imports all four concrete controller owners and both
quick-diff packages. The central enum therefore introduces no new dependency
edge and no cycle: feature packages remain unaware of root `Viewer`.

| Package | `moon.pkg` | `pkg.generated.mbti` | README | Gate action |
|---|---|---|---|---|
| `viewer` | 37 lines, `22cbbe29…` | 280 lines, `28a72282…` | 148 lines, `e1f0826c…` | manifest imports unchanged; regenerate interface; update ownership/lifecycle text |
| `viewer/contrib/hover` | 19 lines, `4ece8e54…` | 326 lines, `25f946d0…` | 53 lines, `00a0e9c6…` | code/interface unchanged; rewrite browser-ownership paragraph that currently names a per-editor table |
| `viewer/contrib/hover/browser` | 12 lines, `ed822e18…` | 133 lines, `68e576aa…` | absent | manifest unchanged; regenerate interface after constructor rename and `get/detach` deletion |
| `viewer/contrib/folding/browser` | 8 lines, `81ee7eca…` | 210 lines, `c837f49d…` | absent | manifest unchanged; regenerate interface after constructor rename and `get/detach` deletion |
| `viewer/contrib/agent_feedback` | 3 lines, `d88df607…` | 121 lines, `2ec18e58…` | absent | unchanged dependency contract |
| `viewer/contrib/agent_feedback/browser` | 9 lines, `f6940469…` | 125 lines, `061539cd…` | absent | manifest unchanged; regenerate interface after two constructor renames and four deletions |
| `viewer/contrib/quick_diff/common` | 4 lines, `6ea3d36a…` | 33 lines, `614979b1…` | absent | unchanged |
| `viewer/contrib/quick_diff/browser` | 7 lines, `09a6a393…` | 23 lines, `cdc6a3af…` | absent | unchanged |

The shortened hashes are display-only prefixes. The following two blocks
together give all eighteen full baselines; artifacts expected to change are
grouped second. The SHA-256 of the ordered `shasum -a 256` output for all
eighteen present artifacts, in package-table order and `moon.pkg` →
`pkg.generated.mbti` → present README order, is
`658f95d3372281df554968a0c0f947e2b37cfa19d9deb928e028cd323c20a9e4`.

```text
viewer/moon.pkg
  22cbbe29e32eda4b73ae3eb5de8cf68096fd4aebccbf80cfebcc95190c039827
viewer/contrib/hover/moon.pkg
  4ece8e5420980494f7b80b3c2e7664732698fbcb2b621ad8da25c4ee05096fba
viewer/contrib/hover/pkg.generated.mbti
  25f946d03e3aa40d4d0679000d0e22b7fc2fadd7a009e5caac35b48985fcff26
viewer/contrib/hover/browser/moon.pkg
  ed822e180475aa42f7d95906fac045b159759501446b8b18ee2c4d7ab2ef7ba7
viewer/contrib/folding/browser/moon.pkg
  81ee7eca1251baedbe4e5d75ea525beae1ce865fa354f5e9a82ecded77328aed
viewer/contrib/agent_feedback/moon.pkg
  d88df60796c3b5dab9a5645dc7f4068449fceef76452663bbce4c506f72e4962
viewer/contrib/agent_feedback/pkg.generated.mbti
  2ec18e58c798101a7711776f72d248b439a0552139cf3e600f3e98535235275c
viewer/contrib/agent_feedback/browser/moon.pkg
  f694046976a2857d4d20d1fed4de5deebde0b5cf8286698efb5dc6d939969132
viewer/contrib/quick_diff/common/moon.pkg
  6ea3d36a0d878ac1be5f47d4413b32bb805991eed56f3e1c4eab4dd1093af56a
viewer/contrib/quick_diff/common/pkg.generated.mbti
  614979b1fe0f9ce7cf6daba38133f153b888771d31e34be0c053d269ff17f100
viewer/contrib/quick_diff/browser/moon.pkg
  09a6a393fadbcf9383c65c596ef7338da649c828535228cb8cb9ba2b5ec274d2
viewer/contrib/quick_diff/browser/pkg.generated.mbti
  cdc6a3afedf55971bfa217e5720d2e7e649a3e99bf712098dc720f659e1dc5a6
```

Changed-artifact complete baselines:

```text
viewer/README.md
  e1f0826c3ac8d6fdf91fe8d099cf0abad023d65fcde81e39211748c5241764a8
viewer/pkg.generated.mbti
  28a722829328f2eaa479a13cbfe36fc6ca19fc3cf667cfb9c6526ce851d362f1
viewer/contrib/hover/README.md
  00a0e9c6847bd7a494dbf86e98622141e2634826f774b8575bd44ae329654b95
viewer/contrib/hover/browser/pkg.generated.mbti
  68e576aa338d77201847c56987b4c709525483930a5c9437d6ee48a3edd29bf3
viewer/contrib/folding/browser/pkg.generated.mbti
  c837f49d71b3942ee5d771c5f25128c55490a2d0e567e5852f777c37a0b5a8df
viewer/contrib/agent_feedback/browser/pkg.generated.mbti
  061539cd49d95a0d6e1bb482d360397cdaceb4cd209913cfaa87428fa165e356
```

### Dependency and owner graph

| From | To | Current reason | Target effect |
|---|---|---|---|
| root `viewer` | `contrib/hover/browser` | controller type, attach/get/detach, widget/event types | keep import; use concrete constructor/type only |
| root `viewer` | `contrib/folding/browser` | controller/model/provider types, attach/get/detach | keep import; use concrete constructor/type only |
| root `viewer` | `contrib/agent_feedback/browser` | two controllers plus widget types, attach/get/detach | keep import; use concrete constructors/types only |
| root `viewer` | `contrib/quick_diff/browser` | change computation and decorations | unchanged |
| root `viewer` | `contrib/quick_diff/common` | service/type contracts | unchanged |
| quick-diff browser | quick-diff common | `get_change_type` | unchanged |
| each feature browser package | root `viewer` | no edge | remains forbidden; central enum/root glue prevent a cycle |

`moon ide analyze` proves `EditorContribution`, its description/registry, and
all feature `attach/get/detach` calls have no production consumer outside the
listed graph. The generated interfaces nevertheless expose the four controller
triples today, so their deletion is intentional interface shrinkage and must be
regenerated, not hidden as a stale `.mbti` diff.

## Five registered contributions — 5/5

`editor_registry()` registers in this exact order: agent-feedback input; its
nested widget registration; folding; hover; quick diff. `instantiate_all`
iterates that array in order. Although three rows declare deferred modes, the
current implementation ignores the mode and constructs all five eagerly during
`Viewer::Viewer`.

| ID | Declared mode | Current constructor and actual state | Listener ownership | Model-scoped state/reset | Current disposal | Typed lookup callers |
|---|---|---|---|---|---|---|
| `agentFeedback.editorInputContribution` | `Eventually` | `agent_feedback_host.mbt:38-62` calls `AgentFeedbackEditorInputContribution::attach(viewer.get_id())`; concrete controller has 10 fields: widget, visible, pinned range, anchor position, preference, hover line, hover decoration ids, lane base width, mouse-down, selection suppression | `hook_agent_feedback` returns 9 Viewer-lifetime subscriptions: feedback service, model, model content, selection, scroll, mouse move/leave/down/up | content/model event calls `on_agent_feedback_model_changed`; `detach_model` calls `reset_model_state` for hover ids/line; hide/glyph/lane logic re-derives resource state | dispose 9 subscriptions in order, then `detach`; no controller-owned listener store today | private root accessor: 19 calls = 18 production + 1 test; exact sites below |
| `agentFeedback.editorWidgetContribution` | `Eventually` | `agent_feedback_widgets_host.mbt:21-47` calls `AgentFeedbackEditorWidgetContribution::attach(viewer.get_id())`; concrete controller has 4 fields: widgets, reply drafts, id pool, highlight decoration ids | `hook_agent_feedback_widgets` returns 5 Viewer-lifetime subscriptions: feedback service, navigation service, model, model content, scroll | model/content events rebuild; `detach_model` resets highlight ids then clears mounted widgets/highlight while preserving draft map | clear widgets first, dispose 5 subscriptions in order, then `detach` | private root accessor: 10 production calls; exact sites below |
| `editor.contrib.folding` | `Eager` | `folding_contribution.mbt:11-62` calls `FoldingController::attach(viewer.get_id())`; concrete controller has 6 fields: folding model, hidden-range model, decoration provider, range provider, mouse-down info, model-local disposables | registration captures 5 Viewer-lifetime subscriptions: model, model content, cursor, mouse down/up; controller owns the dynamic hidden-range subscription in `local_to_dispose` | initial/model event runs `folding_on_model_changed`: `clear_local` then rebuild; content event recomputes; dispose is the reset path because Viewer disposal detaches silently | lookup controller, `clear_local` in exact model/hidden/listener/provider order, dispose 5 captured listeners, then `detach` | private root accessor: 14 calls = 11 production + 3 tests; exact sites below |
| `editor.contrib.contentHover` | `BeforeFirstInteraction` | `hover_contribution.mbt:14-27` calls `ContentHoverController::attach(viewer.get_id())`; concrete controller has 24 fields covering hover state, four timer handles, three debouncers, request source/generation, settings/mouse flags, pointer facts, closer state, notification token, decoration ids/range | no captured registration listener array; controller owns 4 clearable timer handles and one cancellation source; root event bridge invokes it directly | content invalidation cancels react/operation/request and resets decoration bookkeeping while preserving settled view; model detach additionally clears hover/view/flags | `detach` looks up by id, cancels all timers/request, then removes map entry | private root accessor: 41 calls = 31 production + 10 tests; exact sites below |
| `quickDiff.decorator` | `Eager` | `quick_diff_contribution.mbt:13-57` captures the real state as two closure locals: `EditorDecorationsCollection` + listener array; no feature-global map | 3 Viewer-lifetime subscriptions: model, model content, quick-diff original change; initial update runs synchronously | model/content/original changes refill or clear collection; no explicit detach reset because collection is owner-scoped and model event/update selects the current resource | clear collection, then dispose 3 listeners in order | no current typed lookup; four `quick_diff_update` calls at registration lines 22, 30, 40, 46; target adds the fifth central variant/accessor |

Static registration therefore creates **22 Viewer-lifetime listener handles**
(`0 + 5 + 9 + 5 + 3`) plus folding's dynamic model-local listener. The target
must move those captured arrays onto their concrete state/entry without
changing subscription insertion or disposal order.

## Direct map operations and typed caller graph

### Public feature-map API calls — 12/12

Each public `attach/get/detach` method has one and only one production caller:

| Feature | `attach` caller | `get` caller | `detach` caller | Target |
|---|---|---|---|---|
| hover | `viewer/hover_contribution.mbt:19` | `viewer/editor_events.mbt:35` | `viewer/hover_contribution.mbt:23` | constructor + central accessor + typed dispose |
| folding | `viewer/folding_contribution.mbt:16` | `viewer/folding_host.mbt:19` | `viewer/folding_contribution.mbt:58` | constructor + central accessor + typed dispose |
| input feedback | `viewer/agent_feedback_host.mbt:45` | `viewer/agent_feedback_host.mbt:144` | `viewer/agent_feedback_host.mbt:56` | constructor + central accessor + typed dispose |
| widget feedback | `viewer/agent_feedback_widgets_host.mbt:28` | `viewer/agent_feedback_widgets_host.mbt:56` | `viewer/agent_feedback_widgets_host.mbt:40` | constructor + central accessor + typed dispose |

The four `attach` definitions become ordinary primary constructors. The four
`get`, four `detach`, and four global map declarations disappear. No alias or
compatibility shim remains.

### Root typed-accessor calls — 84/84

The accessor definitions themselves are not counted here. Every call is
terminally `REWRITE` to the same accessor name backed by an enum match; caller
control flow is `PRESERVE`.

| Accessor | Exact call sites | Count |
|---|---|---:|
| `content_hover_controller()` | `viewer/editor_events.mbt:3,52,104,133,145,164,184,206,249,272,289,306,332,350,382,413,459,480,513,552,571,599,627,658,674,693,707,731`; `viewer/attach_model.mbt:90`; `viewer/content_hover_widget_host.mbt:14`; `viewer/viewer.mbt:769`; `viewer/async_model_features_wbtest.mbt:117,137,180,209,232,307,359,392,410,434` | 41 |
| `folding_controller()` | `viewer/folding_contribution.mbt:51,87,112,126`; `viewer/folding_host.mbt:25,68,114,136,158,203,272`; `viewer/folding_host_wbtest.mbt:8,24,89` | 14 |
| `agent_feedback_input_contribution()` | `viewer/agent_feedback_host.mbt:93,153,175,190,236,302,330,364,378,425,464,486,525,538,569,587,626`; `viewer/agent_feedback_host_wbtest.mbt:23`; `viewer/viewer.mbt:782` | 19 |
| `agent_feedback_widget_contribution()` | `viewer/agent_feedback_widgets_host.mbt:95,117,178,189,246,267,302,323,341`; `viewer/viewer.mbt:786` | 10 |
| **Total** |  | **84** |

Other central lifecycle references are exactly:

| Operation | Current sites | Count |
|---|---|---:|
| quick-diff state update | `viewer/quick_diff_contribution.mbt:22,30,40,46` | 4 |
| public central presence lookup | five calls in `editor_extensions_wbtest.mbt:9,12,14,15,18`; one in `lifecycle_ownership_wbtest.mbt:137` | 6 |
| registry instantiation | `viewer/viewer.mbt:393` | 1 |
| contribution disposal dispatch | `viewer/viewer.mbt:989` | 1 |
| feature reset/cleanup calls | hover reset `attach_model.mbt:100`, `viewer.mbt:773`; folding `clear_local` `folding_host.mbt:26`, `folding_contribution.mbt:52`; input reset `viewer.mbt:783`; widget reset `viewer.mbt:787` | 6 |

The target adds a private `quick_diff_contribution()` accessor so all five
variants have one typed view. Initialization may hold the just-created state
directly, but every post-insertion callback/lookup must resolve the entry from
the viewer-owned map, never a process-global table.

## Four-map collision and leak audit — 4/4

All four maps are strong process globals keyed by a caller-supplied `String`.
All four `attach` methods assign with `map[editor_id] = controller` and perform
no duplicate check. All four `detach` methods remove by key rather than by
controller identity.

| Map | Insert | Read | Remove/cleanup | Collision behavior | Leak behavior |
|---|---|---|---|---|---|
| hover `instances` (`content_hover_controller.mbt:73`) | `attach:108` overwrites | `get:118`; `detach:124` | `detach:126-131` cancels the controller currently under the key, then removes it | second attach replaces A with B without canceling A; stale A detach cancels **B** timers/request and removes B | map strongly retains timers, cancellation source, hover/decorations until exact detach; overwritten A can keep live async handles outside the map |
| folding `folding_instances` (`folding.mbt:84`) | `attach:97` overwrites | `get:104` | `detach:110` removes current key only; cleanup happens separately via whichever controller lookup succeeds | second attach hides A; stale A dispose first looks up/clears B, then removes B; A's model/provider state is no longer reachable through its Viewer | process global retains folding/text/hidden/provider graphs; omission of Viewer disposal leaves the entry indefinitely |
| feedback input `input_instances` (`agent_feedback_editor_input_contribution.mbt:40`) | `attach:58` overwrites | `get:66` | `detach:71` removes current key only | second attach hides A; any stale detach removes B; A callbacks can mutate B while the shared key still resolves | controller can retain widget DOM and host closures back to Viewer; process global creates a direct Viewer reachability leak |
| feedback widget `widget_instances` (`agent_feedback_editor_widget_contribution.mbt:23`) | `attach:36` overwrites | `get:44` | `detach:51` removes current key only | second attach hides A; stale detach removes B; A callbacks can operate on B's widget/draft state | widgets contain host closures/DOM/drafts; the global roots the controller and transitively the Viewer |

Normal `Viewer` construction currently generates
`vs.editor.ICodeEditor:<counter>` from a monotonic process counter, so ordinary
non-overflowing construction does not intentionally reuse a key. That reduces
collision frequency; it does **not** make the stores safe:

1. all four public `attach(String)` APIs accept arbitrary duplicate keys;
2. overwrite is not identity-aware and stale detach removes the replacement;
3. integer wrap or a future id policy can reintroduce reuse;
4. even with perfect uniqueness, a process global strongly retains state when
   disposal is skipped and violates `Viewer.contributions` sole ownership.

The target per-Viewer map is keyed by contribution id, so two Viewers cannot
collide. Duplicate descriptions within one registry must be rejected **before
constructing or inserting** a replacement; silent `Map::set` overwrite would
recreate the same lost-instance leak inside one Viewer.

## Viewer contribution lifetime — current local trace

This is the local call graph; the sibling lifetime companion expands it into
the exact event/disposal trace and behavior matrix.

| Transition | Current order | State consequence that must remain |
|---|---|---|
| `Viewer::Viewer` | seed empty contribution map → add marker lifetime listener → `editor_registry().instantiate_all(viewer)` → assign returned map | all five contributions exist before constructor returns; registration/construction order is input → widget → folding → hover → quick diff |
| initial `set_model(Some)` | no old detach → `attach_model` → restore focus if needed → fire `did_change_model` → outgoing owner sweep N-A | folding builds model-local state; input/widget/quick-diff react; hover controller persists and starts clean |
| same-model `set_model` | identity guard returns | no contribution callback or state replacement |
| `set_value` | model flush runs swap-scoped content callback; hover cancel/reset occurs before public `did_change_model_content`; contribution listeners then run | same five controller identities survive; feedback/folding/quick diff re-derive; hover settled-view preservation remains |
| model swap | `detach_model`: cancel selection; hover cancel/reset/clear; input reset; widget reset + clear; `ModelData::dispose`; clear DOM facts → attach new model → fire `did_change_model` → outgoing owner sweep | controllers and listener stores survive; only model-scoped state changes; folding's `did_change_model` clears/rebuilds after attach |
| model removal | same detach path → schedule no-model render → fire `did_change_model` → outgoing owner sweep | all central entries remain; folding clears, feedback/quick diff become no-model, hover is cleared |
| reattach | attach → `did_change_model` | same controller instances receive the new model; no constructor repeats |
| Viewer dispose | mark disposed → clear overlay registry → silent `detach_model` + owner sweep → remove placeholder → fire `did_dispose` while central map is still readable → dispose contributions in insertion order → clear map → Viewer lifetime/emitter/service teardown | contribution lookup is live during `did_dispose`; each typed state disposes once; no `did_change_model` fires; callbacks triggered by a contribution cleanup see the still-installed central entries |
| repeated Viewer dispose | `disposed` guard returns | no second controller or listener disposal |

Two current cleanup dependencies make “remove entry, then dispose by lookup”
invalid: folding disposal calls controller cleanup, and widget disposal calls
root widget/highlight helpers that resolve the typed controller. Typed disposal
must dispatch from the entry's enum payload directly while the map remains
installed; the map is cleared only after all five dispatches complete.

## Representation proof and reviewed two-phase initialization

### Closed enum proof

The exact reviewed carrier from the parent plan is viable:

```moonbit nocheck
priv enum EditorContributionInstance {
  ContentHover(@hover_browser.ContentHoverController)
  Folding(@folding_browser.FoldingController)
  AgentFeedbackInput(
    @agent_feedback_browser.AgentFeedbackEditorInputContribution,
  )
  AgentFeedbackWidget(
    @agent_feedback_browser.AgentFeedbackEditorWidgetContribution,
  )
  QuickDiff(QuickDiffContributionState)
}

priv struct EditorContributionEntry {
  id : String
  instance : EditorContributionInstance
  listeners : Array[@base_common.Disposable]
}
```

The root package already compiles the same representation pattern:
`RegisteredEditorCommand` is a private heterogeneous enum
(`editor_extensions.mbt:80`) stored in
`Map[String, RegisteredEditorCommand]` (`:110`), inserted at `:137/:174`, and
exhaustively matched at `:234/:262`. All four controller packages are already
root dependencies. No language bridge, trait-object identity, unsafe cast, or
second table is needed.

A closed enum is appropriate because the product has exactly five statically
registered rows, the description registry is private, no plugin API can add an
unknown controller type, and a sixth row should force compiler-exhaustive
updates to initialization, typed access, reset, and disposal. This is a closed
product registry, not an extensible library registry.

`QuickDiffContributionState` is a private root struct containing exactly the
currently captured `EditorDecorationsCollection` and its three-listener array.
It is not a fifth global map.

### Mandatory two-phase initialization

Replacing `viewer.contributions = instantiate_all(viewer)` with an otherwise
identical “construct all locally, assign at the end” implementation is wrong.
Three current constructors synchronously use their accessor before returning:

- input calls `hook_agent_feedback`, whose first operation is
  `sync_agent_feedback_lane` → `agent_feedback_input_contribution()`;
- widget calls `hook_agent_feedback_widgets`, whose first operation is
  `rebuild_agent_feedback_widgets` →
  `agent_feedback_widget_contribution()`;
- folding calls `folding_on_model_changed` → `folding_controller()`.

Today those succeed because `attach` inserts the global entry first. The
central equivalent must preserve that ordering for each row:

1. **Reject a duplicate id before invoking its constructor.** No overwritten
   state or constructor side effect is permitted.
2. Construct the concrete controller/state without performing a typed central
   lookup.
3. Wrap it in private `EditorContributionEntry` and insert that entry into
   `viewer.contributions` immediately.
4. Dispatch typed initialization from the installed enum variant: install the
   contribution's listener handles and perform the initial lane/widget/folding/
   quick-diff synchronization.
5. Continue to the next description in registration order.

Consequently `instantiate_all` should mutate the already-empty
`viewer.contributions` (or return only after using an equivalent per-row
installed map), not build an invisible local map and assign it after the loop.
The initializers and every callback after step 3 resolve the exact central
instance.

The **22 static listener handles** live with their actual central entry/state,
not in a registration closure, feature package, or second lookup map. The
Viewer/service callbacks are root glue, so the common entry owns the folding
and feedback handles without adding public listener-install APIs to the feature
packages:

| Variant/state | Target listener owner |
|---|---|
| `ContentHover` | no static listener array; the controller continues to own its four timer handles and request source |
| `Folding` | private root `EditorContributionEntry.listeners`, five handles; keep the controller's existing model-local `local_to_dispose` separate |
| `AgentFeedbackInput` | private root `EditorContributionEntry.listeners`, nine handles |
| `AgentFeedbackWidget` | private root `EditorContributionEntry.listeners`, five handles |
| `QuickDiff` | private `QuickDiffContributionState.listeners`, three handles, as required by the parent plan |

Each typed dispose performs feature-specific cleanup and drains the entry/state
handles in the reviewed per-variant order. The root entry disappears only
after dispatch returns. No closure array survives beside the enum payload, and
the feature controller interfaces gain no listener-management seam.

### Typed central access

Each private root accessor matches both the contribution id and enum variant:

```moonbit nocheck
fn Viewer::content_hover_controller(self : Viewer) ->
  @hover_browser.ContentHoverController? {
  match self.contributions.get("editor.contrib.contentHover") {
    Some({ instance: ContentHover(controller), .. }) => Some(controller)
    _ => None
  }
}
```

Folding, input, widget, and quick diff use the same shape. A mismatched id/
variant returns `None` in ordinary access and is a construction-test failure;
the registry never synthesizes a downcast from a string or controller identity.

## Target visibility and constructor decisions

### Visibility

| Symbol/set | Target visibility | Evidence/reason |
|---|---|---|
| `Viewer.contributions` | private | sole per-Viewer owner; no external field access |
| `EditorContributionEntry` | private | actual central map value containing id, closed instance enum, and root-owned listener handles |
| `EditorContributionInstance` | private | contains concrete feature implementation types and is matched only by root lifecycle/accessors |
| `QuickDiffContributionState` | private | root-only collection/listener carrier |
| five `Viewer::*_contribution/controller` accessors | private | 84 current calls are root production or root white-box tests; none is in `pkg.generated.mbti` |
| four global maps | deleted | process state, no consumer contract |
| twelve `attach/get/detach` APIs | deleted | exactly twelve root callers migrate; no other reference from `moon ide find-references` |
| four concrete controller types and root-used fields/methods | remain public at their package boundary | root is a distinct package and all feature behavior still reads/writes these concrete types; this plan does not relocate controller behavior |
| `EditorContributionEntry.listeners` | private | root owns the folding/input/widget Viewer-service callbacks it registers; no cross-package listener API is introduced |
| `EditorContributionRegistry`, description, holder, registration/instantiate methods | private | unchanged internal registry boundary |
| `EditorContributionInstantiation` | preserve current public status temporarily | final facade plan owns public-surface deletion/reshaping |
| `EditorContribution` | preserve the current temporary public facade and adapt it from the private entry | keeps `Viewer::get_contribution`'s exact return contract without exposing/storing the private enum twice; final facade plan decides whether the carrier remains |
| `Viewer::get_contribution` | public, same known/unknown/after-dispose behavior | explicitly deferred to `viewer-public-editor-api-boundary.md` |

The actual instance map therefore uses `EditorContributionEntry`, not the
public facade. `Viewer::get_contribution` adapts a found entry to today's
presence/lifecycle view without creating another state store. A compiler probe
also proved an opaque public carrier with a private-enum layout is legal, but
the next public-boundary plan owns that API narrowing; this plan must not
opportunistically change the public fields or delete the getter.

### Primary constructors

| Current/new construction | Reviewed target | Visibility/action |
|---|---|---|
| `ContentHoverController::attach(String)` | `ContentHoverController::ContentHoverController()` | public package constructor; remove id argument/map write |
| `FoldingController::attach(String)` | `FoldingController::FoldingController()` | public package constructor; initialize the existing empty model-local store; root entry owns Viewer-lifetime listeners |
| `AgentFeedbackEditorInputContribution::attach(String)` | `AgentFeedbackEditorInputContribution::AgentFeedbackEditorInputContribution()` | public package constructor; root entry owns Viewer-lifetime listeners |
| `AgentFeedbackEditorWidgetContribution::attach(String)` | `AgentFeedbackEditorWidgetContribution::AgentFeedbackEditorWidgetContribution()` | public package constructor; root entry owns Viewer-lifetime listeners |
| new quick-diff state construction | `QuickDiffContributionState::QuickDiffContributionState(collection)` | private root primary constructor; listeners initially empty |
| central entry construction | `EditorContributionEntry::EditorContributionEntry(id, instance)` | private root primary constructor; common listener array starts empty |
| description construction | `EditorContributionDescription::EditorContributionDescription(id, instantiation, ctor)` | private root primary constructor; registration does duplicate check independently |

Other existing `::new` constructors in the host/feature files (hover widget,
folding model/providers, agent-feedback DOM widgets, decoration collections)
are behavior dependencies, not primary constructors touched by this ownership
plan, and remain unchanged here.

## Local Gate A reconciliation

- [x] 161/161 complete production-file declarations have a disposition.
- [x] 13/13 bounded lifecycle declarations/carriers are named without a
      whole-file overclaim.
- [x] 52/52 directly relevant test declarations are named (34 tests, 18
      helpers).
- [x] all 5 registration rows record id, mode, state, listeners, model state,
      disposal, and typed callers.
- [x] all 4 maps and all 12 `attach/get/detach` caller paths are accounted.
- [x] all 84 current typed accessor call sites are enumerated.
- [x] normal, collision, stale-detach, skipped-dispose, model-swap, and Viewer
      disposal behavior is recorded.
- [x] the heterogeneous central representation is proven by an existing
      compiled local enum-in-map pattern.
- [x] duplicate check → construct → central insert → typed initialize is the
      reviewed mandatory ordering.
- [x] package manifests, interfaces, README presence/absence, dependency edges,
      visibility, and constructor decisions are recorded.
- [ ] product implementation — **STOP FOR REVIEW**.

Review gate: no contribution storage, constructor, listener, model-lifetime,
or public-interface code may move until this local companion and its sibling
upstream/lifetime companions are explicitly approved.
