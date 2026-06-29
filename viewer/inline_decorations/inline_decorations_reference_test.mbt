///|
/// Faithful 1:1 conformance port of Monaco's inline-decoration computer suites,
/// `vscode/src/vs/editor/test/common/viewModel/inlineDecorations.test.ts`
/// (`suite('InlineModelDecorationsComputer')` + `suite('InjectedTextInline
/// DecorationsComputer')`) at submodule commit
/// 294fb350837dbaee37b949533fead4df4e0e8971. Test names are preserved verbatim.

///|
fn create_model_decoration(
  id : String,
  range : @base_common.Range,
  options : @inline_decorations.ModelDecorationOptions,
) -> @inline_decorations.ModelDecoration {
  { id, owner_id: 0, range, options }
}

///|
/// Per-line, per-decoration `InlineDecoration` equality (avoids the deprecated
/// `Show`-based `assert_eq` on nested arrays while keeping per-element detail).
fn assert_inline_eq(
  actual : Array[Array[@inline_decorations.InlineDecoration]],
  expected : Array[Array[@inline_decorations.InlineDecoration]],
) -> Unit raise {
  assert_eq(actual.length(), expected.length())
  for i in 0..<expected.length() {
    assert_eq(actual[i].length(), expected[i].length())
    for j in 0..<expected[i].length() {
      assert_true(actual[i][j] == expected[i][j])
    }
  }
}

///|
fn assert_bool_array_eq(
  actual : Array[Bool],
  expected : Array[Bool],
) -> Unit raise {
  assert_eq(actual.length(), expected.length())
  for i in 0..<expected.length() {
    assert_eq(actual[i], expected[i])
  }
}

// ---- suite('InlineModelDecorationsComputer') ----

///|
test "no decorations" {
  let model = @inline_decorations.TextModel::create("hello world")
  let coordinates_converter = @inline_decorations.IdentityCoordinatesConverter::new(
    model,
  )
  let context : @inline_decorations.InlineModelContext = {
    get_model_decorations: fn(_view_range, _a, _b) { [] },
  }
  let computer = @inline_decorations.InlineModelDecorationsComputer::new(
    context, model, coordinates_converter,
  )
  let result = computer.get_decorations(
    @base_common.Range::Range(1, 1, 1, 12),
    false,
    false,
  )
  assert_eq(result.decorations.length(), 0)
  assert_inline_eq(result.inline_decorations, [[]])
  assert_bool_array_eq(result.has_variable_fonts, [false])
}

///|
test "inline class name decoration on a single line" {
  let model = @inline_decorations.TextModel::create("hello world")
  let coordinates_converter = @inline_decorations.IdentityCoordinatesConverter::new(
    model,
  )
  let context : @inline_decorations.InlineModelContext = {
    get_model_decorations: fn(_view_range, _a, _b) {
      [
        create_model_decoration(
          "dec1",
          @base_common.Range::Range(1, 1, 1, 6),
          @inline_decorations.ModelDecorationOptions::new(
            description="test",
            inline_class_name="test-class",
          ),
        ),
      ]
    },
  }
  let computer = @inline_decorations.InlineModelDecorationsComputer::new(
    context, model, coordinates_converter,
  )
  let result = computer.get_decorations(
    @base_common.Range::Range(1, 1, 1, 12),
    false,
    false,
  )
  assert_eq(result.decorations.length(), 1)
  assert_inline_eq(result.inline_decorations, [
    [
      @inline_decorations.InlineDecoration::new(
        @base_common.Range::Range(1, 1, 1, 6),
        "test-class",
        @inline_decorations.Regular,
      ),
    ],
  ])
  assert_bool_array_eq(result.has_variable_fonts, [false])
}

