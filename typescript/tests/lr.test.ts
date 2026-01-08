/**
 * SECTION 9: LEFT RECURSION (10 tests)
 */

import { describe, expect, test } from '@jest/globals';
import { CharRange, First, OneOrMore, Ref, Seq, Str } from '../src';
import { parse } from './testUtils';

describe('Left Recursion Tests', () => {
  const lr1 = {
    S: new First([new Seq([new Ref('S'), new Str('+'), new Ref('T')]), new Ref('T')]),
    T: new OneOrMore(new CharRange('0', '9')),
  };

  test('LR01-simple', () => {
    const [ok, err, _] = parse(lr1, '1+2+3');
    expect(ok).toBe(true);
    expect(err).toBe(0);
  });

  test('LR02-single', () => {
    const [ok, err, _] = parse(lr1, '42');
    expect(ok).toBe(true);
    expect(err).toBe(0);
  });

  test('LR03-chain 5', () => {
    const [ok, err, _] = parse(lr1, Array(5).fill('1').join('+'));
    expect(ok).toBe(true);
    expect(err).toBe(0);
  });

  test('LR04-chain 10', () => {
    const [ok, err, _] = parse(lr1, Array(10).fill('1').join('+'));
    expect(ok).toBe(true);
    expect(err).toBe(0);
  });

  const expr = {
    S: new Ref('E'),
    E: new First([new Seq([new Ref('E'), new Str('+'), new Ref('T')]), new Ref('T')]),
    T: new First([new Seq([new Ref('T'), new Str('*'), new Ref('F')]), new Ref('F')]),
    F: new First([
      new Seq([new Str('('), new Ref('E'), new Str(')')]),
      new CharRange('0', '9'),
    ]),
  };

  test('LR05-with mult', () => {
    const [ok, err, _] = parse(expr, '1+2*3');
    expect(ok).toBe(true);
    expect(err).toBe(0);
  });

  test('LR06-parens', () => {
    const [ok, err, _] = parse(expr, '(1+2)*3');
    expect(ok).toBe(true);
    expect(err).toBe(0);
  });

  test('LR07-nested parens', () => {
    const [ok, err, _] = parse(expr, '((1+2))');
    expect(ok).toBe(true);
    expect(err).toBe(0);
  });

  test('LR08-direct', () => {
    const [ok, err, _] = parse(
      {
        S: new First([new Seq([new Ref('S'), new Str('x')]), new Str('y')]),
      },
      'yxxx'
    );
    expect(ok).toBe(true);
    expect(err).toBe(0);
  });

  test('LR09-multi-digit', () => {
    const [ok, err, _] = parse(lr1, '12+345+6789');
    expect(ok).toBe(true);
    expect(err).toBe(0);
  });

  test('LR10-complex expr', () => {
    const [ok, err, _] = parse(expr, '1+2*3+4*5');
    expect(ok).toBe(true);
    expect(err).toBe(0);
  });
});
