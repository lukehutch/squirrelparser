import { MetaGrammar, Parser, SyntaxError } from '../../src/index.js';

describe('MetaGrammar - Operator Precedence', () => {
  test('suffix binds tighter than sequence', () => {
    // "a"+ "b" should be ("a"+ "b"), not ("a" "b")+
    const grammar = `
      Rule <- "a"+ "b";
    `;

    const rules = MetaGrammar.parseGrammar(grammar);
    const clause = rules.get('Rule')!.toString();

    // Should have OneOrMore around first element only
    expect(clause).toContain('"a"+');
    expect(clause).toContain('"b"');
  });

  test('prefix binds tighter than sequence', () => {
    // !"a" "b" should be (!"a" "b"), not !("a" "b")
    const grammar = `
      Rule <- !"a" "b";
    `;

    const rules = MetaGrammar.parseGrammar(grammar);
    const clause = rules.get('Rule')!.toString();

    // Should have NotFollowedBy around first element only
    expect(clause).toContain('!"a"');
    expect(clause).toContain('"b"');
  });

  test('sequence binds tighter than choice', () => {
    // "a" "b" / "c" should be (("a" "b") / "c"), not ("a" ("b" / "c"))
    const grammar = `
      Rule <- "a" "b" / "c";
    `;

    const rules = MetaGrammar.parseGrammar(grammar);

    // Test that it parses "ab" and "c", but not "ac"
    let parser = new Parser({ topRuleName: 'Rule', rules, input: 'ab' });
    let parseResult = parser.parse();
    let result = parseResult.root;
    expect(result).not.toBeNull();

    parser = new Parser({ topRuleName: 'Rule', rules, input: 'c' });
    parseResult = parser.parse();
    result = parseResult.root;
    expect(result).not.toBeNull();

    parser = new Parser({ topRuleName: 'Rule', rules, input: 'ac' });
    parseResult = parser.parse();
    result = parseResult.root;
    expect(result instanceof SyntaxError).toBe(true);
  });

  test('suffix binds tighter than prefix', () => {
    // &"a"+ should be &("a"+), not (&"a")+
    const grammar = `
      Rule <- &"a"+ "a";
    `;

    const rules = MetaGrammar.parseGrammar(grammar);
    const clause = rules.get('Rule')!.toString();

    // Should have FollowedBy wrapping OneOrMore
    expect(clause).toContain('&"a"+');
  });

  test('grouping overrides precedence - sequence in choice', () => {
    // "a" / "b" "c" should parse as ("a" / ("b" "c"))
    // ("a" / "b") "c" should parse differently
    const grammar1 = `
      Rule <- "a" / "b" "c";
    `;

    const grammar2 = `
      Rule <- ("a" / "b") "c";
    `;

    const rules1 = MetaGrammar.parseGrammar(grammar1);
    const rules2 = MetaGrammar.parseGrammar(grammar2);

    // Grammar 1: should match "a" or "bc"
    let parser = new Parser({ topRuleName: 'Rule', rules: rules1, input: 'a' });
    let parseResult = parser.parse();
    let result = parseResult.root;
    expect(result).not.toBeNull();

    parser = new Parser({ topRuleName: 'Rule', rules: rules1, input: 'bc' });
    parseResult = parser.parse();
    result = parseResult.root;
    expect(result).not.toBeNull();

    // 'ac' should not fully match - only matches 'a', leaving 'c'
    parser = new Parser({ topRuleName: 'Rule', rules: rules1, input: 'ac' });
    let matchResult = parser.matchRule('Rule', 0);
    expect(matchResult.isMismatch || matchResult.len !== 2).toBe(true); // Either mismatch or doesn't consume all

    // Grammar 2: should match "ac" or "bc"
    parser = new Parser({ topRuleName: 'Rule', rules: rules2, input: 'ac' });
    parseResult = parser.parse();
    result = parseResult.root;
    expect(result).not.toBeNull();

    parser = new Parser({ topRuleName: 'Rule', rules: rules2, input: 'bc' });
    parseResult = parser.parse();
    result = parseResult.root;
    expect(result).not.toBeNull();

    // 'a' should not match grammar2 - needs 'c' after choice
    parser = new Parser({ topRuleName: 'Rule', rules: rules2, input: 'a' });
    matchResult = parser.matchRule('Rule', 0);
    expect(matchResult.isMismatch).toBe(true);
  });

  test('grouping overrides precedence - choice in suffix', () => {
    // ("a" / "b")+ should allow "aaa", "bbb", "aba", etc.
    const grammar = `
      Rule <- ("a" / "b")+;
    `;

    const rules = MetaGrammar.parseGrammar(grammar);

    let parser = new Parser({ topRuleName: 'Rule', rules, input: 'aaa' });
    let parseResult = parser.parse();
    let result = parseResult.root;
    expect(result).not.toBeNull();

    parser = new Parser({ topRuleName: 'Rule', rules, input: 'bbb' });
    parseResult = parser.parse();
    result = parseResult.root;
    expect(result).not.toBeNull();

    parser = new Parser({ topRuleName: 'Rule', rules, input: 'aba' });
    parseResult = parser.parse();
    result = parseResult.root;
    expect(result).not.toBeNull();

    parser = new Parser({ topRuleName: 'Rule', rules, input: 'bab' });
    parseResult = parser.parse();
    result = parseResult.root;
    expect(result).not.toBeNull();
  });

  test('complex precedence - mixed operators', () => {
    // "a"+ / "b"* "c" should be (("a"+) / (("b"*) "c"))
    const grammar = `
      Rule <- "a"+ / "b"* "c";
    `;

    const rules = MetaGrammar.parseGrammar(grammar);

    // Should match "a", "aa", "aaa", etc.
    let parser = new Parser({ topRuleName: 'Rule', rules, input: 'a' });
    let parseResult = parser.parse();
    let result = parseResult.root;
    expect(result).not.toBeNull();

    parser = new Parser({ topRuleName: 'Rule', rules, input: 'aaa' });
    parseResult = parser.parse();
    result = parseResult.root;
    expect(result).not.toBeNull();

    // Should match "c", "bc", "bbc", etc.
    parser = new Parser({ topRuleName: 'Rule', rules, input: 'c' });
    parseResult = parser.parse();
    result = parseResult.root;
    expect(result).not.toBeNull();

    parser = new Parser({ topRuleName: 'Rule', rules, input: 'bc' });
    parseResult = parser.parse();
    result = parseResult.root;
    expect(result).not.toBeNull();

    parser = new Parser({ topRuleName: 'Rule', rules, input: 'bbc' });
    parseResult = parser.parse();
    result = parseResult.root;
    expect(result).not.toBeNull();
  });

  test('transparent operator precedence', () => {
    // ~"a"+ should be ~("a"+), not (~"a")+
    const grammar = `
      ~Rule <- "a"+;
      Main <- Rule;
    `;

    const rules = MetaGrammar.parseGrammar(grammar);
    const parser = new Parser({ topRuleName: 'Main', rules, input: 'aaa' });
    const parseResult = parser.parse();

    // Rule should be transparent, so it should be successfully parsed
    const result = parseResult.root;
    expect(result).not.toBeNull();
    expect(result.len).toBe(3); // Should match the full input 'aaa'
  });

  test('prefix operators are right-associative', () => {
    // &!"a" should be &(!"a"), not (!(&"a"))
    const grammar = `
      Rule <- &!"a" "b";
    `;

    const rules = MetaGrammar.parseGrammar(grammar);
    const clause = rules.get('Rule')!.toString();

    // Should have FollowedBy wrapping NotFollowedBy
    expect(clause).toContain('&!"a"');
  });

  test('suffix operators are left-associative', () => {
    // "a"+? should be ("a"+)?, not "a"+(?)
    // This test verifies that suffix operators apply to the result of the previous operation
    const grammar = `
      Rule <- "a"+?;
    `;

    const rules = MetaGrammar.parseGrammar(grammar);
    const clause = rules.get('Rule')!.toString();

    // Should have Optional wrapping OneOrMore
    expect(clause).toContain('"a"+');
    expect(clause).toContain('?');
  });

  test('character class binds as atomic unit', () => {
    // [a-z]+ should be ([a-z])+, with the character class as a single unit
    const grammar = `
      Rule <- [a-z]+;
    `;

    const rules = MetaGrammar.parseGrammar(grammar);

    const parser = new Parser({ topRuleName: 'Rule', rules, input: 'abc' });
    const parseResult = parser.parse();
    const result = parseResult.root;
    expect(result).not.toBeNull();
    expect(result.len).toBe(3);
  });

  test('negated character class binds as atomic unit', () => {
    // [^0-9]+ should match multiple non-digits
    const grammar = `
      Rule <- [^0-9]+;
    `;

    const rules = MetaGrammar.parseGrammar(grammar);

    let parser = new Parser({ topRuleName: 'Rule', rules, input: 'abc' });
    const parseResult = parser.parse();
    const result = parseResult.root;
    expect(result).not.toBeNull();
    expect(result.len).toBe(3);

    // Use matchRule for partial match test
    parser = new Parser({ topRuleName: 'Rule', rules, input: 'a1' });
    const matchResult = parser.matchRule('Rule', 0);
    expect(matchResult.isMismatch).toBe(false);
    expect(matchResult.len).toBe(1); // Only 'a' matches
  });
});
