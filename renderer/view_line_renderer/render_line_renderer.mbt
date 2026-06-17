///|
let long_token_threshold = 50

///|
/// Renders one line into `html` and returns mapping/foreign-element metadata.
pub fn render_view_line(
  input : RenderLineInput,
  html : StringBuilder,
) -> RenderLineOutput {
  let render_len = rendered_line_length(input)
  let parts = resolve_line_parts(input, render_len)
  let contains_foreign_elements = foreign_element_type(input.line_decorations)
  let mapping_length = if input.line_content.length() == 0 &&
    contains_foreign_elements == None {
    0
  } else {
    render_len + 1
  }
  let character_mapping = CharacterMapping::new(mapping_length)
  html.write_string("<span class=\"view-line-content\">")
  if input.line_content.length() == 0 {
    render_empty_line(input, html, character_mapping)
    html.write_string("</span>")
    return { character_mapping, contains_foreign_elements }
  }
  let mut char_index = 0
  let mut visible_column = input.start_visible_column
  let mut last_part_index = 0
  let mut last_char_offset_in_part = 0
  for part_index in 0..<parts.length() {
    let part = parts[part_index]
    let part_end = @core.clamp_int(part.end_index, char_index, render_len)
    let class_name = if part.is_whitespace() && input.render_whitespace != None {
      "mtkw"
    } else {
      part.class_name
    }
    html.write_string("<span class=\"")
    write_escaped(html, class_name)
    html.write_string("\">")
    if part_end > char_index {
      let mut offset_in_part = 0
      for column in char_index..<part_end {
        character_mapping.set_column_info(
          column + 1,
          part_index,
          offset_in_part,
          visible_column,
        )
        let width = code_unit_width(
          input.line_content[column].to_int(),
          visible_column,
          input.tab_size,
        )
        visible_column = visible_column + width
        offset_in_part = offset_in_part + 1
      }
      write_rendered_segment(html, input, char_index, part_end)
      char_index = part_end
      last_char_offset_in_part = offset_in_part
      if part_index > last_part_index {
        last_part_index = part_index
      }
    } else if part.is_pseudo_after() && char_index >= render_len {
      last_part_index = part_index
      last_char_offset_in_part = 0
    }
    html.write_string("</span>")
  }
  if char_index < render_len {
    let fallback_index = parts.length()
    html.write_string("<span class=\"")
    write_escaped(html, @syntax.Plain.css_class())
    html.write_string("\">")
    for column in char_index..<render_len {
      character_mapping.set_column_info(
        column + 1,
        fallback_index,
        column - char_index,
        visible_column,
      )
      let width = code_unit_width(
        input.line_content[column].to_int(),
        visible_column,
        input.tab_size,
      )
      visible_column = visible_column + width
    }
    write_rendered_segment(html, input, char_index, render_len)
    html.write_string("</span>")
    last_part_index = fallback_index
    last_char_offset_in_part = render_len - char_index
  }
  if render_len > 0 {
    character_mapping.set_column_info(
      render_len + 1,
      last_part_index,
      last_char_offset_in_part,
      visible_column,
    )
  }
  if render_len < input.line_content.length() {
    html.write_string("<span class=\"mtkoverflow\">")
    html.write_string("Show more (")
    html.write_string((input.line_content.length() - render_len).to_string())
    html.write_string(" chars)</span>")
  }
  html.write_string("</span>")
  { character_mapping, contains_foreign_elements }
}

///|
/// Renders one line and returns the generated HTML with metadata.
pub fn render_view_line2(input : RenderLineInput) -> RenderLineOutput2 {
  let html = StringBuilder()
  let output = render_view_line(input, html)
  {
    html: html.to_string(),
    character_mapping: output.character_mapping,
    contains_foreign_elements: output.contains_foreign_elements,
  }
}

///|
fn render_empty_line(
  input : RenderLineInput,
  html : StringBuilder,
  character_mapping : CharacterMapping,
) -> Unit {
  let mut pseudo_index = 0
  for decoration in input.line_decorations {
    if decoration.decoration_type == Before ||
      decoration.decoration_type == After {
      html.write_string("<span class=\"")
      write_escaped(html, decoration.class_name)
      html.write_string("\"></span>")
      pseudo_index = pseudo_index + 1
    }
  }
  if input.render_new_line_when_empty {
    html.write_string("\n")
  }
  if character_mapping.length > 0 {
    character_mapping.set_column_info(1, pseudo_index, 0, 0)
  }
}

///|
fn rendered_line_length(input : RenderLineInput) -> Int {
  if input.stop_rendering_line_after >= 0 &&
    input.stop_rendering_line_after < input.line_content.length() {
    input.stop_rendering_line_after
  } else {
    input.line_content.length()
  }
}

///|
fn resolve_line_parts(
  input : RenderLineInput,
  render_len : Int,
) -> Array[LinePart] {
  let base = normalized_line_tokens(
    input.line_tokens,
    input.line_content,
    render_len,
  )
  let decorated = apply_inline_decorations(
    input.line_content,
    render_len,
    base,
    input.line_decorations,
  )
  let split = if input.contains_rtl {
    decorated
  } else {
    split_large_tokens(decorated)
  }
  split
}

///|
fn normalized_line_tokens(
  tokens : Array[LinePart],
  line_content : String,
  render_len : Int,
) -> Array[LinePart] {
  let out : Array[LinePart] = []
  let mut cursor = 0
  for token in tokens {
    if cursor >= render_len {
      break
    }
    let end_index = @core.clamp_int(token.end_index, cursor, render_len)
    if cursor < end_index {
      out.push({
        end_index,
        class_name: token.class_name,
        metadata: token.metadata,
        contains_rtl: token.contains_rtl,
      })
      cursor = end_index
    }
  }
  if cursor < render_len {
    out.push(LinePart(render_len, @syntax.Plain.css_class()))
  }
  if out.length() == 0 && line_content.length() > 0 && render_len > 0 {
    out.push(LinePart(render_len, @syntax.Plain.css_class()))
  }
  out
}

