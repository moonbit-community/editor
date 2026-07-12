// Browser fixture for the cursor/input/event parity child. Playwright drives
// actual trusted key and pointer events against the focusable editor root;
// these controls expose only deterministic setup/readback plus the public
// cursor-event stream.

///|
priv struct CursorInputHoverProvider {}

///|
impl @language.HoverProvider for CursorInputHoverProvider with fn provide_hover(
  _self,
  model,
  position,
  _token,
) {
  if position.line_number == 2 && position.column >= 3 && position.column <= 7 {
    Some({
      range: Range(2, 3, 2, 7),
      contents: [PlainText("cursor input hover")],
    })
  } else {
    ignore(model)
    None
  }
}

///|
fn cursor_input_source() -> String {
  let source =
    #|alpha
    #|  beta gamma delta
    #|wrap alpha beta gamma delta epsilon zeta eta theta iota kappa lambda
    #|
    #|  ; punctuation value
    #|line six
    #|line seven
    #|line eight
    #|line nine
    #|line ten
    #|line eleven
    #|omega
  source
}

///|
fn cursor_reason_name(reason : @viewer.CursorChangeReason) -> String {
  match reason {
    NotSet => "NotSet"
    ContentFlush => "ContentFlush"
    RecoverFromMarkers => "RecoverFromMarkers"
    Explicit => "Explicit"
    Paste => "Paste"
    Undo => "Undo"
    Redo => "Redo"
  }
}

///|
fn cursor_input_state_json(
  viewer : @viewer.Viewer,
  model : @model.TextModel,
) -> String {
  match (viewer.get_position(), viewer.get_selection()) {
    (Some(position), Some(selection)) => {
      let anchor = selection.get_selection_start()
      let active = selection.get_position()
      "{" +
      "\"position\":{\"line\":\{position.line_number},\"column\":\{position.column}}," +
      "\"selection\":{" +
      "\"anchorLine\":\{anchor.line_number},\"anchorColumn\":\{anchor.column}," +
      "\"activeLine\":\{active.line_number},\"activeColumn\":\{active.column}}," +
      "\"modelVersionId\":\{model.get_version_id()}," +
      "\"hostVersion\":\{model.version}," +
      "\"hasTextFocus\":\{viewer.has_text_focus()}" +
      "}"
    }
    _ => "null"
  }
}

///|
fn run_cursor_input_events_test() -> Unit {
  let document = @rdom.document()
  guard document.query_selector("#app").to_option() is Some(app) else { return }
  let shell = document.create_element("main")
  shell.set_attribute("class", "editor-shell cursor-input-shell")
  shell.set_attribute("data-theme", "dark")
  shell.set_attribute("style", "height:100vh;display:block;")
  let host = document.create_element("div")
  host.set_attribute("class", "viewer-host cursor-input-host")
  host.set_attribute("style", "height:120px;width:260px;")
  shell.append_child(host.as_node())
  app.append_child(shell.as_node())
  let model = @model.TextModel(
    try! @base_common.Uri::from(
      scheme="inmemory",
      authority="model",
      path="/cursor-input.txt",
    ),
    "cursor-input.txt",
    "plaintext",
    73,
    "cursor-input-rev-1",
    cursor_input_source(),
  )
  let services = @viewer.ViewerServices::new(
    languages=@languages.Languages::new(),
  )
  services.languages.register_hover_provider(LanguageId("plaintext"), CursorInputHoverProvider::{

  })
  |> ignore
  let viewer = @viewer.Viewer::create(
    host,
    services~,
    options=ViewerOptions(soft_wrap=true, smooth_scrolling=false),
  )
  viewer.on_did_change_model_content(event => {
    record_cursor_content_event(event.version_id)
  })
  |> ignore
  viewer.on_did_change_cursor_position(event => {
    let committed = viewer.get_position().unwrap_or(Position(-1, -1))
    record_cursor_position_event(
      event.position.line_number,
      event.position.column,
      committed.line_number,
      committed.column,
      event.secondary_positions.length(),
      event.source,
      cursor_reason_name(event.reason),
    )
  })
  |> ignore
  viewer.on_did_change_cursor_selection(event => {
    let anchor = event.selection.get_selection_start()
    let active = event.selection.get_position()
    let old_selection_count = match event.old_selections {
      Some(selections) => selections.length()
      None => -1
    }
    let (old_anchor_line, old_anchor_column, old_active_line, old_active_column) = match
      event.old_selections {
      Some([old, ..]) => {
        let old_anchor = old.get_selection_start()
        let old_active = old.get_position()
        (
          old_anchor.line_number,
          old_anchor.column,
          old_active.line_number,
          old_active.column,
        )
      }
      _ => (-1, -1, -1, -1)
    }
    let committed = viewer
      .get_selection()
      .unwrap_or(@core.Selection::new(Position(-1, -1), Position(-1, -1)))
    let committed_anchor = committed.get_selection_start()
    let committed_active = committed.get_position()
    record_cursor_selection_event(
      anchor.line_number,
      anchor.column,
      active.line_number,
      active.column,
      event.secondary_selections.length(),
      old_selection_count,
      old_anchor_line,
      old_anchor_column,
      old_active_line,
      old_active_column,
      committed_anchor.line_number,
      committed_anchor.column,
      committed_active.line_number,
      committed_active.column,
      event.old_model_version_id,
      event.model_version_id,
      event.source,
      cursor_reason_name(event.reason),
    )
  })
  |> ignore
  viewer.set_model(Some(model))
  guard viewer.get_dom_node() is Some(root) else { return }
  install_cursor_input_controls(
    root,
    () => cursor_input_state_json(viewer, model),
    (line, column) => viewer.set_position(Position(line, column)),
    (anchor_line, anchor_column, active_line, active_column) => {
      viewer.set_selection(
        @core.Selection::new(
          Position(anchor_line, anchor_column),
          Position(active_line, active_column),
        ),
      )
    },
    value => viewer.set_value(value),
    height => {
      host.set_attribute("style", "height:\{height}px;width:260px;")
      viewer.layout()
    },
    () => viewer.focus(),
  )
}

