/**
 * SECTION 12: LINEARITY TESTS (10 tests)
 *
 * Verify O(N) complexity where N is input length.
 * Work should scale linearly with input size.
 */

import { squirrelParsePT } from '../src/squirrelParse.js';
import { enableParserStats, disableParserStats, parserStats } from '../src/parserStats.js';

describe('Linearity Tests', () => {
  beforeAll(() => {
    // Enable stats tracking for linearity tests
    enableParserStats();
  });

  afterAll(() => {
    // Disable stats tracking after linearity tests
    disableParserStats();
  });

  interface LinearityResult {
    passed: boolean;
    ratioChange: number;
  }

  /**
   * Test linearity helper: returns { passed, ratioChange } where ratioChange < 2 means linear.
   */
  function testLinearity(
    grammarSpec: string,
    topRule: string,
    makeInput: (size: number) => string,
    sizes: number[]
  ): LinearityResult {
    const results: { size: number; work: number; ratio: number }[] = [];

    for (const size of sizes) {
      parserStats!.reset();
      const input = makeInput(size);
      const parseResult = squirrelParsePT({
        grammarSpec,
        topRuleName: topRule,
        input,
      });
      const result = parseResult.root;

      const work = parserStats!.totalWork;
      const success = !result.isMismatch && result.len === input.length;
      const ratio = size > 0 ? work / size : 0;

      results.push({ size, work, ratio });

      if (!success) {
        return { passed: false, ratioChange: Infinity };
      }
    }

    // Check ratio doesn't increase significantly
    const ratios = results.map((r) => r.ratio);
    if (ratios.length === 0 || ratios[0] === 0) {
      return { passed: false, ratioChange: Infinity };
    }

    const ratioChange = ratios[ratios.length - 1] / ratios[0];
    return { passed: ratioChange <= 2.0, ratioChange };
  }

  test('LINEAR-01-simple-rep', () => {
    const result = testLinearity('S <- "x"+ ;', 'S', (size) => 'x'.repeat(size), [10, 50, 100, 500]);
    expect(result.passed).toBe(true);
  });

  test('LINEAR-02-direct-lr', () => {
    const grammar = `
      E <- E "+" N / N ;
      N <- [0-9] ;
    `;
    const result = testLinearity(
      grammar,
      'E',
      (size) => {
        const nums = Array.from({ length: size + 1 }, (_, i) => String(i % 10));
        return nums.join('+');
      },
      [5, 10, 20, 50]
    );
    expect(result.passed).toBe(true);
  });

  test('LINEAR-03-indirect-lr', () => {
    const grammar = `
      A <- B / "x" ;
      B <- A "y" / A "x" ;
    `;
    const result = testLinearity(
      grammar,
      'A',
      (size) => {
        let s = 'x';
        for (let i = 0; i < Math.floor(size / 2); i++) {
          s += 'xy';
        }
        return s.substring(0, size > 0 ? size : 1);
      },
      [5, 10, 20, 50]
    );
    expect(result.passed).toBe(true);
  });

  test('LINEAR-04-interwoven-lr', () => {
    const grammar = `
      L <- P ".x" / "x" ;
      P <- P "(n)" / L ;
    `;
    const result = testLinearity(
      grammar,
      'L',
      (size) => {
        const parts = ['x'];
        for (let i = 0; i < size; i++) {
          parts.push(i % 3 === 0 ? '.x' : '(n)');
        }
        return parts.join('');
      },
      [5, 10, 20, 50]
    );
    expect(result.passed).toBe(true);
  });

  test('LINEAR-05-deep-nesting', () => {
    const grammar = `
      E <- "(" E ")" / "x" ;
    `;
    const result = testLinearity(grammar, 'E', (size) => '('.repeat(size) + 'x' + ')'.repeat(size), [5, 10, 20, 50]);
    expect(result.passed).toBe(true);
  });

  test('LINEAR-06-precedence', () => {
    const grammar = `
      E <- E "+" T / T ;
      T <- T "*" F / F ;
      F <- "(" E ")" / N ;
      N <- [0-9] ;
    `;
    const result = testLinearity(
      grammar,
      'E',
      (size) => {
        const parts: string[] = [];
        for (let i = 0; i < size; i++) {
          parts.push(String(i % 10));
          if (i < size - 1) {
            parts.push(i % 2 === 0 ? '+' : '*');
          }
        }
        return parts.join('');
      },
      [5, 10, 20, 50]
    );
    expect(result.passed).toBe(true);
  });

  test('LINEAR-07-ambiguous', () => {
    const grammar = `
      E <- E "+" E / N ;
      N <- [0-9] ;
    `;
    const result = testLinearity(
      grammar,
      'E',
      (size) => {
        const nums = Array.from({ length: size + 1 }, (_, i) => String(i % 10));
        return nums.join('+');
      },
      [3, 5, 7, 10] // Smaller sizes for ambiguous grammar
    );
    expect(result.passed).toBe(true);
  });

  test('LINEAR-08-long-input', () => {
    const grammar = `
      S <- ("a" "b" "c")+ ;
    `;
    const result = testLinearity(grammar, 'S', (size) => 'abc'.repeat(size), [100, 500, 1000, 2000]);
    expect(result.passed).toBe(true);
  });

  test('LINEAR-09-long-lr', () => {
    const grammar = `
      E <- E "+" N / N ;
      N <- [0-9] ;
    `;
    const result = testLinearity(
      grammar,
      'E',
      (size) => {
        const nums = Array.from({ length: size }, (_, i) => String(i % 10));
        return nums.join('+');
      },
      [50, 100, 200, 500]
    );
    expect(result.passed).toBe(true);
  });

  test('LINEAR-10-recovery', () => {
    const grammar = `
      S <- ("(" "x"+ ")")+ ;
    `;
    const result = testLinearity(
      grammar,
      'S',
      (size) => {
        const parts: string[] = [];
        for (let i = 0; i < size; i++) {
          if (i > 0 && i % 10 === 0) {
            parts.push('(xZx)'); // Error
          } else {
            parts.push('(xx)');
          }
        }
        return parts.join('');
      },
      [10, 20, 50, 100]
    );
    expect(result.passed).toBe(true);
  });
});
