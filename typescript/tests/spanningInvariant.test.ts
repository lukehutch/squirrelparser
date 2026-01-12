// ===========================================================================
// PARSE TREE SPANNING INVARIANT TESTS
// ===========================================================================
// These tests verify that Parser.parse() always returns a MatchResult
// that completely spans the input (from position 0 to input.length).
// - Total failures: SyntaxError spanning entire input
// - Partial matches: wrapped with trailing SyntaxError
// - Complete matches: result spans full input with no wrapper needed

import { squirrelParsePT } from '../src/squirrelParse.js';
import { ParseResult } from '../src/parser.js';
import { Match, SyntaxError, type MatchResult } from '../src/matchResult.js';

/**
 * Helper to get a MatchResult that spans the entire input.
 * If there's an unmatchedInput, this wraps root and unmatchedInput together.
 */
function getSpanningResult(parseResult: ParseResult): MatchResult {
  if (parseResult.unmatchedInput === undefined) {
    return parseResult.root;
  }

  const root = parseResult.root;

  // Total failure case: root is already SyntaxError spanning entire input
  if (root instanceof SyntaxError && root.len === parseResult.input.length) {
    return root;
  }

  // Create a synthetic Match that contains both root and unmatchedInput as children
  let children: MatchResult[];
  let errorCount: number;

  if (root instanceof SyntaxError) {
    children = [root, parseResult.unmatchedInput];
    errorCount = 2;
  } else {
    const rootMatch = root as Match;
    if (rootMatch.subClauseMatches.length === 0) {
      children = [root, parseResult.unmatchedInput];
    } else {
      children = [...rootMatch.subClauseMatches, parseResult.unmatchedInput];
    }
    errorCount = rootMatch.totDescendantErrors + 1;
  }

  return new Match(root.clause, 0, parseResult.input.length, {
    subClauseMatches: children,
    isComplete: true,
    numSyntaxErrors: errorCount,
    addSubClauseErrors: false,
  });
}

function hasTrailingError(result: MatchResult, pos: number, len: number): boolean {
  if (result instanceof SyntaxError) {
    if (result.pos === pos && result.len === len) {
      return true;
    }
  }
  for (const child of result.subClauseMatches) {
    if (hasTrailingError(child, pos, len)) return true;
  }
  return false;
}

function hasSyntaxError(result: MatchResult): boolean {
  if (result instanceof SyntaxError) return true;
  for (const child of result.subClauseMatches) {
    if (hasSyntaxError(child)) return true;
  }
  return false;
}

function collectErrors(result: MatchResult): SyntaxError[] {
  const errors: SyntaxError[] = [];
  const collect = (r: MatchResult) => {
    if (r instanceof SyntaxError) {
      errors.push(r);
    }
    for (const child of r.subClauseMatches) {
      collect(child);
    }
  };
  collect(result);
  return errors;
}

