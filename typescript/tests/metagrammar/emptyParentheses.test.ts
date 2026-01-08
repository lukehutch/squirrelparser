import { describe, expect, test } from '@jest/globals';
import { MetaGrammar } from '../../src/metaGrammar';
import { Parser } from '../../src';

describe('MetaGrammar - Empty Parentheses (Nothing)', () => {
  test('empty parentheses matches empty string', () => {
    const grammar = `
      Empty <- ();
    `;

    const rules = MetaGrammar.parseGrammar(grammar);
    expect(rules['Empty']).toBeDefined();

    const parser = new Parser(rules, '');
    const [result, _] = parser.parse('Empty');
    expect(result).not.toBeNull();
    expect(result!.len).toBe(0);
  });

  test('empty parentheses in sequence', () => {
    const grammar = `
      AB <- "a" () "b";
    `;

    const rules = MetaGrammar.parseGrammar(grammar);
    const parser = new Parser(rules, 'ab');
    const [result, _] = parser.parse('AB');
    expect(result).not.toBeNull();
    expect(result!.len).toBe(2);
  });

  test('parenthesized expression with content', () => {
    const grammar = `
      Parens <- ("hello");
    `;

    const rules = MetaGrammar.parseGrammar(grammar);
    const parser = new Parser(rules, 'hello');
    const [result, _] = parser.parse('Parens');
    expect(result).not.toBeNull();
    expect(result!.len).toBe(5);
  });

  test('nested empty parentheses', () => {
    const grammar = `
      Nested <- (());
    `;

    const rules = MetaGrammar.parseGrammar(grammar);
    const parser = new Parser(rules, '');
    const [result, _] = parser.parse('Nested');
    expect(result).not.toBeNull();
    expect(result!.len).toBe(0);
  });

  test('empty parentheses with optional repetition', () => {
    const grammar = `
      Opt <- ()* "test";
    `;

    const rules = MetaGrammar.parseGrammar(grammar);
    const parser = new Parser(rules, 'test');
    const [result, _] = parser.parse('Opt');
    expect(result).not.toBeNull();
    expect(result!.len).toBe(4);
  });

  test('empty parentheses in choice', () => {
    const grammar = `
      Choice <- "a" / ();
    `;

    const rules = MetaGrammar.parseGrammar(grammar);

    // Should match 'a'
    const parser1 = new Parser(rules, 'a');
    const [result1, _] = parser1.parse('Choice');
    expect(result1).not.toBeNull();
    expect(result1!.len).toBe(1);

    // Should match empty string
    const parser2 = new Parser(rules, '');
    const [result2, __] = parser2.parse('Choice');
    expect(result2).not.toBeNull();
    expect(result2!.len).toBe(0);
  });

  test('rule referencing nothing', () => {
    const grammar = `
      Nothing <- ();
      A <- Nothing "a";
    `;

    const rules = MetaGrammar.parseGrammar(grammar);
    const parser = new Parser(rules, 'a');
    const [result, _] = parser.parse('A');
    expect(result).not.toBeNull();
    expect(result!.len).toBe(1);
  });
});
