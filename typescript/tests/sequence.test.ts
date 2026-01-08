/**
 * SECTION 7: SEQUENCE COMPREHENSIVE (10 tests)
 */

import { describe, expect, test } from '@jest/globals';
import { Parser, Seq, Str, SyntaxError } from '../src';
import { countDeletions, parse } from './testUtils';

describe('Sequence Tests', () => {
  test('S01-2 elem', () => {
    const [ok, err, _] = parse(
      {
        S: new Seq([new Str('a'), new Str('b')]),
      },
      'ab'
    );
    expect(ok).toBe(true);
    expect(err).toBe(0);
  });

  test('S02-3 elem', () => {
    const [ok, err, _] = parse(
      {
        S: new Seq([new Str('a'), new Str('b'), new Str('c')]),
      },
      'abc'
    );
    expect(ok).toBe(true);
    expect(err).toBe(0);
  });

  test('S03-5 elem', () => {
    const [ok, err, _] = parse(
      {
        S: new Seq([new Str('a'), new Str('b'), new Str('c'), new Str('d'), new Str('e')]),
      },
      'abcde'
    );
    expect(ok).toBe(true);
    expect(err).toBe(0);
  });

  test('S04-insert mid', () => {
    const [ok, err, skip] = parse(
      {
        S: new Seq([new Str('a'), new Str('b'), new Str('c')]),
      },
      'aXXbc'
    );
    expect(ok).toBe(true);
    expect(err).toBe(1);
    expect(skip).toContain('XX');
  });

  test('S05-insert end', () => {
    const [ok, err, skip] = parse(
      {
        S: new Seq([new Str('a'), new Str('b'), new Str('c')]),
      },
      'abXXc'
    );
    expect(ok).toBe(true);
    expect(err).toBe(1);
    expect(skip).toContain('XX');
  });

  test('S06-del mid', () => {
    // Cannot delete grammar elements mid-parse (Fix #8 - Visibility Constraint)
    // Input "ac" with grammar "a" "b" "c" would require deleting "b" at position 1
    // Position 1 is not EOF (still have "c" to parse), so this violates constraints
    const parser = new Parser(
      {
        S: new Seq([new Str('a'), new Str('b'), new Str('c')]),
      },
      'ac'
    );
    const [result, _] = parser.parse('S');
    // Should fail - cannot delete "b" mid-parse
    expect(result instanceof SyntaxError).toBe(true);
  });

  test('S07-del end', () => {
    const parser = new Parser(
      {
        S: new Seq([new Str('a'), new Str('b'), new Str('c')]),
      },
      'ab'
    );
    const [result, _] = parser.parse('S');
    expect(result !== null && !result.isMismatch).toBe(true);
    expect(countDeletions(result)).toBe(1);
  });

  test('S08-nested clean', () => {
    const [ok, err, _] = parse(
      {
        S: new Seq([new Seq([new Str('a'), new Str('b')]), new Str('c')]),
      },
      'abc'
    );
    expect(ok).toBe(true);
    expect(err).toBe(0);
  });

  test('S09-nested insert', () => {
    const [ok, err, skip] = parse(
      {
        S: new Seq([new Seq([new Str('a'), new Str('b')]), new Str('c')]),
      },
      'aXbc'
    );
    expect(ok).toBe(true);
    expect(err).toBe(1);
    expect(skip).toContain('X');
  });

  test('S10-long seq clean', () => {
    const clauses = 'abcdefghijklmnop'.split('').map(c => new Str(c));
    const [ok, err, _] = parse({ S: new Seq(clauses) }, 'abcdefghijklmnop');
    expect(ok).toBe(true);
    expect(err).toBe(0);
  });
});
