///|
pub extern "js" fn get_source() -> String =
  #| () => {
  #|   const document = globalThis.__readonlyEditorDocument;
  #|   return document && typeof document.text === "string"
  #|     ? document.text
  #|     : globalThis.__readonlyEditorSource || "";
  #| }

///|
pub extern "js" fn get_uri() -> String =
  #| () => {
  #|   const document = globalThis.__readonlyEditorDocument;
  #|   return document && typeof document.uri === "string" ? document.uri : "";
  #| }

///|
pub extern "js" fn get_display_name() -> String =
  #| () => {
  #|   const document = globalThis.__readonlyEditorDocument;
  #|   return document && typeof document.displayName === "string"
  #|     ? document.displayName
  #|     : "";
  #| }

///|
pub extern "js" fn get_language_id_hint() -> String =
  #| () => {
  #|   const document = globalThis.__readonlyEditorDocument;
  #|   return document && typeof document.languageId === "string"
  #|     ? document.languageId
  #|     : "";
  #| }

///|
pub extern "js" fn get_version() -> Int =
  #| () => {
  #|   const document = globalThis.__readonlyEditorDocument;
  #|   const version = document && Number.isFinite(document.version)
  #|     ? document.version
  #|     : 0;
  #|   return Math.trunc(version);
  #| }

///|
pub extern "js" fn get_revision() -> String =
  #| () => {
  #|   const document = globalThis.__readonlyEditorDocument;
  #|   return document && typeof document.revision === "string"
  #|     ? document.revision
  #|     : "";
  #| }

///|
#external
pub type HostReadResult

///|
#external
pub type HostDisposable

///|
extern "js" fn provider_read_file(
  uri : String,
  signal : @js_async.AbortSignal,
) -> @js_async.Promise[HostReadResult] =
  #| (uri, signal) => {
  #|   if (typeof globalThis.__readonlyEditorProviderReadFile === "function") {
  #|     return globalThis.__readonlyEditorProviderReadFile(uri, signal);
  #|   }
  #|   return Promise.resolve({
  #|     ok: false,
  #|     code: "Unavailable",
  #|     message: "No browser filesystem provider is registered."
  #|   });
  #| }

///|
extern "js" fn provider_watch_file(
  uri : String,
  listener : (String) -> Unit,
) -> HostDisposable =
  #| (uri, listener) => {
  #|   if (typeof globalThis.__readonlyEditorProviderWatchFile === "function") {
  #|     return globalThis.__readonlyEditorProviderWatchFile(uri, listener);
  #|   }
  #|   return { dispose() {} };
  #| }

///|
pub extern "js" fn HostDisposable::dispose(self : HostDisposable) -> Unit =
  #| (disposable) => {
  #|   if (disposable && typeof disposable.dispose === "function") {
  #|     disposable.dispose();
  #|   }
  #| }

///|
pub extern "js" fn provider_disposable(dispose : () -> Unit) -> HostDisposable =
  #| (dispose) => ({ dispose })

///|
extern "js" fn lsp_transport_request(
  message : String,
  signal : @js_async.AbortSignal,
) -> @js_async.Promise[String] =
  #| (message, signal) => {
  #|   const transport = globalThis.__readonlyEditorLspTransport;
  #|   if (transport && typeof transport.request === "function") {
  #|     return Promise.resolve(transport.request(message, { signal }));
  #|   }
  #|   let id = null;
  #|   try {
  #|     id = JSON.parse(message).id ?? null;
  #|   } catch {
  #|   }
  #|   return Promise.resolve(JSON.stringify({
  #|     jsonrpc: "2.0",
  #|     id,
  #|     error: { code: -32099, message: "No LSP transport is registered." }
  #|   }));
  #| }

///|
extern "js" fn lsp_transport_notify(
  message : String,
  signal : @js_async.AbortSignal,
) -> @js_async.Promise[String] =
  #| (message, signal) => {
  #|   const transport = globalThis.__readonlyEditorLspTransport;
  #|   if (transport && typeof transport.notify === "function") {
  #|     return Promise.resolve(transport.notify(message, { signal })).then(() => "");
  #|   }
  #|   return Promise.resolve("");
  #| }

///|
extern "js" fn lsp_transport_subscribe(
  listener : (String) -> Unit,
) -> HostDisposable =
  #| (listener) => {
  #|   const transport = globalThis.__readonlyEditorLspTransport;
  #|   if (transport && typeof transport.subscribe === "function") {
  #|     return transport.subscribe(listener) || { dispose() {} };
  #|   }
  #|   return { dispose() {} };
  #| }

///|
priv struct BrowserLspTransport {}

///|
pub fn browser_lsp_transport() -> &@language.LspTransport {
  BrowserLspTransport::{  }
}

///|
impl @language.LspTransport for BrowserLspTransport with fn request(
  _self,
  message,
) {
  @js_async.run_promise(signal => lsp_transport_request(message, signal))
}

