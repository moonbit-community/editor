///|
test "monaco lineDecorations normalizer reference suite" {
  let content = "abcabcabcabcabcabcabcabcabcabc"
  assert_segments(
    "Bug 9827",
    LineDecorationsNormalizer::normalize(content, [
      LineDecoration(1, 11, "c1"),
      LineDecoration(3, 4, "c2"),
    ]),
    [segment(0, 1, "c1"), segment(2, 2, "c2 c1"), segment(3, 9, "c1")],
  )
  assert_segments(
    "issue #3462",
    LineDecorationsNormalizer::normalize(content, [
      LineDecoration(15, 21, "mtkw"),
      LineDecoration(20, 21, "inline-folded"),
    ]),
    [segment(14, 18, "mtkw"), segment(19, 19, "mtkw inline-folded")],
  )
  assert_segments(
    "ViewLineParts separate decorations",
    LineDecorationsNormalizer::normalize(content, [
      LineDecoration(1, 2, "c1"),
      LineDecoration(3, 4, "c2"),
    ]),
    [segment(0, 0, "c1"), segment(2, 2, "c2")],
  )
  assert_segments(
    "ViewLineParts adjacent decorations",
    LineDecorationsNormalizer::normalize(content, [
      LineDecoration(1, 3, "c1"),
      LineDecoration(3, 4, "c2"),
    ]),
    [segment(0, 1, "c1"), segment(2, 2, "c2")],
  )
  assert_segments(
    "ViewLineParts overlapping decorations",
    LineDecorationsNormalizer::normalize(content, [
      LineDecoration(1, 4, "c1"),
      LineDecoration(3, 4, "c2"),
    ]),
    [segment(0, 1, "c1"), segment(2, 2, "c1 c2")],
  )
  assert_segments(
    "ViewLineParts duplicated base decorations",
    LineDecorationsNormalizer::normalize(content, [
      LineDecoration(1, 4, "c1"),
      LineDecoration(1, 4, "c1*"),
      LineDecoration(3, 4, "c2"),
    ]),
    [segment(0, 1, "c1 c1*"), segment(2, 2, "c1 c1* c2")],
  )
  assert_segments(
    "ViewLineParts three duplicated base decorations",
    LineDecorationsNormalizer::normalize(content, [
      LineDecoration(1, 4, "c1"),
      LineDecoration(1, 4, "c1*"),
      LineDecoration(1, 4, "c1**"),
      LineDecoration(3, 4, "c2"),
    ]),
    [segment(0, 1, "c1 c1* c1**"), segment(2, 2, "c1 c1* c1** c2")],
  )
  assert_segments(
    "ViewLineParts duplicated overlap decorations",
    LineDecorationsNormalizer::normalize(content, [
      LineDecoration(1, 4, "c1"),
      LineDecoration(1, 4, "c1*"),
      LineDecoration(1, 4, "c1**"),
      LineDecoration(3, 4, "c2"),
      LineDecoration(3, 4, "c2*"),
    ]),
    [segment(0, 1, "c1 c1* c1**"), segment(2, 2, "c1 c1* c1** c2 c2*")],
  )
  assert_segments(
    "ViewLineParts overlap with longer tail",
    LineDecorationsNormalizer::normalize(content, [
      LineDecoration(1, 4, "c1"),
      LineDecoration(1, 4, "c1*"),
      LineDecoration(1, 4, "c1**"),
      LineDecoration(3, 4, "c2"),
      LineDecoration(3, 5, "c2*"),
    ]),
    [
      segment(0, 1, "c1 c1* c1**"),
      segment(2, 2, "c1 c1* c1** c2 c2*"),
      segment(3, 3, "c2*"),
    ],
  )
}

