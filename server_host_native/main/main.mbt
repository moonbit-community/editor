///|
struct DevServerConfig {
  root : String
  port : Int
  asset_dir : String
}

///|
async fn main {
  let config = parse_args(@env.args()[1:])
  @server_host_native.run_native_editor_server(
    config.root,
    port=config.port,
    asset_dir=config.asset_dir,
  ) catch {
    error => abort("Readonly editor native server failed: " + error.to_string())
  }
}

///|
fn parse_args(args : ArrayView[String]) -> DevServerConfig {
  let mut root = "docs/fixtures/project"
  let mut port = 5173
  let mut asset_dir = "web/dist"
  let mut i = 0
  while i < args.length() {
    match args[i] {
      "--root" =>
        if i + 1 < args.length() {
          root = args[i + 1]
          i = i + 1
        }
      "--port" =>
        if i + 1 < args.length() {
          port = parse_port(args[i + 1], port)
          i = i + 1
        }
      "--asset-dir" =>
        if i + 1 < args.length() {
          asset_dir = args[i + 1]
          i = i + 1
        }
      _ => ()
    }
    i = i + 1
  }
  { root, port, asset_dir }
}

///|
fn parse_port(value : String, fallback : Int) -> Int {
  @string.parse_int(value, base=10) catch {
    _ => fallback
  }
}
