import { squirrelParsePT } from '../src/squirrelParse.js';
import { SyntaxError } from '../src/matchResult.js';

describe('Lookahead Operators - Direct Matching', () => {
  describe('FollowedBy (&)', () => {
    test('positive lookahead succeeds when pattern matches', () => {
      const result = squirrelParsePT({
        grammarSpec: 'Test <- &"a" ;',
        topRuleName: 'Test',
        input: 'abc',
      });
      expect(result.root.isMismatch).toBe(false);
      expect(result.root.len).toBe(0); // Lookahead doesn't consume
    });

    test('positive lookahead fails when pattern does not match', () => {
      const result = squirrelParsePT({
        grammarSpec: 'Test <- &"a" ;',
        topRuleName: 'Test',
        input: 'b',
      });
      expect(result.root instanceof SyntaxError).toBe(true);
    });

    test('positive lookahead in sequence', () => {
      const result = squirrelParsePT({
        grammarSpec: 'Test <- "a" &"b" ;',
        topRuleName: 'Test',
        input: 'abc',
      });
      expect(result.root.isMismatch).toBe(false);
      expect(result.root.len).toBe(1); // Only 'a' consumed
    });

    test('positive lookahead in sequence - fails when not followed', () => {
      const result = squirrelParsePT({
        grammarSpec: 'Test <- "a" &"b" ;',
        topRuleName: 'Test',
        input: 'ac',
      });
      expect(result.root instanceof SyntaxError).toBe(true); // Fails because no 'b' after 'a'
    });

    test('positive lookahead with continuation', () => {
      const result = squirrelParsePT({
        grammarSpec: 'Test <- "a" &"b" "b" ;',
        topRuleName: 'Test',
        input: 'abc',
      });
      expect(result.root.isMismatch).toBe(false);
      expect(result.root.len).toBe(2); // 'a' and 'b' consumed
    });

    test('positive lookahead at end of input', () => {
      const result = squirrelParsePT({
        grammarSpec: 'Test <- "a" &"b" ;',
        topRuleName: 'Test',
        input: 'a',
      });
      // With error recovery, this succeeds but has syntax errors
      expect(result.hasSyntaxErrors).toBe(true); // No 'b' to look ahead to
    });

    test('nested positive lookaheads', () => {
      const result = squirrelParsePT({
        grammarSpec: 'Test <- &&"a" "a" ;',
        topRuleName: 'Test',
        input: 'a',
      });
      expect(result.root.isMismatch).toBe(false);
      expect(result.root.len).toBe(1);
    });
  });

  describe('NotFollowedBy (!)', () => {
    test('negative lookahead succeeds when pattern does not match', () => {
      const result = squirrelParsePT({
        grammarSpec: 'Test <- !"a" ;',
        topRuleName: 'Test',
        input: 'b',
      });
      expect(result.root.isMismatch).toBe(false);
      expect(result.root.len).toBe(0); // Lookahead doesn't consume
    });

    test('negative lookahead fails when pattern matches', () => {
      const result = squirrelParsePT({
        grammarSpec: 'Test <- !"a" ;',
        topRuleName: 'Test',
        input: 'a',
      });
      expect(result.root instanceof SyntaxError).toBe(true);
    });

    test('negative lookahead in sequence', () => {
      const result = squirrelParsePT({
        grammarSpec: 'Test <- "a" !"b" ;',
        topRuleName: 'Test',
        input: 'ac',
      });
      expect(result.root.isMismatch).toBe(false);
      expect(result.root.len).toBe(1); // Only 'a' consumed
    });

    test('negative lookahead in sequence - fails when followed', () => {
      const result = squirrelParsePT({
        grammarSpec: 'Test <- "a" !"b" ;',
        topRuleName: 'Test',
        input: 'ab',
      });
      expect(result.root instanceof SyntaxError).toBe(true); // Fails because 'a' IS followed by 'b'
    });

    test('negative lookahead with continuation', () => {
      const result = squirrelParsePT({
        grammarSpec: 'Test <- "a" !"b" "c" ;',
        topRuleName: 'Test',
        input: 'ac',
      });
      expect(result.root.isMismatch).toBe(false);
      expect(result.root.len).toBe(2); // 'a' and 'c' consumed
    });

    test('negative lookahead at end of input', () => {
      const result = squirrelParsePT({
        grammarSpec: 'Test <- "a" !"b" ;',
        topRuleName: 'Test',
        input: 'a',
      });
      expect(result.root.isMismatch).toBe(false); // No 'b' following, so succeeds
      expect(result.root.len).toBe(1);
    });

    test('nested negative lookaheads', () => {
      // !!"a" is the same as &"a"
      const result = squirrelParsePT({
        grammarSpec: 'Test <- !!"a" "a" ;',
        topRuleName: 'Test',
        input: 'a',
      });
      expect(result.root.isMismatch).toBe(false);
      expect(result.root.len).toBe(1);
    });
  });

  describe('Mixed Lookaheads', () => {
    test('positive then negative lookahead', () => {
      const grammar = 'Test <- &[a-z] !"x" [a-z] ;';

      // Should match any lowercase letter except 'x'
      let result = squirrelParsePT({
        grammarSpec: grammar,
        topRuleName: 'Test',
        input: 'a',
      });
      expect(result.root.isMismatch).toBe(false);

      result = squirrelParsePT({
        grammarSpec: grammar,
        topRuleName: 'Test',
        input: 'x',
      });
      expect(result.root instanceof SyntaxError).toBe(true);

      result = squirrelParsePT({
        grammarSpec: grammar,
        topRuleName: 'Test',
        input: 'A',
      });
      expect(result.root instanceof SyntaxError).toBe(true);
    });

    test('lookahead in choice', () => {
      const grammar = 'Test <- &"a" "a" / &"b" "b" ;';

      let result = squirrelParsePT({
        grammarSpec: grammar,
        topRuleName: 'Test',
        input: 'a',
      });
      expect(result.root.isMismatch).toBe(false);
      expect(result.root.len).toBe(1);

      result = squirrelParsePT({
        grammarSpec: grammar,
        topRuleName: 'Test',
        input: 'b',
      });
      expect(result.root.isMismatch).toBe(false);
      expect(result.root.len).toBe(1);

      result = squirrelParsePT({
        grammarSpec: grammar,
        topRuleName: 'Test',
        input: 'c',
      });
      expect(result.root instanceof SyntaxError).toBe(true);
    });

    test('lookahead with repetition', () => {
      const grammar = 'Test <- (!"." [a-z])* ;';

      // Match lowercase letters until '.', then parser has unmatched input
      let result = squirrelParsePT({
        grammarSpec: grammar,
        topRuleName: 'Test',
        input: 'abc.def',
      });
      expect(result.root.isMismatch).toBe(false);
      // The grammar itself only matches 'abc', but error recovery captures trailing '.def'
      expect(result.hasSyntaxErrors).toBe(true);

      result = squirrelParsePT({
        grammarSpec: grammar,
        topRuleName: 'Test',
        input: '.abc',
      });
      expect(result.root.isMismatch).toBe(false);
      // With error recovery, unmatched '.abc' is captured as syntax error
      expect(result.hasSyntaxErrors).toBe(true);
    });
  });

  describe('Lookahead with References', () => {
    test('positive lookahead with rule reference', () => {
      const result = squirrelParsePT({
        grammarSpec: `
          Test <- &Digit Digit ;
          Digit <- [0-9] ;
        `,
        topRuleName: 'Test',
        input: '5',
      });
      expect(result.root.isMismatch).toBe(false);
      expect(result.root.len).toBe(1);
    });

    test('negative lookahead with rule reference', () => {
      const grammar = `
        Test <- !Digit [a-z] ;
        Digit <- [0-9] ;
      `;

      let result = squirrelParsePT({
        grammarSpec: grammar,
        topRuleName: 'Test',
        input: 'a',
      });
      expect(result.root.isMismatch).toBe(false);

      result = squirrelParsePT({
        grammarSpec: grammar,
        topRuleName: 'Test',
        input: '5',
      });
      expect(result.root instanceof SyntaxError).toBe(true);
    });
  });
});

