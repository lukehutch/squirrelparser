/**
 * OPTIONAL WITH RECOVERY TESTS
 *
 * These tests verify Optional behavior with and without recovery.
 */

import { describe, expect, test } from '@jest/globals';
import { First, OneOrMore, Optional, Seq, Str, ZeroOrMore } from '../src';
import { parse } from './testUtils';

describe('Optional Recovery Tests', () => {
  test('OPT-01-optional-matches-cleanly', () => {
    // Optional matches its content cleanly
    const [ok, err, _] = parse(
      {
        S: new Seq([new Optional(new Str('a')), new Str('b')]),
      },
      'ab'
    );
    expect(ok).toBe(true);
    expect(err).toBe(0);
    // Optional matches 'a', then 'b'
  });

  test('OPT-02-optional-falls-through-cleanly', () => {
    // Optional doesn't match, falls through
    const [ok, err, _] = parse(
      {
        S: new Seq([new Optional(new Str('a')), new Str('b')]),
      },
      'b'
    );
    expect(ok).toBe(true);
    expect(err).toBe(0);
    // Optional returns empty match (len=0), then 'b' matches
  });

  test('OPT-03-optional-with-recovery-attempt', () => {
    // Optional content needs recovery - should Optional try recovery or fall through?
    // Current behavior: Optional tries recovery
    const [ok, err, skip] = parse(
      {
        S: new Optional(new Seq([new Str('a'), new Str('b')])),
      },
      'aXb'
    );
    expect(ok).toBe(true);
    // If Optional attempts recovery: err=1, skip=['X']
    // If Optional falls through: err=0, but incomplete parse
    expect(err).toBe(1);
    expect(skip.some(s => s.includes('X'))).toBe(true);
  });

  test('OPT-04-optional-in-sequence', () => {
    // Optional in middle of sequence
    const [ok, err, _] = parse(
      {
        S: new Seq([new Str('a'), new Optional(new Str('b')), new Str('c')]),
      },
      'ac'
    );
    expect(ok).toBe(true);
    expect(err).toBe(0);
    // 'a' matches, Optional falls through, 'c' matches
  });

  test('OPT-05-nested-optional', () => {
    // Optional(Optional(...))
    const [ok, err, _] = parse(
      {
        S: new Seq([new Optional(new Optional(new Str('a'))), new Str('b')]),
      },
      'b'
    );
    expect(ok).toBe(true);
    expect(err).toBe(0);
    // Both optionals return empty
  });

  test('OPT-06-optional-with-first', () => {
    // Optional(First([...]))
    const [ok, err, _] = parse(
      {
        S: new Seq([new Optional(new First([new Str('a'), new Str('b')])), new Str('c')]),
      },
      'bc'
    );
    expect(ok).toBe(true);
    expect(err).toBe(0);
    // Optional matches First's second alternative 'b'
  });

  test('OPT-07-optional-with-repetition', () => {
    // Optional(OneOrMore(...))
    const [ok, err, _] = parse(
      {
        S: new Seq([new Optional(new OneOrMore(new Str('x'))), new Str('y')]),
      },
      'xxxy'
    );
    expect(ok).toBe(true);
    expect(err).toBe(0);
    // Optional matches OneOrMore which matches 3 x's
  });

  test('OPT-08-optional-at-eof', () => {
    // Optional at end of grammar
    const [ok, err, _] = parse(
      {
        S: new Seq([new Str('a'), new Optional(new Str('b'))]),
      },
      'a'
    );
    expect(ok).toBe(true);
    expect(err).toBe(0);
    // 'a' matches, Optional at EOF returns empty
  });

  test('OPT-09-multiple-optionals', () => {
    // Multiple optionals in sequence
    const [ok, err, _] = parse(
      {
        S: new Seq([new Optional(new Str('a')), new Optional(new Str('b')), new Str('c')]),
      },
      'c'
    );
    expect(ok).toBe(true);
    expect(err).toBe(0);
    // Both optionals return empty, 'c' matches
  });

  test('OPT-10-optional-vs-zeoormore', () => {
    // Optional(Str(x)) vs ZeroOrMore(Str(x))
    // Optional: matches 0 or 1 time
    // ZeroOrMore: matches 0 or more times
    const opt = parse(
      {
        S: new Seq([new Optional(new Str('x')), new Str('y')]),
      },
      'xxxy'
    );
    // Optional matches first 'x', remaining "xxy" for rest
    // Str('y') sees "xxy", uses recovery to skip "xx", matches 'y'
    expect(opt[0]).toBe(true);
    expect(opt[1]).toBe(1);

    const zm = parse(
      {
        S: new Seq([new ZeroOrMore(new Str('x')), new Str('y')]),
      },
      'xxxy'
    );
    expect(zm[0]).toBe(true);
    expect(zm[1]).toBe(0);
  });

  test('OPT-11-optional-with-complex-content', () => {
    // Optional(Seq([complex structure]))
    const [ok, err, _] = parse(
      {
        S: new Seq([
          new Optional(new Seq([new Str('if'), new Str('('), new Str('x'), new Str(')')])),
          new Str('body'),
        ]),
      },
      'if(x)body'
    );
    expect(ok).toBe(true);
    expect(err).toBe(0);
  });

  test('OPT-12-optional-incomplete-phase1', () => {
    // In Phase 1, if Optional's content is incomplete, should Optional be marked incomplete?
    // This is testing the "mark Optional fallback incomplete" (Modification 5)
    const [ok, _, __] = parse(
      {
        S: new Seq([new Optional(new Str('a')), new Str('b')]),
      },
      'Xb'
    );
    // Phase 1: Optional tries 'a' at 0, sees 'X', fails
    //   Optional falls through (returns empty), marked incomplete
    // Phase 2: Re-evaluates, Optional might try recovery? Or still fall through?
    expect(ok).toBe(true);
    // If Optional tries recovery in Phase 2, would skip X and fail to find 'a'
    // Then falls through, 'b' matches
  });
});
