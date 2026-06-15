export const conformanceSourceText = [
  '///|',
  'pub fn inspect_value(value : Int) -> Int {',
  '  value + helper_value(1)',
  '}',
  '',
  '///|',
  'fn helper_value(seed : Int) -> Int {',
  '  seed + 41',
  '}',
  '',
  '///|',
  'pub fn wide_hover_target() -> String {',
  '  "scroll horizontally"',
  '}',
  '',
  ...Array.from({ length: 30 }, (_, index) => [
    '///|',
    `pub fn generated_conformance_${index}() -> Int {`,
    `  ${index}`,
    '}',
    '',
  ]).flat(),
].join('\n');

export const hoverPayloads = {
  shortSignature: {
    kind: 'markdown',
    contents: [
      '```moonbit',
      'fn inspect_value(value : Int) -> Int',
      '```',
      '',
      'Inspect a readonly value.',
    ].join('\n'),
  },
  markdownLong: {
    kind: 'markdown',
    contents: [
      '### Long hover',
      '',
      'This payload is tall enough to require the hover scrollable element.',
      '',
      ...Array.from({ length: 64 }, (_, index) => `- conformance item ${index}`),
    ].join('\n'),
  },
  wideCode: {
    kind: 'markdown',
    contents: [
      '```moonbit',
      `fn rendered_${'x'.repeat(220)}() -> Unit {}`,
      '```',
    ].join('\n'),
  },
  plaintext: {
    kind: 'plaintext',
    contents: 'Plain hover payload for DOM parity checks.',
  },
  markerDiagnostic: {
    kind: 'marker',
    contents: 'Conformance diagnostic message.',
  },
};

export const conformanceStates = {
  shortHover: { payload: 'shortSignature', line: 2, column: 8 },
  longHover: { payload: 'markdownLong', line: 2, column: 8 },
  wideHover: { payload: 'wideCode', line: 12, column: 8 },
  markerHover: { payload: 'markerDiagnostic', line: 3, column: 8 },
};
