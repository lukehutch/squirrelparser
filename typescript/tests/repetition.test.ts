/**
 * SECTION 6: REPETITION COMPREHENSIVE (14 tests)
 */

import { describe, expect, test } from '@jest/globals';
import { OneOrMore, Seq, Str, ZeroOrMore, First, Ref } from '../src';
import { parse } from './testUtils';

describe('Repetition Tests', () => {
  test('R01-between', () => {
    const [ok, err, skip] = parse({ S: new OneOrMore(new Str('ab')) }, 'abXXab');
    expect(ok).toBe(true);
    expect(err).toBe(1);
    expect(skip).toContain('XX');
  });

  test('R02-multi', () => {
    const [ok, err, skip] = parse({ S: new OneOrMore(new Str('ab')) }, 'abXabYab');
    expect(ok).toBe(true);
    expect(err).toBe(2);
    expect(skip.includes('X') && skip.includes('Y')).toBe(true);
  });

  test('R03-long skip', () => {
    const [ok, err, _] = parse(
      { S: new OneOrMore(new Str('ab')) },
      'ab' + 'X'.repeat(50) + 'ab'
    );
    expect(ok).toBe(true);
    expect(err).toBe(1);
  });

  test('R04-ZeroOrMore start', () => {
    const [ok, err, skip] = parse(
      {
        S: new Seq([new ZeroOrMore(new Str('ab')), new Str('!')]),
      },
      'XXab!'
    );
    expect(ok).toBe(true);
    expect(err).toBe(1);
    expect(skip).toContain('XX');
  });

  test('R05-before first', () => {
    // FIX #10: OneOrMore now allows first-iteration recovery
    const [ok, err, skip] = parse({ S: new OneOrMore(new Str('ab')) }, 'XXab');
    expect(ok).toBe(true);
    expect(err).toBe(1);
    expect(skip).toContain('XX');
  });

  test('R06-trailing captured', () => {
    // With new invariant, trailing errors are captured in parse tree
    const [ok, err, skip] = parse({ S: new OneOrMore(new Str('ab')) }, 'ababXX');
    expect(ok).toBe(true);
    expect(err).toBe(1);
    expect(skip.includes('XX')).toBe(true);
  });

  test('R07-single', () => {
    const [ok, err, _] = parse({ S: new OneOrMore(new Str('ab')) }, 'ab');
    expect(ok).toBe(true);
    expect(err).toBe(0);
  });

  test('R08-ZeroOrMore empty', () => {
    const [ok, err, _] = parse({ S: new ZeroOrMore(new Str('ab')) }, '');
    expect(ok).toBe(true);
    expect(err).toBe(0);
  });

  test('R09-alternating', () => {
    const [ok, err, _] = parse({ S: new OneOrMore(new Str('ab')) }, 'abXabXabXab');
    expect(ok).toBe(true);
    expect(err).toBe(3);
  });

  test('R10-long clean', () => {
    const [ok, err, _] = parse({ S: new OneOrMore(new Str('x')) }, 'x'.repeat(100));
    expect(ok).toBe(true);
    expect(err).toBe(0);
  });

  test('R11-long err', () => {
    const [ok, err, skip] = parse(
      { S: new OneOrMore(new Str('x')) },
      'x'.repeat(50) + 'Z' + 'x'.repeat(49)
    );
    expect(ok).toBe(true);
    expect(err).toBe(1);
    expect(skip).toContain('Z');
  });

  test('R12-20 errors', () => {
    const input = Array.from({ length: 20 }, () => 'abZ').join('') + 'ab';
    const [ok, err, _] = parse({ S: new OneOrMore(new Str('ab')) }, input);
    expect(ok).toBe(true);
    expect(err).toBe(20);
  });

  test('R13-very long', () => {
    const [ok, err, _] = parse({ S: new OneOrMore(new Str('ab')) }, 'ab'.repeat(500));
    expect(ok).toBe(true);
    expect(err).toBe(0);
  });

  test('R14-very long err', () => {
    const [ok, err, _] = parse(
      { S: new OneOrMore(new Str('ab')) },
      'ab'.repeat(250) + 'ZZ' + 'ab'.repeat(249)
    );
    expect(ok).toBe(true);
    expect(err).toBe(1);
  });

  test('R15-trailing single char after recovery', () => {
    const [ok, err, skip] = parse(
      { S: new Ref('A'), A: new OneOrMore(new First([new Str('a'), new Str('b')])) },
      'abxbxax'
    );
    expect(ok).toBe(true);
    expect(err).toBe(3);
    expect(skip.length).toBe(3);
  });

  test('R16-trailing multiple chars after recovery', () => {
    const [ok, err, skip] = parse(
      { S: new OneOrMore(new Str('ab')) },
      'abXabXabXX'
    );
    expect(ok).toBe(true);
    expect(err).toBe(3);
    expect(skip.length).toBe(3);
  });

  test('R17-trailing long error after recovery', () => {
    const [ok, err, _] = parse(
      { S: new OneOrMore(new Str('x')) },
      'x'.repeat(50) + 'Z' + 'x'.repeat(49) + 'YYYY'
    );
    expect(ok).toBe(true);
    expect(err).toBe(2);
  });

  test('R18-trailing after multiple alternating errors', () => {
    const [ok, err, skip] = parse(
      { S: new OneOrMore(new Str('ab')) },
      'abXabYabZabXX'
    );
    expect(ok).toBe(true);
    expect(err).toBe(4);
    expect(skip.length).toBe(4);
  });

  test('R19-single char after first recovery', () => {
    const [ok, err, skip] = parse(
      { S: new OneOrMore(new Str('ab')) },
      'XXabX'
    );
    expect(ok).toBe(true);
    expect(err).toBe(2);
    expect(skip.length).toBe(2);
  });

  test('R20-trailing error with single element', () => {
    const [ok, err, skip] = parse(
      { S: new OneOrMore(new Str('a')) },
      'aXaY'
    );
    expect(ok).toBe(true);
    expect(err).toBe(2);
    expect(skip.length).toBe(2);
  });
});
