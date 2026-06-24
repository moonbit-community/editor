///|
/// Ordered registry of hover-participant factories. The MoonBit analog of
/// Monaco's `HoverParticipantRegistry` singleton in `hoverTypes.ts`: a free
/// global that the hover contribution populates, not state the viewer services
/// own. Each factory builds a participant from the editor-scoped services, like
/// Monaco's `instantiationService.createInstance(ctor, editor)`.
pub(all) struct HoverParticipantRegistry {
  entries : Array[(HoverParticipantServices) -> &HoverParticipant]
}

///|
/// Creates an empty hover participant registry.
pub fn HoverParticipantRegistry::new() -> HoverParticipantRegistry {
  { entries: [] }
}

///|
/// Adds a hover participant factory to the registry.
pub fn HoverParticipantRegistry::register(
  self : HoverParticipantRegistry,
  factory : (HoverParticipantServices) -> &HoverParticipant,
) -> Unit {
  self.entries.push(factory)
}

///|
/// Builds one participant instance per registered factory for the given
/// services — Monaco's per-editor `_initializeHoverParticipants`.
pub fn HoverParticipantRegistry::build_all(
  self : HoverParticipantRegistry,
  services : HoverParticipantServices,
) -> Array[&HoverParticipant] {
  self.entries.map(factory => factory(services))
}

///|
/// Process-wide hover participant registry, populated with the built-in
/// participants. The analog of Monaco's module-level `HoverParticipantRegistry`
/// plus the `HoverParticipantRegistry.register(...)` calls in
/// `hoverContribution.ts`.
pub let hover_participant_registry : HoverParticipantRegistry = make_default_hover_participant_registry()

///|
fn make_default_hover_participant_registry() -> HoverParticipantRegistry {
  let registry = HoverParticipantRegistry::new()
  register_default_hover_participants(registry)
  registry
}

///|
/// Registers the built-in marker, inlay-hint, and markdown hover participants
/// into `registry`, mirroring `hoverContribution.ts`. Registration lives here,
/// in the hover feature, never in the viewer services constructor.
pub fn register_default_hover_participants(
  registry : HoverParticipantRegistry,
) -> Unit {
  registry.register(services => {
    MarkerHoverParticipant::new(services.marker_decorations)
  })
  registry.register(_services => InlayHintHoverParticipant::new())
  registry.register(services => {
    MarkdownHoverParticipant::new(services.languages, services.log_service)
  })
}