///|
extern "js" fn record_cursor_content_event(version_id : Int) -> Unit =
  #| (versionId) => {
  #|   (globalThis.__cursorInputEventLog ??= []).push({
  #|     type: 'content',
  #|     versionId,
  #|   });
  #| }

///|
extern "js" fn record_cursor_position_event(
  line : Int,
  column : Int,
  committed_line : Int,
  committed_column : Int,
  secondary_count : Int,
  source : String,
  reason : String,
) -> Unit =
  #| (line, column, committedLine, committedColumn, secondaryCount, source, reason) => {
  #|   (globalThis.__cursorInputEventLog ??= []).push({
  #|     type: 'position', line, column, committedLine, committedColumn,
  #|     secondaryCount, source, reason,
  #|   });
  #| }

///|
extern "js" fn record_cursor_selection_event(
  anchor_line : Int,
  anchor_column : Int,
  active_line : Int,
  active_column : Int,
  secondary_count : Int,
  old_selection_count : Int,
  old_anchor_line : Int,
  old_anchor_column : Int,
  old_active_line : Int,
  old_active_column : Int,
  committed_anchor_line : Int,
  committed_anchor_column : Int,
  committed_active_line : Int,
  committed_active_column : Int,
  old_model_version_id : Int,
  model_version_id : Int,
  source : String,
  reason : String,
) -> Unit =
  #| (anchorLine, anchorColumn, activeLine, activeColumn, secondaryCount,
  #|  oldSelectionCount, oldAnchorLine, oldAnchorColumn, oldActiveLine,
  #|  oldActiveColumn, committedAnchorLine, committedAnchorColumn,
  #|  committedActiveLine, committedActiveColumn, oldModelVersionId,
  #|  modelVersionId, source, reason) => {
  #|   (globalThis.__cursorInputEventLog ??= []).push({
  #|     type: 'selection', anchorLine, anchorColumn, activeLine, activeColumn,
  #|     secondaryCount, oldSelectionCount, oldAnchorLine, oldAnchorColumn,
  #|     oldActiveLine, oldActiveColumn, committedAnchorLine,
  #|     committedAnchorColumn, committedActiveLine, committedActiveColumn,
  #|     oldModelVersionId, modelVersionId, source, reason,
  #|   });
  #| }

