///|
pub(all) enum InlayHintKind {
  TypeHint
  ParameterHint
} derive(Eq, Debug)

///|
pub(all) struct InlayHint {
  position : @core.Position
  label : String
  kind : InlayHintKind?
  padding_left : Bool
  padding_right : Bool
  tooltip : Array[HoverContent]
} derive(Eq, Debug)

///|
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
pub(open) trait InlayHintsProvider {
  async fn inlay_hints(Self, @workspace.SourceDocument) -> Array[InlayHint]
}
