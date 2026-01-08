/**
 * SECTION 4: FIX #4 - MULTI-LEVEL BOUNDED RECOVERY (35 tests)
 */

import { describe, expect, test } from '@jest/globals';
import { OneOrMore, Seq, Str } from '../src';
import { parse } from './testUtils';

describe('FIX #4 - MULTI-LEVEL BOUNDED RECOVERY', () => {
  test('F4-L1-01-clean 2', () => {
    const [ok, err, _] = parse(
      {
        S: new OneOrMore(new Seq([new Str('('), new OneOrMore(new Str('x')), new Str(')')])),
      },
      '(xx)(xx)'
    );
    expect(ok).toBe(true); // should succeed
    expect(err).toBe(0); // should have 0 errors
  });

  test('F4-L1-02-clean 5', () => {
    const [ok, err, _] = parse(
      {
        S: new OneOrMore(new Seq([new Str('('), new OneOrMore(new Str('x')), new Str(')')])),
      },
      '(xx)(xx)(xx)(xx)(xx)'
    );
    expect(ok).toBe(true); // should succeed
    expect(err).toBe(0); // should have 0 errors
  });

  test('F4-L1-03-err first', () => {
    const [ok, err, skip] = parse(
      {
        S: new OneOrMore(new Seq([new Str('('), new OneOrMore(new Str('x')), new Str(')')])),
      },
      '(xZx)(xx)'
    );
    expect(ok).toBe(true); // should succeed
    expect(err).toBe(1); // should have 1 error
    expect(skip.includes('Z')).toBe(true); // should skip Z
  });

  test('F4-L1-04-err mid', () => {
    const [ok, err, skip] = parse(
      {
        S: new OneOrMore(new Seq([new Str('('), new OneOrMore(new Str('x')), new Str(')')])),
      },
      '(xx)(xZx)(xx)'
    );
    expect(ok).toBe(true); // should succeed
    expect(err).toBe(1); // should have 1 error
    expect(skip.includes('Z')).toBe(true); // should skip Z
  });

  test('F4-L1-05-err last', () => {
    const [ok, err, skip] = parse(
      {
        S: new OneOrMore(new Seq([new Str('('), new OneOrMore(new Str('x')), new Str(')')])),
      },
      '(xx)(xZx)'
    );
    expect(ok).toBe(true); // should succeed
    expect(err).toBe(1); // should have 1 error
    expect(skip.includes('Z')).toBe(true); // should skip Z
  });

  test('F4-L1-06-err all 3', () => {
    const [ok, err, skip] = parse(
      {
        S: new OneOrMore(new Seq([new Str('('), new OneOrMore(new Str('x')), new Str(')')])),
      },
      '(xAx)(xBx)(xCx)'
    );
    expect(ok).toBe(true); // should succeed
    expect(err).toBe(3); // should have 3 errors
    expect(skip.includes('A') && skip.includes('B') && skip.includes('C')).toBe(true); // should skip A, B, C
  });

  test('F4-L1-07-boundary', () => {
    const [ok, err, skip] = parse(
      {
        S: new OneOrMore(new Seq([new Str('('), new OneOrMore(new Str('x')), new Str(')')])),
      },
      '(xx)Z(xx)'
    );
    expect(ok).toBe(true); // should succeed
    expect(err).toBe(1); // should have 1 error
    expect(skip.includes('Z')).toBe(true); // should skip Z
  });

  test('F4-L1-08-long boundary', () => {
    const [ok, err, skip] = parse(
      {
        S: new OneOrMore(new Seq([new Str('('), new OneOrMore(new Str('x')), new Str(')')])),
      },
      '(xx)ZZZ(xx)'
    );
    expect(ok).toBe(true); // should succeed
    expect(err).toBe(1); // should have 1 error
    expect(skip.includes('ZZZ')).toBe(true); // should skip ZZZ
  });

  test('F4-L2-01-clean', () => {
    const [ok, err, _] = parse(
      {
        S: new Seq([
          new Str('{'),
          new OneOrMore(new Seq([new Str('('), new OneOrMore(new Str('x')), new Str(')')])),
          new Str('}'),
        ]),
      },
      '{(xx)(xx)}'
    );
    expect(ok).toBe(true); // should succeed
    expect(err).toBe(0); // should have 0 errors
  });

  test('F4-L2-02-err inner', () => {
    const [ok, err, skip] = parse(
      {
        S: new Seq([
          new Str('{'),
          new OneOrMore(new Seq([new Str('('), new OneOrMore(new Str('x')), new Str(')')])),
          new Str('}'),
        ]),
      },
      '{(xZx)(xx)}'
    );
    expect(ok).toBe(true); // should succeed
    expect(err).toBe(1); // should have 1 error
    expect(skip.includes('Z')).toBe(true); // should skip Z
  });

  test('F4-L2-03-err outer', () => {
    const [ok, err, skip] = parse(
      {
        S: new Seq([
          new Str('{'),
          new OneOrMore(new Seq([new Str('('), new OneOrMore(new Str('x')), new Str(')')])),
          new Str('}'),
        ]),
      },
      '{(xx)Z(xx)}'
    );
    expect(ok).toBe(true); // should succeed
    expect(err).toBe(1); // should have 1 error
    expect(skip.includes('Z')).toBe(true); // should skip Z
  });

  test('F4-L2-04-both levels', () => {
    const [ok, err, _] = parse(
      {
        S: new Seq([
          new Str('{'),
          new OneOrMore(new Seq([new Str('('), new OneOrMore(new Str('x')), new Str(')')])),
          new Str('}'),
        ]),
      },
      '{(xAx)B(xCx)}'
    );
    expect(ok).toBe(true); // should succeed
    expect(err).toBe(3); // should have 3 errors
  });

  test('F4-L3-01-clean', () => {
    const [ok, err, _] = parse(
      {
        S: new Seq([
          new Str('['),
          new Seq([
            new Str('{'),
            new OneOrMore(new Seq([new Str('('), new OneOrMore(new Str('x')), new Str(')')])),
            new Str('}'),
          ]),
          new Str(']'),
        ]),
      },
      '[{(xx)(xx)}]'
    );
    expect(ok).toBe(true); // should succeed
    expect(err).toBe(0); // should have 0 errors
  });

  test('F4-L3-02-err deepest', () => {
    const [ok, err, skip] = parse(
      {
        S: new Seq([
          new Str('['),
          new Seq([
            new Str('{'),
            new OneOrMore(new Seq([new Str('('), new OneOrMore(new Str('x')), new Str(')')])),
            new Str('}'),
          ]),
          new Str(']'),
        ]),
      },
      '[{(xx)(xZx)}]'
    );
    expect(ok).toBe(true); // should succeed
    expect(err).toBe(1); // should have 1 error
    expect(skip.includes('Z')).toBe(true); // should skip Z
  });

  test('F4-N1-10 groups', () => {
    const [ok, err, _] = parse(
      {
        S: new OneOrMore(new Seq([new Str('('), new OneOrMore(new Str('x')), new Str(')')])),
      },
      '(xx)'.repeat(10)
    );
    expect(ok).toBe(true); // should succeed
    expect(err).toBe(0); // should have 0 errors
  });

  test('F4-N2-10 groups 5 err', () => {
    const input = Array.from({ length: 10 }, (_, i) => (i % 2 === 0 ? '(xZx)' : '(xx)')).join('');
    const [ok, err, _] = parse(
      {
        S: new OneOrMore(new Seq([new Str('('), new OneOrMore(new Str('x')), new Str(')')])),
      },
      input
    );
    expect(ok).toBe(true); // should succeed
    expect(err).toBe(5); // should have 5 errors
  });

  test('F4-N3-20 groups', () => {
    const [ok, err, _] = parse(
      {
        S: new OneOrMore(new Seq([new Str('('), new OneOrMore(new Str('x')), new Str(')')])),
      },
      '(xx)'.repeat(20)
    );
    expect(ok).toBe(true); // should succeed
    expect(err).toBe(0); // should have 0 errors
  });
});
