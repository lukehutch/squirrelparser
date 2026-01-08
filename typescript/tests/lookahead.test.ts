/**
 * Lookahead Operators Tests
 */

import { describe, expect, test } from '@jest/globals';
import {
  AnyChar,
  Char as CharClass,
  CharRange,
  First,
  FollowedBy,
  NotFollowedBy,
  OneOrMore,
  Parser,
  Ref,
  Seq,
  Str,
  SyntaxError,
  ZeroOrMore,
} from '../src';

// Helper alias for compatibility with Dart tests
const Char = (ch: string) => new CharClass(ch);

// Helper to match a rule at a position (similar to Dart's matchRule)
function matchRule(parser: Parser, ruleName: string, pos: number) {
  const clause = parser.rules[ruleName];
  if (!clause) {
    throw new Error(`Rule "${ruleName}" not found`);
  }
  return parser.match(clause, pos, null);
}

describe('Lookahead Operators - Direct Matching', () => {
  describe('FollowedBy (&)', () => {
    test('positive lookahead succeeds when pattern matches', () => {
      const rules = {
        Test: new FollowedBy(new Str('a')),
      };

      const parser = new Parser(rules, 'abc');
      const result = matchRule(parser, 'Test', 0);

      expect(result.isMismatch).toBe(false);
      expect(result.len).toBe(0); // Lookahead doesn't consume
    });

    test('positive lookahead fails when pattern does not match', () => {
      const rules = {
        Test: new FollowedBy(new Str('a')),
      };

      const parser = new Parser(rules, 'b');
      const result = matchRule(parser, 'Test', 0);

      expect(result.isMismatch).toBe(true);
    });

    test('positive lookahead in sequence', () => {
      const rules = {
        Test: new Seq([new Str('a'), new FollowedBy(new Str('b'))]),
      };

      // Should match 'a' and check for 'b', consuming only 'a'
      const parser = new Parser(rules, 'abc');
      const result = matchRule(parser, 'Test', 0);

      expect(result.isMismatch).toBe(false);
      expect(result.len).toBe(1); // Only 'a' consumed
    });

    test('positive lookahead in sequence - fails when not followed', () => {
      const rules = {
        Test: new Seq([new Str('a'), new FollowedBy(new Str('b'))]),
      };

      const parser = new Parser(rules, 'ac');
      const result = matchRule(parser, 'Test', 0);

      expect(result.isMismatch).toBe(true); // Fails because no 'b' after 'a'
    });

    test('positive lookahead with continuation', () => {
      const rules = {
        Test: new Seq([new Str('a'), new FollowedBy(new Str('b')), new Str('b')]),
      };

      // Should match 'a', check for 'b', then consume 'b'
      const parser = new Parser(rules, 'abc');
      const result = matchRule(parser, 'Test', 0);

      expect(result.isMismatch).toBe(false);
      expect(result.len).toBe(2); // 'a' and 'b' consumed
    });

    test('positive lookahead at end of input', () => {
      const rules = {
        Test: new Seq([new Str('a'), new FollowedBy(new Str('b'))]),
      };

      const parser = new Parser(rules, 'a');
      const result = matchRule(parser, 'Test', 0);

      expect(result.isMismatch).toBe(true); // No 'b' to look ahead to
    });

    test('nested positive lookaheads', () => {
      const rules = {
        Test: new Seq([new FollowedBy(new FollowedBy(new Str('a'))), new Str('a')]),
      };

      const parser = new Parser(rules, 'a');
      const result = matchRule(parser, 'Test', 0);

      expect(result.isMismatch).toBe(false);
      expect(result.len).toBe(1);
    });
  });

  describe('NotFollowedBy (!)', () => {
    test('negative lookahead succeeds when pattern does not match', () => {
      const rules = {
        Test: new NotFollowedBy(new Str('a')),
      };

      const parser = new Parser(rules, 'b');
      const result = matchRule(parser, 'Test', 0);

      expect(result.isMismatch).toBe(false);
      expect(result.len).toBe(0); // Lookahead doesn't consume
    });

    test('negative lookahead fails when pattern matches', () => {
      const rules = {
        Test: new NotFollowedBy(new Str('a')),
      };

      const parser = new Parser(rules, 'a');
      const result = matchRule(parser, 'Test', 0);

      expect(result.isMismatch).toBe(true);
    });

    test('negative lookahead in sequence', () => {
      const rules = {
        Test: new Seq([new Str('a'), new NotFollowedBy(new Str('b'))]),
      };

      // Should match 'a' when NOT followed by 'b'
      const parser = new Parser(rules, 'ac');
      const result = matchRule(parser, 'Test', 0);

      expect(result.isMismatch).toBe(false);
      expect(result.len).toBe(1); // Only 'a' consumed
    });

    test('negative lookahead in sequence - fails when followed', () => {
      const rules = {
        Test: new Seq([new Str('a'), new NotFollowedBy(new Str('b'))]),
      };

      const parser = new Parser(rules, 'ab');
      const result = matchRule(parser, 'Test', 0);

      expect(result.isMismatch).toBe(true); // Fails because 'a' IS followed by 'b'
    });

    test('negative lookahead with continuation', () => {
      const rules = {
        Test: new Seq([new Str('a'), new NotFollowedBy(new Str('b')), new Str('c')]),
      };

      // Should match 'a', check NOT 'b', then consume 'c'
      const parser = new Parser(rules, 'ac');
      const result = matchRule(parser, 'Test', 0);

      expect(result.isMismatch).toBe(false);
      expect(result.len).toBe(2); // 'a' and 'c' consumed
    });

    test('negative lookahead at end of input', () => {
      const rules = {
        Test: new Seq([new Str('a'), new NotFollowedBy(new Str('b'))]),
      };

      const parser = new Parser(rules, 'a');
      const result = matchRule(parser, 'Test', 0);

      expect(result.isMismatch).toBe(false); // No 'b' following, so succeeds
      expect(result.len).toBe(1);
    });

    test('nested negative lookaheads', () => {
      const rules = {
        // !!"a" is the same as &"a"
        Test: new Seq([new NotFollowedBy(new NotFollowedBy(new Str('a'))), new Str('a')]),
      };

      const parser = new Parser(rules, 'a');
      const result = matchRule(parser, 'Test', 0);

      expect(result.isMismatch).toBe(false);
      expect(result.len).toBe(1);
    });
  });

  describe('Mixed Lookaheads', () => {
    test('positive then negative lookahead', () => {
      const rules = {
        Test: new Seq([
          new FollowedBy(new CharRange('a', 'z')),
          new NotFollowedBy(new Str('x')),
          new CharRange('a', 'z'),
        ]),
      };

      // Should match any lowercase letter except 'x'
      let parser = new Parser(rules, 'a');
      let result = matchRule(parser, 'Test', 0);
      expect(result.isMismatch).toBe(false);

      parser = new Parser(rules, 'x');
      result = matchRule(parser, 'Test', 0);
      expect(result.isMismatch).toBe(true);

      parser = new Parser(rules, 'A');
      result = matchRule(parser, 'Test', 0);
      expect(result.isMismatch).toBe(true);
    });

    test('lookahead in choice', () => {
      const rules = {
        Test: new First([
          new Seq([new FollowedBy(new Str('a')), new Str('a')]),
          new Seq([new FollowedBy(new Str('b')), new Str('b')]),
        ]),
      };

      let parser = new Parser(rules, 'a');
      let result = matchRule(parser, 'Test', 0);
      expect(result.isMismatch).toBe(false);
      expect(result.len).toBe(1);

      parser = new Parser(rules, 'b');
      result = matchRule(parser, 'Test', 0);
      expect(result.isMismatch).toBe(false);
      expect(result.len).toBe(1);

      parser = new Parser(rules, 'c');
      result = matchRule(parser, 'Test', 0);
      expect(result.isMismatch).toBe(true);
    });

    test('lookahead with repetition', () => {
      const rules = {
        Test: new ZeroOrMore(
          new Seq([new NotFollowedBy(new Str('.')), new CharRange('a', 'z')])
        ),
      };

      // Match lowercase letters until '.'
      let parser = new Parser(rules, 'abc.def');
      let result = matchRule(parser, 'Test', 0);
      expect(result.isMismatch).toBe(false);
      expect(result.len).toBe(3); // 'abc'

      parser = new Parser(rules, '.abc');
      result = matchRule(parser, 'Test', 0);
      expect(result.isMismatch).toBe(false);
      expect(result.len).toBe(0); // Stops immediately at '.'
    });
  });

  describe('Lookahead with References', () => {
    test('positive lookahead with rule reference', () => {
      const rules = {
        Digit: new CharRange('0', '9'),
        Test: new Seq([new FollowedBy(new Ref('Digit')), new Ref('Digit')]),
      };

      const parser = new Parser(rules, '5');
      const result = matchRule(parser, 'Test', 0);

      expect(result.isMismatch).toBe(false);
      expect(result.len).toBe(1);
    });

    test('negative lookahead with rule reference', () => {
      const rules = {
        Digit: new CharRange('0', '9'),
        Test: new Seq([new NotFollowedBy(new Ref('Digit')), new CharRange('a', 'z')]),
      };

      let parser = new Parser(rules, 'a');
      let result = matchRule(parser, 'Test', 0);
      expect(result.isMismatch).toBe(false);

      parser = new Parser(rules, '5');
      result = matchRule(parser, 'Test', 0);
      expect(result.isMismatch).toBe(true);
    });
  });
});

