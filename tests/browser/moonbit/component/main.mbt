///|
fn main {
  if scroll_perf_requested() {
    run_scroll_perf_test()
  } else {
    run_viewer_api_test()
  }
}

///|
extern "js" fn scroll_perf_requested() -> Bool =
  #| () => new URLSearchParams(location.search).has('scrollPerf')
