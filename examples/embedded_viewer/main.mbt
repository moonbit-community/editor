// A real embedding target, the way Monaco's standalone editor proves its
// package boundary: the viewer library plus the file-tree widget mounted
// against in-memory providers, with zero server or websocket involvement.
// Implementing `DocumentSource` (and optionally `WorkspaceTreeProvider`)
// is the entire integration surface for a custom backend.

///|
let memory_root : String = "memory://workspace"

///|
/// In-memory workspace backend: a handful of hardcoded documents and
/// directories behind the two `workspace` traits the viewer and the tree
/// widget are built against.
priv struct MemoryWorkspace {
  root_uri : @workspace.DocumentUri
  directories : Map[String, Array[@workspace.WorkspaceStat]]
  documents : Map[String, String]
}

///|
fn memory_uri(raw : String) -> @workspace.DocumentUri {
  { value: raw }
}

///|
fn memory_file(path : String, name : String) -> @workspace.WorkspaceStat {
  {
    uri: memory_uri(memory_root + "/" + path),
    name,
    kind: File,
    children: None,
  }
}

///|
fn memory_dir(path : String, name : String) -> @workspace.WorkspaceStat {
  {
    uri: memory_uri(memory_root + "/" + path),
    name,
    kind: Directory,
    children: None,
  }
}

///|
fn memory_workspace() -> MemoryWorkspace {
  let directories : Map[String, Array[@workspace.WorkspaceStat]] = {}
  directories[memory_root] = [
    memory_dir("src", "src"),
    memory_file("moon.mod", "moon.mod"),
  ]
  directories[memory_root + "/src"] = [
    memory_dir("src/lib", "lib"),
    memory_file("src/main.mbt", "main.mbt"),
  ]
  directories[memory_root + "/src/lib"] = [
    memory_file("src/lib/util.mbt", "util.mbt"),
  ]
  let documents : Map[String, String] = {}
  documents[memory_root + "/moon.mod"] = "name = \"embedded-example\"\n"
  documents[memory_root + "/src/main.mbt"] = (
    #|///|
    #|fn main {
    #|  println(greeting())
    #|}
    #|
  )
  documents[memory_root + "/src/lib/util.mbt"] = (
    #|///|
    #|pub fn util_answer() -> Int {
    #|  42
    #|}
    #|
  )
  { root_uri: memory_uri(memory_root), directories, documents }
}

///|
impl @workspace.DocumentSource for MemoryWorkspace with fn open_document(
  self,
  uri,
) {
  match self.documents.get(uri.to_string()) {
    Some(text) =>
      SourceDocumentLoaded(
        @workspace.SourceDocument::from_file_content(uri, FileContent(text)),
      )
    None =>
      SourceDocumentLoadError(
        FileSystemProviderError(FileNotFound, "Document does not exist.", uri~),
      )
  }
}

///|
impl @workspace.DocumentSource for MemoryWorkspace with fn watch_document(
  _self,
  _uri,
  _listener,
) {
  // In-memory documents never change behind the viewer's back.
  { dispose: () => () }
}

///|
impl @workspace.DocumentSource for MemoryWorkspace with fn close_document(
  _self,
  _uri,
) {

}

///|
impl @workspace.WorkspaceTreeProvider for MemoryWorkspace with fn root(self) {
  self.root_uri
}

///|
impl @workspace.WorkspaceTreeProvider for MemoryWorkspace with fn resolve(
  self,
  uri,
) {
  match self.directories.get(uri.to_string()) {
    Some(children) =>
      WorkspaceResolved({
        uri,
        name: uri.display_name(),
        kind: Directory,
        children: Some(children),
      })
    None =>
      WorkspaceResolveError(
        FileSystemProviderError(FileNotFound, "Directory does not exist.", uri~),
      )
  }
}

///|
let workspace_backend : MemoryWorkspace = memory_workspace()

///|
priv struct EmbedModel {
  status : String
}

