// The debug/instrumentation seam. These package-level subscriptions are NOT
// part of the public Monaco-shaped `Viewer::` API (which is a strict readonly
// subset of `IEditor`/`ICodeEditor`): Monaco has no render-completion or
// hover-resolution events, and its own tests reach into internals for them.
// Dev-tool hosts (the workbench status bar) and browser-test scenarios use
// these for telemetry and render synchronization.

///|
/// Fires after a view model is (re)built from a model — tokenize/build
/// timings and counts for telemetry and test synchronization.
pub fn debug_on_did_build_view_model(
  viewer : Viewer,
  listener : (ViewerViewModelBuiltEvent) -> Unit,
) -> @base_common.Disposable {
  viewer.did_build_view_model.event(listener)
}

///|
/// Fires after the built content is patched into the DOM.
pub fn debug_on_did_render_model(
  viewer : Viewer,
  listener : (ViewerModelRenderedEvent) -> Unit,
) -> @base_common.Disposable {
  viewer.did_render_model.event(listener)
}

///|
/// Fires when a hover resolution operation completes.
pub fn debug_on_did_resolve_hover(
  viewer : Viewer,
  listener : (ViewerHoverResolvedEvent) -> Unit,
) -> @base_common.Disposable {
  viewer.did_resolve_hover.event(listener)
}
