// Port of `vscode/src/vs/editor/common/diff/linesDiffComputers.ts` (vscode
// submodule commit 294fb350837dbaee37b949533fead4df4e0e8971): the computer
// registry.
//
// Parity ledger: `getDefault` — PORTED (package-level fn; the viewer has no
// namespace object). `getLegacy` — N-A (the legacy engine is not ported; the
// default computer is piediff-backed, see
// `default_lines_diff_computer.mbt`).

///|
/// `linesDiffComputers.getDefault()` (`linesDiffComputers.ts:11`).
pub fn get_default() -> &LinesDiffComputer {
  DefaultLinesDiffComputer::new()
}
