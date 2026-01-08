import { describe, expect, test } from '@jest/globals';
import { MetaGrammar } from '../../src/metaGrammar';
import { Parser } from '../../src/parser';

describe('MetaGrammar - Escape Sequences', () => {
  test('newline escape', () => {
    const grammar = String.raw`
      Newline <- "\n";
    `;

    const rules = MetaGrammar.parseGrammar(grammar);
    const parser = new Parser(rules, '\n');
    const [result, _] = parser.parse('Newline');
    expect(result).not.toBeNull();
    expect(result!.len).toBe(1);
  });

  test('tab escape', () => {
    const grammar = String.raw`
      Tab <- "\t";
    `;

    const rules = MetaGrammar.parseGrammar(grammar);
    const parser = new Parser(rules, '\t');
    const [result, _] = parser.parse('Tab');
    expect(result).not.toBeNull();
    expect(result!.len).toBe(1);
  });

  test('backslash escape', () => {
    const grammar = String.raw`
      Backslash <- "\\";
    `;

    const rules = MetaGrammar.parseGrammar(grammar);
    const parser = new Parser(rules, '\\');
    const [result, _] = parser.parse('Backslash');
    expect(result).not.toBeNull();
    expect(result!.len).toBe(1);
  });

  test('quote escapes', () => {
    const grammar = String.raw`
      DoubleQuote <- "\"";
      SingleQuote <- '\'';
    `;

    const rules = MetaGrammar.parseGrammar(grammar);

    let parser = new Parser(rules, '"');
    let [result, _] = parser.parse('DoubleQuote');
    expect(result).not.toBeNull();

    parser = new Parser(rules, "'");
    [result, _] = parser.parse('SingleQuote');
    expect(result).not.toBeNull();
  });

  test('escaped sequence in string', () => {
    const grammar = String.raw`
      Message <- "Hello\nWorld";
    `;

    const rules = MetaGrammar.parseGrammar(grammar);
    const parser = new Parser(rules, 'Hello\nWorld');
    const [result, _] = parser.parse('Message');
    expect(result).not.toBeNull();
    expect(result!.len).toBe(11);
  });
});
