/**
 * Test utilities for Squirrel Parser tests.
 * Shared helper functions for all test files.
 */

import type { Clause, MatchResult } from '../src';
import {
  Char,
  CharRange,
  First,
  OneOrMore,
  Optional,
  Parser,
  Ref,
  Seq,
  Str,
  SyntaxError,
  ZeroOrMore,
  getSyntaxErrors,
  CSTNode,
  CSTNodeFactory,
  CSTConstructionException,
  CSTFactoryValidationException,
  DuplicateRuleNameException,
  AnyChar,
} from '../src';

/**
 * Parse input with error recovery and return [success, errorCount, skipped].
 * topRule defaults to 'S' for backward compatibility.
 */
export function parse(
  rules: Record<string, Clause>,
  input: string,
  topRule: string = 'S'
): [boolean, number, string[]] {
  const parser = new Parser(rules, input);
  const [result, _usedRecovery] = parser.parse(topRule);

  // Result always spans input with new invariant.
  // Check if the entire result is just a SyntaxError (total failure)
  if (result instanceof SyntaxError) {
    return [false, 1, [result.skipped]];
  }

  return [true, countErrors(result), getSkippedStrings(result)];
}

/**
 * Count deletions in parse tree.
 */
export function countDeletions(result: MatchResult | null): number {
  if (result === null || result.isMismatch) return 0;
  let count = result instanceof SyntaxError && result.isDeletion ? 1 : 0;
  for (const child of result.subClauseMatches) {
    count += countDeletions(child);
  }
  return count;
}

/**
 * Count total syntax errors in a parse tree.
 */
export function countErrors(result: MatchResult | null): number {
  if (result === null || result.isMismatch) return 0;
  let count = result instanceof SyntaxError ? 1 : 0;
  for (const child of result.subClauseMatches) {
    count += countErrors(child);
  }
  return count;
}

/**
 * Get list of skipped strings from syntax errors.
 */
export function getSkippedStrings(result: MatchResult | null): string[] {
  const skipped: string[] = [];
  function collect(r: MatchResult | null): void {
    if (r === null || r.isMismatch) return;
    if (r instanceof SyntaxError && !r.isDeletion) {
      skipped.push(r.skipped);
    }
    for (const child of r.subClauseMatches) {
      collect(child);
    }
  }
  collect(result);
  return skipped;
}

/**
 * Parse and return the MatchResult directly for tree structure verification.
 * topRule defaults to 'S' for backward compatibility.
 * Returns null only if parse completely failed (result is SyntaxError covering all input).
 */
export function parseForTree(
  rules: Record<string, Clause>,
  input: string,
  topRule: string = 'S'
): MatchResult | null {
  const parser = new Parser(rules, input);
  const [result, _usedRecovery] = parser.parse(topRule);
  // With new invariant, parse() always returns a MatchResult spanning input
  // Return null only if entire result is a SyntaxError (total failure)
  if (result instanceof SyntaxError) return null;
  return result;
}

/**
 * Debug: print tree structure
 */
export function printTree(result: MatchResult | null, indent: number = 0): void {
  if (result === null) {
    console.log(' '.repeat(indent) + 'null');
    return;
  }
  const prefix = ' '.repeat(indent);
  const clause = result.clause;
  const clauseType = clause?.constructor.name || 'null';
  let clauseInfo = clauseType;
  if (clause instanceof Ref) {
    clauseInfo = `Ref(${clause.ruleName})`;
  } else if (clause instanceof Str) {
    clauseInfo = `Str("${clause.text}")`;
  } else if (clause instanceof CharRange) {
    clauseInfo = `CharRange(${clause.lo}-${clause.hi})`;
  }
  console.log(`${prefix}${clauseInfo} pos=${result.pos} len=${result.len}`);
  for (const child of result.subClauseMatches) {
    if (!child.isMismatch) {
      printTree(child, indent + 2);
    }
  }
}

/**
 * Get a simplified tree representation showing rule structure.
 * Returns a string like "E(E(E(n),+n),+n)" for left-associative parse.
 */