///|
test "monaco lineDecoration compare order is preserved in render input" {
  let input = monaco_input("x", [monaco_part(1, 1)], line_decorations=[
    LineDecoration(1, 1, "regular", decoration_type=Regular),
    LineDecoration(1, 1, "before", decoration_type=Before),
    LineDecoration(1, 1, "after", decoration_type=After),
    LineDecoration(
      1,
      1,
      "regular-affecting",
      decoration_type=RegularAffectingLetterSpacing,
    ),
  ])
  assert_eq(input.line_decorations[0].class_name, "before")
  assert_eq(input.line_decorations[1].class_name, "after")
  assert_eq(input.line_decorations[2].class_name, "regular")
  assert_eq(input.line_decorations[3].class_name, "regular-affecting")
}

///|
test "monaco viewLineRenderer basic html and mapping ports" {
  assert_render_html(
    "escapes less-than",
    "a<b",
    [monaco_part(3, 0)],
    "<span class=\"view-line-content\"><span class=\"mtk0\">a&lt;b</span></span>",
  )
  assert_render_html(
    "escapes greater-than",
    "a>b",
    [monaco_part(3, 0)],
    "<span class=\"view-line-content\"><span class=\"mtk0\">a&gt;b</span></span>",
  )
  assert_render_html(
    "escapes ampersand",
    "a&b",
    [monaco_part(3, 0)],
    "<span class=\"view-line-content\"><span class=\"mtk0\">a&amp;b</span></span>",
  )
  assert_render_html(
    "empty line",
    "",
    [],
    "<span class=\"view-line-content\"></span>",
  )
  assert_render_html(
    "uses part type",
    "x",
    [monaco_part(1, 10)],
    "<span class=\"view-line-content\"><span class=\"mtk10\">x</span></span>",
  )
  assert_render_html(
    "two parts",
    "xy",
    [monaco_part(1, 1), monaco_part(2, 2)],
    "<span class=\"view-line-content\"><span class=\"mtk1\">x</span><span class=\"mtk2\">y</span></span>",
  )
}

///|
test "monaco issue #6885 split-large-token boundaries" {
  let line_text = "This is just a long line that contains very interesting text. This is just a long line that contains very interesting text."
  assert_split_count("49 chars", line_text[0:49].to_owned(), 1)
  assert_split_count("50 chars", line_text[0:50].to_owned(), 1)
  assert_split_count("51 chars", line_text[0:51].to_owned(), 2)
  assert_split_count("99 chars", line_text[0:99].to_owned(), 2)
  assert_split_count("100 chars", line_text[0:100].to_owned(), 2)
  assert_split_count("101 chars", line_text[0:101].to_owned(), 3)
}

