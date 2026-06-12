///|
/// Browser-side document source: implements `@workspace.DocumentSource`
/// over the live protocol socket. Opens are correlated request/response
/// through `protocol_request`; watches register a URI-keyed listener that
/// the websocket push branch feeds `DocumentChanged` packets (and watch
/// errors such as `FileNotFound`) into; closes are fire-and-forget.
priv struct RemoteDocumentSource {}

///|
let document_source : &@workspace.DocumentSource = RemoteDocumentSource::{  }

///|
/// Active document watches keyed by URI string; the push branch of the
/// protocol message handler routes document packets here.
let watch_listeners : Map[String, (@workspace.SourceDocumentLoadResult) -> Unit] = {}

///|
/// Watch request ids back to their URI, so `RemoteError` pushes (which
/// carry only a request id) can reach the watched document's listener.
let watch_request_uris : Map[String, String] = {}

///|
impl @workspace.DocumentSource for RemoteDocumentSource with fn open_document(
  _self,
  uri,
) {
  let response = protocol_request("open", id => OpenDocument({ id, uri }))
  match response {
    DocumentLoaded(payload) => SourceDocumentLoaded(payload.document)
    RemoteError(error) =>
      SourceDocumentLoadError(
        FileSystemProviderError(
          @workspace.FileSystemProviderErrorCode::from_string(
            error.provider_code,
          ),
          error.message,
          uri~,
        ),
      )
    _ =>
      SourceDocumentLoadError(
        FileSystemProviderError(
          Unavailable,
          "Unexpected protocol response for document open.",
          uri~,
        ),
      )
  }
}

///|
impl @workspace.DocumentSource for RemoteDocumentSource with fn watch_document(
  _self,
  uri,
  listener,
) {
  let key = uri.to_string()
  let id = next_request_id("watch")
  watch_listeners[key] = listener
  watch_request_uris[id] = key
  send_protocol_packet(WatchDocument({ id, uri }))
  {
    dispose: () => {
      watch_listeners.remove(key)
      watch_request_uris.remove(id)
    },
  }
}

///|
impl @workspace.DocumentSource for RemoteDocumentSource with fn close_document(
  _self,
  uri,
) {
  send_protocol_packet(CloseDocument({ id: next_request_id("close"), uri }))
}

///|
/// Routes an uncorrelated document push (the watch's initial load and
/// every later change) into the watcher of its URI. Pushes for URIs
/// nobody watches are dropped.
fn route_watched_document_cmd(
  payload : @remote_protocol.DocumentPayload,
) -> @rabbita.Cmd {
  @cmd.custom_cmd(_ => {
    match watch_listeners.get(payload.document.uri.to_string()) {
      Some(listener) => listener(SourceDocumentLoaded(payload.document))
      None => ()
    }
  })
}

///|
/// The watched URI a pushed `RemoteError` belongs to, if its request id
/// was minted by `watch_document`.
fn watched_uri_for_error(error : @remote_protocol.ProtocolError) -> String? {
  watch_request_uris.get(error.request_id)
}

///|
fn route_watched_error_cmd(
  uri_key : String,
  error : @remote_protocol.ProtocolError,
) -> @rabbita.Cmd {
  @cmd.custom_cmd(_ => {
    match watch_listeners.get(uri_key) {
      Some(listener) => {
        let uri = match @workspace.DocumentUri::parse(uri_key) {
          ParsedDocumentUri(uri) => Some(uri)
          DocumentUriError(_) => None
        }
        listener(
          SourceDocumentLoadError(
            match uri {
              Some(uri) =>
                FileSystemProviderError(
                  @workspace.FileSystemProviderErrorCode::from_string(
                    error.provider_code,
                  ),
                  error.message,
                  uri~,
                )
              None =>
                FileSystemProviderError(
                  @workspace.FileSystemProviderErrorCode::from_string(
                    error.provider_code,
                  ),
                  error.message,
                )
            },
          ),
        )
      }
      None => ()
    }
  })
}

///|
/// The single live document watch. Selecting a new document disposes the
/// previous watch before subscribing the next one.
let active_document_watch : Ref[@workspace.FileWatch?] = Ref(None)

///|
fn dispose_active_document_watch() -> Unit {
  match active_document_watch.val {
    Some(watch) => watch.dispose()
    None => ()
  }
  active_document_watch.val = None
}
