///|
/// One renderable contribution to the content hover widget.
pub(all) enum HoverPart {
  MarkdownHover(
    range~ : @base_common.OffsetRange,
    contents~ : Array[@language.HoverContent],
    ordinal~ : Int
  )
  MarkerHover(range~ : @base_common.OffsetRange, marker~ : @markers.Marker)
  LoadingHover(range~ : @base_common.OffsetRange, message~ : String)
} derive(Eq, Debug)

///|
/// Complete hover result after participant parts have been merged and sorted.
pub(all) struct ComputedHover {
  range : @base_common.OffsetRange
  parts : Array[HoverPart]
} derive(Eq, Debug)

///|
/// Inputs shared by synchronous and asynchronous hover participants. Mirrors
/// Monaco's `(anchor, lineDecorations, source)` compute arguments: it carries
/// only the hovered state, never a services bag — participants capture the
/// services they need at construction instead.
pub(all) struct HoverComputeContext {
  model : @model.TextModel
  anchor_range : @base_common.OffsetRange
  offset : Int
  injected_text_index : Int
  inlay_hints : Array[@language.InlayHint]
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
/// The editor-scoped services a hover participant captures at construction, the
/// MoonBit analog of the services Monaco injects into participant constructors
/// (`IMarkerDecorationsService`, `ILanguageFeaturesService`, …). The registry
/// builds participants from this record, so the hover package never depends on
/// the viewer core's `ViewerServices`.
pub(all) struct HoverParticipantServices {
  languages : @languages.Languages
  marker_decorations : @markers.MarkerDecorationsService
  log_service : @log.LogService
}

///|
/// Hover participant that exposes diagnostics/markers at the anchor range.
pub(all) struct MarkerHoverParticipant {
  marker_decorations : @markers.MarkerDecorationsService
}

///|
/// Creates the marker hover participant over the marker decorations service.
pub fn MarkerHoverParticipant::new(
  marker_decorations : @markers.MarkerDecorationsService,
) -> MarkerHoverParticipant {
  { marker_decorations, }
}

///|
/// Marker hovers render first.
pub impl HoverParticipant for MarkerHoverParticipant with fn ordinal(_self) {
  0
}

///|
/// Computes marker hover parts from the current marker decorations.
pub impl HoverParticipant for MarkerHoverParticipant with fn compute_sync(
  self,
  ctx,
) {
  if ctx.injected_text_index >= 0 {
    return []
  }
  let parts : Array[HoverPart] = []
  // Markers carry a line/column `Range`; the offset-based hover widget consumes
  // offset spans, so convert at this boundary through the snapshot. The live
  // markers carry the transform's tracked range, which is what is rendered.
  let snapshot = ctx.model.snapshot
  let query = snapshot.range_of(ctx.anchor_range)
  for entry in self.marker_decorations.get_live_markers(ctx.model.uri) {
    let (range, marker) = entry
    if @base_common.Range::are_intersecting(range, query) ||
      range.contains_position(query.get_start_position()) {
      parts.push(MarkerHover(range=snapshot.offset_range_of(range), marker~))
    }
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
pub(all) struct MarkdownHoverParticipant {
  languages : @languages.Languages
  log_service : @log.LogService
}

///|
/// Creates the markdown hover participant over the language features registry.
pub fn MarkdownHoverParticipant::new(
  languages : @languages.Languages,
  log_service : @log.LogService,
) -> MarkdownHoverParticipant {
  { languages, log_service }
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
  match self.languages.hover_at(ctx.model, ctx.offset, self.log_service) {
    Some(hover) =>
      if hover.contents.length() == 0 {
        []
      } else {
        [
          // Provider hovers carry a line/column `Range`; the offset-based hover
          // widget consumes offset spans, so convert at this boundary.
          MarkdownHover(
            range=ctx.model.snapshot.offset_range_of(hover.range),
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
  participants : Array[&HoverParticipant]
}

///|
/// Creates a content-hover computer, instantiating the registered default
/// participants with the given services — Monaco's
/// `ContentHoverWidgetWrapper._initializeHoverParticipants`.
pub fn ContentHoverComputer::new(
  services : HoverParticipantServices,
) -> ContentHoverComputer {
  { participants: hover_participant_registry.build_all(services) }
}

///|
/// Computes hover parts that are immediately available from viewer state.
pub fn ContentHoverComputer::compute_sync(
  self : ContentHoverComputer,
  model : @model.TextModel,
  anchor_range : @base_common.OffsetRange,
  offset : Int,
  injected_text_index? : Int = -1,
  inlay_hints? : Array[@language.InlayHint] = [],
) -> ComputedHover? {
  let ctx : HoverComputeContext = {
    model,
    anchor_range,
    offset,
    injected_text_index,
    inlay_hints,
  }
  let parts : Array[HoverPart] = []
  for participant in self.participants {
    parts.append(participant.compute_sync(ctx))
  }
  computed_hover_from_parts(anchor_range, parts)
}

///|
/// Computes hover parts that may require provider calls.
pub async fn ContentHoverComputer::compute_async(
  self : ContentHoverComputer,
  model : @model.TextModel,
  anchor_range : @base_common.OffsetRange,
  offset : Int,
  injected_text_index? : Int = -1,
  inlay_hints? : Array[@language.InlayHint] = [],
) -> ComputedHover? noraise {
  let ctx : HoverComputeContext = {
    model,
    anchor_range,
    offset,
    injected_text_index,
    inlay_hints,
  }
  let parts : Array[HoverPart] = []
  for participant in self.participants {
    parts.append(participant.compute_async(ctx))
  }
  computed_hover_from_parts(anchor_range, parts)
}

///|
/// Streams asynchronous hover parts participant by participant, invoking `emit`
/// with each participant's non-empty parts as they resolve. Mirrors Monaco
/// `HoverOperation`'s incremental `computeAsync` consumption: results are fed to
/// the operation as they arrive rather than gathered into a single resolution.
pub async fn ContentHoverComputer::compute_async_each(
  self : ContentHoverComputer,
  model : @model.TextModel,
  anchor_range : @base_common.OffsetRange,
  offset : Int,
  injected_text_index? : Int = -1,
  inlay_hints? : Array[@language.InlayHint] = [],
  emit~ : (Array[HoverPart]) -> Unit,
) -> Unit noraise {
  let ctx : HoverComputeContext = {
    model,
    anchor_range,
    offset,
    injected_text_index,
    inlay_hints,
  }
  for participant in self.participants {
    let parts = participant.compute_async(ctx)
    if parts.length() > 0 {
      emit(parts)
    }
  }
}

///|
/// Union range of accumulated hover parts, falling back to the anchor range when
/// there are none. The offset-based hover widget anchors on this span.
pub fn hover_parts_range(
  parts : Array[HoverPart],
  fallback : @base_common.OffsetRange,
) -> @base_common.OffsetRange {
  let mut range = fallback
  for part in parts {
    range = union_range(range, hover_part_range(part))
  }
  range
}

///|
fn computed_hover_from_parts(
  fallback_range : @base_common.OffsetRange,
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
/// Orders hover parts by participant ordinal, then by start offset. Exposed for
/// the viewer core's hover controller, which merges late-arriving async parts
/// into an already-shown hover.
pub fn compare_hover_parts(left : HoverPart, right : HoverPart) -> Int {
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
fn hover_part_range(part : HoverPart) -> @base_common.OffsetRange {
  match part {
    MarkdownHover(range~, ..) => range
    MarkerHover(range~, ..) => range
    LoadingHover(range~, ..) => range
  }
}

///|
fn union_range(
  left : @base_common.OffsetRange,
  right : @base_common.OffsetRange,
) -> @base_common.OffsetRange {
  left.join(right)
}
