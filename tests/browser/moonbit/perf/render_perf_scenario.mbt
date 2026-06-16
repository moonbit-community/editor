///|
priv struct PerfDocumentSource {
  small_text : String
  large_text : String
}

///|
impl @workspace.DocumentSource for PerfDocumentSource with fn open_document(
  self,
  uri,
) {
  let text = if uri.to_string().contains("large") {
    self.large_text
  } else {
    self.small_text
  }
  SourceDocumentLoaded(
    @workspace.SourceDocument::from_file_content(
      uri,
      FileContent(text, display_name=uri.display_name()),
    ),
  )
}

///|
impl @workspace.DocumentSource for PerfDocumentSource with fn watch_document(
  _self,
  _uri,
  _listener,
) {
  { dispose: () => () }
}

///|
impl @workspace.DocumentSource for PerfDocumentSource with fn close_document(
  _self,
  _uri,
) {

}

///|
fn run_render_perf_test() -> Unit {
  @browser.register_tokenizer("moonbit", @lang_moonbit.MoonbitTokenizer::new())
  let ctx = @support.BrowserTestContext::new("viewer_render_perf")
  let done = Ref(false)
  let sample_index = Ref(-1)
  let sample_start = Ref(0.0)
  let samples : Array[Double] = []
  let source : PerfDocumentSource = {
    small_text: small_source_text(),
    large_text: large_source_text(2000),
  }
  let viewer_ref : Ref[@browser.Viewer?] = Ref(None)
  match mount_host() {
    Some(host) => {
      let viewer = @browser.Viewer(
        source,
        on_notification=notification => {
          match notification {
            ViewerDocumentRendered(document, fresh~, ..) =>
              if fresh && document.uri.to_string().contains("large") {
                record_sample(
                  ctx, viewer_ref, done, sample_index, sample_start, samples,
                )
              }
            ViewerDocumentFailed(error) =>
              ctx.fail("viewer failed to open perf document: " + error.message)
            _ => ()
          }
        },
        placeholder="Loading performance fixture...",
      )
      viewer_ref.val = Some(viewer)
      viewer.attach(host)
      @support.set_timeout(
        () => run_next_sample(viewer, sample_index, sample_start),
        50,
      )
      @support.set_timeout(
        () => {
          if !done.val {
            ctx.fail("timed out waiting for perf samples")
            done.val = true
            ctx.finish()
          }
        },
        15000,
      )
    }
    None => {
      ctx.fail("missing #app mount point")
      ctx.finish()
    }
  }
}

///|
fn mount_host() -> @rdom.Element? {
  let document = @rdom.document()
  match document.query_selector("#app").to_option() {
    Some(app) => {
      let shell = document.create_element("main")
      shell.set_attribute("class", "editor-shell")
      shell.set_attribute("data-theme", "dark")
      shell.set_attribute("style", "height:100vh;display:block;")
      let host = document.create_element("div")
      host.set_attribute("class", "viewer-host")
      host.set_attribute("style", "height:100vh;")
      shell.append_child(host.as_node())
      app.append_child(shell.as_node())
      Some(host)
    }
    None => None
  }
}

///|
fn run_next_sample(
  viewer : @browser.Viewer,
  sample_index : Ref[Int],
  sample_start : Ref[Double],
) -> Unit {
  sample_start.val = @support.now_ms()
  let name = if sample_index.val < 0 {
    "warmup"
  } else {
    "sample_" + sample_index.val.to_string()
  }
  viewer.open(@workspace.DocumentUri::memory("perf/large_" + name + ".mbt"))
}

///|
fn record_sample(
  ctx : @support.BrowserTestContext,
  viewer_ref : Ref[@browser.Viewer?],
  done : Ref[Bool],
  sample_index : Ref[Int],
  sample_start : Ref[Double],
  samples : Array[Double],
) -> Unit {
  if done.val {
    return
  }
  let elapsed = @support.now_ms() - sample_start.val
  if sample_index.val >= 0 {
    samples.push(elapsed)
  }
  sample_index.val = sample_index.val + 1
  if sample_index.val >= 3 {
    finish_perf_report(ctx, done, samples)
  } else {
    match viewer_ref.val {
      Some(viewer) =>
        @support.set_timeout(
          () => run_next_sample(viewer, sample_index, sample_start),
          50,
        )
      None => {
        ctx.fail("viewer reference was not initialized")
        done.val = true
        ctx.finish()
      }
    }
  }
}

///|
fn finish_perf_report(
  ctx : @support.BrowserTestContext,
  done : Ref[Bool],
  samples : Array[Double],
) -> Unit {
  if samples.length() != 3 {
    ctx.fail("expected 3 measured samples, got " + samples.length().to_string())
  }
  let (best, median, worst) = sample_summary(samples)
  ctx.metric_int("warmupCount", 1)
  ctx.metric_int("sampleCount", samples.length())
  ctx.metric(
    "samples",
    Json::array(samples.map(sample => Json::number(sample))),
  )
  ctx.metric_number("bestMs", best)
  ctx.metric_number("medianMs", median)
  ctx.metric_number("p95Ms", worst)
  ctx.metric_number("worstMs", worst)
  done.val = true
  ctx.finish()
}

///|
fn sample_summary(samples : Array[Double]) -> (Double, Double, Double) {
  if samples.length() == 0 {
    return (0.0, 0.0, 0.0)
  }
  let mut best = samples[0]
  let mut worst = samples[0]
  for sample in samples {
    if sample < best {
      best = sample
    }
    if sample > worst {
      worst = sample
    }
  }
  let median = if samples.length() == 3 {
    samples[0] + samples[1] + samples[2] - best - worst
  } else {
    samples[samples.length() / 2]
  }
  (best, median, worst)
}

///|
fn small_source_text() -> String {
  (
    #|///|
    #|pub fn small_value() -> Int {
    #|  1
    #|}
    #|
  )
}

///|
fn large_source_text(count : Int) -> String {
  let builder = StringBuilder()
  for index in 0..<count {
    builder.write_string("///|\n")
    builder.write_string("pub fn perf_value_")
    builder.write_string(index.to_string())
    builder.write_string("() -> Int {\n  ")
    builder.write_string(index.to_string())
    builder.write_string("\n}\n\n")
  }
  builder.to_string()
}
