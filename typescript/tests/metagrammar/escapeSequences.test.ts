import { MetaGrammar, Parser } from '../../src/index.js';

describe('MetaGrammar - Escape Sequences', () => {
  test('newline escape', () => {
    const grammar = String.raw`
      Newline <- "\n";
    `;

    const rules = MetaGrammar.parseGrammar(grammar);
    const parser = new Parser({ topRuleName: 'Newline', rules, input: '\n' });
    const parseResult = parser.parse();
    const result = parseResult.root;
    expect(result).not.toBeNull();
    expect(result.len).toBe(1);
  });

  test('tab escape', () => {
    const grammar = String.raw`
      Tab <- "\t";
    `;

    const rules = MetaGrammar.parseGrammar(grammar);
    const parser = new Parser({ topRuleName: 'Tab', rules, input: '\t' });
    const parseResult = parser.parse();
    const result = parseResult.root;
    expect(result).not.toBeNull();
    expect(result.len).toBe(1);
  });

  test('backslash escape', () => {
    const grammar = String.raw`
      Backslash <- "\\";
    `;

    const rules = MetaGrammar.parseGrammar(grammar);
    const parser = new Parser({ topRuleName: 'Backslash', rules, input: '\\' });
    const parseResult = parser.parse();
    const result = parseResult.root;
    expect(result).not.toBeNull();
    expect(result.len).toBe(1);
  });

  test('quote escapes', () => {
    const grammar = String.raw`
      DoubleQuote <- "\"";
      SingleQuote <- '\'';
    `;

    const rules = MetaGrammar.parseGrammar(grammar);

    let parser = new Parser({ topRuleName: 'DoubleQuote', rules, input: '"' });
    let parseResult = parser.parse();
    let result = parseResult.root;
    expect(result).not.toBeNull();

    parser = new Parser({ topRuleName: 'SingleQuote', rules, input: "'" });
    parseResult = parser.parse();
    result = parseResult.root;
    expect(result).not.toBeNull();
  });

  test('escaped sequence in string', () => {
    const grammar = String.raw`
      Message <- "Hello\nWorld";
    `;

    const rules = MetaGrammar.parseGrammar(grammar);
    const parser = new Parser({ topRuleName: 'Message', rules, input: 'Hello\nWorld' });
    const parseResult = parser.parse();
    const result = parseResult.root;
    expect(result).not.toBeNull();
    expect(result.len).toBe(11);
  });
});