///|
test "monaco viewLineRenderer upstream case matrix stays renderable" {
  assert_monaco_case(
    "overflow",
    "Hello world!",
    [
      monaco_part(1, 0),
      monaco_part(2, 1),
      monaco_part(3, 2),
      monaco_part(4, 3),
      monaco_part(5, 4),
      monaco_part(6, 5),
      monaco_part(7, 6),
      monaco_part(8, 7),
      monaco_part(9, 8),
      monaco_part(10, 9),
      monaco_part(11, 10),
      monaco_part(12, 11),
    ],
    stop_rendering_line_after=6,
    render_whitespace=Boundary,
    expected_classes=["mtkoverflow"],
    expected_overflow=true,
  )
  assert_monaco_case(
    "typical",
    "\t    export class Game { // http://test.com     ",
    [
      monaco_part(5, 1),
      monaco_part(11, 2),
      monaco_part(12, 3),
      monaco_part(17, 4),
      monaco_part(18, 5),
      monaco_part(22, 6),
      monaco_part(23, 7),
      monaco_part(24, 8),
      monaco_part(25, 9),
      monaco_part(28, 10),
      monaco_part(43, 11),
      monaco_part(48, 12),
    ],
    render_whitespace=Boundary,
    expected_classes=["mtk1", "mtk12"],
  )
  assert_monaco_case(
    "issue-2255-1",
    "\t\t\tcursorStyle:\t\t\t\t\t\t(prevOpts.cursorStyle !== newOpts.cursorStyle),",
    [
      monaco_part(3, 1),
      monaco_part(15, 2),
      monaco_part(21, 3),
      monaco_part(22, 4),
      monaco_part(43, 5),
      monaco_part(45, 6),
      monaco_part(46, 7),
      monaco_part(66, 8),
      monaco_part(67, 9),
      monaco_part(68, 10),
    ],
    expected_classes=["mtk1", "mtk10"],
  )
  assert_monaco_case(
    "issue-2255-2",
    " \t\t\tcursorStyle:\t\t\t\t\t\t(prevOpts.cursorStyle !== newOpts.cursorStyle),",
    [
      monaco_part(4, 1),
      monaco_part(16, 2),
      monaco_part(22, 3),
      monaco_part(23, 4),
      monaco_part(44, 5),
      monaco_part(46, 6),
      monaco_part(47, 7),
      monaco_part(67, 8),
      monaco_part(68, 9),
      monaco_part(69, 10),
    ],
    expected_classes=["mtk1", "mtk10"],
  )
  assert_monaco_case(
    "issue-91178",
    "//just a comment",
    [monaco_part(16, 1)],
    line_decorations=[
      LineDecoration(13, 13, "dec1", decoration_type=After),
      LineDecoration(13, 13, "dec2", decoration_type=Before),
    ],
    can_use_halfwidth_rightwards_arrow=false,
    expected_classes=["dec2", "dec1"],
    expected_foreign=After,
  )
  assert_monaco_case(
    "monaco-280",
    "var קודמות = \"מיותר קודמות צ'ט של, אם לשון העברית שינויים ויש, אם\";",
    [LinePart(3, "mtk6"), LinePart(13, "mtk1"), LinePart(66, "mtk20")],
    contains_rtl=true,
    is_basic_ascii=false,
    expected_classes=["mtk6", "mtk20"],
  )
  assert_monaco_case(
    "issue-137036",
    "<option value=\"العربية\">العربية</option>",
    [
      LinePart(
        "<option value=\"العربية\">العربية</option>".length(),
        "mtk3",
      ),
    ],
    contains_rtl=true,
    is_basic_ascii=false,
    expected_classes=["mtk3"],
  )
  assert_monaco_case(
    "issue-99589",
    "    [\"چاپ فاکتور\",\"تنظیمات\"]",
    [
      LinePart(
        "    [\"چاپ فاکتور\",\"تنظیمات\"]".length(),
        "mtk3",
      ),
    ],
    contains_rtl=true,
    is_basic_ascii=false,
    render_whitespace=All,
    expected_classes=["mtk3"],
  )
  assert_monaco_case(
    "issue-260239",
    "<p class=\"myclass\" title=\"العربي\">نشاط التدويل!</p>",
    [
      LinePart(
        "<p class=\"myclass\" title=\"العربي\">نشاط التدويل!</p>".length(),
        "mtk9",
      ),
    ],
    contains_rtl=true,
    is_basic_ascii=false,
    expected_classes=["mtk9"],
  )
  assert_monaco_case(
    "issue-274604",
    "test.com##a:-abp-contains(إ)",
    [LinePart("test.com##a:-abp-contains(إ)".length(), "mtk1")],
    contains_rtl=true,
    is_basic_ascii=false,
    expected_classes=["mtk1"],
  )
  assert_monaco_case(
    "issue-277693",
    "نام کاربر: ${user.firstName}",
    [LinePart("نام کاربر: ${user.firstName}".length(), "mtk1")],
    contains_rtl=true,
    is_basic_ascii=false,
    expected_classes=["mtk1"],
  )
  assert_monaco_case(
    "issue-6885-rtl",
    "את גרמנית בהתייחסות שמו, שנתי המשפט אל חפש",
    [
      LinePart(
        "את גרמנית בהתייחסות שמו, שנתי המשפט אל חפש".length(),
        "mtk1",
      ),
    ],
    contains_rtl=true,
    is_basic_ascii=false,
    expected_classes=["mtk1"],
  )
  assert_monaco_case(
    "issue-19673",
    "    MongoCallback<string>): void {",
    [
      monaco_part(17, 1),
      monaco_part(18, 2),
      monaco_part(24, 3),
      monaco_part(26, 4),
      monaco_part(27, 5),
      monaco_part(28, 6),
      monaco_part(32, 7),
      monaco_part(34, 8),
    ],
    use_monospace_optimizations=true,
    faux_indent_length=4,
    expected_classes=["mtk1", "mtk8"],
  )
  assert_monaco_case(
    "issue-18616",
    "https://microsoft.com",
    [monaco_part(21, 3)],
    line_decorations=[LineDecoration(1, 22, "link")],
    expected_classes=["link"],
  )
  assert_monaco_case(
    "issue-19207",
    "'let url = `http://***/_api/web/lists/GetByTitle(\\'Teambuildingaanvragen\\')/items`;'",
    [
      monaco_part(49, 6),
      monaco_part(51, 4),
      monaco_part(72, 6),
      monaco_part(74, 4),
      monaco_part(84, 6),
    ],
    line_decorations=[LineDecoration(13, 51, "detected-link")],
    use_monospace_optimizations=true,
    expected_classes=["detected-link"],
  )
  assert_monaco_case(
    "ws-4-leading",
    "    Hello world!    ",
    [monaco_part(4, 1), monaco_part(6, 2), monaco_part(20, 3)],
    render_whitespace=Boundary,
    expected_classes=["mtk1", "mtk3"],
  )
  assert_monaco_case(
    "ws-2-tabs",
    "\t\tHello world!\t",
    [monaco_part(2, 1), monaco_part(4, 2), monaco_part(15, 3)],
    render_whitespace=Boundary,
    expected_classes=["mtk1", "mtk3"],
  )
  assert_monaco_case(
    "ws-mixed",
    "  \t\t  Hello world! \t  \t   \t    ",
    [monaco_part(6, 1), monaco_part(8, 2), monaco_part(31, 3)],
    render_whitespace=Boundary,
    expected_classes=["mtk1", "mtk3"],
  )
  assert_monaco_case(
    "ws-faux-indent",
    "\t\t  Hello world! \t  \t   \t    ",
    [monaco_part(4, 1), monaco_part(6, 2), monaco_part(29, 3)],
    faux_indent_length=2,
    render_whitespace=Boundary,
    expected_classes=["mtk1", "mtk3"],
  )
  assert_monaco_case(
    "ws-middle",
    "it  it it  it",
    [monaco_part(6, 1), monaco_part(7, 2), monaco_part(13, 3)],
    render_whitespace=Boundary,
    expected_classes=["mtk1", "mtk3"],
  )
  assert_monaco_case(
    "ws-all-middle",
    " Hello world!\t",
    [monaco_part(4, 0), monaco_part(6, 1), monaco_part(14, 2)],
    render_whitespace=All,
    expected_classes=["mtk0", "mtk2"],
  )
  assert_monaco_case(
    "ws-trail-with-trail",
    " Hello world! \t",
    [monaco_part(4, 0), monaco_part(6, 1), monaco_part(15, 2)],
    render_whitespace=Trailing,
    expected_classes=["mtk0", "mtk2"],
  )
  assert_monaco_case(
    "unsorted-deco",
    "Hello world",
    [monaco_part(11, 0)],
    line_decorations=[
      LineDecoration(5, 7, "a"),
      LineDecoration(1, 3, "b"),
      LineDecoration(2, 8, "c"),
    ],
    expected_classes=["a", "b", "c"],
  )
  assert_monaco_case(
    "issue-11485",
    "\tbla",
    [monaco_part(4, 3)],
    line_decorations=[LineDecoration(1, 2, "before", decoration_type=Before)],
    render_whitespace=All,
    font_ligatures=true,
    expected_classes=["before"],
    expected_foreign=Before,
  )
  assert_monaco_case(
    "issue-32436",
    "\tbla",
    [monaco_part(4, 3)],
    line_decorations=[LineDecoration(2, 3, "before", decoration_type=Before)],
    render_whitespace=All,
    font_ligatures=true,
    expected_classes=["before"],
    expected_foreign=Before,
  )
  assert_monaco_case(
    "issue-30133",
    "",
    [monaco_part(0, 3)],
    line_decorations=[LineDecoration(1, 2, "before", decoration_type=Before)],
    render_whitespace=All,
    font_ligatures=true,
    expected_classes=["before"],
    expected_foreign=Before,
  )
  assert_monaco_case(
    "issue-37208",
    "  1. 🙏",
    [LinePart("  1. 🙏".length(), "mtk3")],
    line_decorations=[
      LineDecoration(
        "  1. 🙏".length(),
        "  1. 🙏".length() + 1,
        "inline-folded",
        decoration_type=After,
      ),
    ],
    is_basic_ascii=false,
    use_monospace_optimizations=true,
    stop_rendering_line_after=10000,
    expected_classes=["inline-folded"],
    expected_foreign=After,
  )
  assert_monaco_case(
    "issue-37401",
    "",
    [monaco_part(0, 3)],
    line_decorations=[
      LineDecoration(1, 1, "before", decoration_type=Before),
      LineDecoration(1, 1, "after", decoration_type=After),
    ],
    use_monospace_optimizations=true,
    stop_rendering_line_after=10000,
    expected_classes=["before", "after"],
    expected_foreign=After,
  )
  assert_monaco_case(
    "issue-118759",
    "",
    [monaco_part(0, 3)],
    line_decorations=[
      LineDecoration(1, 1, "after1", decoration_type=After),
      LineDecoration(1, 1, "after2", decoration_type=After),
      LineDecoration(1, 1, "before1", decoration_type=Before),
      LineDecoration(1, 1, "before2", decoration_type=Before),
    ],
    use_monospace_optimizations=true,
    stop_rendering_line_after=10000,
    expected_classes=["before1", "before2", "after1", "after2"],
    expected_foreign=After,
  )
  assert_monaco_case(
    "issue-38935",
    "\t}",
    [monaco_part(2, 3)],
    line_decorations=[
      LineDecoration(3, 3, "ced-before", decoration_type=Before),
      LineDecoration(3, 3, "ced-after", decoration_type=After),
    ],
    use_monospace_optimizations=true,
    stop_rendering_line_after=10000,
    expected_classes=["ced-before", "ced-after"],
    expected_foreign=After,
  )
  assert_monaco_case(
    "issue-136622",
    "some text £",
    [LinePart("some text £".length(), "mtk3")],
    line_decorations=[
      LineDecoration(5, 5, "inlineDec1", decoration_type=After),
      LineDecoration(6, 6, "inlineDec2", decoration_type=Before),
    ],
    is_basic_ascii=false,
    render_control_characters=true,
    use_monospace_optimizations=true,
    stop_rendering_line_after=10000,
    expected_classes=["inlineDec1", "inlineDec2"],
    expected_foreign=After,
  )
  assert_monaco_case(
    "issue-22832-1",
    "asd = \"擦\"\t\t#asd",
    [LinePart("asd = \"擦\"\t\t#asd".length(), "mtk3")],
    is_basic_ascii=false,
    use_monospace_optimizations=true,
    stop_rendering_line_after=10000,
    expected_classes=["mtk3"],
  )
  assert_monaco_case(
    "issue-22832-2",
    "asd = \"擦\"\t\t#asd",
    [LinePart("asd = \"擦\"\t\t#asd".length(), "mtk3")],
    is_basic_ascii=false,
    use_monospace_optimizations=true,
    stop_rendering_line_after=10000,
    render_whitespace=All,
    expected_classes=["mtk3"],
  )
  assert_monaco_case(
    "issue-22352-1",
    "12345689012345678901234568901234567890123456890abába",
    [
      LinePart(
        "12345689012345678901234568901234567890123456890abába".length(),
        "mtk3",
      ),
    ],
    is_basic_ascii=false,
    use_monospace_optimizations=true,
    stop_rendering_line_after=10000,
    expected_classes=["mtk3"],
  )
  assert_monaco_case(
    "issue-42700",
    " वो ऐसा क्या है जो हमारे अंदर भी है और बाहर भी है।",
    [
      LinePart(
        " वो ऐसा क्या है जो हमारे अंदर भी है और बाहर भी है।".length(),
        "mtk3",
      ),
    ],
    is_basic_ascii=false,
    use_monospace_optimizations=true,
    stop_rendering_line_after=10000,
    expected_classes=["mtk3"],
  )
  assert_monaco_case(
    "issue-38123",
    "This is a long line which never uses more than two spaces. ",
    [monaco_part(59, 3)],
    continues_with_wrapped_line=true,
    render_whitespace=Boundary,
    use_monospace_optimizations=true,
    stop_rendering_line_after=10000,
    expected_classes=["mtk3"],
  )
  assert_monaco_case(
    "issue-33525-1",
    "append data to append data to append data to append data to append data to append data to append data to append data to append data to append data to append data to append data to append data to",
    [monaco_part(194, 3)],
    can_use_halfwidth_rightwards_arrow=false,
    font_ligatures=true,
    stop_rendering_line_after=10000,
    expected_classes=["mtk3"],
  )
  assert_monaco_case(
    "issue-124038",
    "    if",
    [monaco_part(4, 1), monaco_part(6, 2)],
    line_decorations=[
      LineDecoration(7, 7, "ced-before", decoration_type=Before),
      LineDecoration(7, 7, "ced-after", decoration_type=After),
      LineDecoration(7, 7, "ced-ghost-text", decoration_type=After),
    ],
    use_monospace_optimizations=true,
    can_use_halfwidth_rightwards_arrow=false,
    stop_rendering_line_after=10000,
    render_whitespace=All,
    expected_classes=["ced-before", "ced-after", "ced-ghost-text"],
    expected_foreign=After,
  )
}

