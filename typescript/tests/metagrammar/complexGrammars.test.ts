import { describe, expect, test } from '@jest/globals';
import { MetaGrammar } from '../../src/metaGrammar';
import { Parser } from '../../src/parser';

describe('MetaGrammar - Complex Grammars', () => {
  test('arithmetic expression grammar', () => {
    const grammar = `
      Expr <- Term ("+" Term / "-" Term)*;
      Term <- Factor ("*" Factor / "/" Factor)*;
      Factor <- Number / "(" Expr ")";
      Number <- [0-9]+;
    `;

    const rules = MetaGrammar.parseGrammar(grammar);

    let parser = new Parser(rules, '42');
    let [result, _] = parser.parse('Expr');
    expect(result).not.toBeNull();
    expect(result!.len).toBe(2);

    parser = new Parser(rules, '1+2');
    [result, _] = parser.parse('Expr');
    expect(result).not.toBeNull();
    expect(result!.len).toBe(3);

    parser = new Parser(rules, '1+2*3');
    [result, _] = parser.parse('Expr');
    expect(result).not.toBeNull();
    expect(result!.len).toBe(5);

    parser = new Parser(rules, '(1+2)*3');
    [result, _] = parser.parse('Expr');
    expect(result).not.toBeNull();
    expect(result!.len).toBe(7);
  });

  test('identifier and keyword grammar', () => {
    const grammar = `
      Ident <- !Keyword [a-zA-Z_] [a-zA-Z0-9_]*;
      Keyword <- ("if" / "while" / "for") ![a-zA-Z0-9_];
    `;

    const rules = MetaGrammar.parseGrammar(grammar);

    let parser = new Parser(rules, 'foo');
    let [result, _] = parser.parse('Ident');
    expect(result).not.toBeNull();

    // Use matchRule for negative test to avoid recovery
    parser = new Parser(rules, 'if');
    const matchResult = parser.matchRule('Ident', 0);
    expect(matchResult.isMismatch).toBe(true); // 'if' is a keyword

    parser = new Parser(rules, 'iffy');
    [result, _] = parser.parse('Ident');
    expect(result).not.toBeNull(); // 'iffy' is not a keyword
  });

  test('JSON grammar', () => {
    const grammar = String.raw`
      Value <- String / Number / Object / Array / "true" / "false" / "null";
      Object <- "{" _ (Pair (_ "," _ Pair)*)? _ "}";
      Pair <- String _ ":" _ Value;
      Array <- "[" _ (Value (_ "," _ Value)*)? _ "]";
      String <- "\"" [^"]* "\"";
      Number <- [0-9]+;
      _ <- [ \t\n\r]*;
    `;

    const rules = MetaGrammar.parseGrammar(grammar);

    let parser = new Parser(rules, '{}');
    let [result, _] = parser.parse('Object');
    expect(result).not.toBeNull();

    parser = new Parser(rules, '[]');
    [result, _] = parser.parse('Array');
    expect(result).not.toBeNull();

    parser = new Parser(rules, '"hello"');
    [result, _] = parser.parse('String');
    expect(result).not.toBeNull();

    parser = new Parser(rules, '123');
    [result, _] = parser.parse('Number');
    expect(result).not.toBeNull();
  });

  test('whitespace handling', () => {
    const grammar = String.raw`
      Main <- _ "hello" _ "world" _;
      _ <- [ \t\n\r]*;
    `;

    const rules = MetaGrammar.parseGrammar(grammar);

    let parser = new Parser(rules, 'helloworld');
    let [result, _] = parser.parse('Main');
    expect(result).not.toBeNull();

    parser = new Parser(rules, '  hello   world  ');
    [result, _] = parser.parse('Main');
    expect(result).not.toBeNull();

    parser = new Parser(rules, 'hello\n\tworld');
    [result, _] = parser.parse('Main');
    expect(result).not.toBeNull();
  });

  test('comment handling with metagrammar', () => {
    const grammar = `
      # This is a comment
      Main <- "test"; # trailing comment
      # Another comment
    `;

    const rules = MetaGrammar.parseGrammar(grammar);
    expect(rules['Main']).toBeDefined();

    const parser = new Parser(rules, 'test');
    const [result, _] = parser.parse('Main');
    expect(result).not.toBeNull();
  });
});