export function getTreeShape(
  result: MatchResult | null,
  rules: Record<string, Clause>
): string {
  if (result === null || result.isMismatch) return 'MISMATCH';
  return buildTreeShape(result, rules);
}

function buildTreeShape(result: MatchResult, rules: Record<string, Clause>): string {
  const clause = result.clause;

  // For Ref clauses, show the rule name and recurse into the referenced match
  if (clause instanceof Ref) {
    const children = result.subClauseMatches;
    if (children.length === 0) {
      return clause.ruleName;
    }
    // Get the shape of what the ref matched
    const childShapes = children
      .filter(c => !c.isMismatch)
      .map(c => buildTreeShape(c, rules));
    if (childShapes.length === 0) return clause.ruleName;
    if (childShapes.length === 1) return `${clause.ruleName}(${childShapes[0]})`;
    return `${clause.ruleName}(${childShapes.join(',')})`;
  }

  // For Str terminals, show the matched string in quotes
  if (clause instanceof Str) {
    return `'${clause.text}'`;
  }

  // For Char terminals, show the character
  if (clause instanceof Char) {
    return `'${clause.char}'`;
  }

  // For CharRange terminals, show the range
  if (clause instanceof CharRange) {
    return `[${clause.lo}-${clause.hi}]`;
  }

  // For Seq, First, show children
  if (clause instanceof Seq || clause instanceof First) {
    const children = result.subClauseMatches
      .filter(c => !c.isMismatch)
      .map(c => buildTreeShape(c, rules));
    if (children.length === 0) return '()';
    if (children.length === 1) return children[0];
    return `(${children.join(',')})`;
  }

  // For repetition operators
  if (clause instanceof OneOrMore || clause instanceof ZeroOrMore) {
    const children = result.subClauseMatches
      .filter(c => !c.isMismatch)
      .map(c => buildTreeShape(c, rules));
    if (children.length === 0) return '[]';
    return `[${children.join(',')}]`;
  }

  // For Optional
  if (clause instanceof Optional) {
    const children = result.subClauseMatches
      .filter(c => !c.isMismatch)
      .map(c => buildTreeShape(c, rules));
    if (children.length === 0) return '?()';
    return `?(${children.join(',')})`;
  }

  // Default: show clause type
  return clause?.constructor.name || 'unknown';
}

/**
 * Check if tree has left-associative BINDING (not just left-recursive structure).
 *
 * For true left-associativity like ((0+1)+2):
 * - The LEFT child E should itself be a recursive application (E op X), not just base case
 * - This means the left E's first child is also an E
 *
 * For right-associative binding like 0+(1+2) from ambiguous grammar:
 * - The LEFT child E is just the base case (no E child)
 * - The RIGHT child E does all the work
 */
export function isLeftAssociative(result: MatchResult | null, ruleName: string): boolean {
  if (result === null || result.isMismatch) return false;

  // Find all instances of the rule in the tree
  const instances = findRuleInstances(result, ruleName);
  if (instances.length < 2) return false;

  // For left-associativity, check if ANY instance's LEFT CHILD E
  // is itself an application of the recursive pattern (not just base case)
  for (const instance of instances) {
    const [firstChild, isSameRule] = getFirstSemanticChild(instance, ruleName);
    if (!isSameRule || firstChild === null) continue;

    // Now check if this firstChild E is itself recursive (not just base case)
    // A recursive E will have another E as its first child
    const [_nestedFirst, nestedIsSame] = getFirstSemanticChild(firstChild, ruleName);
    if (nestedIsSame) {
      // The left E has another E as its first child -> truly left-associative
      return true;
    }
  }

  return false;
}

/**
 * Get the first semantic child of a result, drilling through Seq/First wrappers.
 * Returns [child, isSameRule] where isSameRule indicates if child is Ref(ruleName).
 */
function getFirstSemanticChild(
  result: MatchResult,
  ruleName: string
): [MatchResult | null, boolean] {
  const children = result.subClauseMatches.filter(c => !c.isMismatch);
  if (children.length === 0) return [null, false];

  let firstChild = children[0];

  // Drill through Seq/First to find actual first element
  while (firstChild.clause instanceof Seq || firstChild.clause instanceof First) {
    const innerChildren = firstChild.subClauseMatches.filter(c => !c.isMismatch);
    if (innerChildren.length === 0) return [null, false];
    firstChild = innerChildren[0];
  }

  const isSameRule =
    firstChild.clause instanceof Ref && firstChild.clause.ruleName === ruleName;
  return [firstChild, isSameRule];
}

