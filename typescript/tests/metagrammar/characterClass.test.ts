import { MetaGrammar, Parser, CharSet, SyntaxError } from '../../src/index.js';

describe('CharSet Terminal - Direct Construction', () => {
  test('CharSet.range matches characters in range', () => {
    const charSet = CharSet.range('a', 'z');
    const rules = new Map([['S', charSet]]);

    let parser = new Parser({ topRuleName: 'S', rules, input: 'a' });
    expect(parser.parse().root instanceof SyntaxError).toBe(false);

    parser = new Parser({ topRuleName: 'S', rules, input: 'm' });
    expect(parser.parse().root instanceof SyntaxError).toBe(false);

    parser = new Parser({ topRuleName: 'S', rules, input: 'z' });
    expect(parser.parse().root instanceof SyntaxError).toBe(false);

    parser = new Parser({ topRuleName: 'S', rules, input: 'A' });
    expect(parser.parse().root instanceof SyntaxError).toBe(true);
  });

  test('CharSet.char matches single character', () => {
    const charSet = CharSet.char('x');
    const rules = new Map([['S', charSet]]);

    let parser = new Parser({ topRuleName: 'S', rules, input: 'x' });
    expect(parser.parse().root instanceof SyntaxError).toBe(false);

    parser = new Parser({ topRuleName: 'S', rules, input: 'y' });
    expect(parser.parse().root instanceof SyntaxError).toBe(true);
  });

  test('CharSet with multiple ranges', () => {
    // [a-zA-Z0-9]
    const charSet = new CharSet([
      ['a'.charCodeAt(0), 'z'.charCodeAt(0)],
      ['A'.charCodeAt(0), 'Z'.charCodeAt(0)],
      ['0'.charCodeAt(0), '9'.charCodeAt(0)],
    ]);
    const rules = new Map([['S', charSet]]);

    // Test lowercase
    let parser = new Parser({ topRuleName: 'S', rules, input: 'a' });
    expect(parser.parse().root instanceof SyntaxError).toBe(false);
    parser = new Parser({ topRuleName: 'S', rules, input: 'z' });
    expect(parser.parse().root instanceof SyntaxError).toBe(false);

    // Test uppercase
    parser = new Parser({ topRuleName: 'S', rules, input: 'A' });
    expect(parser.parse().root instanceof SyntaxError).toBe(false);
    parser = new Parser({ topRuleName: 'S', rules, input: 'Z' });
    expect(parser.parse().root instanceof SyntaxError).toBe(false);

    // Test digits
    parser = new Parser({ topRuleName: 'S', rules, input: '0' });
    expect(parser.parse().root instanceof SyntaxError).toBe(false);
    parser = new Parser({ topRuleName: 'S', rules, input: '9' });
    expect(parser.parse().root instanceof SyntaxError).toBe(false);

    // Test non-alphanumeric
    parser = new Parser({ topRuleName: 'S', rules, input: '!' });
    expect(parser.parse().root instanceof SyntaxError).toBe(true);
    parser = new Parser({ topRuleName: 'S', rules, input: ' ' });
    expect(parser.parse().root instanceof SyntaxError).toBe(true);
  });

  test('CharSet with inversion', () => {
    // [^a-z] - matches anything NOT a lowercase letter
    const charSet = new CharSet(
      [['a'.charCodeAt(0), 'z'.charCodeAt(0)]],
      true
    );
    const rules = new Map([['S', charSet]]);

    // Should NOT match lowercase
    let parser = new Parser({ topRuleName: 'S', rules, input: 'a' });
    expect(parser.parse().root instanceof SyntaxError).toBe(true);
    parser = new Parser({ topRuleName: 'S', rules, input: 'm' });
    expect(parser.parse().root instanceof SyntaxError).toBe(true);
    parser = new Parser({ topRuleName: 'S', rules, input: 'z' });
    expect(parser.parse().root instanceof SyntaxError).toBe(true);

    // Should match uppercase, digits, symbols
    parser = new Parser({ topRuleName: 'S', rules, input: 'A' });
    expect(parser.parse().root instanceof SyntaxError).toBe(false);
    parser = new Parser({ topRuleName: 'S', rules, input: '5' });
    expect(parser.parse().root instanceof SyntaxError).toBe(false);
    parser = new Parser({ topRuleName: 'S', rules, input: '!' });
    expect(parser.parse().root instanceof SyntaxError).toBe(false);
  });

  test('CharSet with inverted multiple ranges', () => {
    // [^a-zA-Z] - matches anything NOT a letter
    const charSet = new CharSet(
      [
        ['a'.charCodeAt(0), 'z'.charCodeAt(0)],
        ['A'.charCodeAt(0), 'Z'.charCodeAt(0)],
      ],
      true
    );
    const rules = new Map([['S', charSet]]);

    // Should NOT match letters
    let parser = new Parser({ topRuleName: 'S', rules, input: 'a' });
    expect(parser.parse().root instanceof SyntaxError).toBe(true);
    parser = new Parser({ topRuleName: 'S', rules, input: 'Z' });
    expect(parser.parse().root instanceof SyntaxError).toBe(true);

    // Should match digits and symbols
    parser = new Parser({ topRuleName: 'S', rules, input: '5' });
    expect(parser.parse().root instanceof SyntaxError).toBe(false);
    parser = new Parser({ topRuleName: 'S', rules, input: '!' });
    expect(parser.parse().root instanceof SyntaxError).toBe(false);
  });

  test('CharSet.notRange convenience constructor', () => {
    const charSet = CharSet.notRange('0', '9');
    const rules = new Map([['S', charSet]]);

    // Should NOT match digits
    let parser = new Parser({ topRuleName: 'S', rules, input: '5' });
    expect(parser.parse().root instanceof SyntaxError).toBe(true);

    // Should match non-digits
    parser = new Parser({ topRuleName: 'S', rules, input: 'a' });
    expect(parser.parse().root instanceof SyntaxError).toBe(false);
  });

  test('CharSet toString formats correctly', () => {
    expect(CharSet.range('a', 'z').toString()).toBe('[a-z]');
    expect(CharSet.char('x').toString()).toBe('[x]');
    expect(
      new CharSet([
        ['a'.charCodeAt(0), 'z'.charCodeAt(0)],
        ['0'.charCodeAt(0), '9'.charCodeAt(0)],
      ]).toString()
    ).toBe('[a-z0-9]');
    expect(
      new CharSet([['a'.charCodeAt(0), 'z'.charCodeAt(0)]], true).toString()
    ).toBe('[^a-z]');
  });

  test('CharSet handles empty input', () => {
    const charSet = CharSet.range('a', 'z');
    const rules = new Map([['S', charSet]]);

    const parser = new Parser({ topRuleName: 'S', rules, input: '' });
    expect(parser.parse().root instanceof SyntaxError).toBe(true);
  });
});

