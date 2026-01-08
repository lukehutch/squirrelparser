/**
 * SECTION 3: FIX #2/#3 - CACHE INTEGRITY (20 tests)
 */

import { describe, expect, test } from '@jest/globals';
import { OneOrMore, Ref, Seq, Str } from '../src';
import { parse } from './testUtils';

describe('FIX #2/#3 - CACHE INTEGRITY', () => {
  test('F2-01-Basic probe', () => {
    const [ok, err, skip] = parse(
      {
        S: new Seq([new Str('('), new OneOrMore(new Str('x')), new Str(')')]),
      },
      '(xZZx)'
    );
    expect(ok).toBe(true); // should succeed
    expect(err).toBe(1); // should have 1 error
    expect(skip.includes('ZZ')).toBe(true); // should skip ZZ
  });

  test('F2-02-Double probe', () => {
    const [ok, err, _] = parse(
      {
        S: new Seq([
          new Str('a'),
          new OneOrMore(new Str('x')),
          new Str('b'),
          new OneOrMore(new Str('y')),
          new Str('c'),
        ]),
      },
      'axXxbyYyc'
    );
    expect(ok).toBe(true); // should succeed
    expect(err).toBe(2); // should have 2 errors
  });

  test('F2-03-Probe same clause', () => {
    const [ok, err, skip] = parse(
      {
        S: new OneOrMore(new Seq([new Str('('), new OneOrMore(new Str('x')), new Str(')')])),
      },
      '(xZx)(xYx)'
    );
    expect(ok).toBe(true); // should succeed
    expect(err).toBe(2); // should have 2 errors
    expect(skip.includes('Z') && skip.includes('Y')).toBe(true); // should skip Z and Y
  });

  test('F2-04-Triple group', () => {
    const [ok, err, _] = parse(
      {
        S: new OneOrMore(new Seq([new Str('['), new OneOrMore(new Str('x')), new Str(']')])),
      },
      '[xAx][xBx][xCx]'
    );
    expect(ok).toBe(true); // should succeed
    expect(err).toBe(3); // should have 3 errors
  });

  test('F2-05-Five groups', () => {
    const [ok, err, _] = parse(
      {
        S: new OneOrMore(new Seq([new Str('('), new OneOrMore(new Str('x')), new Str(')')])),
      },
      '(xAx)(xBx)(xCx)(xDx)(xEx)'
    );
    expect(ok).toBe(true); // should succeed
    expect(err).toBe(5); // should have 5 errors
  });

  test('F2-06-Alternating clean/err', () => {
    const [ok, err, _] = parse(
      {
        S: new OneOrMore(new Seq([new Str('('), new OneOrMore(new Str('x')), new Str(')')])),
      },
      '(xx)(xZx)(xx)(xYx)(xx)'
    );
    expect(ok).toBe(true); // should succeed
    expect(err).toBe(2); // should have 2 errors
  });

  test('F2-07-Long inner error', () => {
    const [ok, err, _] = parse(
      {
        S: new Seq([new Str('('), new OneOrMore(new Str('x')), new Str(')')]),
      },
      `(x${'Z'.repeat(20)}x)`
    );
    expect(ok).toBe(true); // should succeed
    expect(err).toBe(1); // should have 1 error
  });

  test('F2-08-Nested probe', () => {
    const [ok, err, skip] = parse(
      {
        S: new Seq([
          new Str('{'),
          new Seq([new Str('('), new OneOrMore(new Str('x')), new Str(')')]),
          new Str('}'),
        ]),
      },
      '{(xZx)}'
    );
    expect(ok).toBe(true); // should succeed
    expect(err).toBe(1); // should have 1 error
    expect(skip.includes('Z')).toBe(true); // should skip Z
  });

  test('F2-09-Triple nested', () => {
    const [ok, err, skip] = parse(
      {
        S: new Seq([
          new Str('<'),
          new Seq([
            new Str('{'),
            new Seq([new Str('['), new OneOrMore(new Str('x')), new Str(']')]),
            new Str('}'),
          ]),
          new Str('>'),
        ]),
      },
      '<{[xZx]}>'
    );
    expect(ok).toBe(true); // should succeed
    expect(err).toBe(1); // should have 1 error
    expect(skip.includes('Z')).toBe(true); // should skip Z
  });

  test('F2-10-Ref probe', () => {
    const [ok, err, skip] = parse(
      {
        S: new Seq([new Str('('), new Ref('R'), new Str(')')]),
        R: new OneOrMore(new Str('x')),
      },
      '(xZx)'
    );
    expect(ok).toBe(true); // should succeed
    expect(err).toBe(1); // should have 1 error
    expect(skip.includes('Z')).toBe(true); // should skip Z
  });
});