///|
test "monaco getColumnOfLinePartOffset simple ports" {
  let simple = monaco_render("hello world", [monaco_part(11, 1)], tab_size=4)
  assert_get_column("simple text", simple, 0, 11, 0, 1)
  assert_get_column("simple text", simple, 0, 11, 5, 6)
  assert_get_column("simple text", simple, 0, 11, 11, 12)
  let js = monaco_render(
    "var x = 3;",
    [
      monaco_part(3, 1),
      monaco_part(4, 2),
      monaco_part(5, 3),
      monaco_part(8, 4),
      monaco_part(9, 5),
      monaco_part(10, 6),
    ],
    tab_size=4,
  )
  assert_get_column("regular JS", js, 0, 3, 0, 1)
  assert_get_column("regular JS", js, 0, 3, 3, 4)
  assert_get_column("regular JS", js, 3, 3, 2, 8)
  assert_get_column("regular JS", js, 5, 1, 1, 11)
}

///|
fn segment(
  start_offset : Int,
  end_offset : Int,
  class_name : String,
  metadata? : Int = 0,
) -> DecorationSegment {
  { start_offset, end_offset, class_name, metadata }
}

///|
fn assert_segments(
  name : String,
  actual : Array[DecorationSegment],
  expected : Array[DecorationSegment],
) -> Unit raise {
  guard actual == expected else {
    fail("Monaco lineDecorations port failed: \{name}")
  }
}

