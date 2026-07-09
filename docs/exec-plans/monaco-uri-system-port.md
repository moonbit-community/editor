# Monaco URI System 1:1 Port (uri.ts + path.ts + extpath.ts + resources.ts)

Status: implemented — Date: 2026-07-08 (proposed and landed same day). Oracle commit: b18492a288d (vscode submodule).

Follows `_PORT_PLAYBOOK.md`. This plan replaces the homegrown `base/common/uri.mbt`
(opaque-string `Uri` with `scheme()`/`path()` substring extraction, `UriResult`
enum, `Uri::memory`) with the real Monaco URI stack.

## Motivation

The current `Uri` is one opaque string. Measured against Monaco:

- No `authority` / `query` / `fragment` — our `path()` returns everything after
  the first slash *including* query strings, and without the leading slash.
- `parse` hard-requires `://`, rejecting valid scheme-only URIs Monaco produces
  (`untitled:Untitled-1`, `mailto:x@y`, `urn:...`).
- No percent encoding/decoding — `file:///a%20b` and its decoded form are
  different identities under derived `Eq`.
- No `with` / `joinPath` / `fsPath` / normalized comparison (`ExtUri`).
- `Uri::memory` / `display_name()` are inventions with no Monaco counterpart.

## Scope (Phase 0)

Source units (all under `vscode/src/vs/base/common/`), whole-file inventories:

1. **`uri.ts`** (755 lines) — the `URI` class, encoder/decoder, `uriToFsPath`.
2. **`path.ts`** (1589 lines) — vscode's vendored copy of Node v22 `lib/path.js`;
   `posix` + `win32` namespaces.
3. **`extpath.ts`** (433 lines) — OS-path helpers; only the members `resources.ts`
   consumes are ported, the rest are explicit `DEFERRED` rows.
4. **`resources.ts`** (444 lines) — `ExtUri` comparison/derivation layer and its
   three exported instances.

Support seams (named members only, not whole files):

- `strings.ts:343 compare`, `strings.ts:436 equalsIgnoreCase` (+ its
  `doEqualsIgnoreCase` helper), `strings.ts:444 startsWithIgnoreCase` → into
  existing `base/common/strings.mbt`.
- `network.ts:12 Schemas` — constants `file` (:44), `inMemory` (:18),
  `untitled` (:48) only → new `base/common/network.mbt`. The rest of
  `network.ts` (RemoteAuthorities, AppResourcePath, COI, …) is **out**.
- `process.ts:38-43` web fallback (`cwd() => '/'`, empty env) → new
  target-gated `base/common/process.mbt` (+ `_js` variant reading real
  `process.cwd()` when a Node global exists, per `process.ts:26-29`).

Out of scope (named sibling clusters):

- `uriIpc.ts`, `marshalling.ts` / `marshallingIds.ts` (structured-clone
  transport — our remote protocol sends URI strings; see ledger rows for
  `toJSON`/`revive`).
- `network.ts` beyond the three scheme constants.
- `resources.ts` `DataUri`, `distinctParents`, `toLocalResource` (no consumer;
  `DEFERRED` rows below).
- `ResourceMap`/`ResourceSet` (`map.ts`) — follow-up when a consumer appears.
- Glob/language-selector scoring (`languageSelector.ts`) — touched only as a
  migration consumer (Track E), not ported here.

## Target layout

