///|
pub extern "js" fn install_host_capabilities() -> Unit =
  #| () => {
  #|   if (typeof globalThis.__readonlyEditorEvent !== "function") {
  #|     globalThis.__readonlyEditorEvent = (name, payload) => {
  #|       let parsed = payload;
  #|       try {
  #|         parsed = JSON.parse(payload);
  #|       } catch {
  #|         // Keep malformed event payloads visible as raw strings.
  #|       }
  #|       console.info("[readonly-editor]", name, parsed);
  #|     };
  #|   }
  #|
  #|   const providers = globalThis.__readonlyEditorFileSystemProviders instanceof Map
  #|     ? globalThis.__readonlyEditorFileSystemProviders
  #|     : new Map();
  #|   globalThis.__readonlyEditorFileSystemProviders = providers;
  #|   globalThis.__readonlyEditorRegisterFileSystemProvider = (scheme, provider) => {
  #|     providers.set(scheme, provider);
  #|   };
  #|
  #|   if (!providers.has("file")) {
  #|     const provider = globalThis.__readonlyEditorFileSystemProvider || createBrowserFileSystemProvider();
  #|     providers.set("file", provider);
  #|     globalThis.__readonlyEditorFileSystemProvider = provider;
  #|   }
  #|
  #|   if (typeof globalThis.__readonlyEditorProviderReadFile !== "function") {
  #|     globalThis.__readonlyEditorProviderReadFile = async (uri, signal) => {
  #|       const provider = providerForUri(uri);
  #|       if (!provider || typeof provider.readFile !== "function") {
  #|         return readError("Unavailable", `No filesystem provider is registered for ${uri}.`, uri);
  #|       }
  #|       try {
  #|         const content = await provider.readFile(uri, { signal });
  #|         return await normalizeReadResult(uri, content);
  #|       } catch (error) {
  #|         return readError(error?.code || error?.name || "Unavailable", error?.message || "", uri);
  #|       }
  #|     };
  #|   }
  #|
  #|   if (typeof globalThis.__readonlyEditorProviderWatchFile !== "function") {
  #|     globalThis.__readonlyEditorProviderWatchFile = (uri, listener) => {
  #|       const provider = providerForUri(uri);
  #|       if (!provider || typeof provider.watch !== "function") {
  #|         return { dispose() {} };
  #|       }
  #|       return provider.watch(uri, { recursive: false, excludes: [] }, (changes) => {
  #|         listener(JSON.stringify(normalizeFileChanges(uri, changes)));
  #|       }) || { dispose() {} };
  #|     };
  #|   }
  #|
  #|   function createBrowserFileSystemProvider() {
  #|     const entries = new Map();
  #|     const watchers = new Set();
  #|     const provider = {
  #|       async openFile() {
  #|         const entry = await chooseLocalFile();
  #|         return entry ? registerEntry(entry) : "";
  #|       },
  #|       async readFile(uri, { signal } = {}) {
  #|         if (signal?.aborted) {
  #|           throw fileError("AbortError", "File read was cancelled.");
  #|         }
  #|         const entry = entries.get(uri);
  #|         if (!entry) {
  #|           throw fileError("FileNotFound", "Choose a local file before opening this URI.");
  #|         }
  #|         const file = await entryFile(entry);
  #|         if (signal?.aborted) {
  #|           throw fileError("AbortError", "File read was cancelled.");
  #|         }
  #|         const text = await file.text();
  #|         if (text.includes("\0")) {
  #|           throw fileError("InvalidData", "Binary files cannot be viewed as source text.");
  #|         }
  #|         return {
  #|           text,
  #|           displayName: entry.displayName || file.name || uriDisplayName(uri),
  #|           languageId: entry.languageId || "",
  #|           revision: entry.revision || `${file.lastModified}:${file.size}`
  #|         };
  #|       },
  #|       watch(uri, _options, listener) {
  #|         const watcher = { uri, listener, revision: "" };
  #|         watchers.add(watcher);
  #|         pollWatcher(watcher);
  #|         const interval = setInterval(() => pollWatcher(watcher), 1000);
  #|         return {
  #|           dispose() {
  #|             clearInterval(interval);
  #|             watchers.delete(watcher);
  #|           }
  #|         };
  #|       },
  #|       registerFile(uri, file, metadata = {}) {
  #|         entries.set(uri, { file, ...metadata });
  #|         notifyWatchers(uri, "changed");
  #|         return uri;
  #|       }
  #|     };
  #|
  #|     function registerEntry(entry) {
  #|       const uri = entry.uri || fileUriForName(entry.displayName || entry.file?.name || "document");
  #|       entries.set(uri, entry);
  #|       notifyWatchers(uri, "changed");
  #|       return uri;
  #|     }
  #|
  #|     async function pollWatcher(watcher) {
  #|       try {
  #|         const content = await provider.readFile(watcher.uri);
  #|         const revision = content.revision;
  #|         if (watcher.revision && watcher.revision !== revision) {
  #|           watcher.listener([{ uri: watcher.uri, type: "changed" }]);
  #|         }
  #|         watcher.revision = revision;
  #|       } catch {
  #|         if (watcher.revision !== "missing") {
  #|           watcher.revision = "missing";
  #|           watcher.listener([{ uri: watcher.uri, type: "deleted" }]);
  #|         }
  #|       }
  #|     }
  #|
  #|     function notifyWatchers(uri, type) {
  #|       for (const watcher of watchers) {
  #|         if (watcher.uri === uri) {
  #|           watcher.listener([{ uri, type }]);
  #|         }
  #|       }
  #|     }
  #|
  #|     return provider;
  #|   }
  #|
  #|   async function chooseLocalFile() {
  #|     if (typeof window.showOpenFilePicker === "function") {
  #|       const handles = await window.showOpenFilePicker({ multiple: false });
  #|       const handle = handles[0];
  #|       if (!handle) {
  #|         return null;
  #|       }
  #|       const file = await handle.getFile();
  #|       return { handle, displayName: file.name };
  #|     }
  #|     return new Promise((resolve) => {
  #|       const input = document.createElement("input");
  #|       input.type = "file";
  #|       input.style.display = "none";
  #|       input.addEventListener("change", () => {
  #|         resolve(input.files?.[0] ? { file: input.files[0], displayName: input.files[0].name } : null);
  #|         input.remove();
  #|       }, { once: true });
  #|       document.body.appendChild(input);
  #|       input.click();
  #|     });
  #|   }
  #|
  #|   async function entryFile(entry) {
  #|     if (entry.handle && typeof entry.handle.getFile === "function") {
  #|       return entry.handle.getFile();
  #|     }
  #|     if (entry.file) {
  #|       return entry.file;
  #|     }
  #|     throw fileError("FileNotFound", "The local file is no longer available.");
  #|   }
  #|
  #|   async function normalizeReadResult(uri, content) {
  #|     if (typeof content === "string") {
  #|       return { ok: true, text: content, displayName: uriDisplayName(uri), languageId: "", revision: String(content.length) };
  #|     }
  #|     if (content instanceof Uint8Array) {
  #|       const text = new TextDecoder("utf-8", { fatal: true }).decode(content);
  #|       return { ok: true, text, displayName: uriDisplayName(uri), languageId: "", revision: String(content.byteLength) };
  #|     }
  #|     if (content instanceof ArrayBuffer) {
  #|       return normalizeReadResult(uri, new Uint8Array(content));
  #|     }
  #|     if (content instanceof Blob) {
  #|       const text = await content.text();
  #|       return { ok: true, text, displayName: content.name || uriDisplayName(uri), languageId: "", revision: `${content.lastModified || 0}:${content.size}` };
  #|     }
  #|     if (content && content.content) {
  #|       const normalized = await normalizeReadResult(uri, content.content);
  #|       return { ...normalized, ...content, ok: true, text: normalized.text };
  #|     }
  #|     if (content && typeof content.text === "string") {
  #|       return {
  #|         ok: true,
  #|         text: content.text,
  #|         displayName: content.displayName || uriDisplayName(uri),
  #|         languageId: content.languageId || "",
  #|         revision: content.revision || String(content.text.length)
  #|       };
  #|     }
  #|     throw fileError("InvalidData", "Filesystem provider returned unsupported file content.");
  #|   }
  #|
  #|   function normalizeFileChanges(uri, changes) {
  #|     const list = Array.isArray(changes) ? changes : [{ uri, type: "changed" }];
  #|     return list.map((change) => ({
  #|       uri: change.uri || uri,
  #|       type: change.type || "changed"
  #|     }));
  #|   }
  #|   function readError(code, message, uri) {
  #|     return { ok: false, code, message: message || code, uri };
  #|   }
  #|
  #|   function fileError(code, message) {
  #|     const error = new Error(message || code);
  #|     error.code = code;
  #|     return error;
  #|   }
  #|
  #|   function providerForUri(uri) {
  #|     return providers.get(uriScheme(uri));
  #|   }
  #|
  #|   function uriScheme(uri) {
  #|     const index = String(uri || "").indexOf("://");
  #|     return index > 0 ? uri.slice(0, index) : "";
  #|   }
  #|
  #|   function fileUriForName(name) {
  #|     return `file://local/${encodeURIComponent(name || "document")}`;
  #|   }
  #|
  #|   function uriDisplayName(uri) {
  #|     const path = uri.split("://")[1]?.split("/").slice(1).join("/") || uri;
  #|     const name = path.split("/").filter(Boolean).at(-1) || uri;
  #|     try {
  #|       return decodeURIComponent(name);
  #|     } catch {
  #|       return name;
  #|     }
  #|   }
  #| }