///|
test "inlineClassName with affectsLetterSpacing" {
  let model = @inline_decorations.TextModel::create("hello world")
  let coordinates_converter = @inline_decorations.IdentityCoordinatesConverter::new(
    model,
  )
  let context : @inline_decorations.InlineModelContext = {
    get_model_decorations: fn(_view_range, _a, _b) {
      [
        create_model_decoration(
          "dec1",
          @base_common.Range::Range(1, 1, 1, 6),
          @inline_decorations.ModelDecorationOptions::new(
            description="test",
            inline_class_name="test-class",
            inline_class_name_affects_letter_spacing=true,
          ),
        ),
      ]
    },
  }
  let computer = @inline_decorations.InlineModelDecorationsComputer::new(
    context, model, coordinates_converter,
  )
  let result = computer.get_decorations(
    @base_common.Range::Range(1, 1, 1, 12),
    false,
    false,
  )
  assert_inline_eq(result.inline_decorations, [
    [
      @inline_decorations.InlineDecoration::new(
        @base_common.Range::Range(1, 1, 1, 6),
        "test-class",
        @inline_decorations.RegularAffectingLetterSpacing,
      ),
    ],
  ])
}

///|
test "beforeContentClassName decoration" {
  let model = @inline_decorations.TextModel::create("hello world")
  let coordinates_converter = @inline_decorations.IdentityCoordinatesConverter::new(
    model,
  )
  let context : @inline_decorations.InlineModelContext = {
    get_model_decorations: fn(_view_range, _a, _b) {
      [
        create_model_decoration(
          "dec1",
          @base_common.Range::Range(1, 3, 1, 8),
          @inline_decorations.ModelDecorationOptions::new(
            description="test",
            before_content_class_name="before-class",
          ),
        ),
      ]
    },
  }
  let computer = @inline_decorations.InlineModelDecorationsComputer::new(
    context, model, coordinates_converter,
  )
  let result = computer.get_decorations(
    @base_common.Range::Range(1, 1, 1, 12),
    false,
    false,
  )
  assert_inline_eq(result.inline_decorations, [
    [
      @inline_decorations.InlineDecoration::new(
        @base_common.Range::Range(1, 3, 1, 3),
        "before-class",
        @inline_decorations.Before,
      ),
    ],
  ])
}

///|
test "afterContentClassName decoration" {
  let model = @inline_decorations.TextModel::create("hello world")
  let coordinates_converter = @inline_decorations.IdentityCoordinatesConverter::new(
    model,
  )
  let context : @inline_decorations.InlineModelContext = {
    get_model_decorations: fn(_view_range, _a, _b) {
      [
        create_model_decoration(
          "dec1",
          @base_common.Range::Range(1, 3, 1, 8),
          @inline_decorations.ModelDecorationOptions::new(
            description="test",
            after_content_class_name="after-class",
          ),
        ),
      ]
    },
  }
  let computer = @inline_decorations.InlineModelDecorationsComputer::new(
    context, model, coordinates_converter,
  )
  let result = computer.get_decorations(
    @base_common.Range::Range(1, 1, 1, 12),
    false,
    false,
  )
  assert_inline_eq(result.inline_decorations, [
    [
      @inline_decorations.InlineDecoration::new(
        @base_common.Range::Range(1, 8, 1, 8),
        "after-class",
        @inline_decorations.After,
      ),
    ],
  ])
}

///|
test "all decoration types combined" {
  let model = @inline_decorations.TextModel::create("hello world")
  let coordinates_converter = @inline_decorations.IdentityCoordinatesConverter::new(
    model,
  )
  let context : @inline_decorations.InlineModelContext = {
    get_model_decorations: fn(_view_range, _a, _b) {
      [
        create_model_decoration(
          "dec1",
          @base_common.Range::Range(1, 2, 1, 6),
          @inline_decorations.ModelDecorationOptions::new(
            description="test",
            inline_class_name="inline-class",
            before_content_class_name="before-class",
            after_content_class_name="after-class",
          ),
        ),
      ]
    },
  }
  let computer = @inline_decorations.InlineModelDecorationsComputer::new(
    context, model, coordinates_converter,
  )
  let result = computer.get_decorations(
    @base_common.Range::Range(1, 1, 1, 12),
    false,
    false,
  )
  assert_inline_eq(result.inline_decorations, [
    [
      @inline_decorations.InlineDecoration::new(
        @base_common.Range::Range(1, 2, 1, 6),
        "inline-class",
        @inline_decorations.Regular,
      ),
      @inline_decorations.InlineDecoration::new(
        @base_common.Range::Range(1, 2, 1, 2),
        "before-class",
        @inline_decorations.Before,
      ),
      @inline_decorations.InlineDecoration::new(
        @base_common.Range::Range(1, 6, 1, 6),
        "after-class",
        @inline_decorations.After,
      ),
    ],
  ])
}