/**
 * Find all MatchResults where clause is Ref(ruleName)
 */
function findRuleInstances(result: MatchResult, ruleName: string): MatchResult[] {
  const instances: MatchResult[] = [];

  if (result.clause instanceof Ref && result.clause.ruleName === ruleName) {
    instances.push(result);
  }

  for (const child of result.subClauseMatches.filter(c => !c.isMismatch)) {
    instances.push(...findRuleInstances(child, ruleName));
  }

  return instances;
}

/**
 * Count the total occurrences of a rule in the parse tree.
 */
export function countRuleDepth(result: MatchResult | null, ruleName: string): number {
  if (result === null || result.isMismatch) return 0;
  return countDepth(result, ruleName);
}

function countDepth(result: MatchResult, ruleName: string): number {
  const clause = result.clause;
  let count = 0;

  if (clause instanceof Ref && clause.ruleName === ruleName) {
    count = 1;
  }

  // Recurse into ALL children to find all occurrences
  for (const child of result.subClauseMatches.filter(c => !c.isMismatch)) {
    count += countDepth(child, ruleName);
  }

  return count;
}

/**
 * Verify that for input with N operators, we have N+1 base terms and N operator applications.
 * For "n+n+n" we expect 3 'n' terms and 2 '+n' applications in a left-assoc tree.
 */
export function verifyOperatorCount(
  result: MatchResult | null,
  opStr: string,
  expectedOps: number
): boolean {
  if (result === null || result.isMismatch) return false;
  const count = countOperators(result, opStr);
  return count === expectedOps;
}

function countOperators(result: MatchResult, opStr: string): number {
  let count = 0;
  if (result.clause instanceof Str && result.clause.text === opStr) {
    count = 1;
  }
  for (const child of result.subClauseMatches.filter(c => !c.isMismatch)) {
    count += countOperators(child, opStr);
  }
  return count;
}

// ============================================================================
// CST Testing Utilities
// ============================================================================

/**
 * Parse input with pre-parsed grammar rules and return raw parse tree and errors.
 * Test utility only - not part of public API.
 */
export function parseToMatchResultForTesting(
  rules: Record<string, Clause>,
  topRule: string,
  input: string
): [MatchResult, SyntaxError[]] {
  const parser = new Parser(rules, input);
  const [matchResult] = parser.parse(topRule);
  const syntaxErrors = getSyntaxErrors(matchResult, input);
  return [matchResult, syntaxErrors];
}

/**
 * Parse input with pre-parsed grammar rules and return a CST.
 * Test utility only - not part of public API.
 */
export function parseWithRuleMapForTesting(
  rules: Record<string, Clause>,
  topRule: string,
  input: string,
  factories: CSTNodeFactory<CSTNode>[]
): [CSTNode, SyntaxError[]] {
  const [matchResult, syntaxErrors] = parseToMatchResultForTesting(rules, topRule, input);

  // Build factories map, checking for duplicates
  const factoriesMap: Record<string, CSTNodeFactory<CSTNode>> = {};
  const counts: Record<string, number> = {};

  for (const factory of factories) {
    counts[factory.ruleName] = (counts[factory.ruleName] ?? 0) + 1;
  }

  for (const [ruleName, count] of Object.entries(counts)) {
    if (count > 1) {
      throw new DuplicateRuleNameException(ruleName, count);
    }
  }

  for (const factory of factories) {
    factoriesMap[factory.ruleName] = factory;
  }

  // Validate factories
  const transparentRules = new Set<string>();
  for (const [ruleName, clause] of Object.entries(rules)) {
    if (clause.transparent) {
      transparentRules.add(ruleName);
    }
  }

  const requiredRules = new Set(Object.keys(rules));
  for (const rule of transparentRules) {
    requiredRules.delete(rule);
  }

  const factoryRules = new Set(Object.keys(factoriesMap));

  const factoriesForTransparentRules = new Set<string>();
  for (const rule of factoryRules) {
    if (transparentRules.has(rule)) {
      factoriesForTransparentRules.add(rule);
    }
  }

  if (factoriesForTransparentRules.size > 0) {
    throw new CSTFactoryValidationException(factoriesForTransparentRules, new Set());
  }

  const missing = new Set<string>();
  const extra = new Set<string>();

  for (const rule of requiredRules) {
    if (!factoryRules.has(rule)) {
      missing.add(rule);
    }
  }

  for (const rule of factoryRules) {
    if (!requiredRules.has(rule)) {
      extra.add(rule);
    }
  }

  if (missing.size > 0 || extra.size > 0) {
    throw new CSTFactoryValidationException(missing, extra);
  }

  // Build CST
  const cst = buildCST(matchResult, input, factoriesMap, syntaxErrors, topRule);
  return [cst, syntaxErrors];
}

