/**
 * SECTION 13: LEFT RECURSION ERROR RECOVERY
 */

import { describe, expect, test } from '@jest/globals';
import { First, Parser, Ref, Seq, Str } from '../src';
import { parse } from './testUtils';

describe('Left Recursion Error Recovery', () => {
  // directLR grammar for error recovery tests
  const directLR = {
    S: new Ref('E'),
    E: new First([new Seq([new Ref('E'), new Str('+n')]), new Str('n')]),
  };

  // precedenceLR grammar for error recovery tests
  const precedenceLR = {
    S: new Ref('E'),
    E: new First([
      new Seq([new Ref('E'), new Str('+'), new Ref('T')]),
      new Seq([new Ref('E'), new Str('-'), new Ref('T')]),
      new Ref('T'),
    ]),
    T: new First([
      new Seq([new Ref('T'), new Str('*'), new Ref('F')]),
      new Seq([new Ref('T'), new Str('/'), new Ref('F')]),
      new Ref('F'),
    ]),
    F: new First([new Seq([new Str('('), new Ref('E'), new Str(')')]), new Str('n')]),
  };

  // Error recovery in direct LR grammar
  test('LR-Recovery-01-leading-error', () => {
    // Input '+n+n+n+' starts with '+' which is invalid (need 'n' first)
    // and ends with '+' which is also invalid (need 'n' after)
    const [ok, _err, __] = parse(directLR, '+n+n+n+');
    // This should fail because we can't recover a valid parse
    // The leading '+' prevents any initial 'n' match
    expect(ok).toBe(false);
  });

  test('LR-Recovery-02-internal-error', () => {
    // Input 'n+Xn+n' has garbage 'X' between + and n
    // '+n' is a 2-char terminal, so 'n+X' doesn't match '+n'
    // Grammar can only match 'n' at start, rest is captured as error
    const [ok, err, _skip] = parse(directLR, 'n+Xn+n');
    expect(ok).toBe(true);
    expect(err).toBe(1);
  });

  test('LR-Recovery-03-trailing-junk', () => {
    // Input 'n+n+nXXX' has trailing garbage
    const [ok, err, _] = parse(directLR, 'n+n+nXXX');
    // After parsing 'n+n+n', there's trailing 'XXX' that is captured as error
    expect(ok).toBe(true);
    expect(err).toBe(1);
  });

  // Error recovery in precedence grammar
  test('LR-Recovery-04-missing-operand', () => {
    // Input 'n+*n' has missing operand between + and *
    // Parser recovers by skipping the extra '+' to parse as 'n*n'
    const [ok, err, skip] = parse(precedenceLR, 'n+*n');
    expect(ok).toBe(true);
    expect(err).toBe(1);
    expect(skip).toEqual(['+']);
  });

  test('LR-Recovery-05-double-op', () => {
    // Input 'n++n' has double operator
    // Parser recovers by skipping the extra '+' to parse as 'n+n'
    const [ok, err, skip] = parse(precedenceLR, 'n++n');
    expect(ok).toBe(true);
    expect(err).toBe(1);
    expect(skip).toEqual(['+']);
  });

  test('LR-Recovery-06-unclosed-paren', () => {
    // Input '(n+n' has unclosed paren
    const parser = new Parser(precedenceLR, '(n+n');
    const [result, _] = parser.parse('S');
    // With recovery, should insert missing ')'
    expect(result !== null && !result.isMismatch).toBe(true);
  });

  test('LR-Recovery-07-extra-close-paren', () => {
    // Input 'n+n)' has extra close paren
    const [ok, err, _] = parse(precedenceLR, 'n+n)');
    // Should succeed with trailing ) captured as error
    expect(ok).toBe(true);
    expect(err).toBe(1);
  });

  describe('Ref LR Masking Tests', () => {
    // F1-LR-05 case: T -> T*F | F. Input "n+n*Xn".
    // Error is at 'X'.
    // Optimal recovery: T matches "n", * matches "*", F fails on "X". F recovery skips "X" -> "n". Total 1 error.
    // Suboptimal (current): T fails. E matches "n+n". E recursion fails. E recovery skips "*X". Total 2 errors.

    const grammar = {
      E: new First([new Seq([new Ref('E'), new Str('+'), new Ref('T')]), new Ref('T')]),
      T: new First([new Seq([new Ref('T'), new Str('*'), new Ref('F')]), new Ref('F')]),
      F: new First([new Seq([new Str('('), new Ref('E'), new Str(')')]), new Str('n')]),
    };

    test('MASK-01-error-at-T-level-after-star', () => {
      // Current behavior: 2 errors (recovery at E level).
      // Optimal behavior (future goal): 1 error (recovery at F level).
      // This is a known limitation: Ref can mask deeper recovery opportunities.
      // The test expects current behavior, not optimal.
      const [ok, err, skip] = parse(grammar, 'n+n*Xn', 'E');
      expect(ok).toBe(true);
      expect(err).toBe(2);
      expect(skip.some(s => s.includes('*') || s.includes('X'))).toBe(true);
    });
  });
});
