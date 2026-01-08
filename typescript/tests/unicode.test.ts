/**
 * SECTION 10: UNICODE AND SPECIAL (10 tests)
 */

import { describe, expect, test } from '@jest/globals';
import { OneOrMore, Seq, Str } from '../src';
import { parse } from './testUtils';

describe('Unicode and Special Character Tests', () => {
  test('U01-Greek', () => {
    const [ok, err, skip] = parse({ S: new OneOrMore(new Str('α')) }, 'αβα');
    expect(ok).toBe(true);
    expect(err).toBe(1);
    expect(skip).toContain('β');
  });

  test('U02-Chinese', () => {
    const [ok, err, skip] = parse({ S: new OneOrMore(new Str('中')) }, '中文中');
    expect(ok).toBe(true);
    expect(err).toBe(1);
    expect(skip).toContain('文');
  });

  test('U03-Arabic clean', () => {
    const [ok, err, _] = parse({ S: new OneOrMore(new Str('م')) }, 'ممم');
    expect(ok).toBe(true);
    expect(err).toBe(0);
  });

  test('U04-newline', () => {
    const [ok, err, skip] = parse({ S: new OneOrMore(new Str('x')) }, 'x\nx');
    expect(ok).toBe(true);
    expect(err).toBe(1);
    expect(skip).toContain('\n');
  });

  test('U05-tab', () => {
    const [ok, err, _] = parse(
      {
        S: new Seq([new Str('a'), new Str('\t'), new Str('b')]),
      },
      'a\tb'
    );
    expect(ok).toBe(true);
    expect(err).toBe(0);
  });

  test('U06-space', () => {
    const [ok, err, skip] = parse({ S: new OneOrMore(new Str('x')) }, 'x x');
    expect(ok).toBe(true);
    expect(err).toBe(1);
    expect(skip).toContain(' ');
  });

  test('U07-multi space', () => {
    const [ok, err, skip] = parse({ S: new OneOrMore(new Str('x')) }, 'x   x');
    expect(ok).toBe(true);
    expect(err).toBe(1);
    expect(skip).toContain('   ');
  });

  test('U08-Japanese', () => {
    const [ok, err, skip] = parse({ S: new OneOrMore(new Str('日')) }, '日本日');
    expect(ok).toBe(true);
    expect(err).toBe(1);
    expect(skip).toContain('本');
  });

  test('U09-Korean', () => {
    const [ok, err, skip] = parse({ S: new OneOrMore(new Str('한')) }, '한글한');
    expect(ok).toBe(true);
    expect(err).toBe(1);
    expect(skip).toContain('글');
  });

  test('U10-mixed scripts', () => {
    const [ok, err, _] = parse(
      {
        S: new Seq([new Str('α'), new Str('中'), new Str('!')]),
      },
      'α中!'
    );
    expect(ok).toBe(true);
    expect(err).toBe(0);
  });
});