///|
fn monaco_part(end_index : Int, class_index : Int) -> LinePart {
  LinePart(end_index, "mtk" + class_index.to_string())
}

///|
fn monaco_view_line(
  content : String,
  tokens : Array[LinePart],
  tab_size? : Int = 4,
  contains_rtl? : Bool = false,
  is_basic_ascii? : Bool = true,
  continues_with_wrapped_line? : Bool = false,
) -> ViewLineRenderingData {
  {
    min_column: 1,
    max_column: content.length() + 1,
    content,
    continues_with_wrapped_line,
    contains_rtl,
    is_basic_ascii,
    tokens,
    inline_decorations: [],
    tab_size,
    start_visible_column: 0,
    text_direction: LTR,
    has_variable_fonts: false,
  }
}

///|
fn monaco_input(
  content : String,
  tokens : Array[LinePart],
  line_decorations? : Array[LineDecoration] = [],
  tab_size? : Int = 4,
  contains_rtl? : Bool = false,
  is_basic_ascii? : Bool = true,
  continues_with_wrapped_line? : Bool = false,
  use_monospace_optimizations? : Bool = false,
  can_use_halfwidth_rightwards_arrow? : Bool = true,
  faux_indent_length? : Int = 0,
  stop_rendering_line_after? : Int = -1,
  render_whitespace? : RenderWhitespace = None,
  render_control_characters? : Bool = false,
  font_ligatures? : Bool = false,
) -> RenderLineInput {
  RenderLineInput::from_view_line(
    monaco_view_line(
      content,
      tokens,
      tab_size~,
      contains_rtl~,
      is_basic_ascii~,
      continues_with_wrapped_line~,
    ),
    line_decorations~,
    use_monospace_optimizations~,
    can_use_halfwidth_rightwards_arrow~,
    faux_indent_length~,
    stop_rendering_line_after~,
    render_whitespace~,
    render_control_characters~,
    font_ligatures~,
  )
}

