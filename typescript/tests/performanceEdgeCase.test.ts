/**
 * PERFORMANCE & EDGE CASE TESTS
 *
 * These tests verify performance characteristics and edge cases.
 */

import { testParse } from './testUtils.js';
import { squirrelParsePT } from '../src/squirrelParse.js';
import { Parser } from '../src/parser.js';
import { SyntaxError } from '../src/matchResult.js';

describe('Performance Tests', () => {
  test('PERF-01-very-long-input', () => {
    // 10,000 character input should parse in reasonable time
    const input = 'x'.repeat(10000);
    const startTime = Date.now();
    const r = testParse('S <- "x"+ ;', input);
    const elapsed = Date.now() - startTime;

    expect(r.ok).toBe(true);
    expect(r.errorCount).toBe(0);
    expect(elapsed).toBeLessThan(1000);
  });

  test('PERF-02-deep-nesting', () => {
    // 50 levels of Seq nesting
    let inner = '"x"';
    for (let i = 0; i < 50; i++) {
      inner = `(${inner} "y")`;
    }
    const grammarSpec = `S <- ${inner} ;`;
    const input = 'x' + 'y'.repeat(50);

    const r = testParse(grammarSpec, input);
    expect(r.ok).toBe(true);
  });

  test('PERF-03-wide-first', () => {
    // First with 50 alternatives (using padded numbers to avoid prefix issues)
    const alternatives = Array.from({ length: 50 }, (_, i) => `"opt_${i.toString().padStart(3, '0')}"`).join(' / ');
    const grammarSpec = `S <- ${alternatives} ;`;

    const r = testParse(grammarSpec, 'opt_049');
    expect(r.ok).toBe(true);
  });

  test('PERF-04-many-repetitions', () => {
    // 1000 iterations of OneOrMore
    const input = 'x'.repeat(1000);
    const r = testParse('S <- "x"+ ;', input);
    expect(r.ok).toBe(true);
  });

  test('PERF-05-many-errors', () => {
    // 500 errors in input
    const input = Array.from({ length: 500 }, () => 'Xx').join('');
    const r = testParse('S <- "x"+ ;', input);
    expect(r.ok).toBe(true);
    expect(r.errorCount).toBe(500);
  });

  test('PERF-06-lr-expansion-depth', () => {
    // LR with 100 expansions
    const input = Array.from({ length: 100 }, () => '+n')
      .join('')
      .substring(1); // n+n+n+...
    const r = testParse('E <- E "+" "n" / "n" ;', input, 'E');
    expect(r.ok).toBe(true);
  });

  test('PERF-07-cache-efficiency', () => {
    // Same clause at many positions - cache should help
    const input = 'x'.repeat(100);
    const grammar = `
      S <- X+ ;
      X <- "x" ;
    `;
    const r = testParse(grammar, input);
    expect(r.ok).toBe(true);
  });
});

