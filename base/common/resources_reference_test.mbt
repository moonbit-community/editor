// Conformance port of `vs/base/test/common/resources.test.ts` in the checked-in
// vscode source, suite "Resources".
// `distinctParents` covers a DEFERRED member and is not transcribed.
//
// The `isWindows` branches run under the D8 seam (both ways where the JS
// test only ran the host's); URIs are created after setting the seam
// because `fs_path`/`to_string` cache (D5). `dirname`/`isEqualOrParent`
// URI-level calls go through `ext_uri` (bound exports omitted — see
// resources.mbt header).

///|
fn assert_equal_uri(
  actual : @common.Uri,
  expected : @common.Uri,
  msg? : String,
  ignore_case? : Bool = false,
) -> Unit raise {
  let util = if ignore_case {
    @common.ext_uri_ignore_path_case
  } else {
    @common.ext_uri
  }
  if !util.is_equal(Some(expected), Some(actual)) {
    assert_eq(actual.to_string(), expected.to_string(), msg?)
  }
}

///|
test "dirname" {
  @common.set_is_windows_for_testing(value=true)
  assert_eq(
    @common.ext_uri
    .dirname(@common.Uri::file("c:\\some\\file\\test.txt"))
    .to_string(),
    "file:///c%3A/some/file",
  )
  assert_eq(
    @common.ext_uri.dirname(@common.Uri::file("c:\\some\\file")).to_string(),
    "file:///c%3A/some",
  )
  assert_eq(
    @common.ext_uri.dirname(@common.Uri::file("c:\\some\\file\\")).to_string(),
    "file:///c%3A/some",
  )
  assert_eq(
    @common.ext_uri.dirname(@common.Uri::file("c:\\some")).to_string(),
    "file:///c%3A/",
  )
  assert_eq(
    @common.ext_uri.dirname(@common.Uri::file("C:\\some")).to_string(),
    "file:///c%3A/",
  )
  assert_eq(
    @common.ext_uri.dirname(@common.Uri::file("c:\\")).to_string(),
    "file:///c%3A/",
  )
  ignore(
    @common.ext_uri.dirname(
      @common.Uri::from(scheme="file", authority="/users/someone/portal.h"),
    ),
  )
  @common.set_is_windows_for_testing(value=false)
  assert_eq(
    @common.ext_uri
    .dirname(@common.Uri::file("/some/file/test.txt"))
    .to_string(),
    "file:///some/file",
  )
  assert_eq(
    @common.ext_uri.dirname(@common.Uri::file("/some/file/")).to_string(),
    "file:///some",
  )
  assert_eq(
    @common.ext_uri.dirname(@common.Uri::file("/some/file")).to_string(),
    "file:///some",
  )
  // does not explode (https://github.com/microsoft/vscode/issues/41987)
  ignore(
    @common.ext_uri.dirname(
      @common.Uri::from(scheme="file", authority="/users/someone/portal.h"),
    ),
  )
  @common.set_is_windows_for_testing()
  assert_eq(
    @common.ext_uri
    .dirname(@common.Uri::parse("foo://a/some/file/test.txt"))
    .to_string(),
    "foo://a/some/file",
  )
  assert_eq(
    @common.ext_uri
    .dirname(@common.Uri::parse("foo://a/some/file/"))
    .to_string(),
    "foo://a/some",
  )
  assert_eq(
    @common.ext_uri.dirname(@common.Uri::parse("foo://a/some/file")).to_string(),
    "foo://a/some",
  )
  assert_eq(
    @common.ext_uri.dirname(@common.Uri::parse("foo://a/some")).to_string(),
    "foo://a/",
  )
  assert_eq(
    @common.ext_uri.dirname(@common.Uri::parse("foo://a/")).to_string(),
    "foo://a/",
  )
  assert_eq(
    @common.ext_uri.dirname(@common.Uri::parse("foo://a")).to_string(),
    "foo://a",
  )
  assert_eq(
    @common.ext_uri.dirname(@common.Uri::parse("foo://a/b/c?q")).to_string(),
    "foo://a/b?q",
  )
}

///|
test "basename" {
  @common.set_is_windows_for_testing(value=true)
  assert_eq(
    @common.basename(@common.Uri::file("c:\\some\\file\\test.txt")),
    "test.txt",
  )
  assert_eq(@common.basename(@common.Uri::file("c:\\some\\file")), "file")
  assert_eq(@common.basename(@common.Uri::file("c:\\some\\file\\")), "file")
  assert_eq(@common.basename(@common.Uri::file("C:\\some\\file\\")), "file")
  @common.set_is_windows_for_testing(value=false)
  assert_eq(
    @common.basename(@common.Uri::file("/some/file/test.txt")),
    "test.txt",
  )
  assert_eq(@common.basename(@common.Uri::file("/some/file/")), "file")
  assert_eq(@common.basename(@common.Uri::file("/some/file")), "file")
  assert_eq(@common.basename(@common.Uri::file("/some")), "some")
  @common.set_is_windows_for_testing()
  assert_eq(
    @common.basename(@common.Uri::parse("foo://a/some/file/test.txt")),
    "test.txt",
  )
  assert_eq(@common.basename(@common.Uri::parse("foo://a/some/file/")), "file")
  assert_eq(@common.basename(@common.Uri::parse("foo://a/some/file")), "file")
  assert_eq(@common.basename(@common.Uri::parse("foo://a/some")), "some")
  assert_eq(@common.basename(@common.Uri::parse("foo://a/")), "")
  assert_eq(@common.basename(@common.Uri::parse("foo://a")), "")
}

