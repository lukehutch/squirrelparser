import { describe, expect, test } from '@jest/globals';
import { MetaGrammar } from '../../src/metaGrammar';
import { Parser } from '../../src/parser';

describe('MetaGrammar - Rule References', () => {
  test('simple rule reference', () => {
    const grammar = `
      Main <- A "b";
      A <- "a";
    `;

    const rules = MetaGrammar.parseGrammar(grammar);
    const parser = new Parser(rules, 'ab');
    const [result, _] = parser.parse('Main');
    expect(result).not.toBeNull();
    expect(result!.len).toBe(2);
  });

  test('multiple rule references', () => {
    const grammar = `
      Main <- A B C;
      A <- "a";
      B <- "b";
      C <- "c";
    `;

    const rules = MetaGrammar.parseGrammar(grammar);
    const parser = new Parser(rules, 'abc');
    const [result, _] = parser.parse('Main');
    expect(result).not.toBeNull();
    expect(result!.len).toBe(3);
  });

  test('recursive rule', () => {
    const grammar = `
      List <- "a" List / "a";
    `;

    const rules = MetaGrammar.parseGrammar(grammar);

    let parser = new Parser(rules, 'a');
    let [result, _] = parser.parse('List');
    expect(result).not.toBeNull();
    expect(result!.len).toBe(1);

    parser = new Parser(rules, 'aaa');
    [result, _] = parser.parse('List');
    expect(result).not.toBeNull();
    expect(result!.len).toBe(3);
  });

  test('mutually recursive rules', () => {
    const grammar = `
      A <- "a" B / "a";
      B <- "b" A / "b";
    `;

    const rules = MetaGrammar.parseGrammar(grammar);

    let parser = new Parser(rules, 'aba');
    let [result, _] = parser.parse('A');
    expect(result).not.toBeNull();
    expect(result!.len).toBe(3);

    parser = new Parser(rules, 'bab');
    [result, _] = parser.parse('B');
    expect(result).not.toBeNull();
    expect(result!.len).toBe(3);
  });

  test('left-recursive rule', () => {
    const grammar = `
      Expr <- Expr "+" "n" / "n";
    `;

    const rules = MetaGrammar.parseGrammar(grammar);

    let parser = new Parser(rules, 'n');
    let [result, _] = parser.parse('Expr');
    expect(result).not.toBeNull();
    expect(result!.len).toBe(1);

    parser = new Parser(rules, 'n+n');
    [result, _] = parser.parse('Expr');
    expect(result).not.toBeNull();
    expect(result!.len).toBe(3);

    parser = new Parser(rules, 'n+n+n');
    [result, _] = parser.parse('Expr');
    expect(result).not.toBeNull();
    expect(result!.len).toBe(5);
  });
});
