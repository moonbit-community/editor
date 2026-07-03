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
  /// The comment store (`ICommentService` reduced): hosts feed threads and
  /// commenting ranges through it and subscribe to its mutation events for
  /// persistence; the viewer's comments contrib renders from it.
  comments : @comments_common.CommentService
  log_service : @log.LogService
}

///|
/// Creates the default viewer services.
pub fn ViewerServices::new(
  languages? : @languages.Languages = @languages.default_languages(),
  log_service? : @log.LogService = @log.LogService::new(),
) -> ViewerServices {
  let markers = @markers.MarkerService::new()
  {
    languages,
    markers,
    marker_decorations: @markers.MarkerDecorationsService::new(markers),
    comments: @comments_common.CommentService::new(),
    log_service,
  }
}