///|
test "joinPath" {
  @common.set_is_windows_for_testing(value=true)
  assert_eq(
    @common.join_path(@common.Uri::file("c:\\foo\\bar"), ["/file.js"]).to_string(),
    "file:///c%3A/foo/bar/file.js",
  )
  assert_eq(
    @common.join_path(@common.Uri::file("c:\\foo\\bar\\"), ["file.js"]).to_string(),
    "file:///c%3A/foo/bar/file.js",
  )
  assert_eq(
    @common.join_path(@common.Uri::file("c:\\foo\\bar\\"), ["/file.js"]).to_string(),
    "file:///c%3A/foo/bar/file.js",
  )
  assert_eq(
    @common.join_path(@common.Uri::file("c:\\"), ["/file.js"]).to_string(),
    "file:///c%3A/file.js",
  )
  assert_eq(
    @common.join_path(@common.Uri::file("c:\\"), ["bar/file.js"]).to_string(),
    "file:///c%3A/bar/file.js",
  )
  assert_eq(
    @common.join_path(@common.Uri::file("c:\\foo"), ["./file.js"]).to_string(),
    "file:///c%3A/foo/file.js",
  )
  assert_eq(
    @common.join_path(@common.Uri::file("c:\\foo"), ["/./file.js"]).to_string(),
    "file:///c%3A/foo/file.js",
  )
  assert_eq(
    @common.join_path(@common.Uri::file("C:\\foo"), ["../file.js"]).to_string(),
    "file:///c%3A/file.js",
  )
  assert_eq(
    @common.join_path(@common.Uri::file("C:\\foo\\."), ["../file.js"]).to_string(),
    "file:///c%3A/file.js",
  )
  @common.set_is_windows_for_testing(value=false)
  assert_eq(
    @common.join_path(@common.Uri::file("/foo/bar"), ["/file.js"]).to_string(),
    "file:///foo/bar/file.js",
  )
  assert_eq(
    @common.join_path(@common.Uri::file("/foo/bar"), ["file.js"]).to_string(),
    "file:///foo/bar/file.js",
  )
  assert_eq(
    @common.join_path(@common.Uri::file("/foo/bar/"), ["/file.js"]).to_string(),
    "file:///foo/bar/file.js",
  )
  assert_eq(
    @common.join_path(@common.Uri::file("/"), ["/file.js"]).to_string(),
    "file:///file.js",
  )
  assert_eq(
    @common.join_path(@common.Uri::file("/foo/bar"), ["./file.js"]).to_string(),
    "file:///foo/bar/file.js",
  )
  assert_eq(
    @common.join_path(@common.Uri::file("/foo/bar"), ["/./file.js"]).to_string(),
    "file:///foo/bar/file.js",
  )
  assert_eq(
    @common.join_path(@common.Uri::file("/foo/bar"), ["../file.js"]).to_string(),
    "file:///foo/file.js",
  )
  @common.set_is_windows_for_testing()
  assert_eq(
    @common.join_path(@common.Uri::parse("foo://a/foo/bar"), []).to_string(),
    "foo://a/foo/bar",
  )
  assert_eq(
    @common.join_path(@common.Uri::parse("foo://a/foo/bar"), ["/file.js"]).to_string(),
    "foo://a/foo/bar/file.js",
  )
  assert_eq(
    @common.join_path(@common.Uri::parse("foo://a/foo/bar"), ["file.js"]).to_string(),
    "foo://a/foo/bar/file.js",
  )
  assert_eq(
    @common.join_path(@common.Uri::parse("foo://a/foo/bar/"), ["/file.js"]).to_string(),
    "foo://a/foo/bar/file.js",
  )
  assert_eq(
    @common.join_path(@common.Uri::parse("foo://a/"), ["/file.js"]).to_string(),
    "foo://a/file.js",
  )
  assert_eq(
    @common.join_path(@common.Uri::parse("foo://a/foo/bar/"), ["./file.js"]).to_string(),
    "foo://a/foo/bar/file.js",
  )
  assert_eq(
    @common.join_path(@common.Uri::parse("foo://a/foo/bar/"), ["/./file.js"]).to_string(),
    "foo://a/foo/bar/file.js",
  )
  assert_eq(
    @common.join_path(@common.Uri::parse("foo://a/foo/bar/"), ["../file.js"]).to_string(),
    "foo://a/foo/file.js",
  )
  assert_eq(
    @common.join_path(
      @common.Uri::from(
        scheme="myScheme",
        authority="authority",
        path="/path",
        query="query",
        fragment="fragment",
      ),
      ["/file.js"],
    ).to_string(),
    "myScheme://authority/path/file.js?query#fragment",
  )
}

