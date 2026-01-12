import { MetaGrammar, Parser } from '../../src/index.js';

describe('MetaGrammar - Rule References', () => {
  test('simple rule reference', () => {
    const grammar = `
      Main <- A "b";
      A <- "a";
    `;

    const rules = MetaGrammar.parseGrammar(grammar);
    const parser = new Parser({ topRuleName: 'Main', rules, input: 'ab' });
    const parseResult = parser.parse();
    const result = parseResult.root;
    expect(result).not.toBeNull();
    expect(result.len).toBe(2);
  });

  test('multiple rule references', () => {
    const grammar = `
      Main <- A B C;
      A <- "a";
      B <- "b";
      C <- "c";
    `;

    const rules = MetaGrammar.parseGrammar(grammar);
    const parser = new Parser({ topRuleName: 'Main', rules, input: 'abc' });
    const parseResult = parser.parse();
    const result = parseResult.root;
    expect(result).not.toBeNull();
    expect(result.len).toBe(3);
  });

  test('recursive rule', () => {
    const grammar = `
      List <- "a" List / "a";
    `;

    const rules = MetaGrammar.parseGrammar(grammar);

    let parser = new Parser({ topRuleName: 'List', rules, input: 'a' });
    let parseResult = parser.parse();
    let result = parseResult.root;
    expect(result).not.toBeNull();
    expect(result.len).toBe(1);

    parser = new Parser({ topRuleName: 'List', rules, input: 'aaa' });
    parseResult = parser.parse();
    result = parseResult.root;
    expect(result).not.toBeNull();
    expect(result.len).toBe(3);
  });

  test('mutually recursive rules', () => {
    const grammar = `
      A <- "a" B / "a";
      B <- "b" A / "b";
    `;

    const rules = MetaGrammar.parseGrammar(grammar);

    let parser = new Parser({ topRuleName: 'A', rules, input: 'aba' });
    let parseResult = parser.parse();
    let result = parseResult.root;
    expect(result).not.toBeNull();
    expect(result.len).toBe(3);

    parser = new Parser({ topRuleName: 'A', rules, input: 'bab' });
    parseResult = parser.parse();
    result = parseResult.root;
    expect(result).not.toBeNull();
    expect(result.len).toBe(3);
  });

  test('left-recursive rule', () => {
    const grammar = `
      Expr <- Expr "+" "n" / "n";
    `;

    const rules = MetaGrammar.parseGrammar(grammar);

    let parser = new Parser({ topRuleName: 'Expr', rules, input: 'n' });
    let parseResult = parser.parse();
    let result = parseResult.root;
    expect(result).not.toBeNull();
    expect(result.len).toBe(1);

    parser = new Parser({ topRuleName: 'Expr', rules, input: 'n+n' });
    parseResult = parser.parse();
    result = parseResult.root;
    expect(result).not.toBeNull();
    expect(result.len).toBe(3);

    parser = new Parser({ topRuleName: 'Expr', rules, input: 'n+n+n' });
    parseResult = parser.parse();
    result = parseResult.root;
    expect(result).not.toBeNull();
    expect(result.len).toBe(5);
  });
});
