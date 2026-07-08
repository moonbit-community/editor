///|
/// One renderable contribution to the content hover widget.
pub(all) enum HoverPart {
  MarkdownHover(
    range~ : @base_common.Range,
    contents~ : Array[@language.HoverContent],
    ordinal~ : Int
  )
  MarkerHover(range~ : @base_common.Range, marker~ : @markers.Marker)
  LoadingHover(range~ : @base_common.Range, message~ : String)
} derive(Eq, Debug)

///|
/// Complete hover result after participant parts have been merged and sorted.
pub(all) struct ComputedHover {
  range : @base_common.Range
  parts : Array[HoverPart]
} derive(Eq, Debug)

///|
/// Inputs shared by synchronous and asynchronous hover participants. Mirrors
/// Monaco's `(anchor, lineDecorations, source)` compute arguments: it carries
/// only the hovered state, never a services bag — participants capture the
/// services they need at construction instead. (`inlay_hints` backs the
/// foreign anchor's payload lookup; Monaco's anchor carries the rendered
/// hint object itself.)
pub(all) struct HoverComputeContext {
  model : @model.TextModel
  anchor : HoverAnchor
  inlay_hints : Array[@language.InlayHint]
}

///|
/// Pluggable content-hover participant. Synchronous participants provide data
/// already in viewer state; asynchronous participants may call language
/// providers. `suggest_hover_anchor` is Monaco's optional
/// `IEditorHoverParticipant.suggestHoverAnchor(mouseEvent)` — participants
/// without one answer `None`; the viewer resolves the hit position to a
/// collapsed model range at the seam and passes the recorded pointer
/// position alongside.
pub(open) trait HoverParticipant {
  fn ordinal(Self) -> Int noraise
  fn suggest_hover_anchor(
    Self,
    @viewer_common.MouseTarget,
    @base_common.Range,
    Double?,
    Double?,
  ) -> HoverAnchor? noraise
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
/// The marker participant suggests no anchor of its own.
pub impl HoverParticipant for MarkerHoverParticipant with fn suggest_hover_anchor(
  _self,
  _target,
  _target_model_range,
  _initial_mouse_pos_x,
  _initial_mouse_pos_y,
) {
  None
}

///|
/// Computes marker hover parts from the current marker decorations —
/// `computeSync` (`markerHoverParticipant.ts:74-101`) with
/// `ContentHoverComputer._getLineDecorations`'s anchor-line column filter
/// (`contentHoverComputer.ts:29-60`) folded in: the viewer's marker
/// decorations arrive as live `(range, marker)` pairs rather than as line
/// decorations, so the containment check — with the `showIfCollapsed` ±1
/// relaxation; marker decorations always set `showIfCollapsed` — applies
/// here. Part ranges clamp to the anchor's start line, per the source.
pub impl HoverParticipant for MarkerHoverParticipant with fn compute_sync(
  self,
  ctx,
) {
  let anchor = ctx.anchor
  if !(anchor is HoverRangeAnchor(..)) && !anchor.supports_marker_hover() {
    return []
  }
  let anchor_range = anchor.range()
  let line_number = anchor_range.start_line_number
  if line_number > ctx.model.get_line_count() {
    // invalid line (`contentHoverComputer.ts:37-40`)
    return []
  }
  let max_column = ctx.model.get_line_max_column(line_number)
  let parts : Array[HoverPart] = []
  for entry in self.marker_decorations.get_live_markers(ctx.model.uri) {
    let (range, marker) = entry
    // `editor.getLineDecorations(lineNumber)`: only decorations touching the
    // anchor line participate.
    if range.start_line_number > line_number ||
      range.end_line_number < line_number {
      continue
    }
    let start_column = if range.start_line_number == line_number {
      range.start_column
    } else {
      1
    }
    let end_column = if range.end_line_number == line_number {
      range.end_column
    } else {
      max_column
    }
    // Relax check around `showIfCollapsed` decorations to also include +/- 1
    // character (`contentHoverComputer.ts:52-57`).
    if start_column > anchor_range.start_column + 1 ||
      anchor_range.end_column - 1 > end_column {
      continue
    }
    parts.push(
      MarkerHover(
        range=Range(line_number, start_column, line_number, end_column),
        marker~,
      ),
    )
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
/// The markdown participant suggests no anchor of its own.
pub impl HoverParticipant for MarkdownHoverParticipant with fn suggest_hover_anchor(
  _self,
  _target,
  _target_model_range,
  _initial_mouse_pos_x,
  _initial_mouse_pos_y,
) {
  None
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
/// Queries language hover providers at the anchor position — `computeAsync`
/// (`markdownHoverParticipant.ts:168-171`): range anchors only, queried at
/// `anchor.range.getStartPosition()` (the mouse position). The languages
/// registry is offset-addressed, so the conversion happens at this query
/// boundary only.
pub impl HoverParticipant for MarkdownHoverParticipant with fn compute_async(
  self,
  ctx,
) {
  guard ctx.anchor is HoverRangeAnchor(range=anchor_range, ..) else {
    return []
  }
  let offset = ctx.model.get_offset_at(anchor_range.get_start_position())
  match self.languages.hover_at(ctx.model, offset, self.log_service) {
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
pub(all) struct InlayHintsHover {
  identity : Unit
}

///|
/// Creates the inlay-hint hover participant.
pub fn InlayHintsHover::new() -> InlayHintsHover {
  { identity: () }
}

///|
/// Inlay-hint hovers render after markers and before language markdown hovers.
pub impl HoverParticipant for InlayHintsHover with fn ordinal(_self) {
  50
}

///|
/// `InlayHintsHover.suggestHoverAnchor` (`inlayHintsHover.ts:59-72`): a
/// content hit inside injected inlay-hint text anchors a foreign element
/// with the hint as payload — `InlayHintsHoverAnchor`: priority 10,
/// `supportsMarkerHover` true.
pub impl HoverParticipant for InlayHintsHover with fn suggest_hover_anchor(
  _self,
  target,
  target_model_range,
  initial_mouse_pos_x,
  initial_mouse_pos_y,
) {
  if !(target.kind is ContentText) || target.injected_text_index < 0 {
    return None
  }
  Some(
    HoverForeignElementAnchor(
      priority=10,
      injected_text_index=target.injected_text_index,
      range=target_model_range,
      initial_mouse_pos_x~,
      initial_mouse_pos_y~,
      supports_marker_hover=true,
    ),
  )
}

///|
/// Computes tooltip hovers for injected inlay-hint text — gated on this
/// participant's own foreign anchor, Monaco's `anchor instanceof
/// InlayHintsHoverAnchor` (`inlayHintsHover.ts:79`; the tooltip itself is
/// local viewer state, so the compute stays synchronous — recorded
/// deviation).
pub impl HoverParticipant for InlayHintsHover with fn compute_sync(self, ctx) {
  guard ctx.anchor
    is HoverForeignElementAnchor(injected_text_index~, range=anchor_range, ..) else {
    return []
  }
  match ctx.inlay_hints.get(injected_text_index) {
    Some(hint) =>
      if hint.tooltip.length() == 0 {
        []
      } else {
        [
          MarkdownHover(
            range=anchor_range,
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
pub impl HoverParticipant for InlayHintsHover with fn compute_async(_self, _ctx) {
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
  anchor : HoverAnchor,
  inlay_hints? : Array[@language.InlayHint] = [],
) -> ComputedHover? {
  let ctx : HoverComputeContext = { model, anchor, inlay_hints }
  let parts : Array[HoverPart] = []
  for participant in self.participants {
    parts.append(participant.compute_sync(ctx))
  }
  computed_hover_from_parts(anchor.range(), parts)
}

///|
/// Computes hover parts that may require provider calls.
pub async fn ContentHoverComputer::compute_async(
  self : ContentHoverComputer,
  model : @model.TextModel,
  anchor : HoverAnchor,
  inlay_hints? : Array[@language.InlayHint] = [],
) -> ComputedHover? noraise {
  let ctx : HoverComputeContext = { model, anchor, inlay_hints }
  let parts : Array[HoverPart] = []
  for participant in self.participants {
    parts.append(participant.compute_async(ctx))
  }
  computed_hover_from_parts(anchor.range(), parts)
}

///|
/// Streams asynchronous hover parts participant by participant, invoking `emit`
/// with each participant's non-empty parts as they resolve. Mirrors Monaco
/// `HoverOperation`'s incremental `computeAsync` consumption: results are fed to
/// the operation as they arrive rather than gathered into a single resolution.
pub async fn ContentHoverComputer::compute_async_each(
  self : ContentHoverComputer,
  model : @model.TextModel,
  anchor : HoverAnchor,
  inlay_hints? : Array[@language.InlayHint] = [],
  emit~ : (Array[HoverPart]) -> Unit,
) -> Unit noraise {
  let ctx : HoverComputeContext = { model, anchor, inlay_hints }
  for participant in self.participants {
    let parts = participant.compute_async(ctx)
    if parts.length() > 0 {
      emit(parts)
    }
  }
}

///|
/// Union range of accumulated hover parts, falling back to the anchor range
/// when there are none. The hover widget anchors on this span.
pub fn hover_parts_range(
  parts : Array[HoverPart],
  fallback : @base_common.Range,
) -> @base_common.Range {
  let mut range = fallback
  for part in parts {
    range = union_range(range, hover_part_range(part))
  }
  range
}

///|
fn computed_hover_from_parts(
  fallback_range : @base_common.Range,
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
    @base_common.Range::compare_ranges_using_starts(
      hover_part_range(left),
      hover_part_range(right),
    )
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
fn union_range(
  left : @base_common.Range,
  right : @base_common.Range,
) -> @base_common.Range {
  @base_common.Range::plus_range(left, right)
}
