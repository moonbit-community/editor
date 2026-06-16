///|
/// Scroll geometry, the Monaco `Scrollable` role: viewport size plus
/// content size, both backend-neutral pixels. `scroll_width` and
/// `scroll_height` are the scrollable content extents and never report
/// smaller than the viewport.
pub(all) struct ScrollDimensions {
  width : Double
  scroll_width : Double
  height : Double
  scroll_height : Double
} derive(Eq, Debug)

///|
pub(all) struct ScrollPosition {
  scroll_left : Double
  scroll_top : Double
} derive(Eq, Debug)

///|
/// A scroll state change, Monaco's `ScrollEvent` role as plain data: the
/// settled position plus what moved, so a view can decide what to repaint
/// without owning scroll state itself.
pub(all) struct ScrollChange {
  position : ScrollPosition
  delta_left : Double
  delta_top : Double
  left_changed : Bool
  top_changed : Bool
  dimensions_changed : Bool
} derive(Eq, Debug)

///|
/// The single owner of scroll truth (synthetic scrolling): dimensions and
/// a position always clamped inside them. Mutations answer with a
/// `ScrollChange` fact when anything moved, `None` when the request was a
/// no-op after clamping.
pub struct Scrollable {
  priv mut dimensions : ScrollDimensions
  priv mut position : ScrollPosition
}

///|
pub fn Scrollable::new() -> Scrollable {
  {
    dimensions: {
      width: 0.0,
      scroll_width: 0.0,
      height: 0.0,
      scroll_height: 0.0,
    },
    position: { scroll_left: 0.0, scroll_top: 0.0 },
  }
}

///|
pub fn Scrollable::dimensions(self : Scrollable) -> ScrollDimensions {
  self.dimensions
}

///|
pub fn Scrollable::position(self : Scrollable) -> ScrollPosition {
  self.position
}

///|
/// Replaces the dimensions and re-clamps the position into them.
pub fn Scrollable::set_dimensions(
  self : Scrollable,
  dimensions : ScrollDimensions,
) -> ScrollChange? {
  let normalized : ScrollDimensions = {
    width: max_double(dimensions.width, 0.0),
    scroll_width: max_double(
      dimensions.scroll_width,
      max_double(dimensions.width, 0.0),
    ),
    height: max_double(dimensions.height, 0.0),
    scroll_height: max_double(
      dimensions.scroll_height,
      max_double(dimensions.height, 0.0),
    ),
  }
  let dimensions_changed = normalized != self.dimensions
  if !dimensions_changed {
    return None
  }
  self.dimensions = normalized
  let clamped = clamp_position(normalized, self.position)
  self.change_to(clamped, dimensions_changed=true)
}

///|
/// Moves to the requested position, clamped inside the dimensions.
pub fn Scrollable::set_position(
  self : Scrollable,
  position : ScrollPosition,
) -> ScrollChange? {
  self.change_to(
    clamp_position(self.dimensions, position),
    dimensions_changed=false,
  )
}

///|
/// Applies a wheel-style relative scroll.
pub fn Scrollable::scroll_by(
  self : Scrollable,
  delta_left? : Double = 0.0,
  delta_top? : Double = 0.0,
) -> ScrollChange? {
  self.set_position({
    scroll_left: self.position.scroll_left + delta_left,
    scroll_top: self.position.scroll_top + delta_top,
  })
}

///|
fn Scrollable::change_to(
  self : Scrollable,
  position : ScrollPosition,
  dimensions_changed~ : Bool,
) -> ScrollChange? {
  let previous = self.position
  let left_changed = position.scroll_left != previous.scroll_left
  let top_changed = position.scroll_top != previous.scroll_top
  if !left_changed && !top_changed && !dimensions_changed {
    return None
  }
  self.position = position
  Some({
    position,
    delta_left: position.scroll_left - previous.scroll_left,
    delta_top: position.scroll_top - previous.scroll_top,
    left_changed,
    top_changed,
    dimensions_changed,
  })
}

///|
fn clamp_position(
  dimensions : ScrollDimensions,
  position : ScrollPosition,
) -> ScrollPosition {
  {
    scroll_left: clamp_double(
      position.scroll_left,
      0.0,
      dimensions.scroll_width - dimensions.width,
    ),
    scroll_top: clamp_double(
      position.scroll_top,
      0.0,
      dimensions.scroll_height - dimensions.height,
    ),
  }
}

///|
fn clamp_double(value : Double, low : Double, high : Double) -> Double {
  if high < low {
    low
  } else if value < low {
    low
  } else if value > high {
    high
  } else {
    value
  }
}

///|
fn max_double(left : Double, right : Double) -> Double {
  if left > right {
    left
  } else {
    right
  }
}
