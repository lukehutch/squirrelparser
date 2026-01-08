/**
 * VISIBILITY CONSTRAINT TESTS
 * Tests for FIX #8 - Visibility Constraint (no mid-parse grammar deletion)
 */

import { describe, expect, test } from '@jest/globals';
import { OneOrMore, Parser, Seq, Str, SyntaxError } from '../src';
import { parse } from './testUtils';

describe('Visibility Constraint Tests', () => {
  test('VIS-01-no-mid-parse-deletion', () => {
    // Cannot delete grammar elements mid-parse
    const [ok, _, __] = parse(
      {
        S: new Seq([new Str('a'), new Str('b'), new Str('c')]),
      },
      'aXc'
    );
    expect(ok).toBe(false); // should fail (would need to delete 'b' mid-parse)
  });

  test('VIS-02-eof-deletion-ok', () => {
    // Grammar deletion at EOF is allowed
    const [ok, err, _] = parse(
      {
        S: new Seq([new Str('a'), new Str('b'), new Str('c')]),
      },
      'ab'
    );
    expect(ok).toBe(true); // should succeed
    expect(err).toBe(1); // should have 1 error (delete 'c' at EOF)
  });

  test('VIS-03-input-skip-ok', () => {
    // Input skipping is always allowed
    const [ok, err, skip] = parse(
      {
        S: new Seq([new Str('a'), new Str('b'), new Str('c')]),
      },
      'aXbc'
    );
    expect(ok).toBe(true); // should succeed
    expect(err).toBe(1); // should have 1 error
    expect(skip.includes('X')).toBe(true); // should skip X
  });

  test('VIS-04-structural-integrity', () => {
    // Must preserve structural boundaries
    const [ok, _, __] = parse(
      {
        S: new Seq([new Str('aaa'), new Str('bbb')]),
      },
      'aaXbbb'
    );
    expect(ok).toBe(false); // should fail (breaks structural integrity)
  });

  test('VIS-05-repetition-boundary', () => {
    // Repetition should respect boundaries
    const [ok, err, skip] = parse(
      {
        S: new Seq([new OneOrMore(new Str('x')), new Str('end')]),
      },
      'xXxend'
    );
    expect(ok).toBe(true); // should succeed
    expect(err).toBe(1); // should have 1 error
    expect(skip.includes('X')).toBe(true); // should skip X
  });

  test('VIS-06-multiple-consecutive-skips', () => {
    // Multiple consecutive errors should be merged into one region
    const [ok, err, skip] = parse(
      {
        S: new Seq([new Str('a'), new Str('b'), new Str('c')]),
      },
      'aXXXXbc'
    );
    expect(ok).toBe(true); // should succeed
    expect(err).toBe(1); // should have 1 error (entire XXXX region)
    expect(skip.includes('XXXX')).toBe(true); // should skip XXXX as one region
  });

  test('VIS-07-alternating-content-and-errors', () => {
    // Pattern: valid, error, valid, error, valid, error, valid
    const [ok, err, skip] = parse(
      {
        S: new Seq([new Str('a'), new Str('b'), new Str('c'), new Str('d')]),
      },
      'aXbYcZd'
    );
    expect(ok).toBe(true); // should succeed
    expect(err).toBe(3); // should have 3 errors
    expect(skip.includes('X')).toBe(true);
    expect(skip.includes('Y')).toBe(true);
    expect(skip.includes('Z')).toBe(true);
  });

  test('VIS-08-completion-vs-correction', () => {
    // Completion (EOF): allowed
    const comp = parse(
      {
        S: new Seq([new Str('if'), new Str('('), new Str('x'), new Str(')')]),
      },
      'if(x'
    );
    expect(comp[0]).toBe(true); // completion should succeed

    // Correction (mid-parse): NOT allowed
    const parser = new Parser(
      {
        S: new Seq([new Str('if'), new Str('('), new Str('x'), new Str(')')]),
      },
      'if()'
    );
    const [result, _] = parser.parse('S');
    expect(result instanceof SyntaxError).toBe(true);
  });

  test('VIS-09-structural-integrity', () => {
    // Tree must reflect what user sees
    const [ok, _, __] = parse(
      {
        S: new Seq([new Str('('), new Str('E'), new Str(')')]),
      },
      'E)'
    );
    expect(ok).toBe(false); // should fail (cannot reorganize visible structure)
  });

  test('VIS-10-visibility-with-nested-structures', () => {
    // Nested Seq - errors at each level should preserve visibility
    const [ok, err, skip] = parse(
      {
        S: new Seq([new Seq([new Str('a'), new Str('b')]), new Str('c')]),
      },
      'aXbc'
    );
    expect(ok).toBe(true); // should succeed
    expect(err).toBe(1); // should have 1 error
    expect(skip.includes('X')).toBe(true); // should skip X in inner Seq
  });
});