///|
test "normalizePath" {
  @common.set_is_windows_for_testing(value=true)
  assert_eq(
    @common.normalize_path(@common.Uri::file("c:\\foo\\.\\bar")).to_string(),
    "file:///c%3A/foo/bar",
  )
  assert_eq(
    @common.normalize_path(@common.Uri::file("c:\\foo\\.")).to_string(),
    "file:///c%3A/foo",
  )
  assert_eq(
    @common.normalize_path(@common.Uri::file("c:\\foo\\.\\")).to_string(),
    "file:///c%3A/foo/",
  )
  assert_eq(
    @common.normalize_path(@common.Uri::file("c:\\foo\\..")).to_string(),
    "file:///c%3A/",
  )
  assert_eq(
    @common.normalize_path(@common.Uri::file("c:\\foo\\..\\bar")).to_string(),
    "file:///c%3A/bar",
  )
  assert_eq(
    @common.normalize_path(@common.Uri::file("c:\\foo\\..\\..\\bar")).to_string(),
    "file:///c%3A/bar",
  )
  assert_eq(
    @common.normalize_path(@common.Uri::file("c:\\foo\\foo\\..\\..\\bar")).to_string(),
    "file:///c%3A/bar",
  )
  assert_eq(
    @common.normalize_path(@common.Uri::file("C:\\foo\\foo\\.\\..\\..\\bar")).to_string(),
    "file:///c%3A/bar",
  )
  assert_eq(
    @common.normalize_path(
      @common.Uri::file("C:\\foo\\foo\\.\\..\\some\\..\\bar"),
    ).to_string(),
    "file:///c%3A/foo/bar",
  )
  @common.set_is_windows_for_testing(value=false)
  assert_eq(
    @common.normalize_path(@common.Uri::file("/foo/./bar")).to_string(),
    "file:///foo/bar",
  )
  assert_eq(
    @common.normalize_path(@common.Uri::file("/foo/.")).to_string(),
    "file:///foo",
  )
  assert_eq(
    @common.normalize_path(@common.Uri::file("/foo/./")).to_string(),
    "file:///foo/",
  )
  assert_eq(
    @common.normalize_path(@common.Uri::file("/foo/..")).to_string(),
    "file:///",
  )
  assert_eq(
    @common.normalize_path(@common.Uri::file("/foo/../bar")).to_string(),
    "file:///bar",
  )
  assert_eq(
    @common.normalize_path(@common.Uri::file("/foo/../../bar")).to_string(),
    "file:///bar",
  )
  assert_eq(
    @common.normalize_path(@common.Uri::file("/foo/foo/../../bar")).to_string(),
    "file:///bar",
  )
  assert_eq(
    @common.normalize_path(@common.Uri::file("/foo/foo/./../../bar")).to_string(),
    "file:///bar",
  )
  assert_eq(
    @common.normalize_path(@common.Uri::file("/foo/foo/./../some/../bar")).to_string(),
    "file:///foo/bar",
  )
  assert_eq(
    @common.normalize_path(@common.Uri::file("/f")).to_string(),
    "file:///f",
  )
  @common.set_is_windows_for_testing()
  assert_eq(
    @common.normalize_path(@common.Uri::parse("foo://a/foo/./bar")).to_string(),
    "foo://a/foo/bar",
  )
  assert_eq(
    @common.normalize_path(@common.Uri::parse("foo://a/foo/.")).to_string(),
    "foo://a/foo",
  )
  assert_eq(
    @common.normalize_path(@common.Uri::parse("foo://a/foo/./")).to_string(),
    "foo://a/foo/",
  )
  assert_eq(
    @common.normalize_path(@common.Uri::parse("foo://a/foo/..")).to_string(),
    "foo://a/",
  )
  assert_eq(
    @common.normalize_path(@common.Uri::parse("foo://a/foo/../bar")).to_string(),
    "foo://a/bar",
  )
  assert_eq(
    @common.normalize_path(@common.Uri::parse("foo://a/foo/../../bar")).to_string(),
    "foo://a/bar",
  )
  assert_eq(
    @common.normalize_path(@common.Uri::parse("foo://a/foo/foo/../../bar")).to_string(),
    "foo://a/bar",
  )
  assert_eq(
    @common.normalize_path(@common.Uri::parse("foo://a/foo/foo/./../../bar")).to_string(),
    "foo://a/bar",
  )
  assert_eq(
    @common.normalize_path(
      @common.Uri::parse("foo://a/foo/foo/./../some/../bar"),
    ).to_string(),
    "foo://a/foo/bar",
  )
  assert_eq(
    @common.normalize_path(@common.Uri::parse("foo://a")).to_string(),
    "foo://a",
  )
  assert_eq(
    @common.normalize_path(@common.Uri::parse("foo://a/")).to_string(),
    "foo://a/",
  )
  assert_eq(
    @common.normalize_path(@common.Uri::parse("foo://a/foo/./bar?q=1")).to_string(),
    @common.Uri::parse("foo://a/foo/bar?q%3D1").to_string(),
  )
}

///|
test "isAbsolute" {
  @common.set_is_windows_for_testing(value=true)
  assert_eq(@common.is_absolute_path(@common.Uri::file("c:\\foo\\")), true)
  assert_eq(@common.is_absolute_path(@common.Uri::file("C:\\foo\\")), true)
  assert_eq(@common.is_absolute_path(@common.Uri::file("bar")), true) // URI normalizes all file URIs to be absolute
  @common.set_is_windows_for_testing(value=false)
  assert_eq(@common.is_absolute_path(@common.Uri::file("/foo/bar")), true)
  assert_eq(@common.is_absolute_path(@common.Uri::file("bar")), true) // URI normalizes all file URIs to be absolute
  @common.set_is_windows_for_testing()
  assert_eq(@common.is_absolute_path(@common.Uri::parse("foo:foo")), false)
  assert_eq(@common.is_absolute_path(@common.Uri::parse("foo://a/foo/.")), true)
}

///|
fn assert_trailing_separator(u1 : @common.Uri, expected : Bool) -> Unit raise {
  assert_eq(
    @common.has_trailing_path_separator(u1),
    expected,
    msg=u1.to_string(),
  )
}

///|
fn assert_remove_trailing_separator(
  u1 : @common.Uri,
  expected : @common.Uri,
) -> Unit raise {
  assert_equal_uri(
    @common.remove_trailing_path_separator(u1),
    expected,
    msg=u1.to_string(),
  )
}

