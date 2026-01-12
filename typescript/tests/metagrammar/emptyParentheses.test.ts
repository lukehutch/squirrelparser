import { MetaGrammar, Parser } from '../../src/index.js';

describe('MetaGrammar - Empty Parentheses (Nothing)', () => {
  test('empty parentheses matches empty string', () => {
    const grammar = `
      Empty <- ();
    `;

    const rules = MetaGrammar.parseGrammar(grammar);
    expect(rules.has('Empty')).toBe(true);

    const parser = new Parser({ topRuleName: 'Empty', rules, input: '' });
    const parseResult = parser.parse();
    const result = parseResult.root;
    expect(result).not.toBeNull();
    expect(result.len).toBe(0);
  });

  test('empty parentheses in sequence', () => {
    const grammar = `
      AB <- "a" () "b";
    `;

    const rules = MetaGrammar.parseGrammar(grammar);
    const parser = new Parser({ topRuleName: 'AB', rules, input: 'ab' });
    const parseResult = parser.parse();
    const result = parseResult.root;
    expect(result).not.toBeNull();
    expect(result.len).toBe(2);
  });

  test('parenthesized expression with content', () => {
    const grammar = `
      Parens <- ("hello");
    `;

    const rules = MetaGrammar.parseGrammar(grammar);
    const parser = new Parser({ topRuleName: 'Parens', rules, input: 'hello' });
    const parseResult = parser.parse();
    const result = parseResult.root;
    expect(result).not.toBeNull();
    expect(result.len).toBe(5);
  });

  test('nested empty parentheses', () => {
    const grammar = `
      Nested <- (());
    `;

    const rules = MetaGrammar.parseGrammar(grammar);
    const parser = new Parser({ topRuleName: 'Nested', rules, input: '' });
    const parseResult = parser.parse();
    const result = parseResult.root;
    expect(result).not.toBeNull();
    expect(result.len).toBe(0);
  });

  test('empty parentheses with optional repetition', () => {
    const grammar = `
      Opt <- ()* "test";
    `;

    const rules = MetaGrammar.parseGrammar(grammar);
    const parser = new Parser({ topRuleName: 'Opt', rules, input: 'test' });
    const parseResult = parser.parse();
    const result = parseResult.root;
    expect(result).not.toBeNull();
    expect(result.len).toBe(4);
  });

  test('empty parentheses in choice', () => {
    const grammar = `
      Choice <- "a" / ();
    `;

    const rules = MetaGrammar.parseGrammar(grammar);

    // Should match 'a'
    const parser1 = new Parser({ topRuleName: 'Choice', rules, input: 'a' });
    const parseResult1 = parser1.parse();
    const result1 = parseResult1.root;
    expect(result1).not.toBeNull();
    expect(result1.len).toBe(1);

    // Should match empty string
    const parser2 = new Parser({ topRuleName: 'Choice', rules, input: '' });
    const parseResult2 = parser2.parse();
    const result2 = parseResult2.root;
    expect(result2).not.toBeNull();
    expect(result2.len).toBe(0);
  });

  test('rule referencing nothing', () => {
    const grammar = `
      Nothing <- ();
      A <- Nothing "a";
    `;

    const rules = MetaGrammar.parseGrammar(grammar);
    const parser = new Parser({ topRuleName: 'A', rules, input: 'a' });
    const parseResult = parser.parse();
    const result = parseResult.root;
    expect(result).not.toBeNull();
    expect(result.len).toBe(1);
  });
});
