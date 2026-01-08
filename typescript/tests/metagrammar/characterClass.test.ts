import { describe, expect, test } from '@jest/globals';
import { MetaGrammar } from '../../src/metaGrammar';
import { Parser, SyntaxError } from '../../src';

describe('MetaGrammar - Character Classes', () => {
  test('simple character range', () => {
    const grammar = `
      Digit <- [0-9];
    `;

    const rules = MetaGrammar.parseGrammar(grammar);

    let parser = new Parser(rules, '5');
    let [result, _] = parser.parse('Digit');
    expect(result instanceof SyntaxError).toBe(false);
    expect(result!.len).toBe(1);

    parser = new Parser(rules, 'a');
    [result, _] = parser.parse('Digit');
    expect(result instanceof SyntaxError).toBe(true);
  });

  test('multiple character ranges', () => {
    const grammar = `
      AlphaNum <- [a-zA-Z0-9];
    `;

    const rules = MetaGrammar.parseGrammar(grammar);

    let parser = new Parser(rules, 'a');
    let [result, _] = parser.parse('AlphaNum');
    expect(result instanceof SyntaxError).toBe(false);

    parser = new Parser(rules, 'Z');
    [result, _] = parser.parse('AlphaNum');
    expect(result instanceof SyntaxError).toBe(false);

    parser = new Parser(rules, '5');
    [result, _] = parser.parse('AlphaNum');
    expect(result instanceof SyntaxError).toBe(false);

    parser = new Parser(rules, '!');
    [result, _] = parser.parse('AlphaNum');
    expect(result instanceof SyntaxError).toBe(true);
  });

  test('character class with individual characters', () => {
    const grammar = `
      Vowel <- [aeiou];
    `;

    const rules = MetaGrammar.parseGrammar(grammar);

    let parser = new Parser(rules, 'a');
    let [result, _] = parser.parse('Vowel');
    expect(result instanceof SyntaxError).toBe(false);

    parser = new Parser(rules, 'e');
    [result, _] = parser.parse('Vowel');
    expect(result instanceof SyntaxError).toBe(false);

    parser = new Parser(rules, 'b');
    [result, _] = parser.parse('Vowel');
    expect(result instanceof SyntaxError).toBe(true);
  });

  test('negated character class', () => {
    const grammar = `
      NotDigit <- [^0-9];
    `;

    const rules = MetaGrammar.parseGrammar(grammar);

    let parser = new Parser(rules, 'a');
    let [result, _] = parser.parse('NotDigit');
    expect(result instanceof SyntaxError).toBe(false);

    parser = new Parser(rules, '5');
    [result, _] = parser.parse('NotDigit');
    expect(result instanceof SyntaxError).toBe(true);
  });

  test('escaped characters in character class', () => {
    const grammar = String.raw`
      Special <- [\t\n];
    `;

    const rules = MetaGrammar.parseGrammar(grammar);

    let parser = new Parser(rules, '\t');
    let [result, _] = parser.parse('Special');
    expect(result instanceof SyntaxError).toBe(false);

    parser = new Parser(rules, '\n');
    [result, _] = parser.parse('Special');
    expect(result instanceof SyntaxError).toBe(false);

    parser = new Parser(rules, ' ');
    [result, _] = parser.parse('Special');
    expect(result instanceof SyntaxError).toBe(true);
  });
});
