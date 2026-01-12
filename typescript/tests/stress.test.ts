/**
 * SECTION 11: STRESS TESTS (20 tests)
 */

import { testParse } from './testUtils.js';

describe('Stress Tests', () => {
  test('ST01-1000 clean', () => {
    const r = testParse('S <- "ab"+ ;', 'ab'.repeat(500));
    expect(r.ok).toBe(true);
    expect(r.errorCount).toBe(0);
  });

  test('ST02-1000 err', () => {
    const r = testParse('S <- "ab"+ ;', 'ab'.repeat(250) + 'XX' + 'ab'.repeat(249));
    expect(r.ok).toBe(true);
    expect(r.errorCount).toBe(1);
  });

  test('ST03-100 groups', () => {
    const grammar = 'S <- ("(" "x"+ ")")+ ;';
    const r = testParse(grammar, '(xx)'.repeat(100));
    expect(r.ok).toBe(true);
    expect(r.errorCount).toBe(0);
  });

  test('ST04-100 groups err', () => {
    const input = Array.from({ length: 100 }, (_, i) => (i % 10 === 5 ? '(xZx)' : '(xx)')).join('');
    const grammar = 'S <- ("(" "x"+ ")")+ ;';
    const r = testParse(grammar, input);
    expect(r.ok).toBe(true);
    expect(r.errorCount).toBe(10);
  });

  test('ST05-deep nesting', () => {
    const grammar = `
      S <- "(" A ")" ;
      A <- "(" A ")" / "x" ;
    `;
    const r = testParse(grammar, '('.repeat(15) + 'x' + ')'.repeat(15));
    expect(r.ok).toBe(true);
    expect(r.errorCount).toBe(0);
  });

  test('ST06-50 alts', () => {
    const alts = Array.from({ length: 50 }, (_, i) => `"opt${i}"`).join(' / ');
    const grammar = `S <- ${alts} / "match" ;`;
    const r = testParse(grammar, 'match');
    expect(r.ok).toBe(true);
    expect(r.errorCount).toBe(0);
  });

  test('ST07-500 chars', () => {
    const r = testParse('S <- "x"+ ;', 'x'.repeat(500));
    expect(r.ok).toBe(true);
    expect(r.errorCount).toBe(0);
  });

  test('ST08-500+5err', () => {
    let input = 'x'.repeat(100);
    for (let i = 0; i < 5; i++) {
      input += 'Z' + 'x'.repeat(99);
    }
    const r = testParse('S <- "x"+ ;', input);
    expect(r.ok).toBe(true);
    expect(r.errorCount).toBe(5);
  });

  test('ST09-100 seq', () => {
    const elems = Array.from({ length: 100 }, () => '"x"').join(' ');
    const grammar = `S <- ${elems} ;`;
    const r = testParse(grammar, 'x'.repeat(100));
    expect(r.ok).toBe(true);
    expect(r.errorCount).toBe(0);
  });

  test('ST10-50 optional', () => {
    const elems = Array.from({ length: 50 }, () => '"x"?').join(' ');
    const grammar = `S <- ${elems} "!" ;`;
    const r = testParse(grammar, 'x'.repeat(25) + '!');
    expect(r.ok).toBe(true);
    expect(r.errorCount).toBe(0);
  });

  test('ST11-nested rep', () => {
    const grammar = 'S <- ("x"+)+ ;';
    const r = testParse(grammar, 'x'.repeat(200));
    expect(r.ok).toBe(true);
    expect(r.errorCount).toBe(0);
  });

  test('ST12-long err span', () => {
    const r = testParse('S <- "ab"+ ;', 'ab' + 'X'.repeat(200) + 'ab');
    expect(r.ok).toBe(true);
    expect(r.errorCount).toBe(1);
  });

  test('ST13-many short err', () => {
    const input = Array.from({ length: 30 }, () => 'abX').join('') + 'ab';
    const r = testParse('S <- "ab"+ ;', input);
    expect(r.ok).toBe(true);
    expect(r.errorCount).toBe(30);
  });

  test('ST14-2000 clean', () => {
    const r = testParse('S <- "x"+ ;', 'x'.repeat(2000));
    expect(r.ok).toBe(true);
    expect(r.errorCount).toBe(0);
  });

  test('ST15-2000 err', () => {
    const r = testParse('S <- "x"+ ;', 'x'.repeat(1000) + 'ZZ' + 'x'.repeat(998));
    expect(r.ok).toBe(true);
    expect(r.errorCount).toBe(1);
  });

  test('ST16-200 groups', () => {
    const grammar = 'S <- ("(" "x"+ ")")+ ;';
    const r = testParse(grammar, '(xx)'.repeat(200));
    expect(r.ok).toBe(true);
    expect(r.errorCount).toBe(0);
  });

  test('ST17-200 groups 20err', () => {
    const input = Array.from({ length: 200 }, (_, i) => (i % 10 === 0 ? '(xZx)' : '(xx)')).join('');
    const grammar = 'S <- ("(" "x"+ ")")+ ;';
    const r = testParse(grammar, input);
    expect(r.ok).toBe(true);
    expect(r.errorCount).toBe(20);
  });

  test('ST18-50 errors', () => {
    const input = Array.from({ length: 50 }, () => 'abZ').join('') + 'ab';
    const r = testParse('S <- "ab"+ ;', input);
    expect(r.ok).toBe(true);
    expect(r.errorCount).toBe(50);
  });

  test('ST19-deep L5', () => {
    const grammar = `
      S <- "1" (
        "2" (
          "3" (
            "4" (
              "5" "x"+ "5"
            ) "4"
          ) "3"
        ) "2"
      ) "1" ;
    `;
    const r = testParse(grammar, '12345xZx54321');
    expect(r.ok).toBe(true);
    expect(r.errorCount).toBe(1);
    expect(r.skippedStrings.includes('Z')).toBe(true);
  });

  test('ST20-very deep nest', () => {
    const grammar = `
      S <- "(" A ")" ;
      A <- "(" A ")" / "x" ;
    `;
    const r = testParse(grammar, '('.repeat(20) + 'x' + ')'.repeat(20));
    expect(r.ok).toBe(true);
    expect(r.errorCount).toBe(0);
  });
});