///|
pub extern "js" fn set_current_document(payload : String) -> Unit =
  #| (payload) => {
  #|   try {
  #|     const document = JSON.parse(payload);
  #|     globalThis.__readonlyEditorDocument = document;
  #|     globalThis.__readonlyEditorSource = typeof document.text === "string" ? document.text : "";
  #|   } catch (error) {
  #|     console.error("[readonly-editor]", "document:state-error", error);
  #|   }
  #| }

///|
pub extern "js" fn protocol_websocket_url() -> String =
  #| () => {
  #|   const location = globalThis.location;
  #|   const protocol = location?.protocol === "https:" ? "wss:" : "ws:";
  #|   const host = location?.host || "127.0.0.1:5173";
  #|   return `${protocol}//${host}/protocol`;
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
extern "js" fn remote_protocol_request(
  packet : String,
  signal : @js_async.AbortSignal,
) -> @js_async.Promise[String] =
  #| (packet, signal) => {
  #|   const transport = globalThis.__readonlyEditorRemoteProtocolTransport;
  #|   if (transport && typeof transport.request === "function") {
  #|     return Promise.resolve(transport.request(packet, { signal }));
  #|   }
  #|   return Promise.resolve(JSON.stringify({
  #|     version: 1,
  #|     type: "Error",
  #|     error: {
  #|       code: "ProviderError",
  #|       message: "No remote protocol transport is registered.",
  #|       providerCode: "Unavailable"
  #|     }
  #|   }));
  #| }

///|
extern "js" fn remote_protocol_watch(
  packet : String,
  listener : (String) -> Unit,
) -> HostDisposable =
  #| (packet, listener) => {
  #|   const transport = globalThis.__readonlyEditorRemoteProtocolTransport;
  #|   if (transport && typeof transport.watch === "function") {
  #|     return transport.watch(packet, listener) || { dispose() {} };
  #|   }
  #|   return { dispose() {} };
  #| }

///|
pub async fn request_remote_protocol(packet : String) -> String {
  @js_async.run_promise(signal => remote_protocol_request(packet, signal))
}

///|
pub fn watch_remote_protocol(
  packet : String,
  listener : (String) -> Unit,
) -> HostDisposable {
  remote_protocol_watch(packet, listener)
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
