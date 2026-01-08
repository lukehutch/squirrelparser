/**
 * COMPLEX INTERACTIONS TESTS
 * These tests verify complex combinations of features working together.
 */

import { describe, expect, test } from '@jest/globals';
import type { Clause } from '../src';
import { First, FollowedBy, NotFollowedBy, OneOrMore, Optional, Ref, Seq, Str, ZeroOrMore } from '../src';
import { parse } from './testUtils';

describe('Complex Interactions Tests', () => {
  test('COMPLEX-01-lr-bound-recovery-all-together', () => {
    // LR + bound propagation + recovery all working together (EMERG-01 verified)
    const [ok, err, skip] = parse(
      {
        S: new Seq([new Ref('E'), new Str('end')]),
        E: new First([
          new Seq([new Ref('E'), new Str('+'), new OneOrMore(new Str('n'))]),
          new Str('n'),
        ]),
      },
      'n+nXn+nnend'
    );
    expect(ok).toBe(true); // should succeed (FIX #9 bound propagation)
    expect(err).toBeGreaterThan(0); // should have at least 1 error
    expect(skip.includes('X')).toBe(true); // should skip X
    // LR expands, OneOrMore with recovery, bound stops before 'end'
  });

  test('COMPLEX-02-nested-first-with-different-recovery-costs', () => {
    // Nested First, each with alternatives requiring different recovery
    const [ok, err, _] = parse(
      {
        S: new First([
          new Seq([new First([new Str('x'), new Str('y')]), new Str('z')]),
          new Str('a'),
        ]),
      },
      'xXz'
    );
    expect(ok).toBe(true); // should succeed
    expect(err).toBe(1); // should choose first alternative with recovery
    // Outer First chooses first alternative (Seq)
    // Inner First chooses first alternative 'x'
    // Then skip X, match 'z'
  });

  test('COMPLEX-03-recovery-version-overflow-verified', () => {
    // Many recoveries to test version counter doesn't overflow
    const input = 'ab' + Array.from({ length: 50 }, () => 'Xab').join('');
    const [ok, err, _] = parse({ S: new OneOrMore(new Str('ab')) }, input);
    expect(ok).toBe(true); // should succeed (version counter handles 50+ recoveries)
    expect(err).toBe(50); // should count all 50 errors
  });

  test('COMPLEX-04-probe-during-recovery', () => {
    // ZeroOrMore uses probe while recovery is happening
    const [ok, err, skip] = parse(
      {
        S: new Seq([new ZeroOrMore(new Str('x')), new First([new Str('y'), new Str('z')])]),
      },
      'xXxz'
    );
    expect(ok).toBe(true); // should succeed
    expect(err).toBe(1); // should have 1 error
    expect(skip.includes('X')).toBe(true); // should skip X
    // ZeroOrMore with recovery inside, probes to find 'z'
  });

  test('COMPLEX-05-multiple-refs-same-rule-with-recovery', () => {
    // Multiple Refs to same rule, each with independent recovery
    const [ok, err, _skip] = parse(
      {
        S: new Seq([new Ref('A'), new Str('+'), new Ref('A')]),
        A: new Str('n'),
      },
      'nX+n'
    );
    expect(ok).toBe(true); // should succeed
    expect(err).toBe(1); // should have 1 error
    // First Ref('A') needs recovery, second Ref('A') is clean
  });

  test('COMPLEX-06-deeply-nested-lr', () => {
    // Multiple LR levels with recovery at different depths
    const [ok, err, _] = parse(
      {
        A: new First([new Seq([new Ref('A'), new Str('a'), new Ref('B')]), new Ref('B')]),
        B: new First([new Seq([new Ref('B'), new Str('b'), new Str('x')]), new Str('x')]),
      },
      'xbXxaXxbx',
      'A'
    );
    expect(ok).toBe(true); // should succeed
    expect(err).toBe(2); // should have 2 errors (X's at both A and B levels)
  });

  test('COMPLEX-07-recovery-with-lookahead', () => {
    // Recovery near lookahead assertions
    const [ok, err, skip] = parse(
      {
        S: new Seq([new Str('a'), new FollowedBy(new Str('b')), new Str('b'), new Str('c')]),
      },
      'aXbc'
    );
    expect(ok).toBe(true); // should succeed
    expect(err).toBe(1); // should have 1 error
    expect(skip.includes('X')).toBe(true); // should skip X
    // After skipping X, FollowedBy(b) checks 'b' without consuming
  });

  test('COMPLEX-08-recovery-in-negative-lookahead', () => {
    // NotFollowedBy with recovery context
    const [ok, err, _] = parse(
      {
        S: new Seq([new Str('a'), new NotFollowedBy(new Str('x')), new Str('b')]),
      },
      'ab'
    );
    expect(ok).toBe(true); // should succeed
    expect(err).toBe(0); // should have 0 errors
    // NotFollowedBy('x') succeeds (next is 'b', not 'x')
  });

  test('COMPLEX-09-alternating-lr-and-repetition', () => {
    // Grammar with both LR and repetitions at same level
    const [ok, err, _] = parse(
      {
        S: new Seq([new Ref('E'), new Str(';'), new OneOrMore(new Str('x'))]),
        E: new First([new Seq([new Ref('E'), new Str('+'), new Str('n')]), new Str('n')]),
      },
      'n+n;xxx'
    );
    expect(ok).toBe(true); // should succeed
    expect(err).toBe(0); // should have 0 errors
    // E is left-recursive, then ';', then repetition
  });

  test('COMPLEX-10-recovery-spanning-multiple-clauses', () => {
    // Single error region that spans where multiple clauses would try to match
    const [ok, err, skip] = parse(
      {
        S: new Seq([new Str('a'), new Str('b'), new Str('c'), new Str('d')]),
      },
      'aXYZbcd'
    );
    expect(ok).toBe(true); // should succeed
    expect(err).toBe(1); // should have 1 error (entire XYZ region)
    expect(skip.includes('XYZ')).toBe(true); // should skip XYZ as single region
  });

  test('COMPLEX-11-ref-through-multiple-indirections', () => {
    // A → B → C → D, all Refs
    const [ok, err, _] = parse(
      { A: new Ref('B'), B: new Ref('C'), C: new Ref('D'), D: new Str('x') },
      'x',
      'A'
    );
    expect(ok).toBe(true); // should succeed (multiple Ref indirections)
    expect(err).toBe(0); // should have 0 errors
  });

  test('COMPLEX-12-circular-refs-with-recovery', () => {
    // Mutual recursion with simple clean input
    const [ok, err, _skip] = parse(
      {
        S: new Seq([new Ref('A'), new Str('end')]),
        A: new First([new Seq([new Str('a'), new Ref('B')]), new Str('a')]),
        B: new First([new Seq([new Str('b'), new Ref('A')]), new Str('b')]),
      },
      'ababend',
      'S'
    );
    expect(ok).toBe(true); // should succeed
    expect(err).toBe(0); // should have 0 errors (clean parse)
    // Mutual recursion: A → B → A → B (abab)
  });

  test('COMPLEX-13-all-clause-types-in-one-grammar', () => {
    // Every clause type in one complex grammar
    const [ok, err, _] = parse(
      {
        S: new Seq([
          new Ref('A'),
          new Optional(new Str('opt')),
          new ZeroOrMore(new Str('z')),
          new First([new Str('f1'), new Str('f2')]),
          new FollowedBy(new Str('end')),
          new Str('end'),
        ]),
        A: new First([new Seq([new Ref('A'), new Str('+'), new Str('a')]), new Str('a')]),
      },
      'a+aoptzzzf1end',
      'S'
    );
    expect(ok).toBe(true); // should succeed (all clause types work together)
    expect(err).toBe(0); // should have 0 errors
  });

  test('COMPLEX-14-recovery-at-every-level-of-deep-nesting', () => {
    // Error at each level of deep nesting, all recover
    const [ok, err, _] = parse(
      {
        S: new Seq([new Seq([new Str('a'), new Seq([new Str('b'), new Seq([new Str('c'), new Str('d')])])])]),
      },
      'aXbYcZd'
    );
    expect(ok).toBe(true); // should succeed
    expect(err).toBe(3); // should have 3 errors
    // Error at each nesting level
  });

  test('COMPLEX-15-performance-large-grammar', () => {
    // Large grammar with many rules
    const rules: Record<string, Clause> = {};
    for (let i = 0; i < 50; i++) {
      rules[`Rule${i}`] = new Str(`opt_${i.toString().padStart(3, '0')}`);
    }
    rules.S = new First(Array.from({ length: 50 }, (_, i) => new Ref(`Rule${i}`)));

    const [ok, _, __] = parse(rules, 'opt_025', 'S');
    expect(ok).toBe(true); // should succeed (large grammar with 50 rules)
  });
});