describe('Parse Tree Spanning Invariant Tests', () => {
  test('SPAN-01-empty-input', () => {
    const parseResult = squirrelParsePT({
      grammarSpec: 'S <- "a" ;',
      topRuleName: 'S',
      input: '',
    });
    const result = getSpanningResult(parseResult);

    expect(result instanceof SyntaxError).toBe(true);
    expect(result.len).toBe(0);
    expect(result.pos).toBe(0);
  });

  test('SPAN-02-complete-match-no-wrapper', () => {
    const parseResult = squirrelParsePT({
      grammarSpec: 'S <- "a" "b" "c" ;',
      topRuleName: 'S',
      input: 'abc',
    });
    const result = getSpanningResult(parseResult);

    expect(result instanceof SyntaxError).toBe(false);
    expect(result.len).toBe(3);
    expect(result.isMismatch).toBe(false);
  });

  test('SPAN-03-total-failure-returns-syntax-error', () => {
    const parseResult = squirrelParsePT({
      grammarSpec: 'S <- "a" ;',
      topRuleName: 'S',
      input: 'xyz',
    });
    const result = getSpanningResult(parseResult);

    expect(result instanceof SyntaxError).toBe(true);
    expect(result.len).toBe(3);
  });

  test('SPAN-04-trailing-garbage-wrapped', () => {
    const parseResult = squirrelParsePT({
      grammarSpec: 'S <- "a" "b" ;',
      topRuleName: 'S',
      input: 'abXYZ',
    });
    const result = getSpanningResult(parseResult);

    expect(result.len).toBe(5);
    expect(result instanceof SyntaxError).toBe(false);
    expect(hasTrailingError(result, 2, 3)).toBe(true);
  });

  test('SPAN-05-single-char-trailing', () => {
    const parseResult = squirrelParsePT({
      grammarSpec: 'S <- "a" ;',
      topRuleName: 'S',
      input: 'aX',
    });
    const result = getSpanningResult(parseResult);

    expect(parseResult.unmatchedInput).not.toBeUndefined();
    expect(result.len).toBe(2);
    expect(result instanceof SyntaxError).toBe(false);
    expect(hasTrailingError(result, 1, 1)).toBe(true);
  });

  test('SPAN-06-multiple-errors-throughout', () => {
    const parseResult = squirrelParsePT({
      grammarSpec: 'S <- "a" "b" "c" ;',
      topRuleName: 'S',
      input: 'aXbYc',
    });
    const result = getSpanningResult(parseResult);

    expect(result.len).toBe(5);

    const errors = collectErrors(result);
    expect(errors.length).toBe(2);
  });

  test('SPAN-07-recovery-with-deletion', () => {
    const parseResult = squirrelParsePT({
      grammarSpec: 'S <- "a" "b" "c" ;',
      topRuleName: 'S',
      input: 'ab',
    });
    const result = getSpanningResult(parseResult);

    expect(result.len).toBe(2);
    expect(result instanceof SyntaxError).toBe(false);
  });

  test('SPAN-08-first-alternative-with-trailing', () => {
    const parseResult = squirrelParsePT({
      grammarSpec: 'S <- "a" "b" "c" / "a" ;',
      topRuleName: 'S',
      input: 'abcX',
    });
    const result = getSpanningResult(parseResult);

    expect(result.len).toBe(4);
    expect(hasSyntaxError(result)).toBe(true);
  });

  test('SPAN-09-left-recursion-with-trailing', () => {
    const parseResult = squirrelParsePT({
      grammarSpec: 'E <- E "+" "n" / "n" ;',
      topRuleName: 'E',
      input: 'n+nX',
    });
    const result = getSpanningResult(parseResult);

    expect(result.len).toBe(4);
    expect(hasSyntaxError(result)).toBe(true);
  });

  test('SPAN-10-repetition-with-trailing', () => {
    const parseResult = squirrelParsePT({
      grammarSpec: 'S <- "a"+ ;',
      topRuleName: 'S',
      input: 'aaaX',
    });
    const result = getSpanningResult(parseResult);

    expect(result.len).toBe(4);
    expect(hasSyntaxError(result)).toBe(true);
  });

  test('SPAN-11-nested-rules-with-trailing', () => {
    const parseResult = squirrelParsePT({
      grammarSpec: `
        S <- A ";" ;
        A <- "a" "b" ;
      `,
      topRuleName: 'S',
      input: 'ab;X',
    });
    const result = getSpanningResult(parseResult);

    expect(result.len).toBe(4);
  });

  test('SPAN-12-zero-or-more-with-trailing', () => {
    const parseResult = squirrelParsePT({
      grammarSpec: 'S <- "a"* ;',
      topRuleName: 'S',
      input: 'XYZ',
    });
    const result = getSpanningResult(parseResult);

    expect(result.len).toBe(3);
    expect(result instanceof SyntaxError).toBe(false);
    expect(hasSyntaxError(result)).toBe(true);
  });

  test('SPAN-13-optional-with-trailing', () => {
    const parseResult = squirrelParsePT({
      grammarSpec: 'S <- "a"? ;',
      topRuleName: 'S',
      input: 'XYZ',
    });
    const result = getSpanningResult(parseResult);

    expect(result.len).toBe(3);
    expect(hasSyntaxError(result)).toBe(true);
  });

  test('SPAN-14-followed-by-success-with-trailing', () => {
    const parseResult = squirrelParsePT({
      grammarSpec: 'S <- &"a" "a" "b" ;',
      topRuleName: 'S',
      input: 'abX',
    });
    const result = getSpanningResult(parseResult);

    expect(result.len).toBe(3);
    expect(hasTrailingError(result, 2, 1)).toBe(true);
  });

  test('SPAN-15-not-followed-by-failure-total', () => {
    const parseResult = squirrelParsePT({
      grammarSpec: 'S <- !"x" "y" ;',
      topRuleName: 'S',
      input: 'xz',
    });
    const result = getSpanningResult(parseResult);

    expect(result instanceof SyntaxError).toBe(true);
    expect(result.len).toBe(2);
  });

  test('SPAN-16-not-followed-by-success-with-trailing', () => {
    const parseResult = squirrelParsePT({
      grammarSpec: 'S <- "b" "c"? ;',
      topRuleName: 'S',
      input: 'bX',
    });
    const result = getSpanningResult(parseResult);

    expect(result.len).toBe(2);
    expect(hasTrailingError(result, 1, 1)).toBe(true);
  });

  test('SPAN-17-invariant-never-null', () => {
    const testCases: [string, string][] = [
      ['S <- "a" ;', 'a'],
      ['S <- "a" ;', 'b'],
      ['S <- "a" ;', ''],
      ['S <- "a" "b" ;', 'ab'],
      ['S <- "a" "b" ;', 'aXb'],
      ['S <- "a" / "b" ;', 'c'],
    ];

    for (const [grammarSpec, input] of testCases) {
      const parseResult = squirrelParsePT({
        grammarSpec,
        topRuleName: 'S',
        input,
      });
      const result = getSpanningResult(parseResult);

      expect(result).not.toBeNull();
      expect(result.len).toBe(input.length);
    }
  });

  test('SPAN-18-long-input-with-single-trailing-error', () => {
    const input = 'abcdefghijklmnopqrstuvwxyzX';
    const parseResult = squirrelParsePT({
      grammarSpec:
        'S <- "a" "b" "c" "d" "e" "f" "g" "h" "i" "j" "k" "l" "m" "n" "o" "p" "q" "r" "s" "t" "u" "v" "w" "x" "y" "z" ;',
      topRuleName: 'S',
      input,
    });
    const result = getSpanningResult(parseResult);

    expect(result.len).toBe(27);
    expect(hasTrailingError(result, 26, 1)).toBe(true);
  });

  test('SPAN-19-complex-grammar-with-errors', () => {
    const parseResult = squirrelParsePT({
      grammarSpec: `
        S <- E ";" ;
        E <- E "+" T / T ;
        T <- "n" ;
      `,
      topRuleName: 'S',
      input: 'n+Xn;Y',
    });
    const result = getSpanningResult(parseResult);

    expect(result.len).toBe(6);

    const errors = collectErrors(result);
    expect(errors.length).toBeGreaterThanOrEqual(2);
  });

  test('SPAN-20-recovery-preserves-matched-content', () => {
    const parseResult = squirrelParsePT({
      grammarSpec: 'S <- "hello" " " "world" ;',
      topRuleName: 'S',
      input: 'hello X world',
    });
    const result = getSpanningResult(parseResult);

    expect(result.len).toBe(13);
    expect(result instanceof SyntaxError).toBe(false);
    expect(hasSyntaxError(result)).toBe(true);
  });
});
