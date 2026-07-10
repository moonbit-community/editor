///|
/// Model-level features requested after a fresh render. Only inlay hints
/// resolve here: diagnostics are push-only — whoever owns them feeds
/// `services.markers` (Monaco's `setModelMarkers`), and the marker-change
/// event drives the render refresh.
fn Viewer::request_model_features(
  self : Viewer,
  model : @model.TextModel,
) -> Unit {
  guard self.inlay_hints_controller() is Some(controller) else { return }
  let stamp = controller.begin_request(model)
  @js.async_run(() => self.request_model_features_async(stamp))
}

///|
/// Awaitable request body isolated from the fire-and-forget production launch.
/// Controlled browser providers exercise this exact body; only its synchronous
/// apply boundary may commit provider data.
async fn Viewer::request_model_features_async(
  self : Viewer,
  stamp : InlayRequestStamp,
) -> Unit noraise {
  let inlay_hints = self.services.languages.inlay_hints_for_model(
    stamp.model,
    self.services.log_service,
    token=stamp.token,
    run_tasks=run_async_tasks_concurrently,
  )
  self.commit_model_features(stamp, inlay_hints)
}

///|
/// Single synchronous apply boundary shared by the production continuation
/// and deterministic completion-order tests.
fn Viewer::commit_model_features(
  self : Viewer,
  stamp : InlayRequestStamp,
  inlay_hints : Array[@language.InlayHint],
) -> Unit {
  match self.inlay_hints_controller() {
    Some(controller) => {
      if !self.disposed && controller.accepts_request(stamp, self.get_model()) {
        // The hints render as `after` injected-text decorations (Track F);
        // the decoration-change event carries `affects_injected_text`, which
        // rebuilds the projection — no explicit feature re-render here. The
        // raw hints stay on the controller for hover tooltip lookup.
        controller.inlay_hints = inlay_hints
        self.sync_inlay_hint_decorations()
      }
      controller.finish_request(stamp.generation)
    }
    None => ()
  }
}