///|
extern "js" fn install_cursor_input_controls(
  root : @rdom.Element,
  state_json : () -> String,
  set_position : (Int, Int) -> Unit,
  set_selection : (Int, Int, Int, Int) -> Unit,
  set_value : (String) -> Unit,
  resize : (Int) -> Unit,
  focus : () -> Unit,
) -> Unit =
  #| (root, stateJson, setPosition, setSelection, setValue, resize, focus) => {
  #|   globalThis.__cursorInputEventLog = [];
  #|   const keyLog = [];
  #|   const propagationLog = [];
  #|   const focusLog = [];
  #|   const pointerLog = [];
  #|   let originalRequestAnimationFrame = null;
  #|   let animationFrameCount = 0;
  #|   root.addEventListener('keydown', (event) => {
  #|     keyLog.push({
  #|       key: event.key,
  #|       altKey: event.altKey,
  #|       ctrlKey: event.ctrlKey,
  #|       metaKey: event.metaKey,
  #|       shiftKey: event.shiftKey,
  #|       defaultPrevented: event.defaultPrevented,
  #|       activeIsRoot: document.activeElement === root,
  #|     });
  #|   });
  #|   document.addEventListener('keydown', (event) => {
  #|     if (root.contains(event.target)) {
  #|       propagationLog.push({
  #|         key: event.key,
  #|         defaultPrevented: event.defaultPrevented,
  #|       });
  #|     }
  #|   });
  #|   root.addEventListener('focusin', (event) => {
  #|     focusLog.push({ type: 'focusin', targetClass: event.target?.className ?? '' });
  #|   });
  #|   root.addEventListener('focusout', (event) => {
  #|     focusLog.push({ type: 'focusout', targetClass: event.target?.className ?? '' });
  #|   });
  #|   for (const type of ['mousedown', 'mouseup']) {
  #|     root.addEventListener(type, (event) => {
  #|       pointerLog.push({
  #|         type,
  #|         detail: event.detail,
  #|         shiftKey: event.shiftKey,
  #|         defaultPrevented: event.defaultPrevented,
  #|       });
  #|     });
  #|   }
  #|   globalThis.__cursorInputControls = {
  #|     state: () => JSON.parse(stateJson()),
  #|     events: () => [...globalThis.__cursorInputEventLog],
  #|     keys: () => [...keyLog],
  #|     propagation: () => [...propagationLog],
  #|     focus_events: () => [...focusLog],
  #|     pointers: () => [...pointerLog],
  #|     start_raf_probe: () => {
  #|       if (!originalRequestAnimationFrame) {
  #|         originalRequestAnimationFrame = window.requestAnimationFrame.bind(window);
  #|         window.requestAnimationFrame = (callback) => {
  #|           animationFrameCount += 1;
  #|           return originalRequestAnimationFrame(callback);
  #|         };
  #|       }
  #|       animationFrameCount = 0;
  #|     },
  #|     stop_raf_probe: () => {
  #|       const count = animationFrameCount;
  #|       if (originalRequestAnimationFrame) {
  #|         window.requestAnimationFrame = originalRequestAnimationFrame;
  #|         originalRequestAnimationFrame = null;
  #|       }
  #|       return count;
  #|     },
  #|     clear: () => {
  #|       globalThis.__cursorInputEventLog.length = 0;
  #|       keyLog.length = 0;
  #|       propagationLog.length = 0;
  #|       focusLog.length = 0;
  #|       pointerLog.length = 0;
  #|     },
  #|     set_position: setPosition,
  #|     set_selection: setSelection,
  #|     set_value: setValue,
  #|     resize,
  #|     focus,
  #|     focus_hover: () => {
  #|       const wrapper = document.querySelector('.monaco-resizable-hover');
  #|       if (!wrapper) return false;
  #|       wrapper.style.display = 'block';
  #|       wrapper.setAttribute('tabindex', '-1');
  #|       wrapper.addEventListener('keydown', (event) => {
  #|         keyLog.push({
  #|           key: event.key,
  #|           altKey: event.altKey,
  #|           ctrlKey: event.ctrlKey,
  #|           metaKey: event.metaKey,
  #|           shiftKey: event.shiftKey,
  #|           defaultPrevented: event.defaultPrevented,
  #|           activeIsRoot: false,
  #|           scope: 'hover',
  #|         });
  #|       }, { once: true });
  #|       wrapper.focus();
  #|       return document.activeElement === wrapper;
  #|     },
  #|     root,
  #|   };
  #| }