// Helper functions for CST building (test utilities only)

function buildCST(
  matchResult: MatchResult,
  input: string,
  factories: Record<string, CSTNodeFactory<CSTNode>>,
  syntaxErrors: SyntaxError[],
  topRuleName: string
): CSTNode {
  if (matchResult.isMismatch) {
    throw new CSTConstructionException('Cannot build CST from mismatch result');
  }

  const factory = factories[topRuleName];
  if (!factory) {
    throw new CSTConstructionException(`No factory found for rule: ${topRuleName}`);
  }

  const clause = matchResult.clause;
  const children: CSTNode[] = [];

  if (clause instanceof Ref && !clause.transparent) {
    const childFactory = factories[clause.ruleName];
    if (childFactory) {
      const childChildren = buildCSTChildren(
        matchResult,
        input,
        factories,
        syntaxErrors
      );
      children.push(childFactory.factory(clause.ruleName, childChildren));
    }
  } else {
    children.push(
      ...buildCSTChildren(matchResult, input, factories, syntaxErrors)
    );
  }

  return factory.factory(topRuleName, children);
}

function buildCSTNode(
  matchResult: MatchResult,
  input: string,
  factories: Record<string, CSTNodeFactory<CSTNode>>,
  syntaxErrors: SyntaxError[]
): CSTNode {
  const clause = matchResult.clause;
  if (!clause || !(clause instanceof Ref)) {
    throw new CSTConstructionException(`Expected Ref at top level, got ${clause?.constructor.name ?? 'null'}`);
  }

  const ruleName = clause.ruleName;

  if (clause.transparent) {
    const children = matchResult.subClauseMatches.filter(
      (m) => !m.isMismatch && m.clause instanceof Ref && !(m.clause as Ref).transparent
    );

    if (children.length === 0) {
      throw new CSTConstructionException(`Transparent rule ${ruleName} has no non-transparent children`);
    }
    if (children.length === 1) {
      return buildCSTNode(children[0], input, factories, syntaxErrors);
    } else {
      throw new CSTConstructionException(`Transparent rule ${ruleName} has multiple non-transparent children`);
    }
  }

  const factory = factories[ruleName];
  if (!factory) {
    throw new CSTConstructionException(`No factory found for rule: ${ruleName}`);
  }

  const children = buildCSTChildren(matchResult, input, factories, syntaxErrors);
  return factory.factory(ruleName, children);
}

function buildCSTChildren(
  matchResult: MatchResult,
  input: string,
  factories: Record<string, CSTNodeFactory<CSTNode>>,
  syntaxErrors: SyntaxError[]
): CSTNode[] {
  const children: CSTNode[] = [];

  for (const child of matchResult.subClauseMatches) {
    if (child.isMismatch) {
      continue;
    }

    const clause = child.clause;

    if (clause instanceof Str || clause instanceof Char || clause instanceof CharRange || clause instanceof AnyChar) {
      continue;
    }

    if (clause instanceof Ref) {
      if (clause.transparent) {
        continue;
      }

      const childFactory = factories[clause.ruleName];
      if (childFactory) {
        const cstChild = buildCSTNode(child, input, factories, syntaxErrors);
        children.push(cstChild);
      }
    }
  }

  return children;
}
