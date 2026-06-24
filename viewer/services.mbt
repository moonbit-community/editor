///|
/// Ordered registry for hover participants. Participants with lower ordinals
/// render before later participants when ranges overlap.
pub(all) struct HoverParticipantRegistry {
  entries : Array[&HoverParticipant]
}

///|
/// Creates an empty hover participant registry.
pub fn HoverParticipantRegistry::new() -> HoverParticipantRegistry {
  { entries: [] }
}

///|
/// Adds a hover participant to the registry.
pub fn HoverParticipantRegistry::register(
  self : HoverParticipantRegistry,
  participant : &HoverParticipant,
) -> Unit {
  self.entries.push(participant)
}

///|
/// Services shared by the embeddable viewer and its feature controllers.
pub(all) struct ViewerServices {
  languages : Languages
  markers : @markers.MarkerService
  marker_decorations : @markers.MarkerDecorationsService
  hover_participants : HoverParticipantRegistry
  log_service : @log.LogService
}

///|
/// Creates the default viewer services, including marker, inlay-hint, and
/// markdown hover participants.
pub fn ViewerServices::new(
  languages? : Languages = default_languages(),
  log_service? : @log.LogService = @log.LogService::new(),
) -> ViewerServices {
  let markers = @markers.MarkerService::new()
  let hover_participants = HoverParticipantRegistry::new()
  hover_participants.register(MarkerHoverParticipant::new())
  hover_participants.register(InlayHintHoverParticipant::new())
  hover_participants.register(MarkdownHoverParticipant::new())
  {
    languages,
    markers,
    marker_decorations: @markers.MarkerDecorationsService::new(markers),
    hover_participants,
    log_service,
  }
}
