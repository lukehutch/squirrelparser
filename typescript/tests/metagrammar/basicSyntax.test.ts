import { describe, expect, test } from '@jest/globals';
import { MetaGrammar } from '../../src/metaGrammar';
import { Parser, SyntaxError } from '../../src';

describe('MetaGrammar - Basic Syntax', () => {
  test('simple rule with string literal', () => {
    const grammar = `
      Hello <- "hello";
    `;

    const rules = MetaGrammar.parseGrammar(grammar);
    expect(rules['Hello']).toBeDefined();

    const parser = new Parser(rules, 'hello');
    const [result, _] = parser.parse('Hello');
    expect(result).not.toBeNull();
    expect(result!.len).toBe(5);
  });

  test('rule with character literal', () => {
    const grammar = `
      A <- 'a';
    `;

    const rules = MetaGrammar.parseGrammar(grammar);
    const parser = new Parser(rules, 'a');
    const [result, _] = parser.parse('A');
    expect(result).not.toBeNull();
    expect(result!.len).toBe(1);
  });

  test('sequence of literals', () => {
    const grammar = `
      AB <- "a" "b";
    `;

    const rules = MetaGrammar.parseGrammar(grammar);
    const parser = new Parser(rules, 'ab');
    const [result, _] = parser.parse('AB');
    expect(result).not.toBeNull();
    expect(result!.len).toBe(2);
  });

  test('choice between alternatives', () => {
    const grammar = `
      AorB <- "a" / "b";
    `;

    const rules = MetaGrammar.parseGrammar(grammar);

    let parser = new Parser(rules, 'a');
    let [result, _] = parser.parse('AorB');
    expect(result).not.toBeNull();
    expect(result!.len).toBe(1);

    parser = new Parser(rules, 'b');
    [result, _] = parser.parse('AorB');
    expect(result).not.toBeNull();
    expect(result!.len).toBe(1);
  });

  test('zero or more repetition', () => {
    const grammar = `
      As <- "a"*;
    `;

    const rules = MetaGrammar.parseGrammar(grammar);

    let parser = new Parser(rules, '');
    let [result, _] = parser.parse('As');
    expect(result).not.toBeNull();
    expect(result!.len).toBe(0);

    parser = new Parser(rules, 'aaa');
    [result, _] = parser.parse('As');
    expect(result).not.toBeNull();
    expect(result!.len).toBe(3);
  });

  test('one or more repetition', () => {
    const grammar = `
      As <- "a"+;
    `;

    const rules = MetaGrammar.parseGrammar(grammar);

    let parser = new Parser(rules, '');
    let [result, _] = parser.parse('As');
    expect(result instanceof SyntaxError).toBe(true);

    parser = new Parser(rules, 'aaa');
    [result, _] = parser.parse('As');
    expect(result).not.toBeNull();
    expect(result!.len).toBe(3);
  });

  test('optional', () => {
    const grammar = `
      OptA <- "a"?;
    `;

    const rules = MetaGrammar.parseGrammar(grammar);

    let parser = new Parser(rules, '');
    let [result, _] = parser.parse('OptA');
    expect(result).not.toBeNull();
    expect(result!.len).toBe(0);

    parser = new Parser(rules, 'a');
    [result, _] = parser.parse('OptA');
    expect(result).not.toBeNull();
    expect(result!.len).toBe(1);
  });

  test('positive lookahead', () => {
    const grammar = `
      AFollowedByB <- "a" &"b" "b";
    `;

    const rules = MetaGrammar.parseGrammar(grammar);

    let parser = new Parser(rules, 'ab');
    let [result, _] = parser.parse('AFollowedByB');
    expect(result).not.toBeNull();
    expect(result!.len).toBe(2); // Both 'a' and 'b' consumed

    parser = new Parser(rules, 'ac');
    [result, _] = parser.parse('AFollowedByB');
    expect(result instanceof SyntaxError).toBe(true);
  });

  test('negative lookahead', () => {
    const grammar = `
      ANotFollowedByB <- "a" !"b" "c";
    `;

    const rules = MetaGrammar.parseGrammar(grammar);

    let parser = new Parser(rules, 'ac');
    let [result, _] = parser.parse('ANotFollowedByB');
    expect(result).not.toBeNull();
    expect(result!.len).toBe(2); // Both 'a' and 'c' consumed

    parser = new Parser(rules, 'ab');
    [result, _] = parser.parse('ANotFollowedByB');
    expect(result instanceof SyntaxError).toBe(true);
  });

  test('any character', () => {
    const grammar = `
      AnyOne <- .;
    `;

    const rules = MetaGrammar.parseGrammar(grammar);

    let parser = new Parser(rules, 'x');
    let [result, _] = parser.parse('AnyOne');
    expect(result).not.toBeNull();
    expect(result!.len).toBe(1);

    parser = new Parser(rules, '9');
    [result, _] = parser.parse('AnyOne');
    expect(result).not.toBeNull();
    expect(result!.len).toBe(1);
  });

  test('grouping with parentheses', () => {
    const grammar = `
      Group <- ("a" / "b") "c";
    `;

    const rules = MetaGrammar.parseGrammar(grammar);

    let parser = new Parser(rules, 'ac');
    let [result, _] = parser.parse('Group');
    expect(result).not.toBeNull();
    expect(result!.len).toBe(2);

    parser = new Parser(rules, 'bc');
    [result, _] = parser.parse('Group');
    expect(result).not.toBeNull();
    expect(result!.len).toBe(2);
  });
});
