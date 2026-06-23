///|
/// Typed view events, the readonly-viewer subset of Monaco's `viewEvents.ts`.
/// View parts are `ViewEventHandler`s (see `view_part.mbt`): each event is
/// dispatched to every part, which returns whether the event dirties it. This
/// replaces the previous `ViewRenderChange` snapshot-diff struct that parts
/// inspected directly.
///
/// Deliberate deviations from Monaco recorded here: events are *sourced* by
/// diffing one frame snapshot against the previous (`view_events_from_snapshots`)
/// rather than emitted incrementally by an event-emitting view model — the
/// readonly view model is frame-based, and Phase 3's cursor stack will add a
/// second, direct emission path for `ViewCursorStateChanged`. The event set is
/// the subset this viewer observes; composition/focus/theme/language and the
/// fine-grained line insert/delete events have no readonly counterpart yet.
pub(all) enum ViewEvent {
  /// Everything must re-render (Monaco `ViewFlushedEvent`). Emitted on the
  /// first frame.
  ViewFlushed
  /// Line content/tokens (and, for now, decorations) were regenerated
  /// (Monaco `ViewLinesChangedEvent` / `ViewTokensChangedEvent`).
  ViewLinesChanged
  /// Scroll position, scrollable dimensions, or the rendered line window
  /// changed (Monaco `ViewScrollChangedEvent`).
  ViewScrollChanged(ViewScrollChangedEvent)
  /// The selection changed (Monaco `ViewCursorStateChangedEvent`).
  ViewCursorStateChanged
  /// A layout/font configuration input changed (Monaco
  /// `ViewConfigurationChangedEvent`).
  ViewConfigurationChanged(ViewConfigurationChangedEvent)
  /// The model→view line mapping changed, e.g. folding (Monaco
  /// `ViewLineMappingChangedEvent`).
  ViewLineMappingChanged
  /// View zones changed (Monaco `ViewZonesChangedEvent`).
  ViewZonesChanged
} derive(Eq, Debug)

///|
/// Payload for `ViewScrollChanged`. Mirrors Monaco's `ViewScrollChangedEvent`
/// change flags; `window_changed` is the local rendered-line-window shift
/// (a viewer-side windowing concern with no separate Monaco field).
pub(all) struct ViewScrollChangedEvent {
  position_changed : Bool
  dimensions_changed : Bool
  window_changed : Bool
} derive(Eq, Debug)

///|
/// Payload for `ViewConfigurationChanged`. Mirrors the `hasChanged(option)`
/// queries Monaco view parts make against `ViewConfigurationChangedEvent`,
/// reduced to the inputs this viewer's parts consult.
pub(all) struct ViewConfigurationChangedEvent {
  gutter_width_changed : Bool
  font_changed : Bool
} derive(Eq, Debug)

///|
/// Derives the typed view events for one frame by comparing the new render
/// snapshot against the previous one. This is the frame-based event *source*;
/// the dispatch contract the parts see (typed events, accumulate `should_render`)
/// is faithful to Monaco. Hover is intentionally not a view event — the hover
/// content widget is invalidated directly, mirroring Monaco's contrib hover.
fn view_events_from_snapshots(
  previous : ViewRenderSnapshot?,
  current : ViewRenderSnapshot,
) -> Array[ViewEvent] {
  match previous {
    None => [ViewFlushed]
    Some(previous) => {
      let events : Array[ViewEvent] = []
      if previous.generation != current.generation {
        events.push(ViewLinesChanged)
      }
      let position_changed = previous.position != current.position
      let dimensions_changed = previous.dimensions != current.dimensions
      let window_changed = previous.window != current.window
      if position_changed || dimensions_changed || window_changed {
        events.push(
          ViewScrollChanged({ position_changed, dimensions_changed, window_changed }),
        )
      }
      if previous.selection_view_range != current.selection_view_range {
        events.push(ViewCursorStateChanged)
      }
      let gutter_width_changed = previous.gutter_width != current.gutter_width
      let font_changed = previous.space_width != current.space_width
      if gutter_width_changed || font_changed {
        events.push(ViewConfigurationChanged({ gutter_width_changed, font_changed }))
      }
      if previous.folding_ranges != current.folding_ranges ||
        previous.folded_ranges != current.folded_ranges {
        events.push(ViewLineMappingChanged)
      }
      if !same_browser_view_zones(
          previous.browser_view_zones,
          current.browser_view_zones,
        ) {
        events.push(ViewZonesChanged)
      }
      events
    }
  }
}

///|
/// Whether the hover content changed between frames; the hover widget is
/// invalidated directly rather than through a view event (Monaco's hover is a
/// contrib content widget, not a view-event participant).
fn hover_changed_between(
  previous : ViewRenderSnapshot?,
  current : ViewRenderSnapshot,
) -> Bool {
  match previous {
    None => true
    Some(previous) => previous.hover_state != current.hover_state
  }
}
