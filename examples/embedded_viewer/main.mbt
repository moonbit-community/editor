// A real embedding target, the way Monaco's standalone editor proves its
// package boundary: the viewer library plus the file-tree widget mounted
// against in-memory providers, with zero server or websocket involvement.
// Implementing `DocumentProvider` (and optionally `WorkspaceTreeProvider`)
// is the entire integration surface for a custom backend.

///|
let memory_root : String = "memory://workspace"

///|
priv suberror StartupSubscription

///|
fn startup_sub(cmd : @cmd.Cmd) -> @sub.Sub {
  @sub.custom_sub(
    "embedded-viewer-startup",
    Local,
    StartupSubscription,
    SubLoader((_, scheduler) => {
      scheduler.add(cmd)
      Some({ unload: _ => (), update_tagger: _ => () })
    }),
  )
}

///|
/// In-memory workspace backend: a handful of hardcoded documents and
/// directories behind the two `workspace` traits the viewer and the tree
/// widget are built against.
priv struct MemoryWorkspace {
  root_uri : @base_common.Uri
  directories : Map[String, Array[@workspace.WorkspaceStat]]
  documents : Map[String, String]
}

///|
fn memory_uri(raw : String) -> @base_common.Uri {
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
impl @workspace.DocumentProvider for MemoryWorkspace with fn read(self, uri) {
  match self.documents.get(uri.to_string()) {
    Some(text) =>
      DocumentLoaded(
        @workspace.DocumentSnapshot::from_content(uri, DocumentContent(text)),
      )
    None =>
      DocumentReadFailed(
        DocumentError(FileNotFound, "Document does not exist.", uri~),
      )
  }
}

///|
impl @workspace.DocumentProvider for MemoryWorkspace with fn watch(
  _self,
  _uri,
  _listener,
) {
  // In-memory documents never change behind the viewer's back.
  @base_common.Disposable::from(() => ())
}

///|
impl @workspace.DocumentProvider for MemoryWorkspace with fn close(_self, _uri) {

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
  OpenFile(@base_common.Uri)
  ViewerRendered(@viewer.ViewerDocumentRenderedEvent)
  ViewerFailed
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
let embed_viewer_cell : Ref[@viewer.Viewer?] = Ref(None)

///|
fn embed_viewer() -> @viewer.Viewer {
  match embed_viewer_cell.val {
    Some(viewer) => viewer
    None => {
      let viewer = @viewer.Viewer(
        workspace_backend,
        placeholder="Loading source...",
      )
      viewer.on_did_render_document(event => {
        dispatch_embed_msg(ViewerRendered(event))
      })
      |> ignore
      viewer.on_did_fail_document(_error => dispatch_embed_msg(ViewerFailed))
      |> ignore
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
        @rabbita.batch([
          embed_tree().refresh(),
          @cmd.custom_cmd(_ => embed_viewer().open(first_file)),
        ]),
        model,
      )
    }
    OpenFile(uri) => (@cmd.custom_cmd(_ => embed_viewer().open(uri)), model)
    ViewerRendered(event) => {
      let cmd = if event.fresh {
        embed_tree().set_active(event.document.uri)
      } else {
        @rabbita.none
      }
      (cmd, { status: "ready" })
    }
    ViewerFailed => (@rabbita.none, { status: "error" })
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
        // The stable view host: the viewer attaches its imperative DOM
        // into this element after the first paint; the shell must never
        // render vdom children into it.
        @html.div(class="viewer-host", ([] : Array[@html.Html])),
      ]),
    ],
  )
}

///|
fn main {
  // Highlighting needs no server: the language package is composed in
  // by import and registered against the viewer's tokenizer registry.
  @viewer.register_tokenizer("moonbit", @lang_moonbit.MoonbitTokenizer::new())
  let (_, cell) = @rabbita.cell_with_emit(
    model={ status: "loading" },
    update=update_embed,
    view=view_embed,
    subscriptions=(emit, _model) => {
      startup_sub(
        @cmd.custom_cmd(scheduler => {
          embed_dispatch.val = Some(msg => scheduler.add(emit(msg)))
          // Boot after the first paint: the view host and the tree cell
          // must be in the DOM before the viewer attaches and opens.
          scheduler.add(
            @cmd.custom_cmd(
              after => {
                match
                  @rdom.document().query_selector(".viewer-host").to_option() {
                  Some(host) => embed_viewer().attach(host)
                  None => ()
                }
                after.add(emit(Boot))
              },
              kind=@cmd.after_render,
            ),
          )
        }),
      )
    },
  )
  let app = @rabbita.new(cell)
  app.mount("app")
}