///|
fn assert_add_trailing_separator(
  u1 : @common.Uri,
  expected : @common.Uri,
) -> Unit raise {
  assert_equal_uri(
    @common.add_trailing_path_separator(u1),
    expected,
    msg=u1.to_string(),
  )
}

///|
test "trailingPathSeparator" {
  assert_trailing_separator(@common.Uri::parse("foo://a/foo"), false)
  assert_trailing_separator(@common.Uri::parse("foo://a/foo/"), true)
  assert_trailing_separator(@common.Uri::parse("foo://a/"), false)
  assert_trailing_separator(@common.Uri::parse("foo://a"), false)
  assert_remove_trailing_separator(
    @common.Uri::parse("foo://a/foo"),
    @common.Uri::parse("foo://a/foo"),
  )
  assert_remove_trailing_separator(
    @common.Uri::parse("foo://a/foo/"),
    @common.Uri::parse("foo://a/foo"),
  )
  assert_remove_trailing_separator(
    @common.Uri::parse("foo://a/"),
    @common.Uri::parse("foo://a/"),
  )
  assert_remove_trailing_separator(
    @common.Uri::parse("foo://a"),
    @common.Uri::parse("foo://a"),
  )
  assert_add_trailing_separator(
    @common.Uri::parse("foo://a/foo"),
    @common.Uri::parse("foo://a/foo/"),
  )
  assert_add_trailing_separator(
    @common.Uri::parse("foo://a/foo/"),
    @common.Uri::parse("foo://a/foo/"),
  )
  assert_add_trailing_separator(
    @common.Uri::parse("foo://a/"),
    @common.Uri::parse("foo://a/"),
  )
  assert_add_trailing_separator(
    @common.Uri::parse("foo://a"),
    @common.Uri::parse("foo://a/"),
  )
  @common.set_is_windows_for_testing(value=true)
  assert_trailing_separator(@common.Uri::file("c:\\a\\foo"), false)
  assert_trailing_separator(@common.Uri::file("c:\\a\\foo\\"), true)
  assert_trailing_separator(@common.Uri::file("c:\\"), false)
  assert_trailing_separator(
    @common.Uri::file("\\\\server\\share\\some\\"),
    true,
  )
  assert_trailing_separator(@common.Uri::file("\\\\server\\share\\"), false)
  assert_remove_trailing_separator(
    @common.Uri::file("c:\\a\\foo"),
    @common.Uri::file("c:\\a\\foo"),
  )
  assert_remove_trailing_separator(
    @common.Uri::file("c:\\a\\foo\\"),
    @common.Uri::file("c:\\a\\foo"),
  )
  assert_remove_trailing_separator(
    @common.Uri::file("c:\\"),
    @common.Uri::file("c:\\"),
  )
  assert_remove_trailing_separator(
    @common.Uri::file("\\\\server\\share\\some\\"),
    @common.Uri::file("\\\\server\\share\\some"),
  )
  assert_remove_trailing_separator(
    @common.Uri::file("\\\\server\\share\\"),
    @common.Uri::file("\\\\server\\share\\"),
  )
  assert_add_trailing_separator(
    @common.Uri::file("c:\\a\\foo"),
    @common.Uri::file("c:\\a\\foo\\"),
  )
  assert_add_trailing_separator(
    @common.Uri::file("c:\\a\\foo\\"),
    @common.Uri::file("c:\\a\\foo\\"),
  )
  assert_add_trailing_separator(
    @common.Uri::file("c:\\"),
    @common.Uri::file("c:\\"),
  )
  assert_add_trailing_separator(
    @common.Uri::file("\\\\server\\share\\some"),
    @common.Uri::file("\\\\server\\share\\some\\"),
  )
  assert_add_trailing_separator(
    @common.Uri::file("\\\\server\\share\\some\\"),
    @common.Uri::file("\\\\server\\share\\some\\"),
  )
  @common.set_is_windows_for_testing(value=false)
  assert_trailing_separator(@common.Uri::file("/foo/bar"), false)
  assert_trailing_separator(@common.Uri::file("/foo/bar/"), true)
  assert_trailing_separator(@common.Uri::file("/"), false)
  assert_remove_trailing_separator(
    @common.Uri::file("/foo/bar"),
    @common.Uri::file("/foo/bar"),
  )
  assert_remove_trailing_separator(
    @common.Uri::file("/foo/bar/"),
    @common.Uri::file("/foo/bar"),
  )
  assert_remove_trailing_separator(
    @common.Uri::file("/"),
    @common.Uri::file("/"),
  )
  assert_add_trailing_separator(
    @common.Uri::file("/foo/bar"),
    @common.Uri::file("/foo/bar/"),
  )
  assert_add_trailing_separator(
    @common.Uri::file("/foo/bar/"),
    @common.Uri::file("/foo/bar/"),
  )
  assert_add_trailing_separator(@common.Uri::file("/"), @common.Uri::file("/"))
  @common.set_is_windows_for_testing()
}

///|
fn assert_relative_path(
  u1 : @common.Uri,
  u2 : @common.Uri,
  expected_path : String?,
  ignore_join? : Bool = false,
  ignore_case? : Bool = false,
) -> Unit raise {
  let util = if ignore_case {
    @common.ext_uri_ignore_path_case
  } else {
    @common.ext_uri
  }
  assert_true(
    util.relative_path(u1, u2) == expected_path,
    msg="from \{u1.to_string()} to \{u2.to_string()}: got \{Repr(util.relative_path(u1, u2))}, want \{Repr(expected_path)}",
  )
  if expected_path is Some(path) && !ignore_join {
    assert_equal_uri(
      @common.remove_trailing_path_separator(@common.join_path(u1, [path])),
      @common.remove_trailing_path_separator(u2),
      msg="joinPath on relativePath should be equal",
      ignore_case~,
    )
  }
}

