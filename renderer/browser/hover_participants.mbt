///|
/// One renderable contribution to the content hover widget.
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
/// Complete hover result after participant parts have been merged and sorted.
pub(all) struct ComputedHover {
  range : @core.Range
  parts : Array[HoverPart]
} derive(Eq, Debug)

///|
/// Inputs shared by synchronous and asynchronous hover participants.
pub(all) struct HoverComputeContext {
  document : @model.TextModel
  anchor_range : @core.Range
  offset : Int
  injected_text_index : Int
  inlay_hints : Array[@language.InlayHint]
  services : ViewerServices
}

///|
/// Pluggable content-hover participant. Synchronous participants provide data
/// already in viewer state; asynchronous participants may call language
/// providers.
pub(open) trait HoverParticipant {
  fn ordinal(Self) -> Int noraise
  fn compute_sync(Self, HoverComputeContext) -> Array[HoverPart] noraise
  async fn compute_async(Self, HoverComputeContext) -> Array[HoverPart] noraise
}

///|
/// Hover participant that exposes diagnostics/markers at the anchor range.
pub(all) struct MarkerHoverParticipant(Unit)

///|
/// Creates the marker hover participant.
pub fn MarkerHoverParticipant::new() -> MarkerHoverParticipant {
  MarkerHoverParticipant(())
}

///|
/// Marker hovers render first.
pub impl HoverParticipant for MarkerHoverParticipant with fn ordinal(_self) {
  0
}

///|
/// Computes marker hover parts from the current marker decorations.
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
/// Marker hover data is fully synchronous.
pub impl HoverParticipant for MarkerHoverParticipant with fn compute_async(
  _self,
  _ctx,
) {
  []
}

///|
/// Hover participant that queries registered markdown/plaintext hover providers.
pub(all) struct MarkdownHoverParticipant(Unit)

///|
/// Creates the markdown hover participant.
pub fn MarkdownHoverParticipant::new() -> MarkdownHoverParticipant {
  MarkdownHoverParticipant(())
}

///|
/// Markdown hovers render after marker and inlay-hint hovers.
pub impl HoverParticipant for MarkdownHoverParticipant with fn ordinal(_self) {
  100
}

///|
/// Markdown provider hovers are asynchronous only.
pub impl HoverParticipant for MarkdownHoverParticipant with fn compute_sync(
  _self,
  _ctx,
) {
  []
}

///|
/// Queries language hover providers for the anchor offset.
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
/// Hover participant for inlay-hint tooltips.
pub(all) struct InlayHintHoverParticipant {
  identity : Unit
}

///|
/// Creates the inlay-hint hover participant.
pub fn InlayHintHoverParticipant::new() -> InlayHintHoverParticipant {
  { identity: () }
}

///|
/// Inlay-hint hovers render after markers and before language markdown hovers.
pub impl HoverParticipant for InlayHintHoverParticipant with fn ordinal(_self) {
  50
}

///|
/// Computes tooltip hovers for injected inlay-hint text.
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
/// Inlay-hint hover data is fully synchronous.
pub impl HoverParticipant for InlayHintHoverParticipant with fn compute_async(
  _self,
  _ctx,
) {
  []
}

///|
/// Coordinates hover participants for one viewer service set.
pub(all) struct ContentHoverComputer {
  services : ViewerServices
}

///|
/// Creates a content-hover computer over viewer services.
pub fn ContentHoverComputer::new(
  services : ViewerServices,
) -> ContentHoverComputer {
  { services, }
}

///|
/// Computes hover parts that are immediately available from viewer state.
pub fn ContentHoverComputer::compute_sync(
  self : ContentHoverComputer,
  document : @model.TextModel,
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
/// Computes hover parts that may require provider calls.
pub async fn ContentHoverComputer::compute_async(
  self : ContentHoverComputer,
  document : @model.TextModel,
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
