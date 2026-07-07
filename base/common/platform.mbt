// Ported from `vscode/src/vs/base/common/platform.ts` (the OS facts only).
// Monaco reads `process.platform` in a native environment and falls back to
// `navigator.userAgent` sniffing in a browser; the js target applies the
// same order (`platform_js.mbt`) so unit tests under Node and browser runs
// agree on the host OS. Non-js targets report an unknown platform
// (`platform_fallback.mbt`) — they exist only for the no-DOM boundary check.

///|
priv enum HostPlatform {
  Mac
  Windows
  Linux
  UnknownPlatform
} derive(Eq)

///|
let host_platform : HostPlatform = match detect_platform_code() {
  1 => Mac
  2 => Windows
  3 => Linux
  _ => UnknownPlatform
}

///|
/// Monaco `platform.isMacintosh`.
pub let is_macintosh : Bool = host_platform == Mac

///|
/// Monaco `platform.isWindows`.
pub let is_windows : Bool = host_platform == Windows

///|
/// Monaco `platform.isLinux`.
pub let is_linux : Bool = host_platform == Linux
