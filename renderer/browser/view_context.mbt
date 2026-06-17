///|
/// Shared browser render state passed to view parts during one coordinated
/// render. The public facade remains `Viewer`; browser DOM ownership stays on
/// `View`.
priv struct ViewContext {
  viewer : Viewer
  view : View
}

///|
fn ViewContext::new(viewer : Viewer, view : View) -> ViewContext {
  { viewer, view }
}
