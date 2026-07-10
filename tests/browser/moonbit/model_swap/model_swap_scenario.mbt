// Pins the per-model `View` lifecycle across `set_model` (Monaco's
// `setModel` → `_detachModel` → `_attachModel`, `codeEditorWidget.ts:506`):
// the old view's DOM subtree leaves the container, exactly one editor root
// exists per attached model, `data-uri` / `data-mode-id` are stamped,
// registered view zones re-appear on the new view, text focus carries
// across the swap (`cew:528-532`), and detaching to no model restores the
// Viewer-owned placeholder.

///|
/// Whether the document's active element is the given selector's first
/// match (no `document.activeElement` binding in the vendored `@rdom`).
extern "js" fn active_element_matches(selector : String) -> Bool =
  #| (selector) => {
  #|   const el = document.querySelector(selector);
  #|   return !!el && document.activeElement === el;
  #| }

///|
fn swap_model(name : String, marker : String) -> @model.TextModel {
  let lines = StringBuilder()
  lines.write_string(marker)
  for index in 1..<40 {
    lines.write_char('\n')
    lines.write_string("line_\{index}_of_\{name}")
  }
  TextModel(
    try! @base_common.Uri::from(
      scheme="inmemory",
      authority="model",
      path="/" + name,
    ),
    name,
    "plaintext",
    1,
    "swap-rev-\{name}",
    lines.to_string(),
  )
}

///|
fn run_model_swap_test() -> Unit {
  let ctx = @support.BrowserTestContext::new("model_swap")
  let document = @rdom.document()
  guard document.query_selector("#app").to_option() is Some(app) else {
    ctx.fail("missing #app mount point")
    ctx.finish()
    return
  }
  let host = document.create_element("div")
  host.set_attribute("class", "viewer-host")
  host.set_attribute("style", "height:200px;width:400px;")
  app.append_child(host.as_node())
  let viewer = @viewer.Viewer::create(
    host,
    options=ViewerOptions(placeholder="swap-placeholder"),
  )
  let model_a = swap_model("swap-a.txt", "alpha_document_marker")
  let model_b = swap_model("swap-b.txt", "beta_document_marker")
  viewer.set_model(Some(model_a))
  viewer.focus()
  let zone = document.create_element("div")
  zone.set_inner_html("swap view zone")
  viewer.change_view_zones(accessor => {
    accessor.add_zone("swap-zone", 1, 24, zone)
  })
  wait_for_text(ctx, "alpha_document_marker", 80, () => {
    // One editor root per attached model; the placeholder left the container.
    ctx.assert_true(
      @support.query_count(".viewer-host > .monaco-editor") == 1,
      "expected exactly one editor root for model A",
    )
    ctx.assert_true(
      @support.query_attribute(".viewer-host > .monaco-editor", "data-uri") ==
      model_a.uri.to_string(),
      "data-uri not stamped for model A",
    )
    ctx.assert_true(
      @support.query_attribute(".viewer-host", "data-mode-id") == "plaintext",
      "data-mode-id not stamped on the container",
    )
    ctx.assert_true(
      @support.query_count(".view-zone[data-view-zone-id=\"swap-zone\"]") == 1,
      "view zone missing on the first view",
    )
    // Swap: the whole view is rebuilt (Monaco's detach-then-attach).
    viewer.set_model(Some(model_b))
    model_a.dispose()
    wait_for_text(ctx, "beta_document_marker", 80, () => {
      ctx.assert_true(
        @support.query_count(".viewer-host > .monaco-editor") == 1,
        "old view DOM survived the swap",
      )
      ctx.assert_true(
        @support.query_attribute(".viewer-host > .monaco-editor", "data-uri") ==
        model_b.uri.to_string(),
        "data-uri not restamped for model B",
      )
      ctx.assert_true(
        @support.query_count(".view-zone[data-view-zone-id=\"swap-zone\"]") == 1,
        "view zone did not re-appear on the new view",
      )
      // Text focus carries across the swap (`cew:528-532`).
      ctx.assert_true(
        viewer.has_text_focus(),
        "editor lost text focus across the swap",
      )
      ctx.assert_true(
        active_element_matches(".viewer-host > .monaco-editor"),
        "DOM focus is not on the new view root",
      )
      // Detach to no model: the Viewer-owned placeholder returns.
      viewer.set_model(None)
      model_b.dispose()
      wait_for_text(ctx, "swap-placeholder", 80, () => {
        ctx.assert_true(
          @support.query_count(".viewer-host > .monaco-editor.source-empty") ==
          1,
          "placeholder did not return after detach",
        )
        ctx.assert_true(
          @support.query_count(".viewer-host [data-uri]") == 0,
          "a per-model view survived the detach",
        )
        ctx.assert_true(
          @support.query_attribute(".viewer-host", "data-mode-id") == "",
          "data-mode-id survived the detach",
        )
        ctx.assert_true(
          viewer.has_text_focus() == false,
          "editor still reports text focus with no model",
        )
        ctx.finish()
      })
    })
  })
}

///|
/// Polls until the editor surface contains `needle`, then runs `body`.
fn wait_for_text(
  ctx : @support.BrowserTestContext,
  needle : String,
  remaining : Int,
  body : () -> Unit,
) -> Unit {
  if @support.query_text(".viewer-host").contains(needle) {
    body()
    return
  }
  if remaining <= 0 {
    ctx.fail(
      "timed out waiting for text: " +
      needle +
      " (saw: " +
      @support.query_text(".viewer-host") +
      ")",
    )
    ctx.finish()
    return
  }
  @support.set_timeout(
    () => wait_for_text(ctx, needle, remaining - 1, body),
    50,
  )
}
