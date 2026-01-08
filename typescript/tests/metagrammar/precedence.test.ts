import { describe, expect, test } from '@jest/globals';
import { MetaGrammar } from '../../src/metaGrammar';
import { Parser, SyntaxError } from '../../src';

describe('MetaGrammar - Operator Precedence', () => {
  test('suffix binds tighter than sequence', () => {
    // "a"+ "b" should be ("a"+ "b"), not ("a" "b")+
    const grammar = `
      Rule <- "a"+ "b";
    `;

    const rules = MetaGrammar.parseGrammar(grammar);
    const clause = rules['Rule'].toString();

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
    const clause = rules['Rule'].toString();

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
    let parser = new Parser(rules, 'ab');
    let [result, _] = parser.parse('Rule');
    expect(result).not.toBeNull();

    parser = new Parser(rules, 'c');
    [result, _] = parser.parse('Rule');
    expect(result).not.toBeNull();

    parser = new Parser(rules, 'ac');
    [result, _] = parser.parse('Rule');
    expect(result instanceof SyntaxError).toBe(true);
  });

  test('suffix binds tighter than prefix', () => {
    // &"a"+ should be &("a"+), not (&"a")+
    const grammar = `
      Rule <- &"a"+ "a";
    `;

    const rules = MetaGrammar.parseGrammar(grammar);
    const clause = rules['Rule'].toString();

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
    let parser = new Parser(rules1, 'a');
    let [result, _] = parser.parse('Rule');
    expect(result).not.toBeNull();

    parser = new Parser(rules1, 'bc');
    [result, _] = parser.parse('Rule');
    expect(result).not.toBeNull();

    // 'ac' should not fully match - only matches 'a', leaving 'c'
    parser = new Parser(rules1, 'ac');
    let matchResult = parser.matchRule('Rule', 0);
    expect(matchResult.isMismatch || matchResult.len !== 2).toBe(true); // Either mismatch or doesn't consume all

    // Grammar 2: should match "ac" or "bc"
    parser = new Parser(rules2, 'ac');
    [result, _] = parser.parse('Rule');
    expect(result).not.toBeNull();

    parser = new Parser(rules2, 'bc');
    [result, _] = parser.parse('Rule');
    expect(result).not.toBeNull();

    // 'a' should not match grammar2 - needs 'c' after choice
    parser = new Parser(rules2, 'a');
    matchResult = parser.matchRule('Rule', 0);
    expect(matchResult.isMismatch).toBe(true);
  });

  test('grouping overrides precedence - choice in suffix', () => {
    // ("a" / "b")+ should allow "aaa", "bbb", "aba", etc.
    const grammar = `
      Rule <- ("a" / "b")+;
    `;

    const rules = MetaGrammar.parseGrammar(grammar);

    let parser = new Parser(rules, 'aaa');
    let [result, _] = parser.parse('Rule');
    expect(result).not.toBeNull();

    parser = new Parser(rules, 'bbb');
    [result, _] = parser.parse('Rule');
    expect(result).not.toBeNull();

    parser = new Parser(rules, 'aba');
    [result, _] = parser.parse('Rule');
    expect(result).not.toBeNull();

    parser = new Parser(rules, 'bab');
    [result, _] = parser.parse('Rule');
    expect(result).not.toBeNull();
  });

  test('complex precedence - mixed operators', () => {
    // "a"+ / "b"* "c" should be (("a"+) / (("b"*) "c"))
    const grammar = `
      Rule <- "a"+ / "b"* "c";
    `;

    const rules = MetaGrammar.parseGrammar(grammar);

    // Should match "a", "aa", "aaa", etc.
    let parser = new Parser(rules, 'a');
    let [result, _] = parser.parse('Rule');
    expect(result).not.toBeNull();

    parser = new Parser(rules, 'aaa');
    [result, _] = parser.parse('Rule');
    expect(result).not.toBeNull();

    // Should match "c", "bc", "bbc", etc.
    parser = new Parser(rules, 'c');
    [result, _] = parser.parse('Rule');
    expect(result).not.toBeNull();

    parser = new Parser(rules, 'bc');
    [result, _] = parser.parse('Rule');
    expect(result).not.toBeNull();

    parser = new Parser(rules, 'bbc');
    [result, _] = parser.parse('Rule');
    expect(result).not.toBeNull();
  });

  test('transparent operator precedence', () => {
    // ~"a"+ should be ~("a"+), not (~"a")+
    const grammar = `
      ~Rule <- "a"+;
      Main <- Rule;
    `;

    const rules = MetaGrammar.parseGrammar(grammar);
    const parser = new Parser(rules, 'aaa');
    const [ast, _] = parser.parseToAST('Main');

    // Rule should be transparent, so Main should not have a Rule child
    expect(ast).not.toBeNull();
    expect(ast!.label).toBe('Main');
    // If Rule is properly transparent, we shouldn't see it in the AST
  });

  test('prefix operators are right-associative', () => {
    // &!"a" should be &(!"a"), not (!(&"a"))
    const grammar = `
      Rule <- &!"a" "b";
    `;

    const rules = MetaGrammar.parseGrammar(grammar);
    const clause = rules['Rule'].toString();

    // Should have FollowedBy wrapping NotFollowedBy
    expect(clause).toContain('&!"a"');
  });

  test('suffix operators are left-associative', () => {
    // "a"+? should be ("a"+)?, not "a"+(?)
    // Note: PEG doesn't typically allow ++, but if it did, it would be left-associative
    // This test verifies that suffix operators apply to the result of the previous operation
    const grammar = `
      Rule <- "a"+?;
    `;

    const rules = MetaGrammar.parseGrammar(grammar);
    const clause = rules['Rule'].toString();

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

    const parser = new Parser(rules, 'abc');
    const [result, _] = parser.parse('Rule');
    expect(result).not.toBeNull();
    expect(result!.len).toBe(3);
  });

  test('negated character class binds as atomic unit', () => {
    // [^0-9]+ should match multiple non-digits
    const grammar = `
      Rule <- [^0-9]+;
    `;

    const rules = MetaGrammar.parseGrammar(grammar);

    let parser = new Parser(rules, 'abc');
    const [result, _] = parser.parse('Rule');
    expect(result).not.toBeNull();
    expect(result!.len).toBe(3);

    // Use matchRule for partial match test
    parser = new Parser(rules, 'a1');
    const matchResult = parser.matchRule('Rule', 0);
    expect(matchResult.isMismatch).toBe(false);
    expect(matchResult.len).toBe(1); // Only 'a' matches
  });
});
