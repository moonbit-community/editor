///|
/// Small integer clamping helpers shared across the viewer core. (Each viewer
/// sub-package that needs these keeps its own copy, as the common layer is
/// acyclic and these are trivial.)
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
