// ===========================================================================
// VISIBILITY CONSTRAINT TESTS (FIX #8 Verification)
// ===========================================================================
// These tests verify that parse trees match visible input structure and that
// grammar deletion (inserting missing elements) only occurs at EOF.

import { testParse, countDeletions } from './testUtils.js';
import { squirrelParsePT } from '../src/squirrelParse.js';
import { SyntaxError } from '../src/matchResult.js';

describe('Visibility Constraint Tests', () => {
  test('VIS-01-terminal-atomicity', () => {
    // Multi-char terminals are atomic - can't skip through them
    const parseResult = squirrelParsePT({
      grammarSpec: 'S <- "abc" "def" ;',
      topRuleName: 'S',
      input: 'abXdef',
    });
    const result = parseResult.root;
    // Should fail - can't match 'abc' with 'abX', and can't skip 'X' mid-terminal
    // Total failure: result is a SyntaxError spanning entire input
    expect(result instanceof SyntaxError).toBe(true);
  });

  test('VIS-02-grammar-deletion-at-eof', () => {
    // Grammar deletion (completion) allowed at EOF
    const { ok } = testParse('S <- "a" "b" "c" ;', 'ab');
    expect(ok).toBe(true);

    const parseResult = squirrelParsePT({
      grammarSpec: 'S <- "a" "b" "c" ;',
      topRuleName: 'S',
      input: 'ab',
    });
    expect(countDeletions([parseResult.root])).toBe(1);
  });

  test('VIS-03-grammar-deletion-mid-parse-forbidden', () => {
    // Grammar deletion NOT allowed mid-parse (FIX #8)
    const parseResult = squirrelParsePT({
      grammarSpec: 'S <- "a" "b" "c" ;',
      topRuleName: 'S',
      input: 'ac',
    });
    const result = parseResult.root;
    // Should fail - cannot delete 'b' at position 1 (not EOF)
    // Total failure: result is a SyntaxError spanning entire input
    expect(result instanceof SyntaxError).toBe(true);
  });

  test('VIS-04-tree-structure-matches-visible-input', () => {
    // Parse tree structure should match visible input structure
    const { ok, errorCount, skippedStrings } = testParse('S <- "a" "b" "c" ;', 'aXbc');
    expect(ok).toBe(true);
    expect(errorCount).toBe(1);
    expect(skippedStrings).toContain('X');
    // Visible input: a, X, b, c (4 elements)
    // Tree: a, SyntaxError(X), b, c (4 nodes)
  });

  test('VIS-05-hidden-deletion-creates-mismatch', () => {
    // First tries alternatives; Seq needs 'b' but input is just 'a'
    const parseResult = squirrelParsePT({
      grammarSpec: 'S <- "a" "b" / "c" ;',
      topRuleName: 'S',
      input: 'a',
    });
    const result = parseResult.root;
    // First alternative: Try Seq - 'a' matches, 'b' missing at EOF
    //   - Could delete 'b' at EOF, but that gives len=1
    // Second alternative: Try 'c' - fails (input is 'a')
    // Should pick first alternative with completion
    // Result always spans input, so check it's not a total failure
    expect(result instanceof SyntaxError).toBe(false);
    // With new invariant, result.len == input.length always
    expect(result.len).toBe(1);
  });

  test('VIS-06-multiple-consecutive-skips', () => {
    // Multiple consecutive errors should be merged into one region
    const { ok, errorCount, skippedStrings } = testParse('S <- "a" "b" "c" ;', 'aXXXXbc');
    expect(ok).toBe(true);
    expect(errorCount).toBe(1);
    expect(skippedStrings).toContain('XXXX');
  });

  test('VIS-07-alternating-content-and-errors', () => {
    // Pattern: valid, error, valid, error, valid, error, valid
    const { ok, errorCount, skippedStrings } = testParse('S <- "a" "b" "c" "d" ;', 'aXbYcZd');
    expect(ok).toBe(true);
    expect(errorCount).toBe(3);
    expect(skippedStrings).toContain('X');
    expect(skippedStrings).toContain('Y');
    expect(skippedStrings).toContain('Z');
    // Tree: [a, SyntaxError(X), b, SyntaxError(Y), c, SyntaxError(Z), d]
  });

  test('VIS-08-completion-vs-correction', () => {
    // Completion (EOF): "user hasn't finished typing" - allowed
    const comp = testParse('S <- "if" "(" "x" ")" ;', 'if(x');
    expect(comp.ok).toBe(true);

    // Correction (mid-parse): "user typed wrong thing" - NOT allowed via grammar deletion
    const corrResult = squirrelParsePT({
      grammarSpec: 'S <- "if" "(" "x" ")" ;',
      topRuleName: 'S',
      input: 'if()',
    });
    // Would need to delete 'x' at position 3, but ')' remains - not EOF
    const result = corrResult.root;
    // Total failure: result is a SyntaxError spanning entire input
    expect(result instanceof SyntaxError).toBe(true);
  });

  test('VIS-09-structural-integrity', () => {
    // Tree must reflect what user sees, not what we wish they typed
    const { ok } = testParse('S <- "(" "E" ")" ;', 'E)');
    // User sees: E, )
    // Should NOT reinterpret as: (, E, ) by "inserting" ( at start
    // Should fail - cannot delete '(' mid-parse
    expect(ok).toBe(false);
  });

  test('VIS-10-visibility-with-nested-structures', () => {
    // Nested Seq - errors at each level should preserve visibility
    const { ok, errorCount, skippedStrings } = testParse('S <- ("a" "b") "c" ;', 'aXbc');
    expect(ok).toBe(true);
    expect(errorCount).toBe(1);
    expect(skippedStrings).toContain('X');
  });
});