All files land in the existing `base/common` package (mirror of
`vs/base/common`; satisfies the MoonBit foreign-method rule — `Uri::`/`ExtUri::`
methods live in the type's own package):

```
base/common/
  path.mbt                    # port of path.ts (Posix::/Win32:: namespaces)
  path_reference_test.mbt     # from vs/base/test/common/path.test.ts (822 lines)
  uri.mbt                     # REWRITTEN — port of uri.ts (old content deleted)
  uri_reference_test.mbt      # from vs/base/test/common/uri.test.ts (649 lines)
  extpath.mbt                 # port of extpath.ts (consumed subset)
  extpath_reference_test.mbt  # from extpath.test.ts (in-scope members)
  resources.mbt               # port of resources.ts (ExtUri + instances)
  resources_reference_test.mbt# from resources.test.ts
  network.mbt                 # Schemas.file / inMemory / untitled
  process.mbt + process_js.mbt + process_fallback.mbt  # cwd()/env shim
  strings.mbt                 # += compare, equals_ignore_case, starts_with_ignore_case
  uri_test.mbt                # existing file: rewrite for new API
```

Implementation order (each track lands green independently):

- **Track A — seams**: `process.mbt` shim, `network.mbt` Schemas,
  `strings.mbt` additions, `is_windows` test override seam (Deviation D8).
- **Track B — `path.mbt`** + reference tests. Depends on A (cwd).
- **Track C — `uri.mbt` rewrite** + reference tests. Depends on B (join),
  breaks the old API — lands together with Track E's mechanical consumer
  updates so the tree stays green.
- **Track D — `extpath.mbt` + `resources.mbt`** + reference tests. Depends on
  B + C.
- **Track E — consumer migration** (see Migration section) + tree-wide sweep +
  full harness.

## Inventory & parity ledger (Phases 1–2)

Statuses: `TODO` → `PORTED` → `TESTED` → `PASS`; or `DEFERRED (reason)` /
`N-A (reason)`. Grouped rows name every member they cover. Update statuses
in place during implementation.

### uri.ts (24 members)

| Source member (file:line) | Arithmetic / transition | MoonBit symbol | Status |
|---|---|---|---|
| `_schemePattern` (uri.ts:11) | `^\w[\w\d+.-]*$` scheme validation | char-loop in `validate_uri` | PASS |
| `_singleSlashStart` / `_doubleSlashStart` (uri.ts:12-13) | path-shape checks | char checks in `validate_uri` | PASS |
| `_validateUri` (uri.ts:15) | throws on missing scheme (strict), illegal scheme chars, authority+path-without-slash, no-authority+`//`-path | `validate_uri` (raises `UriError`, D6) | PASS |
| `_schemeFix` (uri.ts:54) | empty scheme + non-strict → `"file"` | `scheme_fix` | PASS |
| `_referenceResolution` (uri.ts:62) | http/https/file: empty path → `/`; relative → `/`+path | `reference_resolution` | PASS |
| `_empty` / `_slash` (uri.ts:82-83) | `''` / `'/'` | literals | PASS |
| `_regexp` (uri.ts:84) | RFC3986 appendix-B component split | hand-rolled scanner `parse_components` (D3) | PASS |
| `URI.isUri` (uri.ts:104) | runtime duck-typing | — | N-A (static types) |
| fields `scheme/authority/path/query/fragment` (uri.ts:125-146) | stored **decoded** | `Uri` struct fields | PASS |
| constructor (uri.ts:161) | components path skips validation; string path runs schemeFix → referenceResolution → validateUri | `Uri::new_` (private) | PASS |
| `fsPath` getter (uri.ts:209) | delegates `uriToFsPath(self, false)`, cached (uri.ts:460) | `Uri::fs_path()` w/ `mut _fs_path` cache (D5) | PASS |
| `with` (uri.ts:218) | undefined=keep / null=clear (null → `''` per uri.ts:227-249); identity short-circuit uri.ts:251 | `Uri::with_` (optional named args, `Some("")`=clear, raises `UriError`, D6) | PASS |
| `URI.parse` (uri.ts:271) | regex exec; percent-decode each component; no-match → all-empty URI | `Uri::parse(value, strict~=false)` | PASS |
| `URI.file` (uri.ts:307) | isWindows `\`→`/`; leading `//` → authority split at next `/` (uri.ts:320-329) | `Uri::file` | PASS |
| `URI.from` (uri.ts:341) | components ctor + validation | `Uri::from` | PASS |
| `URI.joinPath` (uri.ts:360) | throws on empty path; isWindows+file → `win32.join(uriToFsPath(uri,true), …)` via `URI.file`; else `posix.join` | `Uri::join_path(uri, Array[String])` | PASS |
| `toString(skipEncoding=false)` (uri.ts:386) | `_asFormatted`; cached when `!skipEncoding` (uri.ts:467-477) | `Uri::to_string(skip_encoding~=false)` w/ `mut _formatted` cache (D5) | PASS |
| `toJSON` (uri.ts:390, 479) + `UriState` (uri.ts:445) + `_pathSepMarker` (uri.ts:452) | `$mid` marshalling + cache export | — | DEFERRED (no structured-clone seam; protocol sends strings, D7) |
| `URI.revive` (uri.ts:408) | rebuild + restore `_formatted`/`_fsPath` | — | DEFERRED (D7) |
| `Symbol debug.description` (uri.ts:421) | debugger label | — | N-A (JS-only) |
| `UriComponents` (uri.ts:426) / `isUriComponents` (uri.ts:434) / `UriDto` (uri.ts:752) | shape interface + runtime check | `from` takes named args; runtime check N-A | N-A (static types) |
| class `Uri` caching subclass (uri.ts:455) | `_formatted`/`_fsPath` lazy caches | merged into `Uri` struct `mut` fields (D5) | PASS |
| `encodeTable` (uri.ts:517) | 19 gen-delim/sub-delim/space → `%XX` | `encode_table` lookup fn | PASS |
| `encodeURIComponentFast` (uri.ts:541) | unreserved fast path; `isPath` keeps `/`; `isAuthority` keeps `[ ] :`; delayed native-encode spans; allocate-only-on-change | `encode_uri_component_fast` (native spans → D4) | PASS |
| `encodeURIComponentMinimal` (uri.ts:605) | only `#` and `?` escaped | `encode_uri_component_minimal` | PASS |
| `uriToFsPath` (uri.ts:626) | UNC `//auth/path` when file+authority+path>1; `/C:/…` drive lower-cased unless keepDriveLetterCasing; isWindows `/`→`\` | `uri_to_fs_path` | PASS |
| `_asFormatted` (uri.ts:656) | scheme `:`; `//` when authority or file; userinfo/`:pass`/`:port` split (uri.ts:672-697); authority lowercase; drive-letter lowering (uri.ts:701-711); query `?`, fragment `#` | `as_formatted` | PASS |
| `decodeURIComponentGraceful` (uri.ts:728) | decode; on throw retry `str[3:]` recursively, keep raw prefix | `decode_uri_component_graceful` (D4) | PASS |
| `_rEncodedAsHex` (uri.ts:740) / `percentDecode` (uri.ts:742) | skip if no `%XX` run; replace runs gracefully | `percent_decode` (scanner, no regex, D3) | PASS |

### path.ts (37 members / member groups)

| Source member (file:line) | Arithmetic / transition | MoonBit symbol | Status |
|---|---|---|---|
| `CHAR_*` ×9 (path.ts:36-46) | ASCII constants A/a/Z/z/`.`/`/`/`\`/`:`/`?` | file-local `let` consts | PASS |
| `ErrorInvalidArgType`/`validateObject`/`validateString` (path.ts:48-80) | JS arg-type guards | — | N-A (static types) |
| `platformIsWin32` (path.ts:82) | bound once from `process.platform` | `is_windows()` read per call (D1) | PASS |
| `isPathSeparator` (path.ts:84) | `/` or `\` | `is_path_separator` | PASS |
| `isPosixPathSeparator` (path.ts:88) | `/` | `is_posix_path_separator` | PASS |
| `isWindowsDeviceRoot` (path.ts:92) | A-Z ∪ a-z | `is_windows_device_root` | PASS |
| `normalizeString` (path.ts:98) | `.`/`..` resolution state machine (lastSlash/dots/lastSegmentLength; allowAboveRoot `..` emission path.ts:142) | `normalize_string` | PASS |
| `formatExt` (path.ts:166) / `_format` (path.ts:170) / `ParsedPath` (path.ts:181) | format/parse support | — | DEFERRED (no consumer of `format`/`parse`) |
| `IPath` (path.ts:189) | namespace shape | `Posix` / `Win32` zero-field namespace types (D2) | PASS |
| `win32.resolve` (path.ts:209) | right-to-left walk; device/UNC/drive root match (path.ts:250-307); per-drive `env['=C:']` cwd (path.ts:232); tail normalize | `Win32::resolve(Array[String])` | PASS |
| `win32.normalize` (path.ts:346) | root match; UNC-only early return (path.ts:397); CVE-2024-36139 relative-colon guard (path.ts:430-446) | `Win32::normalize` | PASS |
| `win32.isAbsolute` (path.ts:453) | sep ∨ (len>2 ∧ drive ∧ `:` ∧ sep) | `Win32::is_absolute` | PASS |
| `win32.join` (path.ts:469) | `\`-join non-empty; UNC double-slash preservation (path.ts:506-534); → normalize | `Win32::join(Array[String])` | PASS |
| `win32.relative` (path.ts:544) | resolve both; lowercase compare; length-mismatch split-path branch (path.ts:566-600); common-sep walk; `..` chain | `Win32::relative` | PASS |
| `win32.toNamespacedPath` (path.ts:702) | `\\?\` long-path prefix | — | DEFERRED (no consumer) |
| `win32.dirname` (path.ts:733) | UNC/drive root offset; reverse sep scan | `Win32::dirname` | PASS |
| `win32.basename` (path.ts:821) | drive-prefix skip (path.ts:834); optional suffix reverse-match (path.ts:840-886) | `Win32::basename(path, suffix?)` | PASS |
| `win32.extname` (path.ts:909) | reverse dot state machine; preDotState `..` guard (path.ts:962-971) | `Win32::extname` | PASS |
| `win32.format` (path.ts:975) / `win32.parse` (path.ts:977) | — | — | DEFERRED (no consumer) |
| `win32.sep`=`\` / `delimiter`=`;` (path.ts:1129-1130) | constants | `Win32::sep()` / `Win32::delimiter()` | PASS |
| `posixCwd` (path.ts:1135) | on win32: `\`→`/`, truncate at first `/`; else `process.cwd()` | `posix_cwd` | PASS |
| `posix.resolve` (path.ts:1152) | right-to-left prepend until absolute; cwd fallback (path.ts:1169-1174); normalize | `Posix::resolve(Array[String])` | PASS |
| `posix.normalize` (path.ts:1189) | abs/trailing-sep flags; normalizeString; `''`→`.`/`/`/`./` cases (path.ts:1203-1208) | `Posix::normalize` | PASS |
| `posix.isAbsolute` (path.ts:1216) | first char `/` | `Posix::is_absolute` | PASS |
| `posix.join` (path.ts:1221) | filter empty, `'/'`-join, normalize; `[]`→`.` | `Posix::join(Array[String])` | PASS |
| `posix.relative` (path.ts:1242) | resolve both; common-prefix from index 1; exact-base early returns (path.ts:1277-1298); `..` chain | `Posix::relative` | PASS |
| `posix.toNamespacedPath` (path.ts:1315) | identity | — | DEFERRED (no consumer) |
| `posix.dirname` (path.ts:1320) | reverse sep scan; `hasRoot`/`//` special (path.ts:1340-1345) | `Posix::dirname` | PASS |
| `posix.basename` (path.ts:1349) | reverse scan; optional suffix match (path.ts:1360-1406) | `Posix::basename(path, suffix?)` | PASS |
| `posix.extname` (path.ts:1429) | reverse dot state machine | `Posix::extname` | PASS |
| `posix.format` (path.ts:1483) / `posix.parse` (path.ts:1485) | — | — | DEFERRED (no consumer) |
| `posix.sep`=`/` / `delimiter`=`:` (path.ts:1568-1569) | constants | `Posix::sep()` / `Posix::delimiter()` | PASS |
| circular `posix.win32 = win32…` (path.ts:1574-1575) | Node API compat | — | N-A (JS namespace compat only) |
| platform-selected `normalize/resolve/relative/dirname/sep` (path.ts:1577-1588) | pick by platformIsWin32; consumed by resources.ts/extpath.ts | top-level fns branching on `is_windows()` | PASS |
| platform-selected `isAbsolute/join/basename/extname/format/parse/toNamespacedPath/delimiter` (path.ts:1578-1589) | idem, unconsumed | — | DEFERRED (no consumer; trivial to add) |

### extpath.ts (17 members / member groups)

| Source member (file:line) | Arithmetic / transition | MoonBit symbol | Status |
|---|---|---|---|
| `isPathSeparator` (extpath.ts:12) | `/` or `\` | `@base_common` shared with path.mbt | PASS |
| `toSlashes` (extpath.ts:21) | `[\\/]`→`/` global replace | `to_slashes` (char loop, no regex) | PASS |
| `toPosixPath` (extpath.ts:32) | toSlashes if no `/`; `^[a-zA-Z]:(\/|$)` → prefix `/` | `to_posix_path` (char checks) | PASS |
| `getRoot` (extpath.ts:47) | UNC root scan (extpath.ts:55-76); drive-letter `C:\`/`C:` (extpath.ts:82-95); `scheme://…/` scan (extpath.ts:101-109) | `get_root(path, sep~="/")` | PASS |
| `isUNC` (extpath.ts:121) | — | — | DEFERRED (no consumer) |
| `WINDOWS_INVALID_FILE_CHARS`/`UNIX_…`/`WINDOWS_FORBIDDEN_NAMES`/`isValidBasename` (extpath.ts:166-202) | — | — | DEFERRED (no consumer) |
| `isEqual` string variant (extpath.ts:209) | deprecated upstream | — | DEFERRED (deprecated; use ExtUri) |
| `isEqualOrParent` (extpath.ts:227) | `..` → normalize both (extpath.ts:238-244); ignoreCase → startsWithIgnoreCase + sep-boundary check (extpath.ts:250-266); else prefix+sep check | `is_equal_or_parent(base, parent, ignore_case, force_posix_semantics~=false)` | PASS |
| `isWindowsDriveLetter` (extpath.ts:275) | A-Z ∪ a-z | `is_windows_drive_letter` | PASS |
| `sanitizeFilePath` (extpath.ts:279) | — | — | DEFERRED (no consumer) |
| `removeTrailingPathSeparator` string variant (extpath.ts:298) | — | — | DEFERRED (no consumer; ExtUri has its own) |
| `isRootOrDriveLetter` (extpath.ts:319) | — | — | DEFERRED (no consumer) |
| `hasDriveLetter` (extpath.ts:334) / `getDriveLetter` (extpath.ts:342) | — | — | DEFERRED (no consumer) |
| `indexOfPath` (extpath.ts:346) | — | — | DEFERRED (no consumer) |
| `IPathWithLineAndColumn`/`parseLineAndColumnAware` (extpath.ts:363-396) | — | — | DEFERRED (no consumer) |
| `pathChars`/`windowsSafePathFirstChars`/`randomPath` (extpath.ts:398-433) | — | — | DEFERRED (no consumer) |

### resources.ts (27 members / member groups)

| Source member (file:line) | Arithmetic / transition | MoonBit symbol | Status |
|---|---|---|---|
| `originalFSPath` (resources.ts:14) | `uriToFsPath(uri, true)` | `original_fs_path` | PASS |
| `IExtUri` (resources.ts:20) | interface | `ExtUri` struct is the impl (no trait needed; single impl parameterized by closure) | N-A (interface) |
| `ExtUri` ctor (resources.ts:141) | holds `_ignorePathCasing: (URI)→bool` | `ExtUri::new(ignore_path_casing: (Uri)->Bool)` | PASS |
| `compare` (resources.ts:143) | identity 0; `strCompare` of comparison keys | `ExtUri::compare(u1, u2, ignore_fragment~=false)` — **must use ported `strings.compare`, not MoonBit's length-first `String` compare** | PASS |
| `isEqual` (resources.ts:150) | identity; None handling; key equality | `ExtUri::is_equal(u1?, u2?, ignore_fragment~)` | PASS |
| `getComparisonKey` (resources.ts:160) | `with(path: lowercased?, fragment: cleared?)`.toString() | `ExtUri::get_comparison_key` | PASS |
| `ignorePathCasing` (resources.ts:167) | closure call | `ExtUri::ignore_path_casing` | PASS |
| `isEqualOrParent` (resources.ts:171) | file scheme → extpath on fsPaths; else authority-equal + extpath posix-forced; query/fragment equality gates | `ExtUri::is_equal_or_parent` | PASS |
| `joinPath` (resources.ts:185) | delegates `URI.joinPath` | `ExtUri::join_path` | PASS |
| `basenameOrAuthority` (resources.ts:189) | basename ∥ authority | `ExtUri::basename_or_authority` | PASS |
| `basename` (resources.ts:193) | `posix.basename(uri.path, suffix?)` | `ExtUri::basename` | PASS |
| `extname` (resources.ts:197) | `posix.extname(uri.path)` | `ExtUri::extname` | PASS |
| `dirname` (resources.ts:201) | empty-path passthrough; file → `URI.file(paths.dirname(originalFSPath)).path`; else posix.dirname + authority/relative-path guard (resources.ts:210-213) | `ExtUri::dirname` | PASS |
| `normalizePath` (resources.ts:220) | file → via fsPath round-trip; else posix.normalize | `ExtUri::normalize_path` | PASS |
| `relativePath` (resources.ts:235) | scheme/authority gate → None; file → platform relative (+toSlashes on win); ignore-case prefix alignment (resources.ts:245-256) | `ExtUri::relative_path -> String?` | PASS |
| `resolvePath` (resources.ts:260) | file → `URI.file(paths.resolve(...))` keep authority; else toPosixPath + posix.resolve | `ExtUri::resolve_path` | PASS |
| `isAbsolutePath` (resources.ts:276) | path[0] == `/` | `ExtUri::is_absolute_path` | PASS |
| `isEqualAuthority` (resources.ts:280) | `===` ∨ equalsIgnoreCase | `ExtUri::is_equal_authority` | PASS |
| `hasTrailingPathSeparator` (resources.ts:284) | file → fsPath vs getRoot length; else path len>1 + trailing `/` + drive-root regex guard (resources.ts:290) | `ExtUri::has_trailing_path_separator(res, sep~)` | PASS |
| `removeTrailingPathSeparator` (resources.ts:294) | conditional `path[:-1]` | `ExtUri::remove_trailing_path_separator` | PASS |
| `addTrailingPathSeparator` (resources.ts:302) | root-sep detection file/other; append `/` | `ExtUri::add_trailing_path_separator` | PASS |
| `extUri` (resources.ts:327) | `ExtUri(() => false)` | top-level `ext_uri` | PASS |
| `extUriBiasedIgnorePathCase` (resources.ts:340) | file → `!isLinux`, else true | `ext_uri_biased_ignore_path_case` | PASS |
| `extUriIgnorePathCase` (resources.ts:358) | always true | `ext_uri_ignore_path_case` | PASS |
| bound exports `isEqual…addTrailingPathSeparator` ×16 (resources.ts:360-375) | `extUri.<fn>.bind` | top-level fns delegating to `ext_uri` — **14 of 16**: `dirname`/`isEqualOrParent` stay methods-only (D10) | PASS |
| `distinctParents` (resources.ts:379) | — | — | DEFERRED (no consumer) |
| `DataUri` namespace (resources.ts:402) / `toLocalResource` (resources.ts:433) | — | — | DEFERRED (no consumer) |

### Support seams (5 members)

| Source member (file:line) | Arithmetic / transition | MoonBit symbol | Status |
|---|---|---|---|
| `strings.ts:343 compare` | charwise `<`/`>` lexicographic on code units | `strings.mbt compare` — required because MoonBit `String` compare is length-first (see `moonbit-string-gotchas`) | PASS |
| `strings.ts:436 equalsIgnoreCase` | length gate + `compareSubstringIgnoreCase` (the pinned commit has no `doEqualsIgnoreCase` helper); non-ASCII falls back to lower-cased `compare_substring` (D9) | `equals_ignore_case` | PASS |
| `strings.ts:444 startsWithIgnoreCase` | length gate + prefix case-fold | `starts_with_ignore_case` | PASS |
| `network.ts:44/18/48 Schemas.file/inMemory/untitled` | `"file"` / `"inmemory"` / `"untitled"` | `network.mbt` `schemas_file` / `schemas_in_memory` / `schemas_untitled` | PASS |
| `process.ts:26-29 (node) / 38-43 (web)` `cwd`/`env` | node: `VSCODE_CWD` ∥ `process.cwd()`; web: `'/'`, `{}` | `process.mbt` `cwd()` / `env(key) -> String?`, target-gated like `platform_js.mbt` | PASS |

Member count: 24 + 37 + 17 + 27 + 5 = **110** ledger member groups (the
tables hold 112 physical rows — some groups span rows). Reconciled at exit —
every row terminal: **86 PASS / 20 DEFERRED / 6 N-A**.

## Deviations (Phase 3)

Every non-source-cited line must trace to one of these; anything else found in
review is a bug.

- **D1 — platform binding.** `platformIsWin32` is bound at module load
  (path.ts:82); we read `@base_common.is_windows()` per call. Observationally
  identical (platform never changes mid-session).
- **D2 — namespace shape.** JS object literals `posix`/`win32` become zero-field
  namespace types `Posix`/`Win32` with static-style methods; JS variadics
  (`...paths`) become `Array[String]` parameters; optional `suffix?` uses
  MoonBit optional named args.
- **D3 — no regex.** MoonBit has no regex dependency here. `_regexp`
  (uri.ts:84), `_rEncodedAsHex` (uri.ts:740), `toSlashes`/`toPosixPath` char
  classes (extpath.ts:22,36), drive-root guard (resources.ts:290), and
  `posixCwd`'s backslash replace (path.ts:1139) become hand-rolled scanners
  with identical accept/capture semantics, each proven by transcribed oracle
  tests.
- **D4 — native URI codec.** JS `encodeURIComponent`/`decodeURIComponent`
  (used for delegated spans in uri.ts:564,599 and decode in uri.ts:730) are
  reimplemented in pure MoonBit as UTF-8 percent transcoding (uppercase hex),
  keeping `base/common` target-independent instead of adding a js extern.
  Semantics to match: chars reaching the native path are exactly those outside
  the fast-path sets, so "UTF-8 encode every delegated char" is equivalent;
  decode of invalid `%` sequences/invalid UTF-8 must fail so
  `decode_uri_component_graceful` keeps raw text; a **lone surrogate** makes JS
  `encodeURIComponent` throw `URIError` — we `abort` (the unchecked analog,
  keeping `to_string` non-raising; pinned by a panic test).
- **D5 — class collapse.** Monaco splits abstract `URI` from caching subclass
  `Uri` (uri.ts:455) purely for `vscode.Uri` API compat. We use one `Uri` struct
  with `mut _formatted : String?` / `mut _fs_path : String?` caches. Derived
  `Eq`/`Hash`/`Debug` must ignore the two cache fields (manual impl over the
  five components).
- **D6 — throws → MoonBit errors.** `[UriError]` throws in `_validateUri`
  become a `UriError` suberror raised by `Uri::parse`/`Uri::from`/`Uri::with_`;
  `Uri::file` also runs the validating constructor but its inputs cannot fail
  validation (the file scheme is fixed and the path is slash-rooted), so it
  stays non-raising with an internal `try!`. `URI.joinPath` on an empty path
  (uri.ts:362) becomes `abort` (programmer error, matching Monaco's
  unconditional throw); `ExtUri`'s internal `with_` calls are `try!` because
  the paths they pass keep the input URI's validated shape. The homegrown
  `UriResult`/`UriError` enums and `Uri::memory`/`display_name` are
  **deleted** (no backcompat, per `editor-refactor-no-backcompat`).
  `with`'s undefined/null distinction maps to optional named args: omitted =
  keep, `Some("")` = clear (Monaco maps null → `''` anyway, uri.ts:227-249).
- **D7 — marshalling deferred.** `toJSON`/`revive`/`UriState`/`$mid`/
  `_pathSepMarker` exist for structured-clone IPC. Our remote protocol
  serializes `uri.to_string()` strings; port these only if a components-level
  protocol seam appears.
- **D8 — `is_windows` test seam.** uri.ts/resources.ts branch on the *global*
  `isWindows` (file/joinPath/uriToFsPath/relativePath). `Posix::`/`Win32::`
  members are directly callable so the bulk of both axes is testable anywhere,
  but the global-branch lines need a debug-only override
  (`set_is_windows_for_testing`, mirroring the `viewer/debug.mbt` seam
  precedent) so non-Windows CI exercises the win32 branches. Monaco itself
  gates these tests with `if (isWindows)` — we improve on that deliberately.

- **D9 — partial Unicode lowercasing.** JS `toLowerCase()` (authority
  lowering in `_asFormatted`, `win32.relative`, `getComparisonKey`, the
  `compareSubstringIgnoreCase` non-ASCII fallback) is full-Unicode; MoonBit's
  `String::to_lower` is ASCII-only. `strings.mbt to_lower_js` implements the
  simple case mapping for ASCII, Latin-1, Latin Extended-A, Greek, Cyrillic
  and fullwidth Latin; other scripts and length-changing mappings (e.g. `İ`)
  pass through unchanged.
- **D10 — flat-package name collisions.** Monaco disambiguates
  `resources.dirname` from `paths.dirname` and `resources.isEqualOrParent`
  from `extpath.isEqualOrParent` by module; one flat `base/common` package
  cannot. The path/extpath members keep the top-level names (they are ported
  whole-file units); the two resources bound exports are reachable as
  `ext_uri.dirname` / `ext_uri.is_equal_or_parent` only (the other 14 bound
  exports are ported as planned).

## Migration (Track E — consumers of the old API)

The old `uri.mbt` surface is deleted; these call sites changed (all landed —
the re-grep found extra sites beyond the original list, noted inline):

1. **`Uri::parse` returns/raises.** DONE — `remote_protocol/protocol.mbt`
   gained a `try_parse_uri` helper (`ProtocolUriResult` keeps its own error
   mapping; **strict mode** preserves the old reject-scheme-less contract,
   since non-strict parse now accepts anything via `_schemeFix`),
   `server/server.mbt`, `workbench/document_source.mbt`,
   `workbench/protocol_client_wbtest.mbt`, `workspace/source.mbt`; extra
   sites: `server_host_native/moon_check.mbt`, `server/server_test.mbt`,
   `workbench/tree_provider.mbt` (built a `Uri` record literal),
   `widgets/file_tree/tree_state.mbt` + `_wbtest` (record literals),
   `examples/embedded_viewer/main.mbt` (record literal), the
   `uri(...)` helpers in `viewer/contrib/agent_feedback` and
   `viewer/common/markers` wbtests, `language/providers_test.mbt`.
2. **`path()` semantics change** — DONE. `language/selectors.mbt` reads the
   `path` field (leading slash included, Monaco `score()` shape); its
   `path_pattern_matches` already strips the leading slash, so the relative
   patterns hosts register keep matching. `language/providers.mbt` needed no
   change.
3. **`display_name()` deleted** → DONE, all sites use
   `basename_or_authority`: `widgets/file_tree/tree_state_wbtest.mbt`,
   `remote_protocol/protocol.mbt`, `examples/embedded_viewer/main.mbt`,
   `tests/browser/moonbit/perf`, plus `workspace/document.mbt` and
   `workspace/filesystem.mbt` (not in the original list).
4. **`Uri::memory(name)` deleted** → DONE, all ~29 sites now build
   `inmemory://model/<name>` via `Uri::from(scheme="inmemory",
   authority="model", path="/" + name)` (the `modelService.ts` pattern;
   `document_source.mbt` uses the `schemas_in_memory` constant).
5. **`workspace/source.mbt:86`** — DONE: `SourcePath::file_uri` now builds
   `Uri::file("/local/" + path)` → `file:///local/<path>` (decided as
   planned; `source_test.mbt` updated).
6. **String-identity drift.** DONE — swept: `text_model_test.mbt` needles
   updated to `inmemory://model/…`; the `memory://session/*.mbt` wbtest URIs
   still parse to themselves (generic scheme) and were left; browser suite
   green (labels come from `basename`, unchanged).
7. **Equality/keys.** DONE — manual `Eq`/`Hash` over the five components
   (D5); the sweep found no `Uri`-keyed maps (hosts key on `to_string()`
   `uri_key` strings, which stay canonical).

## Test matrix (Phase 4)

Oracle transcriptions (conformance ports per `docs/quality.md`):

- `path_reference_test.mbt` ← `vs/base/test/common/path.test.ts` (822 lines).
  Its tables call `posix.*`/`win32.*` explicitly → transcribe against
  `Posix::`/`Win32::` directly; platform-selected assertions use the D8 seam.
- `uri_reference_test.mbt` ← `vs/base/test/common/uri.test.ts` (649 lines):
  component parsing, toString round-trips, `file`+`fsPath` (UNC, drive
  letters), `with`, `joinPath`, strict-mode errors, encode/decode cases,
  non-ASCII. Windows-gated suites run under the D8 seam instead of being
  skipped.
- `extpath_reference_test.mbt` / `resources_reference_test.mbt` ← the in-scope
  members' suites from `extpath.test.ts` / `resources.test.ts`.

Behavior-switching variables (cover combinations, not one happy path):

- **platform**: posix × win32 (namespace-direct and via D8 global seam);
- **strict** flag: true/false × missing scheme × illegal scheme chars ×
  authority/path slash-rule violations (each `_validateUri` branch);
- **scheme**: `file` / `http`,`https` / other (`inmemory`, `untitled`) / empty
  — drives `_schemeFix`, `_referenceResolution`, fsPath, ExtUri file-branches;
- **authority**: empty / host / `user@host` / `user:pass@host` / `host:port` /
  mixed-case (lowercasing) — each `_asFormatted` userinfo branch;
- **path**: empty / `/` / relative / `/C:/…` and `C:/…` drive forms (upper +
  lower) / UNC `//server/share` / trailing separators / `.` `..` segments
  (above root × allowAboveRoot) / `#` `?` literals via `URI.file` vs `parse`;
- **encoding**: unreserved-only (no-alloc fast path) / table chars / delegated
  chars / already-encoded input (`percentDecode` round-trip) / invalid `%ZZ`
  (graceful) / double-encoded / `skipEncoding` variant / non-ASCII + astral
  chars in path (also proves MoonBit surrogate-safe slicing; cut points are
  always at ASCII delimiters) / lone surrogate raise (D4);
- **basename suffix** arg: matching / non-matching / equal-to-path / empty;
- **ExtUri config**: ignorePathCasing false/true/biased × ignoreFragment
  true/false; `compare` ordering incl. the length-vs-lexicographic case that
  MoonBit's built-in compare would get wrong (e.g. `"z"` vs `"aa"`).

Harness: `just check`, `just test` (js target; `moon update` first per
`editor-validation-workflow`), and `just test-browser` for Track E label/needle
fallout. Reference tests run in the same package (whitebox where private fns
need pinning, e.g. `normalize_string`, `encode_uri_component_fast` span logic).

## Exit gate (Phase 5)

- [x] Inventory reconciled (110 member groups / 112 rows): done/deferred/N-A = 86/20/6
- [x] Every ported fn diff-reviewed side-by-side vs source (branch order,
      constants, early returns) — transcription done clause-by-clause from the
      pinned sources; oracle suites pin the behavior
- [x] Test matrix covered; 112 `base/common` tests green on js **and native**;
      full tree 720 js / 635 native; browser suite 29/29 after Track E
- [x] Deviations section complete — every non-source-cited line maps to D1–D10
- [x] Old API fully deleted (`UriResult`, `UriError` enum shape, `Uri::memory`,
      `display_name`, string-field `Uri`); tree-wide grep clean (remaining
      `display_name` hits are the unrelated `SourcePath::display_name` and
      struct fields; `ProtocolUriResult` is the protocol's own enum)
- [x] Closing self-audit pasted below

## Self-audit

Re-read of the four sources against the landed `.mbt` files, 2026-07-08:

- **uri.ts** — every member row terminal. `_validateUri`/`_schemeFix`/
  `_referenceResolution`/ctor pipeline transcribed in order; `parse` scanner
  reproduces `_regexp` group-by-group (incl. the lazy scheme group needing
  ≥1 char before `:` and the fragment `.` stopping at line terminators);
  `file`'s UNC split, `with_`'s identity short-circuit, `joinPath`'s
  win32/posix fork, `toString`/`fsPath` caching (cached only when
  `!skipEncoding`), `encodeURIComponentFast`'s three-state loop (fast path /
  table / delayed native span, allocate-only-on-change), `uriToFsPath`'s UNC
  + drive-letter branches, `_asFormatted`'s userinfo/port/drive-lowering
  branches, `decodeURIComponentGraceful`'s 3-char retry, and
  `percentDecode`'s loose `%[0-9A-Za-z]{2}` run detection all match.
  `toJSON`/`revive` deferred (D7); `isUri`/`isUriComponents`/`UriDto` N-A.
- **path.ts** — `normalizeString` state machine verbatim (lastSlash/dots/
  lastSegmentLength, allowAboveRoot emission); win32 `resolve`/`normalize`
  (UNC-only early return, CVE-2024-36139 colon guard)/`join` (UNC
  double-slash preservation)/`relative` (lowercase compare + split-path
  branch)/`dirname`/`basename` (drive-prefix skip + suffix reverse-match)/
  `extname` (preDotState); posix counterparts; `posixCwd` and the
  platform-selected consumed five. JS NaN/`slice` semantics via
  `char_code_at`/`js_slice`. `format`/`parse`/`toNamespacedPath` +
  unconsumed platform-selected exports deferred.
- **extpath.ts** — consumed subset (`toSlashes`, `toPosixPath`, `getRoot`,
  `isEqualOrParent`, `isWindowsDriveLetter`) matches branch-for-branch,
  including `getRoot`'s out-of-range `charCodeAt(pos + 1)` read; the ten
  unconsumed member groups deferred.
- **resources.ts** — `ExtUri` methods transcribed with the `_ignorePathCasing`
  closure; `getComparisonKey` builds the same `with` change-set;
  `hasTrailingPathSeparator`'s drive-root regex became char checks;
  `removeTrailingPathSeparator` deliberately calls the module-level (bound)
  `has_trailing_path_separator` like the source; the three instances bind the
  same closures (`false` / file→`!isLinux` else `true` / `true`); 14 of 16
  bound exports at top level (D10). `distinctParents`/`DataUri`/
  `toLocalResource` deferred.
- **Cross-checks** — `strings.compare` (not MoonBit's length-first compare)
  feeds `ExtUri::compare` and is pinned by the `"z"` vs `"aa"` matrix test;
  the D8 seam exercises every `isWindows`-gated suite on both axes in CI;
  `base/common` remains target-independent (`process`/`platform` are the only
  target-gated files).

Validation: `just check` (moon check `--target all --warn-list +73` + fmt +
architecture) clean; `moon test --target all` 720 js / 635 native, 0 failures;
`just test-browser` 29/29. Remaining warnings in the tree belong to the
concurrent interval-tree edit-cluster removal, not this port.
