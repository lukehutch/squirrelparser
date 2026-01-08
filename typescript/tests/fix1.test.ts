/**
 * SECTION 2: FIX #1 - isComplete PROPAGATION (25 tests)
 */

import { describe, expect, test } from '@jest/globals';
import { First, OneOrMore, Optional, Seq, Str, ZeroOrMore } from '../src';
import { parse } from './testUtils';

describe('FIX #1 - isComplete PROPAGATION', () => {
  test('F1-01-Rep+Seq basic', () => {
    const [ok, err, skip] = parse(
      {
        S: new Seq([new OneOrMore(new Str('ab')), new Str('!')]),
      },
      'abXXab!'
    );
    expect(ok).toBe(true); // should succeed
    expect(err).toBe(1); // should have 1 error, got {err}
    expect(skip.includes('XX')).toBe(true); // should skip XX
  });

  test('F1-02-Rep+Optional', () => {
    const [ok, err, skip] = parse(
      {
        S: new Seq([new OneOrMore(new Str('ab')), new Optional(new Str('!'))]),
      },
      'abXXab'
    );
    expect(ok).toBe(true); // should succeed
    expect(err).toBe(1); // should have 1 error
    expect(skip.includes('XX')).toBe(true); // should skip XX
  });

  test('F1-03-Rep+Optional+match', () => {
    const [ok, err, skip] = parse(
      {
        S: new Seq([new OneOrMore(new Str('ab')), new Optional(new Str('!'))]),
      },
      'abXXab!'
    );
    expect(ok).toBe(true); // should succeed
    expect(err).toBe(1); // should have 1 error
    expect(skip.includes('XX')).toBe(true); // should skip XX
  });

  test('F1-04-First wrapping', () => {
    const [ok, err, _] = parse(
      {
        S: new First([new Seq([new OneOrMore(new Str('ab')), new Str('!')])]),
      },
      'abXXab!'
    );
    expect(ok).toBe(true); // should succeed
    expect(err).toBe(1); // should have 1 error
  });

  test('F1-05-Nested Seq L1', () => {
    const [ok, err, skip] = parse(
      {
        S: new Seq([new Seq([new OneOrMore(new Str('x'))])]),
      },
      'xZx'
    );
    expect(ok).toBe(true); // should succeed
    expect(err).toBe(1); // should have 1 error
    expect(skip.includes('Z')).toBe(true); // should skip Z
  });

  test('F1-06-Nested Seq L2', () => {
    const [ok, err, skip] = parse(
      {
        S: new Seq([new Seq([new Seq([new OneOrMore(new Str('x'))])])]),
      },
      'xZx'
    );
    expect(ok).toBe(true); // should succeed
    expect(err).toBe(1); // should have 1 error
    expect(skip.includes('Z')).toBe(true); // should skip Z
  });

  test('F1-07-Nested Seq L3', () => {
    const [ok, err, skip] = parse(
      {
        S: new Seq([new Seq([new Seq([new Seq([new OneOrMore(new Str('x'))])])])]),
      },
      'xZx'
    );
    expect(ok).toBe(true); // should succeed
    expect(err).toBe(1); // should have 1 error
    expect(skip.includes('Z')).toBe(true); // should skip Z
  });

  test('F1-08-Optional wrapping', () => {
    const [ok, err, skip] = parse(
      {
        S: new Optional(new Seq([new OneOrMore(new Str('x'))])),
      },
      'xZx'
    );
    expect(ok).toBe(true); // should succeed
    expect(err).toBe(1); // should have 1 error
    expect(skip.includes('Z')).toBe(true); // should skip Z
  });

  test('F1-09-ZeroOrMore in Seq', () => {
    const [ok, err, skip] = parse(
      {
        S: new Seq([new ZeroOrMore(new Str('ab')), new Str('!')]),
      },
      'abXXab!'
    );
    expect(ok).toBe(true); // should succeed
    expect(err).toBe(1); // should have 1 error
    expect(skip.includes('XX')).toBe(true); // should skip XX
  });

  test('F1-10-Multiple Reps', () => {
    const [ok, err, _] = parse(
      {
        S: new Seq([new OneOrMore(new Str('a')), new OneOrMore(new Str('b'))]),
      },
      'aXabYb'
    );
    expect(ok).toBe(true); // should succeed
    expect(err).toBe(2); // should have 2 errors
  });

  test('F1-11-Rep+Rep+Term', () => {
    const [ok, err, _] = parse(
      {
        S: new Seq([new OneOrMore(new Str('a')), new OneOrMore(new Str('b')), new Str('!')]),
      },
      'aXabYb!'
    );
    expect(ok).toBe(true); // should succeed
    expect(err).toBe(2); // should have 2 errors
  });

  test('F1-12-Long error span', () => {
    const [ok, err, _] = parse(
      {
        S: new Seq([new OneOrMore(new Str('x')), new Str('!')]),
      },
      `x${'Z'.repeat(20)}x!`
    );
    expect(ok).toBe(true); // should succeed
    expect(err).toBe(1); // should have 1 error
  });

  test('F1-13-Multiple long errors', () => {
    const [ok, err, _] = parse(
      { S: new OneOrMore(new Str('ab')) },
      `ab${'X'.repeat(10)}ab${'Y'.repeat(10)}ab`
    );
    expect(ok).toBe(true); // should succeed
    expect(err).toBe(2); // should have 2 errors
  });

  test('F1-14-Interspersed errors', () => {
    const [ok, err, _] = parse({ S: new OneOrMore(new Str('ab')) }, 'abXabYabZab');
    expect(ok).toBe(true); // should succeed
    expect(err).toBe(3); // should have 3 errors
  });

  test('F1-15-Five errors', () => {
    const [ok, err, _] = parse({ S: new OneOrMore(new Str('ab')) }, 'abAabBabCabDabEab');
    expect(ok).toBe(true); // should succeed
    expect(err).toBe(5); // should have 5 errors
  });
});
