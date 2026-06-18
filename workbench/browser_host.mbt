///|
/// Installs browser globals used by the reference app and Playwright harness.
extern "js" fn install_host_capabilities() -> Unit =
  #| () => {
  #|   if (typeof globalThis.__readonlyEditorEvent !== "function") {
  #|     globalThis.__readonlyEditorEvent = (name, payload) => {
  #|       // Log the raw JSON string: console object previews truncate
  #|       // after a handful of properties, which silently drops payload
  #|       // keys from harness transcripts.
  #|       console.info("[readonly-editor]", name, payload);
  #|     };
  #|   }
  #| }

///|
/// Publishes the current model JSON on harness globals.
extern "js" fn set_current_model(payload : String) -> Unit =
  #| (payload) => {
  #|   try {
  #|     const model = JSON.parse(payload);
  #|     globalThis.__readonlyEditorModel = model;
  #|     globalThis.__readonlyEditorDocument = model;
  #|     globalThis.__readonlyEditorSource = typeof model.text === "string" ? model.text : "";
  #|   } catch (error) {
  #|     console.error("[readonly-editor]", "model:state-error", error);
  #|   }
  #| }

///|
/// WebSocket endpoint for the current page's native remote protocol server.
extern "js" fn protocol_websocket_url() -> String =
  #| () => {
  #|   const location = globalThis.location;
  #|   const protocol = location?.protocol === "https:" ? "wss:" : "ws:";
  #|   const host = location?.host || "127.0.0.1:5173";
  #|   return `${protocol}//${host}/protocol`;
  #| }

///|
/// Emits one harness/browser observability event.
extern "js" fn emit_host_event(name : String, payload : String) -> Unit =
  #| (name, payload) => {
  #|   if (typeof globalThis.__readonlyEditorEvent === "function") {
  #|     globalThis.__readonlyEditorEvent(name, payload);
  #|   }
  #| }

///|
/// Best-effort local storage read; returns empty string when unavailable.
extern "js" fn storage_get_item(key : String) -> String =
  #| (key) => {
  #|   try {
  #|     return globalThis.localStorage?.getItem(key) ?? "";
  #|   } catch {
  #|     return "";
  #|   }
  #| }

///|
/// Best-effort local storage write; private browsing failures are ignored.
extern "js" fn storage_set_item(key : String, value : String) -> Unit =
  #| (key, value) => {
  #|   try {
  #|     globalThis.localStorage?.setItem(key, value);
  #|   } catch {
  #|     // Persistence is best-effort; private browsing may deny storage.
  #|   }
  #| }

///|
/// Installs the harness scroll control: `__readonlyEditorScrollTo(top)`
/// drives the viewer's synthetic scrolling, replacing the native
/// `scrollTop` assignment specs used before the imperative view.
extern "js" fn install_scroll_control(scroll_to : (Double) -> Unit) -> Unit =
  #| (scroll_to) => {
  #|   globalThis.__readonlyEditorScrollTo = (top) => scroll_to(Number(top) || 0);
  #| }

///|
/// Installs the browser-test hover fixture hook. Normal usage never calls
/// this global, so the workbench's remote language provider remains the
/// first provider that answers.
extern "js" fn install_hover_fixture_control(
  configure : (String, String) -> Unit,
) -> Unit =
  #| (configure) => {
  #|   globalThis.__readonlyEditorSetHover = (kind, contents) => {
  #|     configure(String(kind ?? "plaintext"), String(contents ?? ""));
  #|   };
  #|   globalThis.__readonlyEditorClearHover = () => configure("", "");
  #| }

