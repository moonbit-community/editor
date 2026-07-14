///|
/// The Monaco-shaped option identifiers that view parts query from
/// `ViewConfigurationChangedEvent.hasChanged`.  The root `Viewer` maps its
/// concrete option diffs to this semantic set; view parts never need to know
/// about the root option record.
pub(all) enum ViewConfigurationOption {
  LayoutInfo
  FontInfo
  LineHeight
  WrappingInfo
  RevealHorizontalRightPadding
  CursorSurroundingLines
  CursorSurroundingLinesStyle
  DisableLayerHinting
  StickyScroll
  RenderWhitespace
  RenderControlCharacters
  RenderLineHighlight
  RenderLineHighlightOnlyWhenFocus
  RenderValidationDecorations
  ReadOnly
  CursorBlinking
  EffectiveCursorStyle
  CursorSmoothCaretAnimation
  EffectiveEditContext
} derive(Eq, Debug)

///|
/// Source-shaped configuration payload.  `changed_options` is a typed bitset
/// represented as a deduplicated array because the readonly viewer has a
/// deliberately small option surface.
pub(all) struct ViewConfigurationChangedEvent {
  changed_options : Array[ViewConfigurationOption]
}

///|
pub fn ViewConfigurationChangedEvent::from_changed_options(
  changed_options : Array[ViewConfigurationOption],
) -> ViewConfigurationChangedEvent {
  let result : Array[ViewConfigurationOption] = []
  for option in changed_options {
    if !view_configuration_options_contain(result, option) {
      result.push(option)
    }
  }
  { changed_options: result }
}

///|
pub fn ViewConfigurationChangedEvent::has_changed(
  self : ViewConfigurationChangedEvent,
  option : ViewConfigurationOption,
) -> Bool {
  view_configuration_options_contain(self.changed_options, option)
}

///|
fn view_configuration_options_contain(
  options : Array[ViewConfigurationOption],
  expected : ViewConfigurationOption,
) -> Bool {
  for option in options {
    if option == expected {
      return true
    }
  }
  false
}

///|
/// `ViewCursorStateChangedEvent`: view-space selections, model-space
/// selections, and the originating cursor reason are kept separate exactly as
/// in the source event.
pub(all) struct ViewCursorStateChangedEvent {
  selections : Array[@core.Selection]
  model_selections : Array[@core.Selection]
  reason : @cursor.CursorChangeReason
}

///|
pub fn ViewCursorStateChangedEvent::ViewCursorStateChangedEvent(
  selections : Array[@core.Selection],
  model_selections : Array[@core.Selection],
  reason : @cursor.CursorChangeReason,
) -> ViewCursorStateChangedEvent {
  { selections, model_selections, reason }
}

///|
/// `ViewDecorationsChangedEvent`.  A producer without source detail must use
/// `all`, matching Monaco's null-source constructor which conservatively sets
/// every flag.
pub(all) struct ViewDecorationsChangedEvent {
  affects_minimap : Bool
  affects_overview_ruler : Bool
  affects_glyph_margin : Bool
  affects_line_number : Bool
}

///|
pub fn ViewDecorationsChangedEvent::ViewDecorationsChangedEvent(
  affects_minimap : Bool,
  affects_overview_ruler : Bool,
  affects_glyph_margin : Bool,
  affects_line_number : Bool,
) -> ViewDecorationsChangedEvent {
  {
    affects_minimap,
    affects_overview_ruler,
    affects_glyph_margin,
    affects_line_number,
  }
}

///|
pub fn ViewDecorationsChangedEvent::all() -> ViewDecorationsChangedEvent {
  {
    affects_minimap: true,
    affects_overview_ruler: true,
    affects_glyph_margin: true,
    affects_line_number: true,
  }
}

///|
pub(all) struct ViewFocusChangedEvent {
  is_focused : Bool
}

///|
pub fn ViewFocusChangedEvent::ViewFocusChangedEvent(
  is_focused : Bool,
) -> ViewFocusChangedEvent {
  { is_focused, }
}

///|
/// The changed view-line interval is `[from_line_number,
/// from_line_number + count - 1]` (inclusive), matching Monaco.
pub(all) struct ViewLinesChangedEvent {
  from_line_number : Int
  count : Int
}

