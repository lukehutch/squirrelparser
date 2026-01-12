import { MetaGrammar, Parser, SyntaxError } from '../../src/index.js';

describe('MetaGrammar - Basic Syntax', () => {
  test('simple rule with string literal', () => {
    const grammar = `
      Hello <- "hello";
    `;

    const rules = MetaGrammar.parseGrammar(grammar);
    expect(rules.has('Hello')).toBe(true);

    const parser = new Parser({ topRuleName: 'Hello', rules, input: 'hello' });
    const parseResult = parser.parse();
    const result = parseResult.root;
    expect(result).not.toBeNull();
    expect(result.len).toBe(5);
  });

  test('rule with character literal', () => {
    const grammar = `
      A <- 'a';
    `;

    const rules = MetaGrammar.parseGrammar(grammar);
    const parser = new Parser({ topRuleName: 'A', rules, input: 'a' });
    const parseResult = parser.parse();
    const result = parseResult.root;
    expect(result).not.toBeNull();
    expect(result.len).toBe(1);
  });

  test('sequence of literals', () => {
    const grammar = `
      AB <- "a" "b";
    `;

    const rules = MetaGrammar.parseGrammar(grammar);
    const parser = new Parser({ topRuleName: 'AB', rules, input: 'ab' });
    const parseResult = parser.parse();
    const result = parseResult.root;
    expect(result).not.toBeNull();
    expect(result.len).toBe(2);
  });

  test('choice between alternatives', () => {
    const grammar = `
      AorB <- "a" / "b";
    `;

    const rules = MetaGrammar.parseGrammar(grammar);

    let parser = new Parser({ topRuleName: 'AorB', rules, input: 'a' });
    let parseResult = parser.parse();
    let result = parseResult.root;
    expect(result).not.toBeNull();
    expect(result.len).toBe(1);

    parser = new Parser({ topRuleName: 'AorB', rules, input: 'b' });
    parseResult = parser.parse();
    result = parseResult.root;
    expect(result).not.toBeNull();
    expect(result.len).toBe(1);
  });

  test('zero or more repetition', () => {
    const grammar = `
      As <- "a"*;
    `;

    const rules = MetaGrammar.parseGrammar(grammar);

    let parser = new Parser({ topRuleName: 'As', rules, input: '' });
    let parseResult = parser.parse();
    let result = parseResult.root;
    expect(result).not.toBeNull();
    expect(result.len).toBe(0);

    parser = new Parser({ topRuleName: 'As', rules, input: 'aaa' });
    parseResult = parser.parse();
    result = parseResult.root;
    expect(result).not.toBeNull();
    expect(result.len).toBe(3);
  });

  test('one or more repetition', () => {
    const grammar = `
      As <- "a"+;
    `;

    const rules = MetaGrammar.parseGrammar(grammar);

    let parser = new Parser({ topRuleName: 'As', rules, input: '' });
    let parseResult = parser.parse();
    let result = parseResult.root;
    expect(result instanceof SyntaxError).toBe(true);

    parser = new Parser({ topRuleName: 'As', rules, input: 'aaa' });
    parseResult = parser.parse();
    result = parseResult.root;
    expect(result).not.toBeNull();
    expect(result.len).toBe(3);
  });

  test('optional', () => {
    const grammar = `
      OptA <- "a"?;
    `;

    const rules = MetaGrammar.parseGrammar(grammar);

    let parser = new Parser({ topRuleName: 'OptA', rules, input: '' });
    let parseResult = parser.parse();
    let result = parseResult.root;
    expect(result).not.toBeNull();
    expect(result.len).toBe(0);

    parser = new Parser({ topRuleName: 'OptA', rules, input: 'a' });
    parseResult = parser.parse();
    result = parseResult.root;
    expect(result).not.toBeNull();
    expect(result.len).toBe(1);
  });

  test('positive lookahead', () => {
    const grammar = `
      AFollowedByB <- "a" &"b" "b";
    `;

    const rules = MetaGrammar.parseGrammar(grammar);

    let parser = new Parser({ topRuleName: 'AFollowedByB', rules, input: 'ab' });
    let parseResult = parser.parse();
    let result = parseResult.root;
    expect(result).not.toBeNull();
    expect(result.len).toBe(2); // Both 'a' and 'b' consumed

    parser = new Parser({ topRuleName: 'AFollowedByB', rules, input: 'ac' });
    parseResult = parser.parse();
    result = parseResult.root;
    expect(result instanceof SyntaxError).toBe(true);
  });

  test('negative lookahead', () => {
    const grammar = `
      ANotFollowedByB <- "a" !"b" "c";
    `;

    const rules = MetaGrammar.parseGrammar(grammar);

    let parser = new Parser({ topRuleName: 'ANotFollowedByB', rules, input: 'ac' });
    let parseResult = parser.parse();
    let result = parseResult.root;
    expect(result).not.toBeNull();
    expect(result.len).toBe(2); // Both 'a' and 'c' consumed

    parser = new Parser({ topRuleName: 'ANotFollowedByB', rules, input: 'ab' });
    parseResult = parser.parse();
    result = parseResult.root;
    expect(result instanceof SyntaxError).toBe(true);
  });

  test('any character', () => {
    const grammar = `
      AnyOne <- .;
    `;

    const rules = MetaGrammar.parseGrammar(grammar);

    let parser = new Parser({ topRuleName: 'AnyOne', rules, input: 'x' });
    let parseResult = parser.parse();
    let result = parseResult.root;
    expect(result).not.toBeNull();
    expect(result.len).toBe(1);

    parser = new Parser({ topRuleName: 'AnyOne', rules, input: '9' });
    parseResult = parser.parse();
    result = parseResult.root;
    expect(result).not.toBeNull();
    expect(result.len).toBe(1);
  });

  test('grouping with parentheses', () => {
    const grammar = `
      Group <- ("a" / "b") "c";
    `;

    const rules = MetaGrammar.parseGrammar(grammar);

    let parser = new Parser({ topRuleName: 'Group', rules, input: 'ac' });
    let parseResult = parser.parse();
    let result = parseResult.root;
    expect(result).not.toBeNull();
    expect(result.len).toBe(2);

    parser = new Parser({ topRuleName: 'Group', rules, input: 'bc' });
    parseResult = parser.parse();
    result = parseResult.root;
    expect(result).not.toBeNull();
    expect(result.len).toBe(2);
  });
});