describe('MetaGrammar - Character Classes', () => {
  test('simple character range', () => {
    const grammar = `
      Digit <- [0-9];
    `;

    const rules = MetaGrammar.parseGrammar(grammar);

    let parser = new Parser({ topRuleName: 'Digit', rules, input: '5' });
    let parseResult = parser.parse();
    let result = parseResult.root;
    expect(result instanceof SyntaxError).toBe(false);
    expect(result.len).toBe(1);

    parser = new Parser({ topRuleName: 'Digit', rules, input: 'a' });
    parseResult = parser.parse();
    result = parseResult.root;
    expect(result instanceof SyntaxError).toBe(true);
  });

  test('multiple character ranges', () => {
    const grammar = `
      AlphaNum <- [a-zA-Z0-9];
    `;

    const rules = MetaGrammar.parseGrammar(grammar);

    let parser = new Parser({ topRuleName: 'AlphaNum', rules, input: 'a' });
    let parseResult = parser.parse();
    let result = parseResult.root;
    expect(result instanceof SyntaxError).toBe(false);

    parser = new Parser({ topRuleName: 'AlphaNum', rules, input: 'Z' });
    parseResult = parser.parse();
    result = parseResult.root;
    expect(result instanceof SyntaxError).toBe(false);

    parser = new Parser({ topRuleName: 'AlphaNum', rules, input: '5' });
    parseResult = parser.parse();
    result = parseResult.root;
    expect(result instanceof SyntaxError).toBe(false);

    parser = new Parser({ topRuleName: 'AlphaNum', rules, input: '!' });
    parseResult = parser.parse();
    result = parseResult.root;
    expect(result instanceof SyntaxError).toBe(true);
  });

  test('character class with individual characters', () => {
    const grammar = `
      Vowel <- [aeiou];
    `;

    const rules = MetaGrammar.parseGrammar(grammar);

    let parser = new Parser({ topRuleName: 'Vowel', rules, input: 'a' });
    let parseResult = parser.parse();
    let result = parseResult.root;
    expect(result instanceof SyntaxError).toBe(false);

    parser = new Parser({ topRuleName: 'Vowel', rules, input: 'e' });
    parseResult = parser.parse();
    result = parseResult.root;
    expect(result instanceof SyntaxError).toBe(false);

    parser = new Parser({ topRuleName: 'Vowel', rules, input: 'b' });
    parseResult = parser.parse();
    result = parseResult.root;
    expect(result instanceof SyntaxError).toBe(true);
  });

  test('negated character class', () => {
    const grammar = `
      NotDigit <- [^0-9];
    `;

    const rules = MetaGrammar.parseGrammar(grammar);

    let parser = new Parser({ topRuleName: 'NotDigit', rules, input: 'a' });
    let parseResult = parser.parse();
    let result = parseResult.root;
    expect(result instanceof SyntaxError).toBe(false);

    parser = new Parser({ topRuleName: 'NotDigit', rules, input: '5' });
    parseResult = parser.parse();
    result = parseResult.root;
    expect(result instanceof SyntaxError).toBe(true);
  });

  test('escaped characters in character class', () => {
    const grammar = String.raw`
      Special <- [\t\n];
    `;

    const rules = MetaGrammar.parseGrammar(grammar);

    let parser = new Parser({ topRuleName: 'Special', rules, input: '\t' });
    let parseResult = parser.parse();
    let result = parseResult.root;
    expect(result instanceof SyntaxError).toBe(false);

    parser = new Parser({ topRuleName: 'Special', rules, input: '\n' });
    parseResult = parser.parse();
    result = parseResult.root;
    expect(result instanceof SyntaxError).toBe(false);

    parser = new Parser({ topRuleName: 'Special', rules, input: ' ' });
    parseResult = parser.parse();
    result = parseResult.root;
    expect(result instanceof SyntaxError).toBe(true);
  });
});