describe('Lookahead Operators - Integration with parse()', () => {
  test('lookahead with full input consumption', () => {
    const rules = {
      Test: new Seq([new Str('a'), new FollowedBy(new Str('b')), new Str('b')]),
    };

    // Should match and consume all input
    const parser = new Parser(rules, 'ab');
    const [result, _] = parser.parse('Test');

    expect(result).not.toBeNull();
    expect(result!.len).toBe(2); // Both 'a' and 'b' consumed
  });

  test('negative lookahead with full input consumption', () => {
    const rules = {
      Test: new Seq([new Str('a'), new NotFollowedBy(new Str('b')), new Str('c')]),
    };

    const parser = new Parser(rules, 'ac');
    const [result, _] = parser.parse('Test');

    expect(result).not.toBeNull();
    expect(result!.len).toBe(2); // 'a' and 'c' consumed
  });

  test('identifier parser with lookahead - valid', () => {
    // Parse identifiers that don't start with a digit
    const rules = {
      Identifier: new Seq([
        new NotFollowedBy(new CharRange('0', '9')),
        new OneOrMore(
          new First([
            new CharRange('a', 'z'),
            new CharRange('A', 'Z'),
            new CharRange('0', '9'),
            Char('_'),
          ])
        ),
      ]),
    };

    // Valid identifier (all input consumed)
    const parser = new Parser(rules, 'abc123');
    const [result, _] = parser.parse('Identifier');
    expect(result).not.toBeNull();
    expect(result!.len).toBe(6);
  });

  test('identifier parser with lookahead - using matchRule', () => {
    // Parse identifiers that don't start with a digit
    const rules = {
      Identifier: new Seq([
        new NotFollowedBy(new CharRange('0', '9')),
        new OneOrMore(
          new First([
            new CharRange('a', 'z'),
            new CharRange('A', 'Z'),
            new CharRange('0', '9'),
            Char('_'),
          ])
        ),
      ]),
    };

    // Test with matchRule to avoid recovery
    const parser = new Parser(rules, '123abc');
    const result = matchRule(parser, 'Identifier', 0);
    expect(result.isMismatch).toBe(true); // Starts with digit, should fail
  });

  test('keyword vs identifier with lookahead', () => {
    // Parse 'if' only when not followed by alphanumeric (i.e., as keyword)
    const rules = {
      Keyword: new Seq([
        new Str('if'),
        new NotFollowedBy(
          new First([
            new CharRange('a', 'z'),
            new CharRange('A', 'Z'),
            new CharRange('0', '9'),
            Char('_'),
          ])
        ),
      ]),
    };

    // Valid keyword (all input consumed)
    let parser = new Parser(rules, 'if');
    let [result, _] = parser.parse('Keyword');
    expect(result).not.toBeNull(); // 'if' as keyword
    expect(result!.len).toBe(2);

    // Invalid - 'ifx' is not just 'if'
    parser = new Parser(rules, 'ifx');
    [result, _] = parser.parse('Keyword');
    expect(result instanceof SyntaxError).toBe(true); // Would need to consume all 'ifx', but can't
  });

  test('comment parser with lookahead', () => {
    // Parse // style comments until end of line
    const rules = {
      Comment: new Seq([
        new Str('//'),
        new ZeroOrMore(new Seq([new NotFollowedBy(Char('\n')), new AnyChar()])),
        Char('\n'),
      ]),
    };

    const parser = new Parser(rules, '//hello world\n');
    const [result, _] = parser.parse('Comment');
    expect(result).not.toBeNull();
    expect(result!.len).toBe(14); // All input consumed
  });

  test('string literal parser with lookahead', () => {
    // Parse string literals with escape sequences
    const rules = {
      String: new Seq([
        Char('"'),
        new ZeroOrMore(
          new First([
            new Seq([new Str('\\'), new AnyChar()]), // Escape sequence
            new Seq([new NotFollowedBy(Char('"')), new AnyChar()]), // Non-quote char
          ])
        ),
        Char('"'),
      ]),
    };

    let parser = new Parser(rules, '"hello"');
    let [result, _] = parser.parse('String');
    expect(result).not.toBeNull();

    parser = new Parser(rules, '"hello\\"world"');
    [result, _] = parser.parse('String');
    expect(result).not.toBeNull();
  });
});
