/**
 * SECTION 8: FIRST (ORDERED CHOICE) (8 tests)
 */

import { describe, expect, test } from '@jest/globals';
import { First, OneOrMore, Seq, Str } from '../src';
import { parse } from './testUtils';

describe('First (Ordered Choice) Tests', () => {
  test('FR01-match 1st', () => {
    const [ok, err, _] = parse(
      {
        S: new First([new Str('abc'), new Str('ab'), new Str('a')]),
      },
      'abc'
    );
    expect(ok).toBe(true);
    expect(err).toBe(0);
  });

  test('FR02-match 2nd', () => {
    const [ok, err, _] = parse(
      {
        S: new First([new Str('xyz'), new Str('abc')]),
      },
      'abc'
    );
    expect(ok).toBe(true);
    expect(err).toBe(0);
  });

  test('FR03-match 3rd', () => {
    const [ok, err, _] = parse(
      {
        S: new First([new Str('x'), new Str('y'), new Str('z')]),
      },
      'z'
    );
    expect(ok).toBe(true);
    expect(err).toBe(0);
  });

  test('FR04-with recovery', () => {
    const [ok, err, skip] = parse(
      {
        S: new First([
          new Seq([new OneOrMore(new Str('x')), new Str('!')]),
          new Str('fallback'),
        ]),
      },
      'xZx!'
    );
    expect(ok).toBe(true);
    expect(err).toBe(1);
    expect(skip).toContain('Z');
  });

  test('FR05-fallback', () => {
    const [ok, err, _] = parse(
      {
        S: new First([new Seq([new Str('a'), new Str('b')]), new Str('x')]),
      },
      'x'
    );
    expect(ok).toBe(true);
    expect(err).toBe(0);
  });

  test('FR06-none match', () => {
    const [ok, _, __] = parse(
      {
        S: new First([new Str('a'), new Str('b'), new Str('c')]),
      },
      'x'
    );
    expect(ok).toBe(false);
  });

  test('FR07-nested', () => {
    const [ok, err, _] = parse(
      {
        S: new First([new First([new Str('a'), new Str('b')]), new Str('c')]),
      },
      'b'
    );
    expect(ok).toBe(true);
    expect(err).toBe(0);
  });

  test('FR08-deep nested', () => {
    const [ok, err, _] = parse(
      {
        S: new First([new First([new First([new Str('a')])])]),
      },
      'a'
    );
    expect(ok).toBe(true);
    expect(err).toBe(0);
  });
});
