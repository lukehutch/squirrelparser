/**
 * Test utilities for Squirrel Parser tests.
 */

import { squirrelParsePT } from '../src/squirrelParse.js';
import { SyntaxError, type MatchResult } from '../src/matchResult.js';
import { Ref, Seq, First, Str } from '../src/index.js';

/**
 * Result of parsing with error recovery.
 */
export interface ParseTestResult {
  ok: boolean;
  errorCount: number;
  skippedStrings: string[];
}

/**
 * Parse input with error recovery and return (success, errorCount, skippedStrings).
 */
export function testParse(grammarSpec: string, input: string, topRule: string = 'S'): ParseTestResult {
  const parseResult = squirrelParsePT({
    grammarSpec,
    topRuleName: topRule,
    input,
  });

  const result = parseResult.root;
  const isCompleteFailure = result instanceof SyntaxError && result.len === parseResult.input.length;
  const ok = !isCompleteFailure;

  let totErrors = result.totDescendantErrors;
  if (parseResult.unmatchedInput !== undefined && parseResult.unmatchedInput.pos >= 0) {
    totErrors += 1;
  }

  const skippedStrings = getSkippedStrings([result], input);
  if (parseResult.unmatchedInput !== undefined && parseResult.unmatchedInput.pos >= 0) {
    const unmatched = parseResult.unmatchedInput;
    skippedStrings.push(parseResult.input.substring(unmatched.pos, unmatched.pos + unmatched.len));
  }

  return { ok, errorCount: totErrors, skippedStrings };
}

/**
 * Collect all SyntaxError nodes from the parse tree.
 */
export function getSyntaxErrors(results: MatchResult[]): SyntaxError[] {
  const errors: SyntaxError[] = [];

  function collect(r: MatchResult): void {
    if (!r.isMismatch) {
      if (r instanceof SyntaxError) {
        errors.push(r);
      } else {
        for (const child of r.subClauseMatches) {
          collect(child);
        }
      }
    }
  }

  for (const result of results) {
    collect(result);
  }
  return errors;
}

/**
 * Count deletions in parse tree (SyntaxErrors with len == 0).
 */
export function countDeletions(results: MatchResult[]): number {
  return getSyntaxErrors(results).filter((e) => e.len === 0).length;
}

/**
 * Get list of skipped strings from syntax errors (SyntaxErrors with len > 0).
 */
export function getSkippedStrings(results: MatchResult[], input: string): string[] {
  return getSyntaxErrors(results)
    .filter((e) => e.len > 0)
    .map((e) => input.substring(e.pos, e.pos + e.len));
}

/**
 * Parse and return the MatchResult for tree structure verification.
 * Returns null if the entire input is a SyntaxError.
 */
export function parseForTree(grammarSpec: string, input: string, topRule: string = 'S'): MatchResult | null {
  const parseResult = squirrelParsePT({
    grammarSpec,
    topRuleName: topRule,
    input,
  });
  const result = parseResult.root;
  return result instanceof SyntaxError ? null : result;
}

/**
 * Count occurrences of a rule in the parse tree.
 */
export function countRuleDepth(result: MatchResult | null, ruleName: string): number {
  if (result === null || result.isMismatch) return 0;
  let count = 0;
  if (result.clause instanceof Ref && result.clause.ruleName === ruleName) {
    count = 1;
  }
  for (const child of result.subClauseMatches) {
    if (!child.isMismatch) {
      count += countRuleDepth(child, ruleName);
    }
  }
  return count;
}

/**
 * Check if tree has left-associative binding for a rule.
 */
export function isLeftAssociative(result: MatchResult | null, ruleName: string): boolean {
  if (result === null || result.isMismatch) return false;

  const instances = findRuleInstances(result, ruleName);
  if (instances.length < 2) return false;

  for (const instance of instances) {
    const firstChildResult = getFirstSemanticChild(instance, ruleName);
    if (!firstChildResult.isSameRule || firstChildResult.child === null) continue;

    const nestedResult = getFirstSemanticChild(firstChildResult.child, ruleName);
    if (nestedResult.isSameRule) return true;
  }
  return false;
}

/**
 * Verify operator count in parse tree.
 */
export function verifyOperatorCount(result: MatchResult | null, opStr: string, expectedOps: number): boolean {
  if (result === null || result.isMismatch) return false;
  return countOperators(result, opStr) === expectedOps;
}

function findRuleInstances(result: MatchResult, ruleName: string): MatchResult[] {
  const instances: MatchResult[] = [];
  if (result.clause instanceof Ref && result.clause.ruleName === ruleName) {
    instances.push(result);
  }
  for (const child of result.subClauseMatches) {
    if (!child.isMismatch) {
      instances.push(...findRuleInstances(child, ruleName));
    }
  }
  return instances;
}

interface FirstSemanticChildResult {
  child: MatchResult | null;
  isSameRule: boolean;
}

function getFirstSemanticChild(result: MatchResult, ruleName: string): FirstSemanticChildResult {
  const children = result.subClauseMatches.filter((c) => !c.isMismatch);
  if (children.length === 0) return { child: null, isSameRule: false };

  let firstChild = children[0];
  while (firstChild.clause instanceof Seq || firstChild.clause instanceof First) {
    const innerChildren = firstChild.subClauseMatches.filter((c) => !c.isMismatch);
    if (innerChildren.length === 0) return { child: null, isSameRule: false };
    firstChild = innerChildren[0];
  }

  const isSameRule = firstChild.clause instanceof Ref && firstChild.clause.ruleName === ruleName;
  return { child: firstChild, isSameRule };
}

function countOperators(result: MatchResult, opStr: string): number {
  let count = 0;
  if (result.clause instanceof Str && result.clause.text === opStr) {
    count = 1;
  }
  for (const child of result.subClauseMatches) {
    if (!child.isMismatch) {
      count += countOperators(child, opStr);
    }
  }
  return count;
}