///|
test "decoration spanning multiple lines" {
  let model = @inline_decorations.TextModel::create(
    "line one\nline two\nline three",
  )
  let coordinates_converter = @inline_decorations.IdentityCoordinatesConverter::new(
    model,
  )
  let context : @inline_decorations.InlineModelContext = {
    get_model_decorations: fn(_view_range, _a, _b) {
      [
        create_model_decoration(
          "dec1",
          @base_common.Range::Range(1, 3, 3, 5),
          @inline_decorations.ModelDecorationOptions::new(
            description="test",
            inline_class_name="multi-line",
          ),
        ),
      ]
    },
  }
  let computer = @inline_decorations.InlineModelDecorationsComputer::new(
    context, model, coordinates_converter,
  )
  let result = computer.get_decorations(
    @base_common.Range::Range(1, 1, 3, 11),
    false,
    false,
  )
  let expected = @inline_decorations.InlineDecoration::new(
    @base_common.Range::Range(1, 3, 3, 5),
    "multi-line",
    @inline_decorations.Regular,
  )
  assert_inline_eq(result.inline_decorations, [
    [expected],
    [expected],
    [expected],
  ])
}

///|
test "decoration with affectsFont sets hasVariableFonts" {
  let model = @inline_decorations.TextModel::create("hello world")
  let coordinates_converter = @inline_decorations.IdentityCoordinatesConverter::new(
    model,
  )
  let context : @inline_decorations.InlineModelContext = {
    get_model_decorations: fn(_view_range, _a, _b) {
      [
        create_model_decoration(
          "dec1",
          @base_common.Range::Range(1, 1, 1, 6),
          @inline_decorations.ModelDecorationOptions::new(
            description="test",
            inline_class_name="font-class",
            affects_font=true,
          ),
        ),
      ]
    },
  }
  let computer = @inline_decorations.InlineModelDecorationsComputer::new(
    context, model, coordinates_converter,
  )
  let result = computer.get_decorations(
    @base_common.Range::Range(1, 1, 1, 12),
    false,
    false,
  )
  assert_bool_array_eq(result.has_variable_fonts, [true])
}

///|
test "multiple decorations on different lines" {
  let model = @inline_decorations.TextModel::create("line one\nline two")
  let coordinates_converter = @inline_decorations.IdentityCoordinatesConverter::new(
    model,
  )
  let context : @inline_decorations.InlineModelContext = {
    get_model_decorations: fn(_view_range, _a, _b) {
      [
        create_model_decoration(
          "dec1",
          @base_common.Range::Range(1, 1, 1, 5),
          @inline_decorations.ModelDecorationOptions::new(
            description="test",
            inline_class_name="class-a",
          ),
        ),
        create_model_decoration(
          "dec2",
          @base_common.Range::Range(2, 1, 2, 5),
          @inline_decorations.ModelDecorationOptions::new(
            description="test",
            inline_class_name="class-b",
          ),
        ),
      ]
    },
  }
  let computer = @inline_decorations.InlineModelDecorationsComputer::new(
    context, model, coordinates_converter,
  )
  let result = computer.get_decorations(
    @base_common.Range::Range(1, 1, 2, 9),
    false,
    false,
  )
  assert_inline_eq(result.inline_decorations, [
    [
      @inline_decorations.InlineDecoration::new(
        @base_common.Range::Range(1, 1, 1, 5),
        "class-a",
        @inline_decorations.Regular,
      ),
    ],
    [
      @inline_decorations.InlineDecoration::new(
        @base_common.Range::Range(2, 1, 2, 5),
        "class-b",
        @inline_decorations.Regular,
      ),
    ],
  ])
}

