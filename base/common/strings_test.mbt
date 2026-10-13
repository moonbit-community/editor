// Pins for the `strings.ts` members ported for the URI stack (plan test
// matrix): `compare` must be JS `<`/`>` code-unit lexicographic — MoonBit's
// built-in String compare is length-first and would invert the first case.

///|
test "compare (strings.ts:343)" {
  assert_eq(@common.compare("z", "aa"), 1)
  assert_eq(@common.compare("aa", "z"), -1)
  assert_eq(@common.compare("a", "aa"), -1)
  assert_eq(@common.compare("aa", "a"), 1)
  assert_eq(@common.compare("abc", "abc"), 0)
  assert_eq(@common.compare("", "a"), -1)
  assert_eq(@common.compare("", ""), 0)
}

///|
test "equalsIgnoreCase (strings.ts:436)" {
  assert_true(@common.equals_ignore_case("", ""))
  assert_false(@common.equals_ignore_case("", "1"))
  assert_false(@common.equals_ignore_case("1", ""))
  assert_true(@common.equals_ignore_case("a", "a"))
  assert_true(@common.equals_ignore_case("abc", "Abc"))
  assert_true(@common.equals_ignore_case("abc", "ABC"))
  assert_true(@common.equals_ignore_case("Höhenmeter", "HÖhenmeter"))
  assert_true(@common.equals_ignore_case("ÖL", "Öl"))
  assert_false(@common.equals_ignore_case("Höhenmeter", "Höhenmeterr"))
}

///|
test "startsWithIgnoreCase (strings.ts:444)" {
  assert_true(@common.starts_with_ignore_case("", ""))
  assert_false(@common.starts_with_ignore_case("", "1"))
  assert_true(@common.starts_with_ignore_case("1", ""))
  assert_true(@common.starts_with_ignore_case("abc", "aBc"))
  assert_true(@common.starts_with_ignore_case("abc", "aB"))
  assert_false(@common.starts_with_ignore_case("abc", "bc"))
  assert_true(@common.starts_with_ignore_case("alles klar", "alles k"))
  assert_false(@common.starts_with_ignore_case("alles klar", "ö"))
}

///|
test "splitLines (strings.ts:251)" {
  assert_eq(@common.split_lines("").join("|"), "")
  assert_eq(@common.split_lines("one").join("|"), "one")
  assert_eq(@common.split_lines("a\nb").join("|"), "a|b")
  // \r\n is one separator, lone \r and \n each split.
  assert_eq(@common.split_lines("a\r\nb\rc\nd").join("|"), "a|b|c|d")
  // A trailing newline yields a trailing empty line, like the JS split.
  assert_eq(@common.split_lines("a\n").length(), 2)
  assert_eq(@common.split_lines("a\n")[1], "")
  assert_eq(@common.split_lines("\n\n").length(), 3)
}
