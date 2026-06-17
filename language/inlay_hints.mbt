///|
/// Inlay hint category used for styling and hover copy.
pub(all) enum InlayHintKind {
  TypeHint
  ParameterHint
} derive(Eq, Debug)

///|
/// Inline annotation rendered at a core document position, with optional
/// spacing and hover tooltip content.
pub(all) struct InlayHint {
  position : @core.Position
  label : String
  kind : InlayHintKind?
  padding_left : Bool
  padding_right : Bool
  tooltip : Array[HoverContent]
} derive(Eq, Debug)

///|
/// Builds an inlay hint with explicit spacing and tooltip defaults.
pub fn InlayHint::InlayHint(
  position : @core.Position,
  label : String,
  kind? : InlayHintKind,
  padding_left? : Bool = false,
  padding_right? : Bool = false,
  tooltip? : Array[HoverContent] = [],
) -> InlayHint {
  { position, label, kind, padding_left, padding_right, tooltip }
}

///|
/// Document-level inlay hint provider.
pub(open) trait InlayHintsProvider {
  async fn inlay_hints(Self, @model.TextModel) -> Array[InlayHint]
}