describe('Edge Case Tests', () => {
  test('EDGE-01-empty-input', () => {
    // Various grammars with empty input
    const zm = testParse('S <- "x"* ;', '');
    expect(zm.ok).toBe(true);

    const om = testParse('S <- "x"+ ;', '');
    expect(om.ok).toBe(false);

    const opt = testParse('S <- "x"? ;', '');
    expect(opt.ok).toBe(true);

    // Empty sequence (no elements) matches empty input
    const parseResult = squirrelParsePT({
      grammarSpec: 'S <- ""? ;', // Optional empty string
      topRuleName: 'S',
      input: '',
    });
    expect(!parseResult.root.isMismatch).toBe(true);
  });

  test('EDGE-02-input-with-only-errors', () => {
    // Input is all garbage
    const r = testParse('S <- "abc" ;', 'XYZ');
    expect(r.ok).toBe(false);
  });

  test('EDGE-03-grammar-with-only-optional-zeromore', () => {
    // Grammar that accepts empty: Seq([ZeroOrMore(...), Optional(...)])
    const r = testParse('S <- "x"* "y"? ;', '');
    expect(r.ok).toBe(true);
    expect(r.errorCount).toBe(0);
  });

  test('EDGE-04-single-char-terminals', () => {
    // All single-character terminals
    const r = testParse('S <- "a" "b" "c" ;', 'abc');
    expect(r.ok).toBe(true);
    expect(r.errorCount).toBe(0);
  });

  test('EDGE-05-very-long-terminal', () => {
    // Multi-hundred-char terminal
    const longStr = 'x'.repeat(500);
    const r = testParse(`S <- "${longStr}" ;`, longStr);
    expect(r.ok).toBe(true);
  });

  test('EDGE-06-unicode-handling', () => {
    // Unicode characters in terminals and input
    const r = testParse('S <- "\u3053\u3093\u306b\u3061\u306f" "\u4e16\u754c" ;', '\u3053\u3093\u306b\u3061\u306f\u4e16\u754c');
    expect(r.ok).toBe(true);
    expect(r.errorCount).toBe(0);
  });

  test('EDGE-07-mixed-unicode-and-ascii', () => {
    // Mix of Unicode and ASCII with errors
    const r = testParse('S <- "hello" "\u4e16\u754c" ;', 'helloX\u4e16\u754c');
    expect(r.ok).toBe(true);
    expect(r.errorCount).toBe(1);
    expect(r.skippedStrings.includes('X')).toBe(true);
  });

  test('EDGE-08-newlines-and-whitespace', () => {
    // Newlines and whitespace as errors
    const r = testParse('S <- "a" "b" ;', 'a\n\tb');
    expect(r.ok).toBe(true);
    expect(r.errorCount).toBe(1);
  });

  test('EDGE-09-eof-at-various-positions', () => {
    // EOF at different points in grammar
    const cases = [
      { input: 'ab', expectedLen: 2 }, // EOF after full match
      { input: 'a', expectedLen: 1 }, // EOF after partial match
      { input: '', expectedLen: 0 }, // EOF at start
    ];

    for (const { input } of cases) {
      const parseResult = squirrelParsePT({
        grammarSpec: 'S <- "a" "b" ;',
        topRuleName: 'S',
        input,
      });
      const result = parseResult.root;
      expect(!(result instanceof SyntaxError) || input === '').toBe(true);
    }
  });

  test('EDGE-10-recovery-with-moderate-skip', () => {
    // Recovery with moderate skip distance
    const r = testParse('S <- "a" "b" "c" ;', 'aXXXXXXXXXbc');
    expect(r.ok).toBe(true);
    expect(r.errorCount).toBe(1);
    expect(r.skippedStrings[0].length).toBeGreaterThan(5);
  });

  test('EDGE-11-alternating-success-failure', () => {
    // Pattern that alternates between success and failure
    const r = testParse('S <- ("a" "b")+ ;', 'abXabYabZab');
    expect(r.ok).toBe(true);
    expect(r.errorCount).toBe(3);
  });

  test('EDGE-12-boundary-at-every-position', () => {
    // Multiple sequences with delimiters
    const r = testParse('S <- "a"+ "," "b"+ "," "c"+ ;', 'aaa,bbb,ccc');
    expect(r.ok).toBe(true);
  });

  test('EDGE-13-no-grammar-rules', () => {
    // Empty grammar (edge case that should fail gracefully)
    expect(() => {
      new Parser({ rules: new Map(), topRuleName: 'S', input: 'x' }).parse();
    }).toThrow();
  });

  test('EDGE-14-circular-ref-with-base-case', () => {
    // A -> A | 'x' (left-recursive with base case)
    // Should work correctly with LR detection
    const parseResult = squirrelParsePT({
      grammarSpec: 'A <- A "y" / "x" ;',
      topRuleName: 'A',
      input: 'xy',
    });
    const result = parseResult.root;
    expect(!result.isMismatch).toBe(true);
  });

  test('EDGE-15-all-printable-ascii', () => {
    // Test all printable ASCII characters
    const ascii = Array.from({ length: 95 }, (_, i) => String.fromCharCode(i + 32)).join('');

    // Escape special characters for the grammar spec string literal
    const escaped = ascii.replace(/\\/g, '\\\\').replace(/"/g, '\\"').replace(/\n/g, '\\n').replace(/\r/g, '\\r').replace(/\t/g, '\\t');

    const r = testParse(`S <- "${escaped}" ;`, ascii);
    expect(r.ok).toBe(true);
  });
});