///|
test "relativePath" {
  assert_relative_path(
    @common.Uri::parse("foo://a/foo"),
    @common.Uri::parse("foo://a/foo/bar"),
    Some("bar"),
  )
  assert_relative_path(
    @common.Uri::parse("foo://a/foo"),
    @common.Uri::parse("foo://a/foo/bar/"),
    Some("bar"),
  )
  assert_relative_path(
    @common.Uri::parse("foo://a/foo"),
    @common.Uri::parse("foo://a/foo/bar/goo"),
    Some("bar/goo"),
  )
  assert_relative_path(
    @common.Uri::parse("foo://a/"),
    @common.Uri::parse("foo://a/foo/bar/goo"),
    Some("foo/bar/goo"),
  )
  assert_relative_path(
    @common.Uri::parse("foo://a/foo/xoo"),
    @common.Uri::parse("foo://a/foo/bar"),
    Some("../bar"),
  )
  assert_relative_path(
    @common.Uri::parse("foo://a/foo/xoo/yoo"),
    @common.Uri::parse("foo://a"),
    Some("../../.."),
    ignore_join=true,
  )
  assert_relative_path(
    @common.Uri::parse("foo://a/foo"),
    @common.Uri::parse("foo://a/foo/"),
    Some(""),
  )
  assert_relative_path(
    @common.Uri::parse("foo://a/foo/"),
    @common.Uri::parse("foo://a/foo"),
    Some(""),
  )
  assert_relative_path(
    @common.Uri::parse("foo://a/foo/"),
    @common.Uri::parse("foo://a/foo/"),
    Some(""),
  )
  assert_relative_path(
    @common.Uri::parse("foo://a/foo"),
    @common.Uri::parse("foo://a/foo"),
    Some(""),
  )
  assert_relative_path(
    @common.Uri::parse("foo://a"),
    @common.Uri::parse("foo://a"),
    Some(""),
    ignore_join=true,
  )
  assert_relative_path(
    @common.Uri::parse("foo://a/"),
    @common.Uri::parse("foo://a/"),
    Some(""),
  )
  assert_relative_path(
    @common.Uri::parse("foo://a/"),
    @common.Uri::parse("foo://a"),
    Some(""),
    ignore_join=true,
  )
  assert_relative_path(
    @common.Uri::parse("foo://a/foo?q"),
    @common.Uri::parse("foo://a/foo/bar#h"),
    Some("bar"),
    ignore_join=true,
  )
  assert_relative_path(
    @common.Uri::parse("foo://"),
    @common.Uri::parse("foo://a/b"),
    None,
  )
  assert_relative_path(
    @common.Uri::parse("foo://a2/b"),
    @common.Uri::parse("foo://a/b"),
    None,
  )
  assert_relative_path(
    @common.Uri::parse("goo://a/b"),
    @common.Uri::parse("foo://a/b"),
    None,
  )
  assert_relative_path(
    @common.Uri::parse("foo://a/foo"),
    @common.Uri::parse("foo://A/FOO/bar/goo"),
    Some("bar/goo"),
    ignore_case=true,
  )
  assert_relative_path(
    @common.Uri::parse("foo://a/foo"),
    @common.Uri::parse("foo://A/FOO/BAR/GOO"),
    Some("BAR/GOO"),
    ignore_case=true,
  )
  assert_relative_path(
    @common.Uri::parse("foo://a/foo/xoo"),
    @common.Uri::parse("foo://A/FOO/BAR/GOO"),
    Some("../BAR/GOO"),
    ignore_case=true,
  )
  assert_relative_path(
    @common.Uri::parse("foo:///c:/a/foo"),
    @common.Uri::parse("foo:///C:/a/foo/xoo/"),
    Some("xoo"),
    ignore_case=true,
  )
  @common.set_is_windows_for_testing(value=true)
  assert_relative_path(
    @common.Uri::file("c:\\foo\\bar"),
    @common.Uri::file("c:\\foo\\bar"),
    Some(""),
  )
  assert_relative_path(
    @common.Uri::file("c:\\foo\\bar\\huu"),
    @common.Uri::file("c:\\foo\\bar"),
    Some(".."),
  )
  assert_relative_path(
    @common.Uri::file("c:\\foo\\bar\\a1\\a2"),
    @common.Uri::file("c:\\foo\\bar"),
    Some("../.."),
  )
  assert_relative_path(
    @common.Uri::file("c:\\foo\\bar\\"),
    @common.Uri::file("c:\\foo\\bar\\a1\\a2"),
    Some("a1/a2"),
  )
  assert_relative_path(
    @common.Uri::file("c:\\foo\\bar\\"),
    @common.Uri::file("c:\\foo\\bar\\a1\\a2\\"),
    Some("a1/a2"),
  )
  assert_relative_path(
    @common.Uri::file("c:\\"),
    @common.Uri::file("c:\\foo\\bar"),
    Some("foo/bar"),
  )
  assert_relative_path(
    @common.Uri::file("\\\\server\\share\\some\\"),
    @common.Uri::file("\\\\server\\share\\some\\path"),
    Some("path"),
  )
  // ignore joinPath assert: path.join is not root aware
  assert_relative_path(
    @common.Uri::file("\\\\server\\share\\some\\"),
    @common.Uri::file("\\\\server\\share2\\some\\path"),
    Some("../../share2/some/path"),
    ignore_join=true,
  )
  @common.set_is_windows_for_testing(value=false)
  assert_relative_path(
    @common.Uri::file("/a/foo"),
    @common.Uri::file("/a/foo/bar"),
    Some("bar"),
  )
  assert_relative_path(
    @common.Uri::file("/a/foo"),
    @common.Uri::file("/a/foo/bar/"),
    Some("bar"),
  )
  assert_relative_path(
    @common.Uri::file("/a/foo"),
    @common.Uri::file("/a/foo/bar/goo"),
    Some("bar/goo"),
  )
  assert_relative_path(
    @common.Uri::file("/a/"),
    @common.Uri::file("/a/foo/bar/goo"),
    Some("foo/bar/goo"),
  )
  assert_relative_path(
    @common.Uri::file("/"),
    @common.Uri::file("/a/foo/bar/goo"),
    Some("a/foo/bar/goo"),
  )
  assert_relative_path(
    @common.Uri::file("/a/foo/xoo"),
    @common.Uri::file("/a/foo/bar"),
    Some("../bar"),
  )
  assert_relative_path(
    @common.Uri::file("/a/foo/xoo/yoo"),
    @common.Uri::file("/a"),
    Some("../../.."),
  )
  assert_relative_path(
    @common.Uri::file("/a/foo"),
    @common.Uri::file("/a/foo/"),
    Some(""),
  )
  assert_relative_path(
    @common.Uri::file("/a/foo"),
    @common.Uri::file("/b/foo/"),
    Some("../../b/foo"),
  )
  @common.set_is_windows_for_testing()
}