///|
fn apply_inline_decorations(
  line_content : String,
  render_len : Int,
  tokens : Array[LinePart],
  line_decorations : Array[LineDecoration],
) -> Array[LinePart] {
  if line_decorations.length() == 0 {
    return tokens
  }
  let segments = LineDecorationsNormalizer::normalize(
    line_content, line_decorations,
  )
  if segments.length() == 0 {
    return tokens
  }
  let result : Array[LinePart] = []
  let mut segment_index = 0
  let mut last_result_end_index = 0
  for token in tokens {
    let token_end = @core.clamp_int(
      token.end_index,
      last_result_end_index,
      render_len,
    )
    while segment_index < segments.length() &&
          segments[segment_index].start_offset < token_end {
      let segment = segments[segment_index]
      if segment.start_offset > last_result_end_index {
        last_result_end_index = segment.start_offset
        result.push({
          end_index: last_result_end_index,
          class_name: token.class_name,
          metadata: token.metadata,
          contains_rtl: token.contains_rtl,
        })
      }
      let class_name = if token.class_name == "" {
        segment.class_name
      } else {
        token.class_name + " " + segment.class_name
      }
      if segment.end_offset + 1 <= token_end {
        last_result_end_index = segment.end_offset + 1
        result.push({
          end_index: last_result_end_index,
          class_name,
          metadata: token.metadata | segment.metadata,
          contains_rtl: token.contains_rtl,
        })
        segment_index = segment_index + 1
      } else {
        last_result_end_index = token_end
        result.push({
          end_index: last_result_end_index,
          class_name,
          metadata: token.metadata | segment.metadata,
          contains_rtl: token.contains_rtl,
        })
        break
      }
    }
    if token_end > last_result_end_index {
      last_result_end_index = token_end
      result.push({
        end_index: last_result_end_index,
        class_name: token.class_name,
        metadata: token.metadata,
        contains_rtl: token.contains_rtl,
      })
    }
  }
  let last_token_end_index = match tokens.last() {
    Some(token) => token.end_index
    None => 0
  }
  if segment_index < segments.length() &&
    segments[segment_index].start_offset == last_token_end_index {
    while segment_index < segments.length() &&
          segments[segment_index].start_offset == last_token_end_index {
      let segment = segments[segment_index]
      result.push({
        end_index: last_result_end_index,
        class_name: segment.class_name,
        metadata: segment.metadata,
        contains_rtl: false,
      })
      segment_index = segment_index + 1
    }
  }
  result
}

///|
fn split_large_tokens(tokens : Array[LinePart]) -> Array[LinePart] {
  let result : Array[LinePart] = []
  let mut previous_end = 0
  for token in tokens {
    if token.is_pseudo_before() || token.is_pseudo_after() {
      result.push(token)
      continue
    }
    let diff = token.end_index - previous_end
    if diff > long_token_threshold {
      let mut end_index = previous_end + long_token_threshold
      while end_index < token.end_index {
        result.push({
          end_index,
          class_name: token.class_name,
          metadata: token.metadata,
          contains_rtl: token.contains_rtl,
        })
        end_index = end_index + long_token_threshold
      }
    }
    result.push(token)
    previous_end = token.end_index
  }
  result
}

///|
fn write_rendered_segment(
  html : StringBuilder,
  input : RenderLineInput,
  start : Int,
  end : Int,
) -> Unit {
  if start >= end {
    return
  }
  let text = input.line_content[start:end].to_owned()
  if input.render_whitespace == None && !input.render_control_characters {
    write_escaped(html, text)
  } else {
    write_visible_text(
      html,
      text,
      input.render_whitespace,
      input.render_control_characters,
    )
  }
}

///|
fn write_visible_text(
  html : StringBuilder,
  text : String,
  render_whitespace : RenderWhitespace,
  render_control_characters : Bool,
) -> Unit {
  for ch in text {
    match ch {
      ' ' =>
        if render_whitespace == None {
          html.write_char(ch)
        } else {
          html.write_string("&middot;")
        }
      '\t' =>
        if render_whitespace == None {
          html.write_char(ch)
        } else {
          html.write_string("&rarr;")
        }
      '<' => html.write_string("&lt;")
      '>' => html.write_string("&gt;")
      '&' => html.write_string("&amp;")
      '"' => html.write_string("&quot;")
      _ =>
        if render_control_characters && ch.to_int() < 32 {
          html.write_string("&#9216;")
        } else {
          html.write_char(ch)
        }
    }
  }
}

///|
fn code_unit_width(code : Int, visible_column : Int, tab_size : Int) -> Int {
  if code == 9 {
    let remainder = visible_column % tab_size
    if remainder == 0 {
      tab_size
    } else {
      tab_size - remainder
    }
  } else if code > 0xff {
    2
  } else {
    1
  }
}

///|
fn foreign_element_type(
  line_decorations : Array[LineDecoration],
) -> ForeignElementType {
  let mut found : ForeignElementType = None
  for decoration in line_decorations {
    match decoration.decoration_type {
      Before | RegularAffectingLetterSpacing =>
        if found == None {
          found = Before
        }
      After => found = After
      Regular => ()
    }
  }
  found
}

///|
fn write_escaped(html : StringBuilder, text : String) -> Unit {
  for ch in text {
    match ch {
      '&' => html.write_string("&amp;")
      '<' => html.write_string("&lt;")
      '>' => html.write_string("&gt;")
      '"' => html.write_string("&quot;")
      _ => html.write_char(ch)
    }
  }
}
