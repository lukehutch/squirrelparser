/**
 * SECTION 11: STRESS TESTS (20 tests)
 */

import { describe, expect, test } from '@jest/globals';
import type { Clause } from '../src';
import { First, OneOrMore, Optional, Ref, Seq, Str } from '../src';
import { parse } from './testUtils';

describe('Stress Tests', () => {
  test('ST01-1000 clean', () => {
    const [ok, err, _] = parse({ S: new OneOrMore(new Str('ab')) }, 'ab'.repeat(500));
    expect(ok).toBe(true);
    expect(err).toBe(0);
  });

  test('ST02-1000 err', () => {
    const [ok, err, _] = parse(
      { S: new OneOrMore(new Str('ab')) },
      'ab'.repeat(250) + 'XX' + 'ab'.repeat(249)
    );
    expect(ok).toBe(true);
    expect(err).toBe(1);
  });

  test('ST03-100 groups', () => {
    const [ok, err, _] = parse(
      {
        S: new OneOrMore(new Seq([new Str('('), new OneOrMore(new Str('x')), new Str(')')])),
      },
      '(xx)'.repeat(100)
    );
    expect(ok).toBe(true);
    expect(err).toBe(0);
  });

  test('ST04-100 groups err', () => {
    const input = Array.from({ length: 100 }, (_, i) => (i % 10 === 5 ? '(xZx)' : '(xx)')).join('');
    const [ok, err, _] = parse(
      {
        S: new OneOrMore(new Seq([new Str('('), new OneOrMore(new Str('x')), new Str(')')])),
      },
      input
    );
    expect(ok).toBe(true);
    expect(err).toBe(10);
  });

  test('ST05-deep nesting', () => {
    const [ok, err, _] = parse(
      {
        S: new Seq([new Str('('), new Ref('A'), new Str(')')]),
        A: new First([new Seq([new Str('('), new Ref('A'), new Str(')')]), new Str('x')]),
      },
      '('.repeat(15) + 'x' + ')'.repeat(15)
    );
    expect(ok).toBe(true);
    expect(err).toBe(0);
  });

  test('ST06-50 alts', () => {
    const alts = [...Array.from({ length: 50 }, (_, i) => new Str(`opt${i}`)), new Str('match')];
    const [ok, err, _] = parse({ S: new First(alts) }, 'match');
    expect(ok).toBe(true);
    expect(err).toBe(0);
  });

  test('ST07-500 chars', () => {
    const [ok, err, _] = parse({ S: new OneOrMore(new Str('x')) }, 'x'.repeat(500));
    expect(ok).toBe(true);
    expect(err).toBe(0);
  });

  test('ST08-500+5err', () => {
    let input = 'x'.repeat(100);
    for (let i = 0; i < 5; i++) {
      input += 'Z' + 'x'.repeat(99);
    }
    const [ok, err, _] = parse({ S: new OneOrMore(new Str('x')) }, input);
    expect(ok).toBe(true);
    expect(err).toBe(5);
  });

  test('ST09-100 seq', () => {
    const clauses = Array(100).fill(new Str('x'));
    const [ok, err, _] = parse({ S: new Seq(clauses) }, 'x'.repeat(100));
    expect(ok).toBe(true);
    expect(err).toBe(0);
  });

  test('ST10-50 optional', () => {
    const clauses: Clause[] = [
      ...Array(50).fill(new Optional(new Str('x'))),
      new Str('!'),
    ];
    const [ok, err, _] = parse({ S: new Seq(clauses) }, 'x'.repeat(25) + '!');
    expect(ok).toBe(true);
    expect(err).toBe(0);
  });

  test('ST11-nested rep', () => {
    const [ok, err, _] = parse(
      { S: new OneOrMore(new OneOrMore(new Str('x'))) },
      'x'.repeat(200)
    );
    expect(ok).toBe(true);
    expect(err).toBe(0);
  });

  test('ST12-long err span', () => {
    const [ok, err, _] = parse(
      { S: new OneOrMore(new Str('ab')) },
      'ab' + 'X'.repeat(200) + 'ab'
    );
    expect(ok).toBe(true);
    expect(err).toBe(1);
  });

  test('ST13-many short err', () => {
    const input = Array(30).fill('abX').join('') + 'ab';
    const [ok, err, _] = parse({ S: new OneOrMore(new Str('ab')) }, input);
    expect(ok).toBe(true);
    expect(err).toBe(30);
  });

  test('ST14-2000 clean', () => {
    const [ok, err, _] = parse({ S: new OneOrMore(new Str('x')) }, 'x'.repeat(2000));
    expect(ok).toBe(true);
    expect(err).toBe(0);
  });

  test('ST15-2000 err', () => {
    const [ok, err, _] = parse(
      { S: new OneOrMore(new Str('x')) },
      'x'.repeat(1000) + 'ZZ' + 'x'.repeat(998)
    );
    expect(ok).toBe(true);
    expect(err).toBe(1);
  });

  test('ST16-200 groups', () => {
    const [ok, err, _] = parse(
      {
        S: new OneOrMore(new Seq([new Str('('), new OneOrMore(new Str('x')), new Str(')')])),
      },
      '(xx)'.repeat(200)
    );
    expect(ok).toBe(true);
    expect(err).toBe(0);
  });

  test('ST17-200 groups 20err', () => {
    const input = Array.from({ length: 200 }, (_, i) => (i % 10 === 0 ? '(xZx)' : '(xx)')).join('');
    const [ok, err, _] = parse(
      {
        S: new OneOrMore(new Seq([new Str('('), new OneOrMore(new Str('x')), new Str(')')])),
      },
      input
    );
    expect(ok).toBe(true);
    expect(err).toBe(20);
  });

  test('ST18-50 errors', () => {
    const input = Array(50).fill('abZ').join('') + 'ab';
    const [ok, err, _] = parse({ S: new OneOrMore(new Str('ab')) }, input);
    expect(ok).toBe(true);
    expect(err).toBe(50);
  });

  test('ST19-deep L5', () => {
    const [ok, err, skip] = parse(
      {
        S: new Seq([
          new Str('1'),
          new Seq([
            new Str('2'),
            new Seq([
              new Str('3'),
              new Seq([
                new Str('4'),
                new Seq([new Str('5'), new OneOrMore(new Str('x')), new Str('5')]),
                new Str('4'),
              ]),
              new Str('3'),
            ]),
            new Str('2'),
          ]),
          new Str('1'),
        ]),
      },
      '12345xZx54321'
    );
    expect(ok).toBe(true);
    expect(err).toBe(1);
    expect(skip).toContain('Z');
  });

  test('ST20-very deep nest', () => {
    const [ok, err, _] = parse(
      {
        S: new Seq([new Str('('), new Ref('A'), new Str(')')]),
        A: new First([new Seq([new Str('('), new Ref('A'), new Str(')')]), new Str('x')]),
      },
      '('.repeat(20) + 'x' + ')'.repeat(20)
    );
    expect(ok).toBe(true);
    expect(err).toBe(0);
  });
});
