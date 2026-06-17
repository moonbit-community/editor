///|
pub(all) enum HoverPart {
  MarkdownHover(
    range~ : @core.Range,
    contents~ : Array[@language.HoverContent],
    ordinal~ : Int
  )
  MarkerHover(range~ : @core.Range, marker~ : Marker)
  LoadingHover(range~ : @core.Range, message~ : String)
} derive(Eq, Debug)

///|
pub(all) struct ComputedHover {
  range : @core.Range
  parts : Array[HoverPart]
} derive(Eq, Debug)

///|
pub(all) struct HoverComputeContext {
  document : @workspace.SourceDocument
  anchor_range : @core.Range
  offset : Int
  injected_text_index : Int
  inlay_hints : Array[@language.InlayHint]
  services : ViewerServices
}

///|
pub(open) trait HoverParticipant {
  fn ordinal(Self) -> Int noraise
  fn compute_sync(Self, HoverComputeContext) -> Array[HoverPart] noraise
  async fn compute_async(Self, HoverComputeContext) -> Array[HoverPart] noraise
}

///|
pub(all) struct MarkerHoverParticipant(Unit)

///|
pub fn MarkerHoverParticipant::new() -> MarkerHoverParticipant {
  MarkerHoverParticipant(())
}

///|
pub impl HoverParticipant for MarkerHoverParticipant with fn ordinal(_self) {
  0
}

///|
pub impl HoverParticipant for MarkerHoverParticipant with fn compute_sync(
  _self,
  ctx,
) {
  if ctx.injected_text_index >= 0 {
    return []
  }
  let parts : Array[HoverPart] = []
  for
    marker in ctx.services.marker_decorations.markers_at(
      ctx.document.uri,
      ctx.anchor_range,
    ) {
    parts.push(MarkerHover(range=marker.range, marker~))
  }
  parts
}

///|
pub impl HoverParticipant for MarkerHoverParticipant with fn compute_async(
  _self,
  _ctx,
) {
  []
}

///|
pub(all) struct MarkdownHoverParticipant(Unit)

///|
pub fn MarkdownHoverParticipant::new() -> MarkdownHoverParticipant {
  MarkdownHoverParticipant(())
}

///|
pub impl HoverParticipant for MarkdownHoverParticipant with fn ordinal(_self) {
  100
}

///|
pub impl HoverParticipant for MarkdownHoverParticipant with fn compute_sync(
  _self,
  _ctx,
) {
  []
}

///|
pub impl HoverParticipant for MarkdownHoverParticipant with fn compute_async(
  self,
  ctx,
) {
  if ctx.injected_text_index >= 0 {
    return []
  }
  match ctx.services.language_features.hover_at(ctx.document, ctx.offset) {
    Some(hover) =>
      if hover.contents.length() == 0 {
        []
      } else {
        [
          MarkdownHover(
            range=hover.range,
            contents=hover.contents,
            ordinal=self.ordinal(),
          ),
        ]
      }
    None => []
  }
}

///|
pub(all) struct InlayHintHoverParticipant {
  identity : Unit
}

///|
pub fn InlayHintHoverParticipant::new() -> InlayHintHoverParticipant {
  { identity: () }
}

///|
pub impl HoverParticipant for InlayHintHoverParticipant with fn ordinal(_self) {
  50
}

///|
pub impl HoverParticipant for InlayHintHoverParticipant with fn compute_sync(
  self,
  ctx,
) {
  if ctx.injected_text_index < 0 {
    return []
  }
  match ctx.inlay_hints.get(ctx.injected_text_index) {
    Some(hint) =>
      if hint.tooltip.length() == 0 {
        []
      } else {
        [
          MarkdownHover(
            range=ctx.anchor_range,
            contents=hint.tooltip,
            ordinal=self.ordinal(),
          ),
        ]
      }
    None => []
  }
}

///|
pub impl HoverParticipant for InlayHintHoverParticipant with fn compute_async(
  _self,
  _ctx,
) {
  []
}

///|
pub(all) struct ContentHoverComputer {
  services : ViewerServices
}

///|
pub fn ContentHoverComputer::new(
  services : ViewerServices,
) -> ContentHoverComputer {
  { services, }
}

///|
pub fn ContentHoverComputer::compute_sync(
  self : ContentHoverComputer,
  document : @workspace.SourceDocument,
  anchor_range : @core.Range,
  offset : Int,
  injected_text_index? : Int = -1,
  inlay_hints? : Array[@language.InlayHint] = [],
) -> ComputedHover? {
  let ctx : HoverComputeContext = {
    document,
    anchor_range,
    offset,
    injected_text_index,
    inlay_hints,
    services: self.services,
  }
  let parts : Array[HoverPart] = []
  for participant in self.services.hover_participants.entries {
    parts.append(participant.compute_sync(ctx))
  }
  computed_hover_from_parts(anchor_range, parts)
}

///|
pub async fn ContentHoverComputer::compute_async(
  self : ContentHoverComputer,
  document : @workspace.SourceDocument,
  anchor_range : @core.Range,
  offset : Int,
  injected_text_index? : Int = -1,
  inlay_hints? : Array[@language.InlayHint] = [],
) -> ComputedHover? noraise {
  let ctx : HoverComputeContext = {
    document,
    anchor_range,
    offset,
    injected_text_index,
    inlay_hints,
    services: self.services,
  }
  let parts : Array[HoverPart] = []
  for participant in self.services.hover_participants.entries {
    parts.append(participant.compute_async(ctx))
  }
  computed_hover_from_parts(anchor_range, parts)
}

///|
fn computed_hover_from_parts(
  fallback_range : @core.Range,
  parts : Array[HoverPart],
) -> ComputedHover? {
  if parts.length() == 0 {
    return None
  }
  parts.sort_by(compare_hover_parts)
  let mut range = fallback_range
  for part in parts {
    range = union_range(range, hover_part_range(part))
  }
  Some({ range, parts })
}

///|
fn compare_hover_parts(left : HoverPart, right : HoverPart) -> Int {
  let ordinal = hover_part_ordinal(left) - hover_part_ordinal(right)
  if ordinal != 0 {
    ordinal
  } else {
    hover_part_range(left).start - hover_part_range(right).start
  }
}

///|
fn hover_part_ordinal(part : HoverPart) -> Int {
  match part {
    MarkdownHover(ordinal~, ..) => ordinal
    MarkerHover(_) => 0
    LoadingHover(_) => -1
  }
}

///|
fn hover_part_range(part : HoverPart) -> @core.Range {
  match part {
    MarkdownHover(range~, ..) => range
    MarkerHover(range~, ..) => range
    LoadingHover(range~, ..) => range
  }
}

///|
fn union_range(left : @core.Range, right : @core.Range) -> @core.Range {
  Range(min_int(left.start, right.start), max_int(left.end, right.end))
}

///|
fn min_int(left : Int, right : Int) -> Int {
  if left < right {
    left
  } else {
    right
  }
}

///|
fn max_int(left : Int, right : Int) -> Int {
  if left > right {
    left
  } else {
    right
  }
}
