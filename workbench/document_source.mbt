///|
/// Browser-side document provider: implements `@workspace.DocumentProvider`
/// over the live protocol socket. Opens are correlated request/response
/// through `protocol_request`; watches register a URI-keyed listener that
/// the websocket push branch feeds `DocumentChanged` packets (and watch
/// errors such as `FileNotFound`) into; closes are fire-and-forget.
priv struct RemoteDocumentProvider {}

///|
let document_provider : &@workspace.DocumentProvider = RemoteDocumentProvider::{

}

///|
/// Active document watches keyed by URI string; the push branch of the
/// protocol message handler routes document packets here.
let watch_listeners : Map[String, (@workspace.DocumentChange) -> Unit] = {}

///|
/// Watch request ids back to their URI, so `RemoteError` pushes (which
/// carry only a request id) can reach the watched document's listener.
let watch_request_uris : Map[String, String] = {}

///|
impl @workspace.DocumentProvider for RemoteDocumentProvider with fn read(
  _self,
  uri,
) {
  let response = protocol_request("open", id => OpenDocument({ id, uri }))
  match response {
    DocumentLoaded(payload) => DocumentLoaded(payload.document)
    RemoteError(error) =>
      DocumentReadFailed(
        DocumentError(
          @workspace.FileSystemProviderErrorCode::from_string(
            error.provider_code,
          ),
          error.message,
          uri~,
        ),
      )
    _ =>
      DocumentReadFailed(
        DocumentError(
          Unavailable,
          "Unexpected protocol response for document open.",
          uri~,
        ),
      )
  }
}

///|
impl @workspace.DocumentProvider for RemoteDocumentProvider with fn watch(
  _self,
  uri,
  listener,
) {
  let key = uri.to_string()
  let id = next_request_id("watch")
  watch_listeners[key] = listener
  watch_request_uris[id] = key
  send_protocol_packet(WatchDocument({ id, uri }))
  @base_common.Disposable::from(() => {
    watch_listeners.remove(key)
    watch_request_uris.remove(id)
  })
}

///|
impl @workspace.DocumentProvider for RemoteDocumentProvider with fn close(
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
      Some(listener) => listener(DocumentUpdated(payload.document))
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
        let uri = match @base_common.Uri::parse(uri_key) {
          ParsedUri(uri) => Some(uri)
          UriError(_) => None
        }
        let document_uri = match uri {
          Some(uri) => uri
          None => @base_common.Uri::memory(uri_key)
        }
        let document_error = match uri {
          Some(uri) =>
            @workspace.DocumentError(
              @workspace.FileSystemProviderErrorCode::from_string(
                error.provider_code,
              ),
              error.message,
              uri~,
            )
          None =>
            DocumentError(
              @workspace.FileSystemProviderErrorCode::from_string(
                error.provider_code,
              ),
              error.message,
            )
        }
        listener(DocumentChangeFailed(uri=document_uri, error=document_error))
      }
      None => ()
    }
  })
}