describe('Lookahead Operators - Integration with parse()', () => {
  test('lookahead with full input consumption', () => {
    const result = squirrelParsePT({
      grammarSpec: 'Test <- "a" &"b" "b" ;',
      topRuleName: 'Test',
      input: 'ab',
    });
    expect(result.root).not.toBeNull();
    expect(result.root.len).toBe(2); // Both 'a' and 'b' consumed
  });

  test('negative lookahead with full input consumption', () => {
    const result = squirrelParsePT({
      grammarSpec: 'Test <- "a" !"b" "c" ;',
      topRuleName: 'Test',
      input: 'ac',
    });
    expect(result.root).not.toBeNull();
    expect(result.root.len).toBe(2); // 'a' and 'c' consumed
  });

  test('identifier parser with lookahead - valid', () => {
    // Parse identifiers that don't start with a digit
    const result = squirrelParsePT({
      grammarSpec: 'Identifier <- ![0-9] [a-zA-Z0-9_]+ ;',
      topRuleName: 'Identifier',
      input: 'abc123',
    });
    expect(result.root).not.toBeNull();
    expect(result.root.len).toBe(6);
  });

  test('identifier parser with lookahead - invalid starts with digit', () => {
    // Parse identifiers that don't start with a digit
    const result = squirrelParsePT({
      grammarSpec: 'Identifier <- ![0-9] [a-zA-Z0-9_]+ ;',
      topRuleName: 'Identifier',
      input: '123abc',
    });
    // With error recovery, this may recover by skipping digits, so check for errors
    expect(result.hasSyntaxErrors).toBe(true); // Starts with digit, should have errors
  });

  test('keyword vs identifier with lookahead', () => {
    // Parse 'if' only when not followed by alphanumeric (i.e., as keyword)
    const grammar = 'Keyword <- "if" ![a-zA-Z0-9_] ;';

    // Valid keyword (all input consumed)
    let result = squirrelParsePT({
      grammarSpec: grammar,
      topRuleName: 'Keyword',
      input: 'if',
    });
    expect(result.root).not.toBeNull(); // 'if' as keyword
    expect(result.root.len).toBe(2);

    // Invalid - 'ifx' is not just 'if'
    result = squirrelParsePT({
      grammarSpec: grammar,
      topRuleName: 'Keyword',
      input: 'ifx',
    });
    // Total failure: result is SyntaxError spanning entire input
    expect(result.root instanceof SyntaxError).toBe(true);
  });

  test('comment parser with lookahead', () => {
    // Parse // style comments until end of line
    const result = squirrelParsePT({
      grammarSpec: `Comment <- "//" (!'\\n' .)* '\\n' ;`,
      topRuleName: 'Comment',
      input: '//hello world\n',
    });
    expect(result.root).not.toBeNull();
    expect(result.root.len).toBe(14); // All input consumed
  });

  test('string literal parser with lookahead', () => {
    // Parse string literals with escape sequences
    const grammar = `String <- '"' ("\\\\" . / !'"' .)* '"' ;`;

    let result = squirrelParsePT({
      grammarSpec: grammar,
      topRuleName: 'String',
      input: '"hello"',
    });
    expect(result.root).not.toBeNull();

    result = squirrelParsePT({
      grammarSpec: grammar,
      topRuleName: 'String',
      input: '"hello\\"world"',
    });
    expect(result.root).not.toBeNull();
  });
});