///|
test "decoration cache is used for same decoration id" {
  let model = @inline_decorations.TextModel::create("hello world")
  let coordinates_converter = @inline_decorations.IdentityCoordinatesConverter::new(
    model,
  )
  let dec = create_model_decoration(
    "dec1",
    @base_common.Range::Range(1, 1, 1, 6),
    @inline_decorations.ModelDecorationOptions::new(
      description="test",
      inline_class_name="test-class",
    ),
  )
  let context : @inline_decorations.InlineModelContext = {
    get_model_decorations: fn(_view_range, _a, _b) { [dec] },
  }
  let computer = @inline_decorations.InlineModelDecorationsComputer::new(
    context, model, coordinates_converter,
  )
  let result1 = computer.get_decorations(
    @base_common.Range::Range(1, 1, 1, 12),
    false,
    false,
  )
  let result2 = computer.get_decorations(
    @base_common.Range::Range(1, 1, 1, 12),
    false,
    false,
  )
  assert_true(physical_equal(result1.decorations[0], result2.decorations[0]))
}

///|
test "reset clears decoration cache" {
  let model = @inline_decorations.TextModel::create("hello world")
  let coordinates_converter = @inline_decorations.IdentityCoordinatesConverter::new(
    model,
  )
  let dec = create_model_decoration(
    "dec1",
    @base_common.Range::Range(1, 1, 1, 6),
    @inline_decorations.ModelDecorationOptions::new(
      description="test",
      inline_class_name="test-class",
    ),
  )
  let context : @inline_decorations.InlineModelContext = {
    get_model_decorations: fn(_view_range, _a, _b) { [dec] },
  }
  let computer = @inline_decorations.InlineModelDecorationsComputer::new(
    context, model, coordinates_converter,
  )
  let result1 = computer.get_decorations(
    @base_common.Range::Range(1, 1, 1, 12),
    false,
    false,
  )
  computer.reset()
  let result2 = computer.get_decorations(
    @base_common.Range::Range(1, 1, 1, 12),
    false,
    false,
  )
  assert_false(physical_equal(result1.decorations[0], result2.decorations[0]))
}

///|
test "getInlineDecorations returns inline decorations for a model line" {
  let model = @inline_decorations.TextModel::create("hello world")
  let coordinates_converter = @inline_decorations.IdentityCoordinatesConverter::new(
    model,
  )
  let context : @inline_decorations.InlineModelContext = {
    get_model_decorations: fn(_view_range, _a, _b) {
      [
        create_model_decoration(
          "dec1",
          @base_common.Range::Range(1, 1, 1, 6),
          @inline_decorations.ModelDecorationOptions::new(
            description="test",
            inline_class_name="test-class",
          ),
        ),
      ]
    },
  }
  let computer = @inline_decorations.InlineModelDecorationsComputer::new(
    context, model, coordinates_converter,
  )
  let result = computer.get_inline_decorations(1)
  assert_inline_eq(result, [
    [
      @inline_decorations.InlineDecoration::new(
        @base_common.Range::Range(1, 1, 1, 6),
        "test-class",
        @inline_decorations.Regular,
      ),
    ],
  ])
}

// ---- suite('InjectedTextInlineDecorationsComputer') ----

///|
test "no injections returns empty" {
  let context : @inline_decorations.InjectedTextContext = {
    get_injection_options: fn(
      _l,
    ) -> Array[@inline_decorations.InjectedTextOptions]? {
      None
    },
    get_injection_offsets: fn(_l) -> Array[Int]? { None },
    get_break_offsets: fn(_l) { [10] },
    get_wrapped_text_indent_length: fn(_l) { 0 },
    get_base_view_line_number: fn(_l) { 1 },
  }
  let computer = @inline_decorations.InjectedTextInlineDecorationsComputer::new(
    context,
  )
  let result = computer.get_inline_decorations(1)
  assert_inline_eq(result, [])
}

