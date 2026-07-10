///|
fn main {
  if async_features_requested() {
    run_async_model_features_test()
  } else if scroll_perf_requested() {
    run_scroll_perf_test()
  } else {
    run_viewer_api_test()
  }
}

///|
extern "js" fn async_features_requested() -> Bool =
  #| () => new URLSearchParams(location.search).has('asyncFeatures')

///|
extern "js" fn scroll_perf_requested() -> Bool =
  #| () => new URLSearchParams(location.search).has('scrollPerf')
