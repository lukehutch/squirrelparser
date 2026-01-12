import { MetaGrammar, Parser } from '../../src/index.js';

describe('MetaGrammar - Complex Grammars', () => {
  test('arithmetic expression grammar', () => {
    const grammar = `
      Expr <- Term ("+" Term / "-" Term)*;
      Term <- Factor ("*" Factor / "/" Factor)*;
      Factor <- Number / "(" Expr ")";
      Number <- [0-9]+;
    `;

    const rules = MetaGrammar.parseGrammar(grammar);

    let parser = new Parser({ topRuleName: 'Expr', rules, input: '42' });
    let parseResult = parser.parse();
    let result = parseResult.root;
    expect(result).not.toBeNull();
    expect(result.len).toBe(2);

    parser = new Parser({ topRuleName: 'Expr', rules, input: '1+2' });
    parseResult = parser.parse();
    result = parseResult.root;
    expect(result).not.toBeNull();
    expect(result.len).toBe(3);

    parser = new Parser({ topRuleName: 'Expr', rules, input: '1+2*3' });
    parseResult = parser.parse();
    result = parseResult.root;
    expect(result).not.toBeNull();
    expect(result.len).toBe(5);

    parser = new Parser({ topRuleName: 'Expr', rules, input: '(1+2)*3' });
    parseResult = parser.parse();
    result = parseResult.root;
    expect(result).not.toBeNull();
    expect(result.len).toBe(7);
  });

  test('identifier and keyword grammar', () => {
    const grammar = `
      Ident <- !Keyword [a-zA-Z_] [a-zA-Z0-9_]*;
      Keyword <- ("if" / "while" / "for") ![a-zA-Z0-9_];
    `;

    const rules = MetaGrammar.parseGrammar(grammar);

    let parser = new Parser({ topRuleName: 'Ident', rules, input: 'foo' });
    let parseResult = parser.parse();
    let result = parseResult.root;
    expect(result).not.toBeNull();

    // Use matchRule for negative test to avoid recovery
    parser = new Parser({ topRuleName: 'Ident', rules, input: 'if' });
    const matchResult = parser.matchRule('Ident', 0);
    expect(matchResult.isMismatch).toBe(true); // 'if' is a keyword

    parser = new Parser({ topRuleName: 'Ident', rules, input: 'iffy' });
    parseResult = parser.parse();
    result = parseResult.root;
    expect(result).not.toBeNull(); // 'iffy' is not a keyword
  });

  test('JSON grammar', () => {
    const grammar = String.raw`
      Value <- String / Number / Object / Array / "true" / "false" / "null";
      Object <- "{" _ (Pair (_ "," _ Pair)*)? _ "}";
      Pair <- String _ ":" _ Value;
      Array <- "[" _ (Value (_ "," _ Value)*)? _ "]";
      String <- "\"" [^"]* "\"";
      Number <- [0-9]+;
      _ <- [ \t\n\r]*;
    `;

    const rules = MetaGrammar.parseGrammar(grammar);

    let parser = new Parser({ topRuleName: 'Value', rules, input: '{}' });
    let parseResult = parser.parse();
    let result = parseResult.root;
    expect(result).not.toBeNull();

    parser = new Parser({ topRuleName: 'Value', rules, input: '[]' });
    parseResult = parser.parse();
    result = parseResult.root;
    expect(result).not.toBeNull();

    parser = new Parser({ topRuleName: 'Value', rules, input: '"hello"' });
    parseResult = parser.parse();
    result = parseResult.root;
    expect(result).not.toBeNull();

    parser = new Parser({ topRuleName: 'Value', rules, input: '123' });
    parseResult = parser.parse();
    result = parseResult.root;
    expect(result).not.toBeNull();
  });

  test('whitespace handling', () => {
    const grammar = String.raw`
      Main <- _ "hello" _ "world" _;
      _ <- [ \t\n\r]*;
    `;

    const rules = MetaGrammar.parseGrammar(grammar);

    let parser = new Parser({ topRuleName: 'Main', rules, input: 'helloworld' });
    let parseResult = parser.parse();
    let result = parseResult.root;
    expect(result).not.toBeNull();

    parser = new Parser({ topRuleName: 'Main', rules, input: '  hello   world  ' });
    parseResult = parser.parse();
    result = parseResult.root;
    expect(result).not.toBeNull();

    parser = new Parser({ topRuleName: 'Main', rules, input: 'hello\n\tworld' });
    parseResult = parser.parse();
    result = parseResult.root;
    expect(result).not.toBeNull();
  });

  test('comment handling with metagrammar', () => {
    const grammar = `
      # This is a comment
      Main <- "test"; # trailing comment
      # Another comment
    `;

    const rules = MetaGrammar.parseGrammar(grammar);
    expect(rules.has('Main')).toBe(true);

    const parser = new Parser({ topRuleName: 'Main', rules, input: 'test' });
    const parseResult = parser.parse();
    const result = parseResult.root;
    expect(result).not.toBeNull();
  });
});