///|
fn monaco_render(
  content : String,
  tokens : Array[LinePart],
  line_decorations? : Array[LineDecoration] = [],
  tab_size? : Int = 4,
  contains_rtl? : Bool = false,
  is_basic_ascii? : Bool = true,
  continues_with_wrapped_line? : Bool = false,
  use_monospace_optimizations? : Bool = false,
  can_use_halfwidth_rightwards_arrow? : Bool = true,
  faux_indent_length? : Int = 0,
  stop_rendering_line_after? : Int = -1,
  render_whitespace? : RenderWhitespace = None,
  render_control_characters? : Bool = false,
  font_ligatures? : Bool = false,
) -> RenderLineOutput2 {
  render_view_line2(
    monaco_input(
      content,
      tokens,
      line_decorations~,
      tab_size~,
      contains_rtl~,
      is_basic_ascii~,
      continues_with_wrapped_line~,
      use_monospace_optimizations~,
      can_use_halfwidth_rightwards_arrow~,
      faux_indent_length~,
      stop_rendering_line_after~,
      render_whitespace~,
      render_control_characters~,
      font_ligatures~,
    ),
  )
}

///|
fn assert_render_html(
  name : String,
  content : String,
  tokens : Array[LinePart],
  expected_html : String,
) -> Unit raise {
  let output = monaco_render(content, tokens)
  assert_eq(output.html, expected_html)
  assert_mapping_invariants(name, output)
}

