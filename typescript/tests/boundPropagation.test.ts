/**
 * BOUND PROPAGATION TESTS (FIX #9 Verification)
 * These tests verify that bounds propagate through arbitrary nesting levels
 * to correctly stop repetitions before consuming delimiters.
 */

import { describe, expect, test } from '@jest/globals';
import { First, OneOrMore, Ref, Seq, Str, ZeroOrMore } from '../src';
import { parse } from './testUtils';

describe('Bound Propagation Tests', () => {
  test('BP-01-direct-repetition', () => {
    // Baseline: Bound with direct Repetition child (was already working)
    const [ok, err, _] = parse(
      {
        S: new Seq([new OneOrMore(new Str('x')), new Str('end')]),
      },
      'xxxxend'
    );
    expect(ok).toBe(true); // should succeed
    expect(err).toBe(0); // should have 0 errors
  });

  test('BP-02-through-ref', () => {
    // FIX #9: Bound propagates through Ref
    const [ok, err, _] = parse(
      {
        S: new Seq([new Ref('A'), new Str('end')]),
        A: new OneOrMore(new Str('x')),
      },
      'xxxxend'
    );
    expect(ok).toBe(true); // should succeed (bound through Ref)
    expect(err).toBe(0); // should have 0 errors
  });

  test('BP-03-through-nested-refs', () => {
    // FIX #9: Bound propagates through multiple Refs
    const [ok, err, _] = parse(
      {
        S: new Seq([new Ref('A'), new Str('end')]),
        A: new Ref('B'),
        B: new OneOrMore(new Str('x')),
      },
      'xxxxend'
    );
    expect(ok).toBe(true); // should succeed (bound through 2 Refs)
    expect(err).toBe(0); // should have 0 errors
  });

  test('BP-04-through-first', () => {
    // FIX #9: Bound propagates through First alternatives
    const [ok, err, _] = parse(
      {
        S: new Seq([new Ref('A'), new Str('end')]),
        A: new First([new OneOrMore(new Str('x')), new OneOrMore(new Str('y'))]),
      },
      'xxxxend'
    );
    expect(ok).toBe(true); // should succeed (bound through First)
    expect(err).toBe(0); // should have 0 errors
  });

  test('BP-05-left-recursive-with-repetition', () => {
    // FIX #9: The EMERG-01 case - bound through LR + First + Seq + Repetition
    const [ok, err, _] = parse(
      {
        S: new Seq([new Ref('E'), new Str('end')]),
        E: new First([
          new Seq([new Ref('E'), new Str('+'), new OneOrMore(new Str('n'))]),
          new Str('n'),
        ]),
      },
      'n+nnn+nnend'
    );
    expect(ok).toBe(true); // should succeed (bound through LR)
    expect(err).toBe(0); // should have 0 errors
  });

  test('BP-06-with-recovery-inside-bounded-rep', () => {
    // FIX #9 + recovery: Bound propagates AND recovery works inside repetition
    const [ok, err, skip] = parse(
      {
        S: new Seq([new Ref('A'), new Str('end')]),
        A: new OneOrMore(new Str('ab')),
      },
      'abXabYabend'
    );
    expect(ok).toBe(true); // should succeed
    expect(err).toBe(2); // should have 2 errors (X and Y)
    expect(skip.includes('X')).toBe(true); // should skip X
    expect(skip.includes('Y')).toBe(true); // should skip Y
  });

  test('BP-07-multiple-bounds-nested-seq', () => {
    // Multiple bounds in nested Seq structures
    const [ok, err, _] = parse(
      {
        S: new Seq([new Ref('A'), new Str(';'), new Ref('B'), new Str('end')]),
        A: new OneOrMore(new Str('x')),
        B: new OneOrMore(new Str('y')),
      },
      'xxxx;yyyyend'
    );
    expect(ok).toBe(true); // should succeed
    expect(err).toBe(0); // should have 0 errors
    // A stops at ';', B stops at 'end'
  });

  test('BP-08-bound-vs-eof', () => {
    // Without explicit bound, should consume until EOF
    const [ok, err, _] = parse({ S: new OneOrMore(new Str('x')) }, 'xxxx');
    expect(ok).toBe(true); // should succeed
    expect(err).toBe(0); // should have 0 errors
    // No bound, so consumes all x's
  });

  test('BP-09-zeoormore-with-bound', () => {
    // Bound applies to ZeroOrMore too
    const [ok, err, _] = parse(
      {
        S: new Seq([new ZeroOrMore(new Str('x')), new Str('end')]),
      },
      'end'
    );
    expect(ok).toBe(true); // should succeed (ZeroOrMore matches 0)
    expect(err).toBe(0); // should have 0 errors
  });

  test('BP-10-complex-nesting', () => {
    // Deeply nested: Ref → First → Seq → Ref → Repetition
    const [ok, err, _] = parse(
      {
        S: new Seq([new Ref('A'), new Str('end')]),
        A: new First([new Seq([new Str('a'), new Ref('B')]), new Str('fallback')]),
        B: new OneOrMore(new Str('x')),
      },
      'axxxxend'
    );
    expect(ok).toBe(true); // should succeed (bound through complex nesting)
    expect(err).toBe(0); // should have 0 errors
  });
});
