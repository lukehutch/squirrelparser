// ===========================================================================
// SECTION 7: SEQUENCE COMPREHENSIVE (10 tests)
// ===========================================================================

import { testParse, countDeletions } from './testUtils.js';
import { squirrelParsePT, SyntaxError } from '../src/index.js';

describe('Sequence Comprehensive', () => {
  test('S01-2 elem', () => {
    const { ok, errorCount } = testParse(
      'S <- "a" "b" ;',
      'ab'
    );
    expect(ok).toBe(true);
    expect(errorCount).toBe(0);
  });

  test('S02-3 elem', () => {
    const { ok, errorCount } = testParse(
      'S <- "a" "b" "c" ;',
      'abc'
    );
    expect(ok).toBe(true);
    expect(errorCount).toBe(0);
  });

  test('S03-5 elem', () => {
    const { ok, errorCount } = testParse(
      'S <- "a" "b" "c" "d" "e" ;',
      'abcde'
    );
    expect(ok).toBe(true);
    expect(errorCount).toBe(0);
  });

  test('S04-insert mid', () => {
    const { ok, errorCount, skippedStrings } = testParse(
      'S <- "a" "b" "c" ;',
      'aXXbc'
    );
    expect(ok).toBe(true);
    expect(errorCount).toBe(1);
    expect(skippedStrings).toContain('XX');
  });

  test('S05-insert end', () => {
    const { ok, errorCount, skippedStrings } = testParse(
      'S <- "a" "b" "c" ;',
      'abXXc'
    );
    expect(ok).toBe(true);
    expect(errorCount).toBe(1);
    expect(skippedStrings).toContain('XX');
  });

  test('S06-del mid', () => {
    // Cannot delete grammar elements mid-parse (Fix #8 - Visibility Constraint)
    // Input "ac" with grammar "a" "b" "c" would require deleting "b" at position 1
    // Position 1 is not EOF (still have "c" to parse), so this violates constraints
    const parseResult = squirrelParsePT({
      grammarSpec: 'S <- "a" "b" "c" ;',
      topRuleName: 'S',
      input: 'ac',
    });
    const result = parseResult.root;
    // Should fail - cannot delete "b" mid-parse
    // Total failure: result is SyntaxError spanning entire input
    expect(result instanceof SyntaxError).toBe(true);
  });

  test('S07-del end', () => {
    const parseResult = squirrelParsePT({
      grammarSpec: 'S <- "a" "b" "c" ;',
      topRuleName: 'S',
      input: 'ab',
    });
    const result = parseResult.root;
    expect(result.isMismatch).toBe(false);
    expect(countDeletions([result])).toBe(1);
  });

  test('S08-nested clean', () => {
    const { ok, errorCount } = testParse(
      'S <- ("a" "b") "c" ;',
      'abc'
    );
    expect(ok).toBe(true);
    expect(errorCount).toBe(0);
  });

  test('S09-nested insert', () => {
    const { ok, errorCount, skippedStrings } = testParse(
      'S <- ("a" "b") "c" ;',
      'aXbc'
    );
    expect(ok).toBe(true);
    expect(errorCount).toBe(1);
    expect(skippedStrings).toContain('X');
  });

  test('S10-long seq clean', () => {
    const { ok, errorCount } = testParse(
      'S <- "a" "b" "c" "d" "e" "f" "g" "h" "i" "j" "k" "l" "m" "n" "o" "p" ;',
      'abcdefghijklmnop'
    );
    expect(ok).toBe(true);
    expect(errorCount).toBe(0);
  });
});