///|
test "single injection with inlineClassName on a single output line" {
  let injection_options = [
    @inline_decorations.InjectedTextOptions::new(
      content="injected",
      inline_class_name="injected-class",
    ),
  ]
  let context : @inline_decorations.InjectedTextContext = {
    get_injection_options: fn(_l) { Some(injection_options) },
    get_injection_offsets: fn(_l) { Some([5]) },
    get_break_offsets: fn(_l) { [18] }, // 10 (original) + 8 (injected)
    get_wrapped_text_indent_length: fn(_l) { 0 },
    get_base_view_line_number: fn(_l) { 1 },
  }
  let computer = @inline_decorations.InjectedTextInlineDecorationsComputer::new(
    context,
  )
  let result = computer.get_inline_decorations(1)
  assert_inline_eq(result, [
    [
      @inline_decorations.InlineDecoration::new(
        @base_common.Range::Range(1, 6, 1, 14),
        "injected-class",
        @inline_decorations.Regular,
      ),
    ],
  ])
}

///|
test "injection without inlineClassName produces no inline decorations" {
  let injection_options = [
    @inline_decorations.InjectedTextOptions::new(content="injected"),
  ]
  let context : @inline_decorations.InjectedTextContext = {
    get_injection_options: fn(_l) { Some(injection_options) },
    get_injection_offsets: fn(_l) { Some([5]) },
    get_break_offsets: fn(_l) { [18] },
    get_wrapped_text_indent_length: fn(_l) { 0 },
    get_base_view_line_number: fn(_l) { 1 },
  }
  let computer = @inline_decorations.InjectedTextInlineDecorationsComputer::new(
    context,
  )
  let result = computer.get_inline_decorations(1)
  assert_inline_eq(result, [[]]) // empty - no inlineClassName
}

///|
test "injection with inlineClassNameAffectsLetterSpacing" {
  let injection_options = [
    @inline_decorations.InjectedTextOptions::new(
      content="abc",
      inline_class_name="ls-class",
      inline_class_name_affects_letter_spacing=true,
    ),
  ]
  let context : @inline_decorations.InjectedTextContext = {
    get_injection_options: fn(_l) { Some(injection_options) },
    get_injection_offsets: fn(_l) { Some([0]) },
    get_break_offsets: fn(_l) { [13] }, // 10 + 3
    get_wrapped_text_indent_length: fn(_l) { 0 },
    get_base_view_line_number: fn(_l) { 1 },
  }
  let computer = @inline_decorations.InjectedTextInlineDecorationsComputer::new(
    context,
  )
  let result = computer.get_inline_decorations(1)
  assert_inline_eq(result, [
    [
      @inline_decorations.InlineDecoration::new(
        @base_common.Range::Range(1, 1, 1, 4),
        "ls-class",
        @inline_decorations.RegularAffectingLetterSpacing,
      ),
    ],
  ])
}

///|
test "multiple injections on a single output line" {
  let injection_options = [
    @inline_decorations.InjectedTextOptions::new(
      content="AA",
      inline_class_name="class-a",
    ),
    @inline_decorations.InjectedTextOptions::new(
      content="BBB",
      inline_class_name="class-b",
    ),
  ]
  let context : @inline_decorations.InjectedTextContext = {
    get_injection_options: fn(_l) { Some(injection_options) },
    get_injection_offsets: fn(_l) { Some([2, 5]) },
    get_break_offsets: fn(_l) { [15] }, // 10 + 2 + 3
    get_wrapped_text_indent_length: fn(_l) { 0 },
    get_base_view_line_number: fn(_l) { 1 },
  }
  let computer = @inline_decorations.InjectedTextInlineDecorationsComputer::new(
    context,
  )
  let result = computer.get_inline_decorations(1)
  assert_inline_eq(result, [
    [
      @inline_decorations.InlineDecoration::new(
        @base_common.Range::Range(1, 3, 1, 5),
        "class-a",
        @inline_decorations.Regular,
      ),
      @inline_decorations.InlineDecoration::new(
        @base_common.Range::Range(1, 8, 1, 11),
        "class-b",
        @inline_decorations.Regular,
      ),
    ],
  ])
}

