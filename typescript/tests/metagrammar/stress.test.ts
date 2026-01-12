import { MetaGrammar, Parser, buildAST } from '../../src/index.js';

describe('MetaGrammar - Stress Tests', () => {
  test('deeply nested parentheses', () => {
    // Test parser can handle deeply nested groupings
    const grammar = `
      Rule <- ((((("a")))));
    `;

    const rules = MetaGrammar.parseGrammar(grammar);
    const parser = new Parser({ topRuleName: 'Rule', rules, input: 'a' });
    const parseResult = parser.parse();
    const result = parseResult.root;
    expect(result).not.toBeNull();
    expect(result.len).toBe(1);
  });

  test('many choice alternatives', () => {
    // Stress test with 20 alternatives
    const grammar = `
      Rule <- "a" / "b" / "c" / "d" / "e" / "f" / "g" / "h" / "i" / "j" /
              "k" / "l" / "m" / "n" / "o" / "p" / "q" / "r" / "s" / "t" ;
    `;

    const rules = MetaGrammar.parseGrammar(grammar);

    // Test first alternative
    let parser = new Parser({ topRuleName: 'Rule', rules, input: 'a' });
    let parseResult = parser.parse();
    let result = parseResult.root;
    expect(result).not.toBeNull();

    // Test middle alternative
    parser = new Parser({ topRuleName: 'Rule', rules, input: 'j' });
    parseResult = parser.parse();
    result = parseResult.root;
    expect(result).not.toBeNull();

    // Test last alternative
    parser = new Parser({ topRuleName: 'Rule', rules, input: 't' });
    parseResult = parser.parse();
    result = parseResult.root;
    expect(result).not.toBeNull();
  });

  test('deeply nested choices and sequences', () => {
    // Complex nesting: (a (b / c) d (e / f / g))
    const grammar = `
      Rule <- "a" ("b" / "c") "d" ("e" / "f" / "g");
    `;

    const rules = MetaGrammar.parseGrammar(grammar);

    let parser = new Parser({ topRuleName: 'Rule', rules, input: 'abde' });
    let parseResult = parser.parse();
    let result = parseResult.root;
    expect(result).not.toBeNull();

    parser = new Parser({ topRuleName: 'Rule', rules, input: 'acdg' });
    parseResult = parser.parse();
    result = parseResult.root;
    expect(result).not.toBeNull();

    parser = new Parser({ topRuleName: 'Rule', rules, input: 'acdf' });
    parseResult = parser.parse();
    result = parseResult.root;
    expect(result).not.toBeNull();
  });

  test('long sequence', () => {
    // Test a very long sequence
    const grammar = `
      Rule <- "a" "b" "c" "d" "e" "f" "g" "h" "i" "j"
              "k" "l" "m" "n" "o" "p" "q" "r" "s" "t";
    `;

    const rules = MetaGrammar.parseGrammar(grammar);
    const parser = new Parser({ topRuleName: 'Rule', rules, input: 'abcdefghijklmnopqrst' });
    const parseResult = parser.parse();
    const result = parseResult.root;
    expect(result).not.toBeNull();
    expect(result.len).toBe(20);
  });

  test('stacked repetition operators', () => {
    // Test multiple suffix operators: (a+)?*
    // This is a bit pathological but should parse
    const grammar = `
      Rule <- ("a"+)?;
    `;

    const rules = MetaGrammar.parseGrammar(grammar);

    // Empty input (optional matches)
    let parser = new Parser({ topRuleName: 'Rule', rules, input: '' });
    let parseResult = parser.parse();
    let result = parseResult.root;
    expect(result).not.toBeNull();

    // One 'a'
    parser = new Parser({ topRuleName: 'Rule', rules, input: 'a' });
    parseResult = parser.parse();
    result = parseResult.root;
    expect(result).not.toBeNull();

    // Multiple 'a's
    parser = new Parser({ topRuleName: 'Rule', rules, input: 'aaa' });
    parseResult = parser.parse();
    result = parseResult.root;
    expect(result).not.toBeNull();
  });

  test('complex lookahead combinations', () => {
    // Test &!&! pattern
    const grammar = `
      Rule <- &![0-9] [a-z]+ ;
    `;

    const rules = MetaGrammar.parseGrammar(grammar);

    // Should match letters not preceded by digits
    let parser = new Parser({ topRuleName: 'Rule', rules, input: 'hello' });
    const parseResult = parser.parse();
    const result = parseResult.root;
    expect(result).not.toBeNull();

    // Should fail on digit start
    parser = new Parser({ topRuleName: 'Rule', rules, input: '5hello' });
    const matchResult = parser.matchRule('Rule', 0);
    expect(matchResult.isMismatch).toBe(true);
  });

  test('character class edge cases', () => {
    // Test character classes with many ranges
    const grammar = `
      Rule <- [a-zA-Z0-9_-.@]+ ;
    `;

    const rules = MetaGrammar.parseGrammar(grammar);

    const parser = new Parser({ topRuleName: 'Rule', rules, input: 'Test_123-name.email@' });
    const parseResult = parser.parse();
    const result = parseResult.root;
    expect(result).not.toBeNull();
  });

  test('negated character class with multiple ranges', () => {
    // Everything except digits and whitespace
    const grammar = String.raw`
      Rule <- [^0-9 \t\n\r]+ ;
    `;

    const rules = MetaGrammar.parseGrammar(grammar);

    let parser = new Parser({ topRuleName: 'Rule', rules, input: 'hello' });
    const parseResult = parser.parse();
    const result = parseResult.root;
    expect(result).not.toBeNull();

    // Should stop at first digit
    parser = new Parser({ topRuleName: 'Rule', rules, input: 'test123' });
    const matchResult = parser.matchRule('Rule', 0);
    expect(matchResult.len).toBe(4); // Matches 'test'
  });

  test('multiple transparent rules interacting', () => {
    const grammar = String.raw`
      ~Space <- " " ;
      ~Tab <- "\t" ;
      ~WS <- (Space / Tab)+ ;
      Main <- WS "hello" WS "world" WS ;
    `;

    const rules = MetaGrammar.parseGrammar(grammar);
    const parser = new Parser({ topRuleName: 'Main', rules, input: '  \thello\t  world \t' });
    const parseResult = parser.parse();
    const ast = buildAST(parseResult);

    expect(ast).not.toBeNull();
    // Should have 2 children: "hello" and "world" (WS nodes are transparent)
    expect(ast.children.length).toBe(2);
  });

  test('deeply nested rule references', () => {
    const grammar = `
      A <- B ;
      B <- C ;
      C <- D ;
      D <- E ;
      E <- "x" ;
    `;

    const rules = MetaGrammar.parseGrammar(grammar);
    const parser = new Parser({ topRuleName: 'A', rules, input: 'x' });
    const parseResult = parser.parse();
    const result = parseResult.root;
    expect(result).not.toBeNull();
  });

  test('complex escape sequences', () => {
    // Test escape sequences: newline, tab, quotes
    const grammar = String.raw`
      Rule <- "line1\n\tquote\"test" ;
    `;

    const rules = MetaGrammar.parseGrammar(grammar);
    const parser = new Parser({ topRuleName: 'Rule', rules, input: 'line1\n\tquote"test' });
    const parseResult = parser.parse();
    const result = parseResult.root;
    expect(result).not.toBeNull();
    expect(result.len).toBe(17);
  });

  test('comments in various positions', () => {
    const grammar = `
      # Leading comment
      Rule <- # inline comment
              "a" # after token
              "b" # another
              ; # end comment
      # Trailing comment
    `;

    const rules = MetaGrammar.parseGrammar(grammar);
    const parser = new Parser({ topRuleName: 'Rule', rules, input: 'ab' });
    const parseResult = parser.parse();
    const result = parseResult.root;
    expect(result).not.toBeNull();
  });

  test('mutual recursion between rules', () => {
    const grammar = `
      A <- "a" B / "a" ;
      B <- "b" A / "b" ;
    `;

    const rules = MetaGrammar.parseGrammar(grammar);

    // Just 'a'
    let parser = new Parser({ topRuleName: 'A', rules, input: 'a' });
    let parseResult = parser.parse();
    let result = parseResult.root;
    expect(result).not.toBeNull();

    // 'aba'
    parser = new Parser({ topRuleName: 'A', rules, input: 'aba' });
    parseResult = parser.parse();
    result = parseResult.root;
    expect(result).not.toBeNull();

    // 'ababa'
    parser = new Parser({ topRuleName: 'A', rules, input: 'ababa' });
    parseResult = parser.parse();
    result = parseResult.root;
    expect(result).not.toBeNull();
  });

  test('complex lookahead in repetition', () => {
    // Match characters until we see "end"
    const grammar = `
      Rule <- (!"end" .)* "end" ;
    `;

    const rules = MetaGrammar.parseGrammar(grammar);
    const parser = new Parser({ topRuleName: 'Rule', rules, input: 'hello world end' });
    const parseResult = parser.parse();
    const result = parseResult.root;
    expect(result).not.toBeNull();
    expect(result.len).toBe(15); // "hello world end"
  });

  test('optional with lookahead', () => {
    // Optional digit followed by letter, but only if not followed by digit
    const grammar = `
      Rule <- ([0-9] ![0-9])? [a-z]+ ;
    `;

    const rules = MetaGrammar.parseGrammar(grammar);

    // Just letters
    let parser = new Parser({ topRuleName: 'Rule', rules, input: 'hello' });
    let parseResult = parser.parse();
    let result = parseResult.root;
    expect(result).not.toBeNull();

    // Digit then letters
    parser = new Parser({ topRuleName: 'Rule', rules, input: '5hello' });
    parseResult = parser.parse();
    result = parseResult.root;
    expect(result).not.toBeNull();
  });

  test('zero-or-more with complex content', () => {
    // Pairs of letters and digits, zero or more times
    const grammar = `
      Rule <- ([a-z] [0-9])* ;
    `;

    const rules = MetaGrammar.parseGrammar(grammar);

    // Empty
    let parser = new Parser({ topRuleName: 'Rule', rules, input: '' });
    let parseResult = parser.parse();
    let result = parseResult.root;
    expect(result).not.toBeNull();

    // One pair
    parser = new Parser({ topRuleName: 'Rule', rules, input: 'a5' });
    parseResult = parser.parse();
    result = parseResult.root;
    expect(result).not.toBeNull();

    // Multiple pairs
    parser = new Parser({ topRuleName: 'Rule', rules, input: 'a5b3c7' });
    parseResult = parser.parse();
    result = parseResult.root;
    expect(result).not.toBeNull();
  });

  test('choice with lookahead conditions', () => {
    // Match different patterns based on lookahead
    const grammar = `
      Rule <- &[a-z] Lowercase / &[A-Z] Uppercase / Digit ;
      Lowercase <- [a-z]+ ;
      Uppercase <- [A-Z]+ ;
      Digit <- [0-9]+ ;
    `;

    const rules = MetaGrammar.parseGrammar(grammar);

    let parser = new Parser({ topRuleName: 'Rule', rules, input: 'hello' });
    let parseResult = parser.parse();
    let result = parseResult.root;
    expect(result).not.toBeNull();

    parser = new Parser({ topRuleName: 'Rule', rules, input: 'WORLD' });
    parseResult = parser.parse();
    result = parseResult.root;
    expect(result).not.toBeNull();

    parser = new Parser({ topRuleName: 'Rule', rules, input: '123' });
    parseResult = parser.parse();
    result = parseResult.root;
    expect(result).not.toBeNull();
  });

  test('nested optional and repetition', () => {
    // Optional groups with repetition inside
    const grammar = `
      Rule <- ("a"+ "b"?)* ;
    `;

    const rules = MetaGrammar.parseGrammar(grammar);

    let parser = new Parser({ topRuleName: 'Rule', rules, input: '' });
    let parseResult = parser.parse();
    let result = parseResult.root;
    expect(result).not.toBeNull();

    parser = new Parser({ topRuleName: 'Rule', rules, input: 'abaab' });
    parseResult = parser.parse();
    result = parseResult.root;
    expect(result).not.toBeNull();

    parser = new Parser({ topRuleName: 'Rule', rules, input: 'aaabaaaa' });
    parseResult = parser.parse();
    result = parseResult.root;
    expect(result).not.toBeNull();
  });

  test('any char with repetition and bounds', () => {
    // Exactly 5 characters
    const grammar = `
      Rule <- . . . . . ;
    `;

    const rules = MetaGrammar.parseGrammar(grammar);
    const parser = new Parser({ topRuleName: 'Rule', rules, input: 'hello' });
    const parseResult = parser.parse();
    const result = parseResult.root;
    expect(result).not.toBeNull();
    expect(result.len).toBe(5);
  });

  test('complex sequence with all operator types', () => {
    // Combine all operators in one rule
    const grammar = `
      Rule <- &[a-z] [a-z]+ ![0-9] ("_" [a-z]+)* ([0-9]+)? ;
    `;

    const rules = MetaGrammar.parseGrammar(grammar);

    // Basic identifier
    let parser = new Parser({ topRuleName: 'Rule', rules, input: 'hello' });
    let parseResult = parser.parse();
    let result = parseResult.root;
    expect(result).not.toBeNull();

    // With underscores
    parser = new Parser({ topRuleName: 'Rule', rules, input: 'hello_world_test' });
    parseResult = parser.parse();
    result = parseResult.root;
    expect(result).not.toBeNull();

    // With trailing digits
    parser = new Parser({ topRuleName: 'Rule', rules, input: 'test_var123' });
    parseResult = parser.parse();
    result = parseResult.root;
    expect(result).not.toBeNull();
  });

  test('pathological backtracking case', () => {
    // A pattern that could cause excessive backtracking in naive parsers
    const grammar = `
      Rule <- "a"* "a"* "a"* "a"* "b" ;
    `;

    const rules = MetaGrammar.parseGrammar(grammar);
    const parser = new Parser({ topRuleName: 'Rule', rules, input: 'aaaaab' });
    const parseResult = parser.parse();
    const result = parseResult.root;
    expect(result).not.toBeNull();
    expect(result.len).toBe(6);
  });

  test('rule with mixed transparent and non-transparent references', () => {
    const grammar = `
      Main <- A ~B C ;
      A <- "a" ;
      ~B <- "b" ;
      C <- "c" ;
    `;

    const rules = MetaGrammar.parseGrammar(grammar);
    const parser = new Parser({ topRuleName: 'Main', rules, input: 'abc' });
    const parseResult = parser.parse();
    const ast = buildAST(parseResult);

    expect(ast).not.toBeNull();
    expect(ast.label).toBe('Main');
    // Transparent rules (marked with ~) should not appear in the AST
    // So only A and C should be present, not B
    expect(ast.children.length).toBe(2);
    expect(ast.children[0].label).toBe('A');
    expect(ast.children[1].label).toBe('C');
  });

  test('character class with special characters', () => {
    // Test characters including dot, underscore, hyphen
    const grammar = `
      Rule <- [a-z.@_]+ ;
    `;

    const rules = MetaGrammar.parseGrammar(grammar);
    const parser = new Parser({ topRuleName: 'Rule', rules, input: 'test.name_value@' });
    const parseResult = parser.parse();
    const result = parseResult.root;
    expect(result).not.toBeNull();
  });

  test('very long rule name', () => {
    const grammar = `
      ThisIsAVeryLongRuleNameToTestThatLongIdentifiersWork <- "test" ;
    `;

    const rules = MetaGrammar.parseGrammar(grammar);
    expect(rules.has('ThisIsAVeryLongRuleNameToTestThatLongIdentifiersWork')).toBe(true);
  });

  test('multiple consecutive lookaheads', () => {
    // Multiple positive lookaheads in sequence
    const grammar = `
      Rule <- &[a-z] &[a-c] "a" ;
    `;

    const rules = MetaGrammar.parseGrammar(grammar);

    let parser = new Parser({ topRuleName: 'Rule', rules, input: 'a' });
    const parseResult = parser.parse();
    const result = parseResult.root;
    expect(result).not.toBeNull();

    // Should fail for 'd' (doesn't match second lookahead)
    parser = new Parser({ topRuleName: 'Rule', rules, input: 'd' });
    const matchResult = parser.matchRule('Rule', 0);
    expect(matchResult.isMismatch).toBe(true);
  });

  test('choice with potentially empty matches', () => {
    // Test choice where alternatives can match varying lengths
    const grammar = `
      Rule <- "a"+ / "b"+ / "" ;
    `;

    const rules = MetaGrammar.parseGrammar(grammar);

    // 'aaa' matches first alternative
    let parser = new Parser({ topRuleName: 'Rule', rules, input: 'aaa' });
    let parseResult = parser.parse();
    let result = parseResult.root;
    expect(result).not.toBeNull();

    // 'bbb' matches second alternative
    parser = new Parser({ topRuleName: 'Rule', rules, input: 'bbb' });
    parseResult = parser.parse();
    result = parseResult.root;
    expect(result).not.toBeNull();

    // Empty input matches third alternative
    parser = new Parser({ topRuleName: 'Rule', rules, input: '' });
    const matchResult = parser.matchRule('Rule', 0);
    expect(matchResult.isMismatch).toBe(false);
    expect(matchResult.len).toBe(0);
  });

  test('negated lookahead with alternatives', () => {
    // Not followed by keyword
    const grammar = `
      Rule <- !(Keyword ![a-z]) [a-z]+ ;
      Keyword <- "if" / "while" / "for" ;
    `;

    const rules = MetaGrammar.parseGrammar(grammar);

    // Regular identifier works
    let parser = new Parser({ topRuleName: 'Rule', rules, input: 'hello' });
    let parseResult = parser.parse();
    let result = parseResult.root;
    expect(result).not.toBeNull();

    // Keyword prefix works (iffy)
    parser = new Parser({ topRuleName: 'Rule', rules, input: 'iffy' });
    parseResult = parser.parse();
    result = parseResult.root;
    expect(result).not.toBeNull();

    // Pure keyword should fail
    parser = new Parser({ topRuleName: 'Rule', rules, input: 'if' });
    const matchResult = parser.matchRule('Rule', 0);
    expect(matchResult.isMismatch).toBe(true);
  });

  test('repetition of grouped alternation', () => {
    // Repeat a choice multiple times
    const grammar = `
      Rule <- ("a" / "b" / "c")+ ;
    `;

    const rules = MetaGrammar.parseGrammar(grammar);
    const parser = new Parser({ topRuleName: 'Rule', rules, input: 'abccbaabccc' });
    const parseResult = parser.parse();
    const result = parseResult.root;
    expect(result).not.toBeNull();
    expect(result.len).toBe(11);
  });
});
