/**
 * REPETITION EDGE CASE TESTS
 * Tests edge cases in repetition operators
 * Ported from Dart: dart/test/parser/repetition_edge_case_test.dart
 */

import { describe, expect, test } from '@jest/globals';
import { First, OneOrMore, Seq, Str, ZeroOrMore } from '../src';
import { parse } from './testUtils';

describe('Repetition Edge Case Tests', () => {
  test('REP-01-zeromore-empty-match', () => {
    // ZeroOrMore can match zero times
    const [ok, err, _] = parse(
      { S: new Seq([new ZeroOrMore(new Str('x')), new Str('y')]) },
      'y'
    );
    expect(ok).toBe(true);
    expect(err).toBe(0);
  });

  test('REP-02-oneormore-vs-zeromore-at-eof', () => {
    // OneOrMore requires at least one match, ZeroOrMore doesn't
    const om = parse({ S: new OneOrMore(new Str('x')) }, '');
    expect(om[0]).toBe(false);

    const zm = parse({ S: new ZeroOrMore(new Str('x')) }, '');
    expect(zm[0]).toBe(true);
  });

  test('REP-03-nested-repetition', () => {
    // OneOrMore(OneOrMore(x)) - nested repetitions
    const [ok, err, _] = parse(
      { S: new OneOrMore(new OneOrMore(new Str('x'))) },
      'xxxXxxXxxx'
    );
    expect(ok).toBe(true);
    expect(err).toBe(2);
  });

  test('REP-04-repetition-with-recovery-hits-bound', () => {
    // Repetition with recovery, encounters bound
    const [ok, err, skip] = parse(
      { S: new Seq([new OneOrMore(new Str('x')), new Str('end')]) },
      'xXxXxend'
    );
    expect(ok).toBe(true);
    expect(err).toBe(2);
    expect(skip.length).toBe(2);
  });

  test('REP-05-repetition-recovery-vs-probe', () => {
    // ZeroOrMore must probe ahead to avoid consuming boundary
    const [ok, err, _] = parse(
      { S: new Seq([new ZeroOrMore(new Str('x')), new Str('y')]) },
      'xxxy'
    );
    expect(ok).toBe(true);
    expect(err).toBe(0);
  });

  test('REP-06-alternating-match-skip-pattern', () => {
    // Pattern: match, skip, match, skip, ...
    const [ok, err, _] = parse({ S: new OneOrMore(new Str('ab')) }, 'abXabXabXab');
    expect(ok).toBe(true);
    expect(err).toBe(3);
  });

  test('REP-07-repetition-of-complex-structure', () => {
    // OneOrMore(Seq([...])) - repetition of sequences
    const [ok, err, _] = parse(
      { S: new OneOrMore(new Seq([new Str('a'), new Str('b')])) },
      'ababab'
    );
    expect(ok).toBe(true);
    expect(err).toBe(0);
  });

  test('REP-08-repetition-stops-on-non-match', () => {
    // Repetition stops when element no longer matches
    const [ok, err, _] = parse(
      { S: new Seq([new OneOrMore(new Str('x')), new Str('y')]) },
      'xxxy'
    );
    expect(ok).toBe(true);
    expect(err).toBe(0);
  });

  test('REP-09-repetition-with-first-alternative', () => {
    // OneOrMore(First([...])) - repetition of alternatives
    const [ok, err, _] = parse(
      { S: new OneOrMore(new First([new Str('a'), new Str('b')])) },
      'aabba'
    );
    expect(ok).toBe(true);
    expect(err).toBe(0);
  });

  test('REP-10-zeromore-with-recovery-inside', () => {
    // ZeroOrMore element needs recovery
    const [ok, err, _] = parse(
      { S: new ZeroOrMore(new Seq([new Str('a'), new Str('b')])) },
      'abXaYb'
    );
    expect(ok).toBe(true);
    expect(err).toBe(2);
  });

  test('REP-11-greedy-vs-non-greedy', () => {
    // Repetitions are greedy - match as many as possible
    const [ok, err, _] = parse(
      { S: new Seq([new ZeroOrMore(new Str('x')), new Str('y'), new Str('z')]) },
      'xxxxxyz'
    );
    expect(ok).toBe(true);
    expect(err).toBe(0);
  });

  test('REP-12-repetition-at-eof-with-deletion', () => {
    // Repetition at EOF can have grammar deletion (completion)
    const [ok, _, __] = parse(
      { S: new Seq([new Str('a'), new OneOrMore(new Str('b'))]) },
      'a'
    );
    expect(ok).toBe(true);
  });

  test('REP-13-very-long-repetition', () => {
    // Performance test: many iterations
    const input = 'x'.repeat(1000);
    const [ok, err, _] = parse({ S: new OneOrMore(new Str('x')) }, input);
    expect(ok).toBe(true);
    expect(err).toBe(0);
  });

  test('REP-14-repetition-with-many-errors', () => {
    // Many errors within repetition
    const input = Array.from({ length: 100 }, () => 'Xx').join('');
    const [ok, err, _] = parse({ S: new OneOrMore(new Str('x')) }, input);
    expect(ok).toBe(true);
    expect(err).toBe(100);
  });

  test('REP-15-nested-zeromore', () => {
    // ZeroOrMore(ZeroOrMore(...)) - both can match zero
    const [ok, err, _] = parse(
      { S: new Seq([new ZeroOrMore(new ZeroOrMore(new Str('x'))), new Str('y')]) },
      'y'
    );
    expect(ok).toBe(true);
    expect(err).toBe(0);
  });
});