///|
test "injection spanning across wrapped lines" {
  // Original text is 20 chars, injection of 10 chars at offset 8.
  // Break offsets split at 15 and 30 (two wrapped lines).
  let injection_options = [
    @inline_decorations.InjectedTextOptions::new(
      content="1234567890",
      inline_class_name="injected",
    ),
  ]
  let context : @inline_decorations.InjectedTextContext = {
    get_injection_options: fn(_l) { Some(injection_options) },
    get_injection_offsets: fn(_l) { Some([8]) },
    get_break_offsets: fn(_l) { [15, 30] },
    get_wrapped_text_indent_length: fn(_l) { 0 },
    get_base_view_line_number: fn(_l) { 5 },
  }
  let computer = @inline_decorations.InjectedTextInlineDecorationsComputer::new(
    context,
  )
  let result = computer.get_inline_decorations(1)
  // Injected text starts at offset 8 in the input with injections.
  // Line 0: [0, 15), injected text occupies [8, 18) -> clipped to [8, 15)
  // Line 1: [15, 30), injected text occupies [8, 18) -> clipped to [15, 18) -> [0, 3)
  assert_inline_eq(result, [
    [
      @inline_decorations.InlineDecoration::new(
        @base_common.Range::Range(5, 9, 5, 16),
        "injected",
        @inline_decorations.Regular,
      ),
    ],
    [
      @inline_decorations.InlineDecoration::new(
        @base_common.Range::Range(6, 1, 6, 4),
        "injected",
        @inline_decorations.Regular,
      ),
    ],
  ])
}

///|
test "injection with wrappedTextIndentLength on wrapped lines" {
  let injection_options = [
    @inline_decorations.InjectedTextOptions::new(
      content="12345678901234567890",
      inline_class_name="injected",
    ),
  ]
  let context : @inline_decorations.InjectedTextContext = {
    get_injection_options: fn(_l) { Some(injection_options) },
    get_injection_offsets: fn(_l) { Some([0]) },
    get_break_offsets: fn(_l) { [15, 30] },
    get_wrapped_text_indent_length: fn(_l) { 4 },
    get_base_view_line_number: fn(_l) { 1 },
  }
  let computer = @inline_decorations.InjectedTextInlineDecorationsComputer::new(
    context,
  )
  let result = computer.get_inline_decorations(1)
  // Line 0 (outputLineIndex 0): no offset, start=0, end=15 -> columns 1 to 16
  // Line 1 (outputLineIndex 1): wrappedTextIndentLength=4, start=4, end=9 -> columns 5 to 10
  assert_inline_eq(result, [
    [
      @inline_decorations.InlineDecoration::new(
        @base_common.Range::Range(1, 1, 1, 16),
        "injected",
        @inline_decorations.Regular,
      ),
    ],
    [
      @inline_decorations.InlineDecoration::new(
        @base_common.Range::Range(2, 5, 2, 10),
        "injected",
        @inline_decorations.Regular,
      ),
    ],
  ])
}

///|
test "injection starting in later wrapped line" {
  // Injection at offset 20 which is past the first line break.
  let injection_options = [
    @inline_decorations.InjectedTextOptions::new(
      content="ab",
      inline_class_name="late-class",
    ),
  ]
  let context : @inline_decorations.InjectedTextContext = {
    get_injection_options: fn(_l) { Some(injection_options) },
    get_injection_offsets: fn(_l) { Some([20]) },
    get_break_offsets: fn(_l) { [15, 32] }, // 30 + 2
    get_wrapped_text_indent_length: fn(_l) { 0 },
    get_base_view_line_number: fn(_l) { 1 },
  }
  let computer = @inline_decorations.InjectedTextInlineDecorationsComputer::new(
    context,
  )
  let result = computer.get_inline_decorations(1)
  // Line 0: [0, 15) -> injection at offset 20 is past this line -> empty
  // Line 1: [15, 32) -> injection at offset 20 -> start=5, end=7 -> columns 6 to 8
  assert_inline_eq(result, [
    [],
    [
      @inline_decorations.InlineDecoration::new(
        @base_common.Range::Range(2, 6, 2, 8),
        "late-class",
        @inline_decorations.Regular,
      ),
    ],
  ])
}

