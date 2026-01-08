/**
 * SECTION 1: EMPTY AND BOUNDARY CONDITIONS (27 tests)
 */

import { describe, expect, test } from '@jest/globals';
import { AnyChar, CharRange, First, OneOrMore, Optional, Parser, Ref, Seq, Str, ZeroOrMore } from '../src';
import { countDeletions, parse } from './testUtils';

describe('Empty and Boundary Conditions', () => {
  test('E01-ZeroOrMore empty', () => {
    const [ok, err, _] = parse({ S: new ZeroOrMore(new Str('x')) }, '');
    expect(ok).toBe(true);
    expect(err).toBe(0);
  });

  test('E02-OneOrMore empty', () => {
    const [ok, _, __] = parse({ S: new OneOrMore(new Str('x')) }, '');
    expect(ok).toBe(false);
  });

  test('E03-Optional empty', () => {
    const [ok, err, _] = parse({ S: new Optional(new Str('x')) }, '');
    expect(ok).toBe(true);
    expect(err).toBe(0);
  });

  test('E04-Seq empty recovery', () => {
    const parser = new Parser(
      {
        S: new Seq([new Str('a'), new Str('b')]),
      },
      ''
    );
    const [result, _] = parser.parse('S');
    expect(result !== null && !result.isMismatch).toBe(true);
    expect(countDeletions(result)).toBe(2);
  });

  test('E05-First empty', () => {
    const [ok, _, __] = parse(
      {
        S: new First([new Str('a'), new Str('b')]),
      },
      ''
    );
    expect(ok).toBe(false);
  });

  test('E06-Ref empty', () => {
    const [ok, _, __] = parse({ S: new Ref('A'), A: new Str('x') }, '');
    expect(ok).toBe(false);
  });

  test('E07-Single char match', () => {
    const [ok, err, _] = parse({ S: new Str('x') }, 'x');
    expect(ok).toBe(true);
    expect(err).toBe(0);
  });

  test('E08-Single char mismatch', () => {
    const [ok, _, __] = parse({ S: new Str('x') }, 'y');
    expect(ok).toBe(false);
  });

  test('E09-ZeroOrMore single', () => {
    const [ok, err, _] = parse({ S: new ZeroOrMore(new Str('x')) }, 'x');
    expect(ok).toBe(true);
    expect(err).toBe(0);
  });

  test('E10-OneOrMore single', () => {
    const [ok, err, _] = parse({ S: new OneOrMore(new Str('x')) }, 'x');
    expect(ok).toBe(true);
    expect(err).toBe(0);
  });

  test('E11-Optional match', () => {
    const [ok, err, _] = parse({ S: new Optional(new Str('x')) }, 'x');
    expect(ok).toBe(true);
    expect(err).toBe(0);
  });

  test('E12-Two chars match', () => {
    const [ok, err, _] = parse({ S: new Str('xy') }, 'xy');
    expect(ok).toBe(true);
    expect(err).toBe(0);
  });

  test('E13-Two chars partial', () => {
    const [ok, _, __] = parse({ S: new Str('xy') }, 'x');
    expect(ok).toBe(false);
  });

  test('E14-CharRange match', () => {
    const [ok, err, _] = parse({ S: new CharRange('a', 'z') }, 'm');
    expect(ok).toBe(true);
    expect(err).toBe(0);
  });

  test('E15-CharRange boundary low', () => {
    const [ok, err, _] = parse({ S: new CharRange('a', 'z') }, 'a');
    expect(ok).toBe(true);
    expect(err).toBe(0);
  });

  test('E16-CharRange boundary high', () => {
    const [ok, err, _] = parse({ S: new CharRange('a', 'z') }, 'z');
    expect(ok).toBe(true);
    expect(err).toBe(0);
  });

  test('E17-CharRange fail low', () => {
    const [ok, _, __] = parse({ S: new CharRange('b', 'y') }, 'a');
    expect(ok).toBe(false);
  });

  test('E18-CharRange fail high', () => {
    const [ok, _, __] = parse({ S: new CharRange('b', 'y') }, 'z');
    expect(ok).toBe(false);
  });

  test('E19-AnyChar match', () => {
    const [ok, err, _] = parse({ S: new AnyChar() }, 'x');
    expect(ok).toBe(true);
    expect(err).toBe(0);
  });

  test('E20-AnyChar empty', () => {
    const [ok, _, __] = parse({ S: new AnyChar() }, '');
    expect(ok).toBe(false);
  });

  test('E21-Seq single', () => {
    const [ok, err, _] = parse(
      {
        S: new Seq([new Str('x')]),
      },
      'x'
    );
    expect(ok).toBe(true);
    expect(err).toBe(0);
  });

  test('E22-First single', () => {
    const [ok, err, _] = parse(
      {
        S: new First([new Str('x')]),
      },
      'x'
    );
    expect(ok).toBe(true);
    expect(err).toBe(0);
  });

  test('E23-Nested empty', () => {
    const [ok, err, _] = parse(
      {
        S: new Seq([new Optional(new Str('a')), new Optional(new Str('b'))]),
      },
      ''
    );
    expect(ok).toBe(true);
    expect(err).toBe(0);
  });

  test('E24-ZeroOrMore multi', () => {
    const [ok, err, _] = parse({ S: new ZeroOrMore(new Str('x')) }, 'xxx');
    expect(ok).toBe(true);
    expect(err).toBe(0);
  });

  test('E25-OneOrMore multi', () => {
    const [ok, err, _] = parse({ S: new OneOrMore(new Str('x')) }, 'xxx');
    expect(ok).toBe(true);
    expect(err).toBe(0);
  });

  test('E26-Long string match', () => {
    const [ok, err, _] = parse({ S: new Str('abcdefghij') }, 'abcdefghij');
    expect(ok).toBe(true);
    expect(err).toBe(0);
  });

  test('E27-Long string partial', () => {
    const [ok, _, __] = parse({ S: new Str('abcdefghij') }, 'abcdefghi');
    expect(ok).toBe(false);
  });
});