///|
impl @language.LspTransport for BrowserLspTransport with fn notify(
  _self,
  message,
) {
  ignore(@js_async.run_promise(signal => lsp_transport_notify(message, signal)))
}

///|
impl @language.LspTransport for BrowserLspTransport with fn subscribe(
  _self,
  listener,
) {
  let disposable = lsp_transport_subscribe(listener)
  LspSubscription(() => disposable.dispose())
}

///|
extern "js" fn HostReadResult::ok(self : HostReadResult) -> Bool =
  #| (result) => !!(result && result.ok === true)

///|
extern "js" fn HostReadResult::code(self : HostReadResult) -> String =
  #| (result) => result && typeof result.code === "string"
  #|   ? result.code
  #|   : "Unavailable"

///|
extern "js" fn HostReadResult::message(self : HostReadResult) -> String =
  #| (result) => result && typeof result.message === "string"
  #|   ? result.message
  #|   : ""

///|
extern "js" fn HostReadResult::text(self : HostReadResult) -> String =
  #| (result) => result && typeof result.text === "string" ? result.text : ""

///|
extern "js" fn HostReadResult::display_name(self : HostReadResult) -> String =
  #| (result) => result && typeof result.displayName === "string"
  #|   ? result.displayName
  #|   : ""

///|
extern "js" fn HostReadResult::language_id(self : HostReadResult) -> String =
  #| (result) => result && typeof result.languageId === "string"
  #|   ? result.languageId
  #|   : ""

///|
extern "js" fn HostReadResult::revision(self : HostReadResult) -> String =
  #| (result) => result && typeof result.revision === "string"
  #|   ? result.revision
  #|   : ""

///|
priv struct BrowserFileSystemProvider {}

///|
pub fn browser_file_system_provider() -> &@workspace.FileSystemProvider {
  BrowserFileSystemProvider::{  }
}

///|
impl @workspace.FileSystemProvider for BrowserFileSystemProvider with fn scheme(
  _self,
) {
  "file"
}

///|
impl @workspace.FileSystemProvider for BrowserFileSystemProvider with fn read_file(
  _self,
  uri,
) {
  read_browser_file(uri)
}

///|
impl @workspace.FileSystemProvider for BrowserFileSystemProvider with fn watch(
  _self,
  uri,
  options,
  listener,
) {
  watch_browser_file(uri, options, listener)
}

///|
async fn read_browser_file(
  uri : @workspace.DocumentUri,
) -> @workspace.FileReadResult {
  let result = @js_async.run_promise(signal => {
    provider_read_file(uri.to_string(), signal)
  })
  if result.ok() {
    FileReadOk(
      FileContent(
        result.text(),
        display_name=result.display_name(),
        language_id=result.language_id(),
        revision=result.revision(),
      ),
    )
  } else {
    FileReadError(
      FileSystemProviderError(
        @workspace.FileSystemProviderErrorCode::from_string(result.code()),
        result.message(),
        uri~,
      ),
    )
  }
}

///|
fn watch_browser_file(
  uri : @workspace.DocumentUri,
  _options : @workspace.WatchOptions,
  listener : (Array[@workspace.FileChange]) -> Unit,
) -> @workspace.FileWatch {
  let disposable = provider_watch_file(uri.to_string(), payload => {
    listener([{ uri, change_type: Changed }])
    ignore(payload)
  })
  { dispose: () => disposable.dispose() }
}

///|
pub extern "js" fn emit_event(name : String, payload : String) -> Unit =
  #| (name, payload) => {
  #|   if (typeof globalThis.__readonlyEditorEvent === "function") {
  #|     globalThis.__readonlyEditorEvent(name, payload);
  #|   }
  #| }

///|
pub extern "js" fn mount_render_model(payload : String) -> Unit =
  #| (payload) => {
  #|   if (typeof globalThis.__readonlyEditorMount === "function") {
  #|     globalThis.__readonlyEditorMount(payload);
  #|   }
  #| }

///|
pub extern "js" fn register_render_callback(
  callback : () -> @js_async.Promise[Unit],
) -> Unit =
  #| (callback) => {
  #|   globalThis.__readonlyEditorRender = callback;
  #| }

///|
pub extern "js" fn register_load_callback(
  callback : (String) -> @js_async.Promise[String],
) -> Unit =
  #| (callback) => {
  #|   globalThis.__readonlyEditorLoadSource = callback;
  #| }

///|
pub extern "js" fn register_watch_callback(
  callback : (String, (String) -> Unit) -> HostDisposable,
) -> Unit =
  #| (callback) => {
  #|   globalThis.__readonlyEditorWatchSource = callback;
  #| }

///|
pub extern "js" fn register_hover_callback(
  callback : (Int, Int) -> @js_async.Promise[String],
) -> Unit =
  #| (callback) => {
  #|   globalThis.__readonlyEditorHover = callback;
  #| }
