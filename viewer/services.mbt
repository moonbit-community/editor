///|
/// Services shared by the embeddable viewer and its feature controllers.
///
/// The hover participant registry is *not* held here: it is a free global in
/// `viewer/hover` populated by that feature's contribution, mirroring Monaco's
/// `HoverParticipantRegistry`. `Viewer::request_hover` projects these services
/// into a `@hover.HoverParticipantServices` when it builds a hover computer.
pub(all) struct ViewerServices {
  languages : @languages.Languages
  markers : @markers.MarkerService
  marker_decorations : @markers.MarkerDecorationsService
  /// The agent-feedback store (`IAgentFeedbackService` reduced): hosts
  /// enable it per resource and subscribe to its add/submit events; the
  /// viewer's agent-feedback contrib renders from it.
  agent_feedback : @agent_feedback.AgentFeedbackService
  log_service : @log.LogService
}

///|
/// Creates the default viewer services.
pub fn ViewerServices::new(
  languages? : @languages.Languages = @languages.default_languages(),
  log_service? : @log.LogService = @log.LogService::new(),
) -> ViewerServices {
  // The change event merges same-tick updates on a real microtask here
  // (Monaco's `MicrotaskEmitter`); headless tests use the sync default.
  let markers = @markers.MarkerService::new(schedule=queue_microtask)
  {
    languages,
    markers,
    marker_decorations: @markers.MarkerDecorationsService::new(markers),
    agent_feedback: @agent_feedback.AgentFeedbackService::new(),
    log_service,
  }
}
