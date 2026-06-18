///|
fn fallback_folding_ranges(
  document : @workspace.DocumentSnapshot,
) -> Array[@language.FoldingRange] {
  if document.language_id == "moonbit" {
    moonbit_indentation_folding_ranges(document)
  } else {
    []
  }
}

///|
fn moonbit_indentation_folding_ranges(
  snapshot : @workspace.DocumentSnapshot,
) -> Array[@language.FoldingRange] {
  let ranges : Array[@language.FoldingRange] = []
  for line_index in 0..<snapshot.line_count() {
    let line = snapshot.line_text(line_index)
    let trimmed = line.trim(char_set=" \t\r\n")
    if trimmed == "" {
      continue
    }
    let next = next_non_empty_line(snapshot, line_index + 1)
    match next {
      Some(next_line_index) => {
        let indent = line_indent(line)
        let next_indent = line_indent(snapshot.line_text(next_line_index))
        let mut end_line_index = -1
        if next_indent > indent {
          end_line_index = indentation_block_end(snapshot, line_index, indent)
        }
        if trimmed.has_suffix("{") {
          let brace_end = brace_block_end(snapshot, line_index, indent)
          if brace_end > end_line_index {
            end_line_index = brace_end
          }
        }
        if end_line_index > line_index {
          ranges.push(FoldingRange(line_index + 1, end_line_index + 1))
        }
      }
      None => ()
    }
  }
  ranges
}

///|
fn next_non_empty_line(
  snapshot : @workspace.DocumentSnapshot,
  start_index : Int,
) -> Int? {
  for index in start_index..<snapshot.line_count() {
    if snapshot.line_text(index).trim(char_set=" \t\r\n") != "" {
      return Some(index)
    }
  }
  None
}

///|
fn indentation_block_end(
  snapshot : @workspace.DocumentSnapshot,
  start_index : Int,
  indent : Int,
) -> Int {
  let mut end_line_index = start_index
  for index in (start_index + 1)..<snapshot.line_count() {
    let text = snapshot.line_text(index)
    let trimmed = text.trim(char_set=" \t\r\n")
    if trimmed == "" {
      continue
    }
    if line_indent(text) <= indent {
      return end_line_index
    }
    end_line_index = index
  }
  end_line_index
}

///|
fn brace_block_end(
  snapshot : @workspace.DocumentSnapshot,
  start_index : Int,
  indent : Int,
) -> Int {
  for index in (start_index + 1)..<snapshot.line_count() {
    let text = snapshot.line_text(index)
    let trimmed = text.trim(char_set=" \t\r\n")
    if trimmed == "" {
      continue
    }
    if line_indent(text) <= indent && trimmed.has_prefix("}") {
      return index
    }
  }
  -1
}

///|
fn line_indent(line : String) -> Int {
  let mut indent = 0
  for index in 0..<line.length() {
    let code = line[index].to_int()
    if code == 32 {
      indent += 1
    } else if code == 9 {
      indent += 2
    } else {
      return indent
    }
  }
  indent
}

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
  markers : MarkerService
  marker_decorations : MarkerDecorationsService
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
  let markers = MarkerService::new()
  let hover_participants = HoverParticipantRegistry::new()
  hover_participants.register(MarkerHoverParticipant::new())
  hover_participants.register(InlayHintHoverParticipant::new())
  hover_participants.register(MarkdownHoverParticipant::new())
  {
    languages,
    markers,
    marker_decorations: MarkerDecorationsService::new(markers),
    hover_participants,
    log_service,
  }
}