///|
fn assert_split_count(
  name : String,
  content : String,
  expected_count : Int,
) -> Unit raise {
  let output = monaco_render(content, [monaco_part(content.length(), 1)])
  let actual_count = monaco_count_occurrences(output.html, "class=\"mtk1\"")
  guard actual_count == expected_count else {
    fail(
      "Monaco split-large-token port failed: \{name}, expected \{expected_count}, got \{actual_count}",
    )
  }
  assert_mapping_invariants(name, output)
}

///|
fn assert_monaco_case(
  name : String,
  content : String,
  tokens : Array[LinePart],
  line_decorations? : Array[LineDecoration] = [],
  tab_size? : Int = 4,
  contains_rtl? : Bool = false,
  is_basic_ascii? : Bool = true,
  continues_with_wrapped_line? : Bool = false,
  use_monospace_optimizations? : Bool = false,
  can_use_halfwidth_rightwards_arrow? : Bool = true,
  faux_indent_length? : Int = 0,
  stop_rendering_line_after? : Int = -1,
  render_whitespace? : RenderWhitespace = None,
  render_control_characters? : Bool = false,
  font_ligatures? : Bool = false,
  expected_classes? : Array[String] = [],
  expected_foreign? : ForeignElementType = None,
  expected_overflow? : Bool = false,
) -> Unit raise {
  let output = monaco_render(
    content,
    tokens,
    line_decorations~,
    tab_size~,
    contains_rtl~,
    is_basic_ascii~,
    continues_with_wrapped_line~,
    use_monospace_optimizations~,
    can_use_halfwidth_rightwards_arrow~,
    faux_indent_length~,
    stop_rendering_line_after~,
    render_whitespace~,
    render_control_characters~,
    font_ligatures~,
  )
  guard output.html.contains("view-line-content") else {
    fail("Monaco render port produced unexpected wrapper: \{name}")
  }
  for class_name in expected_classes {
    guard output.html.contains(class_name) else {
      fail("Monaco render port missing class \{class_name}: \{name}")
    }
  }
  guard output.contains_foreign_elements == expected_foreign else {
    fail("Monaco render port foreign-element mismatch: \{name}")
  }
  if expected_overflow {
    guard output.html.contains("mtkoverflow") else {
      fail("Monaco render port missing overflow marker: \{name}")
    }
  }
  let expected_mapping_length = if content.length() == 0 &&
    expected_foreign == None {
    0
  } else {
    let render_len = if stop_rendering_line_after >= 0 &&
      stop_rendering_line_after < content.length() {
      stop_rendering_line_after
    } else {
      content.length()
    }
    render_len + 1
  }
  guard output.character_mapping.length == expected_mapping_length else {
    fail("Monaco render port mapping length mismatch: \{name}")
  }
  assert_mapping_invariants(name, output)
}