///|
/// Installs Playwright-only conformance controls for hover/scrollbar parity
/// checks. Product embedders should keep using the viewer API.
extern "js" fn install_conformance_control(
  configure_hover : (String, String) -> Unit,
  scroll_to : (Double, Double) -> Unit,
  hide_hover : () -> Unit,
) -> Unit =
  #| (configureHover, scrollTo, hideHoverFn) => {
  #|   const STYLE_PROPS = [
  #|     "opacity",
  #|     "display",
  #|     "pointer-events",
  #|     "transition",
  #|     "background-color",
  #|     "color",
  #|     "border-top-color",
  #|     "border-top-width",
  #|     "border-radius",
  #|     "box-shadow",
  #|     "padding-top",
  #|     "padding-right",
  #|     "padding-bottom",
  #|     "padding-left",
  #|     "font-family",
  #|     "font-size",
  #|     "line-height",
  #|     "overflow-x",
  #|     "overflow-y",
  #|     "scrollbar-width",
  #|     "max-width",
  #|     "max-height",
  #|     "cursor",
  #|     "z-index",
  #|     "visibility"
  #|   ];
  #|   const rounded = (value) => Math.round(Number(value) * 100) / 100;
  #|   const box = (node) => {
  #|     if (!node) return null;
  #|     const rect = node.getBoundingClientRect();
  #|     return {
  #|       x: rounded(rect.x),
  #|       y: rounded(rect.y),
  #|       width: rounded(rect.width),
  #|       height: rounded(rect.height),
  #|       top: rounded(rect.top),
  #|       right: rounded(rect.right),
  #|       bottom: rounded(rect.bottom),
  #|       left: rounded(rect.left)
  #|     };
  #|   };
  #|   const styles = (node) => {
  #|     if (!node) return null;
  #|     const computed = globalThis.getComputedStyle(node);
  #|     const result = {};
  #|     for (const prop of STYLE_PROPS) {
  #|       result[prop] = computed.getPropertyValue(prop);
  #|     }
  #|     return result;
  #|   };
  #|   const scrollbar = (root, axis) => {
  #|     const bar = root?.querySelector(`:scope > .scrollbar.${axis}`) ?? null;
  #|     const slider = bar?.querySelector(":scope > .slider") ?? null;
  #|     return {
  #|       className: bar?.className ?? "",
  #|       role: bar?.getAttribute("role"),
  #|       ariaHidden: bar?.getAttribute("aria-hidden"),
  #|       box: box(bar),
  #|       styles: styles(bar),
  #|       sliderClassName: slider?.className ?? "",
  #|       sliderBox: box(slider),
  #|       sliderStyles: styles(slider),
  #|       visible: !!bar?.classList.contains("visible"),
  #|       invisible: !!bar?.classList.contains("invisible"),
  #|       fade: !!bar?.classList.contains("fade"),
  #|       active: !!slider?.classList.contains("active")
  #|     };
  #|   };
  #|   const linePoint = (line, column) => {
  #|     const root = document.querySelector(".moonbit-viewer.readonly-editor");
  #|     const lineNode = document.querySelector(`.view-line[data-line="${line}"]`);
  #|     const content = lineNode?.querySelector(".view-line-content") ?? lineNode;
  #|     if (!root || !content) return null;
  #|     const rect = content.getBoundingClientRect();
  #|     const font = globalThis.getComputedStyle(content);
  #|     const size = Number.parseFloat(font.fontSize) || 12;
  #|     const charWidth = size * 0.6;
  #|     return {
  #|       root,
  #|       x: rect.left + Math.max(0, Number(column) || 0) * charWidth,
  #|       y: rect.top + rect.height / 2
  #|     };
  #|   };
  #|   const measure = () => {
  #|     const root = document.querySelector(".moonbit-viewer.readonly-editor");
  #|     const editor = document.querySelector(".monaco-scrollable-element.editor-scrollable");
  #|     const hoverWidget = document.querySelector('[data-content-widget="hover"]');
  #|     const hover = hoverWidget?.querySelector(".monaco-hover") ?? null;
  #|     const hoverScrollable = hover?.querySelector(".monaco-scrollable-element") ?? null;
  #|     const hoverContent = hover?.querySelector(".monaco-hover-content") ?? null;
  #|     const rows = Array.from(hover?.querySelectorAll(".hover-row") ?? []);
  #|     const copyButton = hover?.querySelector(".hover-copy-button") ?? null;
  #|     const statusBar = hover?.querySelector(".hover-row.status-bar") ?? null;
  #|     return {
  #|       rootClassName: root?.className ?? "",
  #|       editor: {
  #|         className: editor?.className ?? "",
  #|         box: box(editor),
  #|         styles: styles(editor),
  #|         verticalScrollbar: scrollbar(editor, "vertical"),
  #|         horizontalScrollbar: scrollbar(editor, "horizontal"),
  #|         shadows: Array.from(editor?.querySelectorAll(":scope > .shadow") ?? []).map((node) => ({
  #|           className: node.className,
  #|           box: box(node),
  #|           styles: styles(node)
  #|         }))
  #|       },
  #|       hover: {
  #|         wrapperClassName: hoverWidget?.className ?? "",
  #|         wrapperBox: box(hoverWidget),
  #|         wrapperStyles: styles(hoverWidget),
  #|         className: hover?.className ?? "",
  #|         role: hover?.getAttribute("role"),
  #|         tabindex: hover?.getAttribute("tabindex"),
  #|         box: box(hover),
  #|         styles: styles(hover),
  #|         contentBox: box(hoverContent),
  #|         contentStyles: styles(hoverContent),
  #|         nativeScrollbarInset: hoverContent ? {
  #|           x: hoverContent.offsetHeight - hoverContent.clientHeight,
  #|           y: hoverContent.offsetWidth - hoverContent.clientWidth
  #|         } : null,
  #|         verticalScrollbar: scrollbar(hoverScrollable, "vertical"),
  #|         horizontalScrollbar: scrollbar(hoverScrollable, "horizontal"),
  #|         rowClasses: rows.map((node) => node.className),
  #|         rowBoxes: rows.map(box),
  #|         statusBar: {
  #|           present: !!statusBar,
  #|           box: box(statusBar),
  #|           styles: styles(statusBar),
  #|           actionText: statusBar?.querySelector(".action")?.textContent ?? ""
  #|         },
  #|         copyButton: {
  #|           present: !!copyButton,
  #|           box: box(copyButton),
  #|           styles: styles(copyButton),
  #|           ariaLabel: copyButton?.getAttribute("aria-label")
  #|         }
  #|       }
  #|     };
  #|   };
  #|   globalThis.__readonlyEditorConformance = {
  #|     setPayloads(payloads) {
  #|       globalThis.__readonlyEditorConformancePayloads = payloads || {};
  #|     },
  #|     setHoverPayload(name) {
  #|       const payload = globalThis.__readonlyEditorConformancePayloads?.[name];
  #|       if (!payload) throw new Error(`Unknown hover payload: ${name}`);
  #|       configureHover(String(payload.kind ?? "plaintext"), String(payload.contents ?? ""));
  #|     },
  #|     showHover(line, column) {
  #|       const point = linePoint(line, column);
  #|       if (!point) return false;
  #|       point.root.dispatchEvent(new MouseEvent("mousemove", {
  #|         bubbles: true,
  #|         cancelable: true,
  #|         clientX: point.x,
  #|         clientY: point.y
  #|       }));
  #|       return true;
  #|     },
  #|     hideHover() {
  #|       hideHoverFn();
  #|     },
  #|     scrollEditor(top, left = 0) {
  #|       scrollTo(Number(top) || 0, Number(left) || 0);
  #|     },
  #|     measure
  #|   };
  #| }