///|
priv enum EmbedMsg {
  Boot
  OpenFile(@workspace.DocumentUri)
  ViewerNotified(@browser.ViewerNotification)
}

///|
let embed_dispatch : Ref[((EmbedMsg) -> Unit)?] = Ref(None)

///|
fn dispatch_embed_msg(msg : EmbedMsg) -> Unit {
  match embed_dispatch.val {
    Some(dispatch) => dispatch(msg)
    None => ()
  }
}

///|
let embed_viewer_cell : Ref[@browser.Viewer?] = Ref(None)

///|
fn embed_viewer() -> @browser.Viewer {
  match embed_viewer_cell.val {
    Some(viewer) => viewer
    None => {
      let viewer = @browser.Viewer(
        workspace_backend,
        on_notification=notification => {
          dispatch_embed_msg(ViewerNotified(notification))
        },
        placeholder="Loading source...",
      )
      embed_viewer_cell.val = Some(viewer)
      viewer
    }
  }
}

///|
let embed_tree_cell : Ref[@file_tree.FileTree?] = Ref(None)

///|
fn embed_tree() -> @file_tree.FileTree {
  match embed_tree_cell.val {
    Some(tree) => tree
    None => {
      let tree = @file_tree.FileTree(workspace_backend, on_open=uri => {
        dispatch_embed_msg(OpenFile(uri))
      })
      embed_tree_cell.val = Some(tree)
      tree
    }
  }
}

///|
fn update_embed(
  _emit : @rabbita.Emit[EmbedMsg],
  msg : EmbedMsg,
  model : EmbedModel,
) -> (@rabbita.Cmd, EmbedModel) {
  match msg {
    Boot => {
      let first_file = memory_uri(memory_root + "/src/main.mbt")
      (
        @rabbita.batch([embed_tree().refresh(), embed_viewer().open(first_file)]),
        model,
      )
    }
    OpenFile(uri) => (embed_viewer().open(uri), model)
    ViewerNotified(notification) =>
      match notification {
        ViewerDocumentRendered(document, fresh~, ..) => {
          let cmd = if fresh {
            embed_tree().set_active(document.uri)
          } else {
            @rabbita.none
          }
          (cmd, { status: "ready" })
        }
        ViewerDocumentFailed(_) => (@rabbita.none, { status: "error" })
        _ => (@rabbita.none, model)
      }
  }
}

///|
fn view_embed(
  _emit : @rabbita.Emit[EmbedMsg],
  model : EmbedModel,
) -> @html.Html {
  @html.main_(
    class="editor-shell",
    attrs=@html.Attrs::build()
      .data_set("status", model.status)
      .data_set("theme", "dark"),
    [
      @html.div(class="editor-main", [
        @html.aside(
          class="workspace-sidebar",
          attrs=@html.Attrs::build().aria_label("Workspace files"),
          [
            @html.div(class="workspace-title", [
              @html.span(class="workspace-title-label", "Explorer"),
            ]),
            embed_tree().view(),
          ],
        ),
        embed_viewer().view(),
      ]),
    ],
  )
}

///|
fn main {
  // Highlighting needs no server: the language package is composed in
  // by import and registered against the viewer's tokenizer registry.
  @browser.register_tokenizer("moonbit", @lang_moonbit.MoonbitTokenizer::new())
  let (emit, cell) = @rabbita.cell_with_emit(
    model={ status: "loading" },
    update=update_embed,
    view=view_embed,
  )
  let app = @rabbita.new(cell)
  app.with_init(
    @cmd.custom_cmd(scheduler => {
      embed_dispatch.val = Some(msg => scheduler.add(emit(msg)))
      // Boot after the first paint: the tree and viewer child cells must
      // be mounted before messages can reach their update loops.
      scheduler.add(
        @cmd.custom_cmd(after => after.add(emit(Boot)), kind=@cmd.after_render),
      )
    }),
  )
  app.mount("app")
}