///|
fn assert_mapping_invariants(
  name : String,
  output : RenderLineOutput2,
) -> Unit raise {
  let mapping = output.character_mapping
  let mut previous_horizontal_offset = -1
  for index in 0..<mapping.length {
    let column = index + 1
    let entry = mapping.entries[index]
    guard entry.visible_column >= previous_horizontal_offset else {
      fail("Monaco render port mapping horizontal offset regressed: \{name}")
    }
    let position = mapping.get_dom_position(column)
    guard position.part_index == entry.part_index &&
      position.char_index == entry.char_index else {
      fail("Monaco render port getDomPosition mismatch: \{name}")
    }
    let round_trip = mapping.get_column(position, entry.char_index + 1)
    guard round_trip == column else {
      fail("Monaco render port getColumn round trip failed: \{name}")
    }
    previous_horizontal_offset = entry.visible_column
  }
}

///|
fn assert_get_column(
  name : String,
  output : RenderLineOutput2,
  part_index : Int,
  part_length : Int,
  char_index : Int,
  expected_column : Int,
) -> Unit raise {
  let actual = output.character_mapping.get_column(
    { part_index, char_index },
    part_length,
  )
  guard actual == expected_column else {
    fail("Monaco getColumn port failed: \{name}")
  }
}

///|
fn monaco_count_occurrences(haystack : String, needle : String) -> Int {
  let needle_len = needle.length()
  if needle_len == 0 || haystack.length() < needle_len {
    return 0
  }
  let mut count = 0
  for index in 0..<=(haystack.length() - needle_len) {
    if haystack[index:index + needle_len].to_owned() == needle {
      count = count + 1
    }
  }
  count
}