///|
fn assert_resolve(
  u1 : @common.Uri,
  path : String,
  expected : @common.Uri,
  is_win : Bool,
) -> Unit raise {
  let actual = @common.resolve_path(u1, path)
  assert_equal_uri(actual, expected, msg="from \{u1.to_string()} and \{path}")
  let path_is_absolute = if path.contains("/") {
    @common.Posix::is_absolute(path)
  } else {
    @common.Win32::is_absolute(path)
  }
  if !path_is_absolute {
    let mut expected_path = if is_win { @common.to_slashes(path) } else { path }
    expected_path = if expected_path.has_prefix("./") {
      expected_path[2:].to_owned()
    } else {
      expected_path
    }
    assert_true(
      @common.relative_path(u1, actual) == Some(expected_path),
      msg="relativePath (\{u1.to_string()}) on actual (\{actual.to_string()}) should be to path (\{expected_path})",
    )
  }
}

///|
test "resolve" {
  @common.set_is_windows_for_testing(value=true)
  assert_resolve(
    @common.Uri::file("c:\\foo\\bar"),
    "file.js",
    @common.Uri::file("c:\\foo\\bar\\file.js"),
    true,
  )
  assert_resolve(
    @common.Uri::file("c:\\foo\\bar"),
    "t\\file.js",
    @common.Uri::file("c:\\foo\\bar\\t\\file.js"),
    true,
  )
  assert_resolve(
    @common.Uri::file("c:\\foo\\bar"),
    ".\\t\\file.js",
    @common.Uri::file("c:\\foo\\bar\\t\\file.js"),
    true,
  )
  assert_resolve(
    @common.Uri::file("c:\\foo\\bar"),
    "a1/file.js",
    @common.Uri::file("c:\\foo\\bar\\a1\\file.js"),
    true,
  )
  assert_resolve(
    @common.Uri::file("c:\\foo\\bar"),
    "./a1/file.js",
    @common.Uri::file("c:\\foo\\bar\\a1\\file.js"),
    true,
  )
  assert_resolve(
    @common.Uri::file("c:\\foo\\bar"),
    "\\b1\\file.js",
    @common.Uri::file("c:\\b1\\file.js"),
    true,
  )
  assert_resolve(
    @common.Uri::file("c:\\foo\\bar"),
    "/b1/file.js",
    @common.Uri::file("c:\\b1\\file.js"),
    true,
  )
  assert_resolve(
    @common.Uri::file("c:\\foo\\bar\\"),
    "file.js",
    @common.Uri::file("c:\\foo\\bar\\file.js"),
    true,
  )
  assert_resolve(
    @common.Uri::file("c:\\"),
    "file.js",
    @common.Uri::file("c:\\file.js"),
    true,
  )
  assert_resolve(
    @common.Uri::file("c:\\"),
    "\\b1\\file.js",
    @common.Uri::file("c:\\b1\\file.js"),
    true,
  )
  assert_resolve(
    @common.Uri::file("c:\\"),
    "/b1/file.js",
    @common.Uri::file("c:\\b1\\file.js"),
    true,
  )
  assert_resolve(
    @common.Uri::file("c:\\"),
    "d:\\foo\\bar.txt",
    @common.Uri::file("d:\\foo\\bar.txt"),
    true,
  )
  assert_resolve(
    @common.Uri::file("\\\\server\\share\\some\\"),
    "b1\\file.js",
    @common.Uri::file("\\\\server\\share\\some\\b1\\file.js"),
    true,
  )
  assert_resolve(
    @common.Uri::file("\\\\server\\share\\some\\"),
    "\\file.js",
    @common.Uri::file("\\\\server\\share\\file.js"),
    true,
  )
  assert_resolve(
    @common.Uri::file("c:\\"),
    "\\\\server\\share\\some\\",
    @common.Uri::file("\\\\server\\share\\some"),
    true,
  )
  assert_resolve(
    @common.Uri::file("\\\\server\\share\\some\\"),
    "c:\\",
    @common.Uri::file("c:\\"),
    true,
  )
  @common.set_is_windows_for_testing(value=false)
  assert_resolve(
    @common.Uri::file("/foo/bar"),
    "file.js",
    @common.Uri::file("/foo/bar/file.js"),
    false,
  )
  assert_resolve(
    @common.Uri::file("/foo/bar"),
    "./file.js",
    @common.Uri::file("/foo/bar/file.js"),
    false,
  )
  assert_resolve(
    @common.Uri::file("/foo/bar"),
    "/file.js",
    @common.Uri::file("/file.js"),
    false,
  )
  assert_resolve(
    @common.Uri::file("/foo/bar/"),
    "file.js",
    @common.Uri::file("/foo/bar/file.js"),
    false,
  )
  assert_resolve(
    @common.Uri::file("/"),
    "file.js",
    @common.Uri::file("/file.js"),
    false,
  )
  assert_resolve(
    @common.Uri::file(""),
    "./file.js",
    @common.Uri::file("/file.js"),
    false,
  )
  assert_resolve(
    @common.Uri::file(""),
    "/file.js",
    @common.Uri::file("/file.js"),
    false,
  )
  assert_resolve(
    @common.Uri::parse("foo://server/foo/bar"),
    "file.js",
    @common.Uri::parse("foo://server/foo/bar/file.js"),
    false,
  )
  assert_resolve(
    @common.Uri::parse("foo://server/foo/bar"),
    "./file.js",
    @common.Uri::parse("foo://server/foo/bar/file.js"),
    false,
  )
  assert_resolve(
    @common.Uri::parse("foo://server/foo/bar"),
    "c:\\a1\\b1",
    @common.Uri::parse("foo://server/c:/a1/b1"),
    false,
  )
  assert_resolve(
    @common.Uri::parse("foo://server/foo/bar"),
    "c:\\",
    @common.Uri::parse("foo://server/c:"),
    false,
  )
  @common.set_is_windows_for_testing()
}

