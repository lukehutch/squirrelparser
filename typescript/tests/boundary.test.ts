// ===========================================================================
// SECTION 1: EMPTY AND BOUNDARY CONDITIONS (27 tests)
// ===========================================================================

import { testParse, countDeletions } from './testUtils.js';
import { squirrelParsePT } from '../src/squirrelParse.js';

describe('Empty and Boundary Conditions', () => {
  test('E01-ZeroOrMore empty', () => {
    const { ok, errorCount } = testParse('S <- "x"* ;', '');
    expect(ok).toBe(true);
    expect(errorCount).toBe(0);
  });

  test('E02-OneOrMore empty', () => {
    const { ok } = testParse('S <- "x"+ ;', '');
    expect(ok).toBe(false);
  });

  test('E03-Optional empty', () => {
    const { ok, errorCount } = testParse('S <- "x"? ;', '');
    expect(ok).toBe(true);
    expect(errorCount).toBe(0);
  });

  test('E04-Seq empty recovery', () => {
    const parseResult = squirrelParsePT({
      grammarSpec: 'S <- "a" "b" ;',
      topRuleName: 'S',
      input: '',
    });
    const result = parseResult.root;
    expect(result.isMismatch).toBe(false);
    expect(countDeletions([result])).toBe(2);
  });

  test('E05-First empty', () => {
    const { ok } = testParse('S <- "a" / "b" ;', '');
    expect(ok).toBe(false);
  });

  test('E06-Ref empty', () => {
    const { ok } = testParse('S <- A ; A <- "x" ;', '');
    expect(ok).toBe(false);
  });

  test('E07-Single char match', () => {
    const { ok, errorCount } = testParse('S <- "x" ;', 'x');
    expect(ok).toBe(true);
    expect(errorCount).toBe(0);
  });

  test('E08-Single char mismatch', () => {
    const { ok } = testParse('S <- "x" ;', 'y');
    expect(ok).toBe(false);
  });

  test('E09-ZeroOrMore single', () => {
    const { ok, errorCount } = testParse('S <- "x"* ;', 'x');
    expect(ok).toBe(true);
    expect(errorCount).toBe(0);
  });

  test('E10-OneOrMore single', () => {
    const { ok, errorCount } = testParse('S <- "x"+ ;', 'x');
    expect(ok).toBe(true);
    expect(errorCount).toBe(0);
  });

  test('E11-Optional match', () => {
    const { ok, errorCount } = testParse('S <- "x"? ;', 'x');
    expect(ok).toBe(true);
    expect(errorCount).toBe(0);
  });

  test('E12-Two chars match', () => {
    const { ok, errorCount } = testParse('S <- "xy" ;', 'xy');
    expect(ok).toBe(true);
    expect(errorCount).toBe(0);
  });

  test('E13-Two chars partial', () => {
    const { ok } = testParse('S <- "xy" ;', 'x');
    expect(ok).toBe(false);
  });

  test('E14-CharRange match', () => {
    const { ok, errorCount } = testParse('S <- [a-z] ;', 'm');
    expect(ok).toBe(true);
    expect(errorCount).toBe(0);
  });

  test('E15-CharRange boundary low', () => {
    const { ok, errorCount } = testParse('S <- [a-z] ;', 'a');
    expect(ok).toBe(true);
    expect(errorCount).toBe(0);
  });

  test('E16-CharRange boundary high', () => {
    const { ok, errorCount } = testParse('S <- [a-z] ;', 'z');
    expect(ok).toBe(true);
    expect(errorCount).toBe(0);
  });

  test('E17-CharRange fail low', () => {
    const { ok } = testParse('S <- [b-y] ;', 'a');
    expect(ok).toBe(false);
  });

  test('E18-CharRange fail high', () => {
    const { ok } = testParse('S <- [b-y] ;', 'z');
    expect(ok).toBe(false);
  });

  test('E19-AnyChar match', () => {
    const { ok, errorCount } = testParse('S <- . ;', 'x');
    expect(ok).toBe(true);
    expect(errorCount).toBe(0);
  });

  test('E20-AnyChar empty', () => {
    const { ok } = testParse('S <- . ;', '');
    expect(ok).toBe(false);
  });

  test('E21-Seq single', () => {
    const { ok, errorCount } = testParse('S <- ("x") ;', 'x');
    expect(ok).toBe(true);
    expect(errorCount).toBe(0);
  });

  test('E22-First single', () => {
    const { ok, errorCount } = testParse('S <- "x" ;', 'x');
    expect(ok).toBe(true);
    expect(errorCount).toBe(0);
  });

  test('E23-Nested empty', () => {
    const { ok, errorCount } = testParse('S <- "a"? "b"? ;', '');
    expect(ok).toBe(true);
    expect(errorCount).toBe(0);
  });

  test('E24-ZeroOrMore multi', () => {
    const { ok, errorCount } = testParse('S <- "x"* ;', 'xxx');
    expect(ok).toBe(true);
    expect(errorCount).toBe(0);
  });

  test('E25-OneOrMore multi', () => {
    const { ok, errorCount } = testParse('S <- "x"+ ;', 'xxx');
    expect(ok).toBe(true);
    expect(errorCount).toBe(0);
  });

  test('E26-Long string match', () => {
    const { ok, errorCount } = testParse('S <- "abcdefghij" ;', 'abcdefghij');
    expect(ok).toBe(true);
    expect(errorCount).toBe(0);
  });

  test('E27-Long string partial', () => {
    const { ok } = testParse('S <- "abcdefghij" ;', 'abcdefghi');
    expect(ok).toBe(false);
  });
});