///|
test "base view line number offsets correctly" {
  let injection_options = [
    @inline_decorations.InjectedTextOptions::new(
      content="test",
      inline_class_name="test-class",
    ),
  ]
  let context : @inline_decorations.InjectedTextContext = {
    get_injection_options: fn(_l) { Some(injection_options) },
    get_injection_offsets: fn(_l) { Some([0]) },
    get_break_offsets: fn(_l) { [14] },
    get_wrapped_text_indent_length: fn(_l) { 0 },
    get_base_view_line_number: fn(_l) { 10 },
  }
  let computer = @inline_decorations.InjectedTextInlineDecorationsComputer::new(
    context,
  )
  let result = computer.get_inline_decorations(1)
  assert_inline_eq(result, [
    [
      @inline_decorations.InlineDecoration::new(
        @base_common.Range::Range(10, 1, 10, 5),
        "test-class",
        @inline_decorations.Regular,
      ),
    ],
  ])
}

///|
test "range uses view line number, not model line number" {
  // Model line 3 maps to view line 7 (e.g. due to previous lines wrapping).
  // The range in the resulting InlineDecoration must use the view line number.
  let model_line_number = 3
  let base_view_line_number = 7
  let injection_options = [
    @inline_decorations.InjectedTextOptions::new(
      content="ghost",
      inline_class_name="ghost-class",
    ),
  ]
  let context : @inline_decorations.InjectedTextContext = {
    get_injection_options: fn(_l) { Some(injection_options) },
    get_injection_offsets: fn(_l) { Some([0]) },
    get_break_offsets: fn(_l) { [15] }, // 10 (original) + 5 (injected)
    get_wrapped_text_indent_length: fn(_l) { 0 },
    get_base_view_line_number: fn(_l) { base_view_line_number },
  }
  let computer = @inline_decorations.InjectedTextInlineDecorationsComputer::new(
    context,
  )
  let result = computer.get_inline_decorations(model_line_number)
  // The range must reference view line 7, not model line 3.
  assert_inline_eq(result, [
    [
      @inline_decorations.InlineDecoration::new(
        @base_common.Range::Range(7, 1, 7, 6),
        "ghost-class",
        @inline_decorations.Regular,
      ),
    ],
  ])
}

///|
test "range uses view line number on wrapped lines, not model line number" {
  // Model line 2 wraps into view lines 5 and 6.
  let model_line_number = 2
  let base_view_line_number = 5
  let injection_options = [
    @inline_decorations.InjectedTextOptions::new(
      content="1234567890",
      inline_class_name="wrap-class",
    ),
  ]
  let context : @inline_decorations.InjectedTextContext = {
    get_injection_options: fn(_l) { Some(injection_options) },
    get_injection_offsets: fn(_l) { Some([0]) },
    get_break_offsets: fn(_l) { [8, 20] },
    get_wrapped_text_indent_length: fn(_l) { 0 },
    get_base_view_line_number: fn(_l) { base_view_line_number },
  }
  let computer = @inline_decorations.InjectedTextInlineDecorationsComputer::new(
    context,
  )
  let result = computer.get_inline_decorations(model_line_number)
  // First wrapped line uses view line 5, second uses view line 6.
  assert_inline_eq(result, [
    [
      @inline_decorations.InlineDecoration::new(
        @base_common.Range::Range(5, 1, 5, 9),
        "wrap-class",
        @inline_decorations.Regular,
      ),
    ],
    [
      @inline_decorations.InlineDecoration::new(
        @base_common.Range::Range(6, 1, 6, 3),
        "wrap-class",
        @inline_decorations.Regular,
      ),
    ],
  ])
}