///|
fn assert_is_equal(
  u1 : @common.Uri,
  u2 : @common.Uri,
  ignore_case : Bool?,
  expected : Bool,
) -> Unit raise {
  let util = if ignore_case is Some(true) {
    @common.ext_uri_ignore_path_case
  } else {
    @common.ext_uri
  }
  let relation = if expected { "===" } else { "!==" }
  assert_eq(
    util.is_equal(Some(u1), Some(u2)),
    expected,
    msg="\{u1.to_string()}\{relation}\{u2.to_string()}",
  )
  assert_eq(util.compare(u1, u2) == 0, expected)
  assert_eq(
    util.get_comparison_key(u1) == util.get_comparison_key(u2),
    expected,
    msg="comparison keys \{u1.to_string()}, \{u2.to_string()}",
  )
  assert_eq(
    util.is_equal_or_parent(u1, u2),
    expected,
    msg="isEqualOrParent \{u1.to_string()}, \{u2.to_string()}",
  )
  if !(ignore_case is Some(true)) {
    assert_eq(u1.to_string() == u2.to_string(), expected)
  }
}

///|
fn run_is_equal_suite(
  file_uri : @common.Uri,
  file_uri2 : @common.Uri,
) -> Unit raise {
  assert_is_equal(file_uri, file_uri, Some(true), true)
  assert_is_equal(file_uri, file_uri, Some(false), true)
  assert_is_equal(file_uri, file_uri, None, true)
  assert_is_equal(file_uri, file_uri2, Some(true), true)
  assert_is_equal(file_uri, file_uri2, Some(false), false)
  let file_uri3 = @common.Uri::parse("foo://server:453/foo/bar")
  let file_uri4 = @common.Uri::parse("foo://server:453/foo/Bar")
  assert_is_equal(file_uri3, file_uri3, Some(true), true)
  assert_is_equal(file_uri3, file_uri3, Some(false), true)
  assert_is_equal(file_uri3, file_uri3, None, true)
  assert_is_equal(file_uri3, file_uri4, Some(true), true)
  assert_is_equal(file_uri3, file_uri4, Some(false), false)
  assert_is_equal(file_uri, file_uri3, Some(true), false)
  assert_is_equal(
    @common.Uri::parse("file://server"),
    @common.Uri::parse("file://server/"),
    Some(true),
    true,
  )
  assert_is_equal(
    @common.Uri::parse("http://server"),
    @common.Uri::parse("http://server/"),
    Some(true),
    true,
  )
  // only selected scheme have / as the default path
  assert_is_equal(
    @common.Uri::parse("foo://server"),
    @common.Uri::parse("foo://server/"),
    Some(true),
    false,
  )
  assert_is_equal(
    @common.Uri::parse("foo://server/foo"),
    @common.Uri::parse("foo://server/foo/"),
    Some(true),
    false,
  )
  assert_is_equal(
    @common.Uri::parse("foo://server/foo"),
    @common.Uri::parse("foo://server/foo?"),
    Some(true),
    true,
  )
  let file_uri5 = @common.Uri::parse("foo://server:453/foo/bar?q=1")
  let file_uri6 = @common.Uri::parse("foo://server:453/foo/bar#xy")
  assert_is_equal(file_uri5, file_uri5, Some(true), true)
  assert_is_equal(file_uri5, file_uri3, Some(true), false)
  assert_is_equal(file_uri6, file_uri6, Some(true), true)
  assert_is_equal(file_uri6, file_uri5, Some(true), false)
  assert_is_equal(file_uri6, file_uri3, Some(true), false)
}

///|
test "isEqual" {
  @common.set_is_windows_for_testing(value=false)
  run_is_equal_suite(
    @common.Uri::file("/foo/bar"),
    @common.Uri::file("/foo/Bar"),
  )
  @common.set_is_windows_for_testing(value=true)
  run_is_equal_suite(
    @common.Uri::file("c:\\foo\\bar"),
    @common.Uri::file("C:\\foo\\Bar"),
  )
  @common.set_is_windows_for_testing()
}