///|
pub fn ViewLinesChangedEvent::ViewLinesChangedEvent(
  from_line_number : Int,
  count : Int,
) -> ViewLinesChangedEvent {
  { from_line_number, count }
}

///|
pub(all) struct ViewLinesDeletedEvent {
  from_line_number : Int
  to_line_number : Int
}

///|
pub fn ViewLinesDeletedEvent::ViewLinesDeletedEvent(
  from_line_number : Int,
  to_line_number : Int,
) -> ViewLinesDeletedEvent {
  { from_line_number, to_line_number }
}

///|
pub(all) struct ViewLinesInsertedEvent {
  from_line_number : Int
  to_line_number : Int
}

///|
pub fn ViewLinesInsertedEvent::ViewLinesInsertedEvent(
  from_line_number : Int,
  to_line_number : Int,
) -> ViewLinesInsertedEvent {
  { from_line_number, to_line_number }
}

///|
/// Exact `ViewScrollChangedEvent` payload.  Values are always the new scroll
/// state; each axis/dimension carries its own changed flag so handlers cannot
/// accidentally conflate independent source branches.
pub(all) struct ViewScrollChangedEvent {
  scroll_width : Double
  scroll_left : Double
  scroll_height : Double
  scroll_top : Double
  scroll_width_changed : Bool
  scroll_left_changed : Bool
  scroll_height_changed : Bool
  scroll_top_changed : Bool
}

///|
pub fn ViewScrollChangedEvent::ViewScrollChangedEvent(
  scroll_width : Double,
  scroll_left : Double,
  scroll_height : Double,
  scroll_top : Double,
  scroll_width_changed : Bool,
  scroll_left_changed : Bool,
  scroll_height_changed : Bool,
  scroll_top_changed : Bool,
) -> ViewScrollChangedEvent {
  {
    scroll_width,
    scroll_left,
    scroll_height,
    scroll_top,
    scroll_width_changed,
    scroll_left_changed,
    scroll_height_changed,
    scroll_top_changed,
  }
}

///|
pub(all) struct ViewThemeChangedEvent {
  theme : String
}

///|
pub fn ViewThemeChangedEvent::ViewThemeChangedEvent(
  theme : String,
) -> ViewThemeChangedEvent {
  { theme, }
}

///|
/// Inclusive line range carried by `ViewTokensChangedEvent`.
pub(all) struct ViewTokenChangeRange {
  from_line_number : Int
  to_line_number : Int
}

///|
pub fn ViewTokenChangeRange::ViewTokenChangeRange(
  from_line_number : Int,
  to_line_number : Int,
) -> ViewTokenChangeRange {
  { from_line_number, to_line_number }
}

///|
pub(all) struct ViewTokensChangedEvent {
  ranges : Array[ViewTokenChangeRange]
}

///|
pub fn ViewTokensChangedEvent::ViewTokensChangedEvent(
  ranges : Array[ViewTokenChangeRange],
) -> ViewTokensChangedEvent {
  { ranges, }
}

///|
/// Closed, source-shaped readonly-view event union.  Composition and theme
/// events are intentionally declaration/dispatch-only in this package: their
/// concrete producers belong to later input/theme seams.  Language
/// configuration, reveal-range, and token-color events remain outside the
/// approved readonly slice.
pub(all) enum ViewEvent {
  ViewCompositionStart
  ViewCompositionEnd
  ViewConfigurationChanged(ViewConfigurationChangedEvent)
  ViewCursorStateChanged(ViewCursorStateChangedEvent)
  ViewDecorationsChanged(ViewDecorationsChangedEvent)
  ViewFlushed
  ViewFocusChanged(ViewFocusChangedEvent)
  ViewLineMappingChanged
  ViewLinesChanged(ViewLinesChangedEvent)
  ViewLinesDeleted(ViewLinesDeletedEvent)
  ViewLinesInserted(ViewLinesInsertedEvent)
  ViewScrollChanged(ViewScrollChangedEvent)
  ViewThemeChanged(ViewThemeChangedEvent)
  ViewTokensChanged(ViewTokensChangedEvent)
  ViewZonesChanged
}