///|
fn run_is_equal_or_parent_suite(
  file_uri : @common.Uri,
  file_uri2 : @common.Uri,
  file_uri2b : @common.Uri,
) -> Unit raise {
  assert_eq(
    @common.ext_uri_ignore_path_case.is_equal_or_parent(file_uri, file_uri),
    true,
    msg="1",
  )
  assert_eq(
    @common.ext_uri.is_equal_or_parent(file_uri, file_uri),
    true,
    msg="2",
  )
  assert_eq(
    @common.ext_uri_ignore_path_case.is_equal_or_parent(file_uri, file_uri2),
    true,
    msg="3",
  )
  assert_eq(
    @common.ext_uri.is_equal_or_parent(file_uri, file_uri2),
    true,
    msg="4",
  )
  assert_eq(
    @common.ext_uri_ignore_path_case.is_equal_or_parent(file_uri, file_uri2b),
    true,
    msg="5",
  )
  assert_eq(
    @common.ext_uri.is_equal_or_parent(file_uri, file_uri2b),
    false,
    msg="6",
  )
  assert_eq(
    @common.ext_uri.is_equal_or_parent(file_uri2, file_uri),
    false,
    msg="7",
  )
  assert_eq(
    @common.ext_uri_ignore_path_case.is_equal_or_parent(file_uri2b, file_uri2),
    true,
    msg="8",
  )
  let file_uri3 = @common.Uri::parse("foo://server:453/foo/bar/goo")
  let file_uri4 = @common.Uri::parse("foo://server:453/foo/")
  let file_uri5 = @common.Uri::parse("foo://server:453/foo")
  assert_eq(
    @common.ext_uri_ignore_path_case.is_equal_or_parent(
      file_uri3,
      file_uri3,
      ignore_fragment=true,
    ),
    true,
    msg="11",
  )
  assert_eq(
    @common.ext_uri.is_equal_or_parent(file_uri3, file_uri3),
    true,
    msg="12",
  )
  assert_eq(
    @common.ext_uri_ignore_path_case.is_equal_or_parent(
      file_uri3,
      file_uri4,
      ignore_fragment=true,
    ),
    true,
    msg="13",
  )
  assert_eq(
    @common.ext_uri.is_equal_or_parent(file_uri3, file_uri4),
    true,
    msg="14",
  )
  assert_eq(
    @common.ext_uri_ignore_path_case.is_equal_or_parent(
      file_uri3,
      file_uri,
      ignore_fragment=true,
    ),
    false,
    msg="15",
  )
  assert_eq(
    @common.ext_uri_ignore_path_case.is_equal_or_parent(
      file_uri5,
      file_uri5,
      ignore_fragment=true,
    ),
    true,
    msg="16",
  )
  let file_uri6 = @common.Uri::parse("foo://server:453/foo?q=1")
  let file_uri7 = @common.Uri::parse("foo://server:453/foo/bar?q=1")
  assert_eq(
    @common.ext_uri_ignore_path_case.is_equal_or_parent(file_uri6, file_uri5),
    false,
    msg="17",
  )
  assert_eq(
    @common.ext_uri_ignore_path_case.is_equal_or_parent(file_uri6, file_uri6),
    true,
    msg="18",
  )
  assert_eq(
    @common.ext_uri_ignore_path_case.is_equal_or_parent(file_uri7, file_uri6),
    true,
    msg="19",
  )
  assert_eq(
    @common.ext_uri_ignore_path_case.is_equal_or_parent(file_uri7, file_uri5),
    false,
    msg="20",
  )
}

///|
test "isEqualOrParent" {
  @common.set_is_windows_for_testing(value=false)
  run_is_equal_or_parent_suite(
    @common.Uri::file("/foo/bar"),
    @common.Uri::file("/foo"),
    @common.Uri::file("/Foo/"),
  )
  @common.set_is_windows_for_testing(value=true)
  run_is_equal_or_parent_suite(
    @common.Uri::file("c:\\foo\\bar"),
    @common.Uri::file("c:\\foo"),
    @common.Uri::file("C:\\Foo\\"),
  )
  @common.set_is_windows_for_testing()
}

///|
test "isEqualOrParent handles ../" {
  @common.set_is_windows_for_testing(value=false)
  let file_uri = @common.Uri::file("/home/user/projects")
  let file_uri2 = @common.Uri::file(
    "/home/user/projects/../../../../tmp/folder",
  )
  assert_eq(@common.ext_uri.is_equal_or_parent(file_uri2, file_uri), false)
  @common.set_is_windows_for_testing()
}

///|
test "compare is code-unit lexicographic, not length-first (test matrix)" {
  // MoonBit's built-in String compare would order "z" before "aa".
  assert_eq(
    @common.ext_uri.compare(
      @common.Uri::parse("s://x/z"),
      @common.Uri::parse("s://x/aa"),
    ),
    1,
  )
  assert_eq(
    @common.ext_uri.compare(
      @common.Uri::parse("s://x/aa"),
      @common.Uri::parse("s://x/z"),
    ),
    -1,
  )
  assert_eq(
    @common.ext_uri.compare(
      @common.Uri::parse("s://x/a"),
      @common.Uri::parse("s://x/a"),
    ),
    0,
  )
  // fragment handling
  assert_eq(
    @common.ext_uri.compare(
      @common.Uri::parse("s://x/a#f"),
      @common.Uri::parse("s://x/a"),
      ignore_fragment=true,
    ),
    0,
  )
}
