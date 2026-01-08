/**
 * squirrelParse - Parse input and return a Concrete Syntax Tree (CST)
 */

import type { Clause } from './clause';
import { Ref, getSyntaxErrors } from './combinators';
import {
  CSTConstructionException,
  CSTFactoryValidationException,
  CSTNode,
  CSTNodeFactory,
  DuplicateRuleNameException,
} from './cstNode';
import type { MatchResult, SyntaxError } from './matchResult';
import { MetaGrammar } from './metaGrammar';
import { Parser } from './parser';
import { AnyChar, Char, CharRange, Str } from './terminals';

// ============================================================================
// Public CST API
// ============================================================================

/**
 * Parse input and return a Concrete Syntax Tree (CST), and any syntax errors.
 *
 * The CST is constructed directly from the parse tree using the provided factory functions.
 * This allows for fully custom syntax tree representations.
 *
 * @param grammarText The grammar as a PEG metagrammar string
 * @param input The input string to parse
 * @param topRule The name of the top-level rule to parse
 * @param factories List of CST node factories for each grammar rule
 * @returns A tuple [cst, syntaxErrors] where cst is the root CST node
 * @throws {CSTFactoryValidationException} if the factory list is invalid
 * @throws {DuplicateRuleNameException} if any rule name appears more than once
 * @throws {CSTConstructionException} if CST construction fails
 *
 * @example
 * ```typescript
 * const factories = [
 *   new CSTNodeFactory<MyNode>(
 *     'Expr',
 *     ['Term'],
 *     (ruleName, expectedChildren, children) => {
 *       return new MyNode(ruleName, children);
 *     }
 *   ),
 *   new CSTNodeFactory<MyNode>(
 *     'Term',
 *     ['<Terminal>'],
 *     (ruleName, expectedChildren, children) => {
 *       return new MyNode(ruleName);
 *     }
 *   ),
 * ];
 *
 * const [cst, errors] = squirrelParse(grammar, input, 'Expr', factories);
 * ```
 */
export function squirrelParse(
  grammarText: string,
  input: string,
  topRule: string,
  factories: CSTNodeFactory<CSTNode>[]
): [CSTNode, SyntaxError[]] {
  const rules = MetaGrammar.parseGrammar(grammarText);
  return doParse(rules, topRule, input, factories);
}

// ============================================================================
// Internal API: For testing only
// ============================================================================

/**
 * Internal method for parsing with pre-parsed grammar rules and raw parse tree.
 * Exposed for testing purposes only - not part of public API.
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
 * Internal method for parsing with pre-parsed grammar rules.
 * Exposed for testing purposes only - not part of public API.
 */
export function parseWithRuleMapForTesting(
  rules: Record<string, Clause>,
  topRule: string,
  input: string,
  factories: CSTNodeFactory<CSTNode>[]
): [CSTNode, SyntaxError[]] {
  return doParse(rules, topRule, input, factories);
}

// ============================================================================
// Private helpers
// ============================================================================

/**
 * Performs the actual parsing work with pre-parsed grammar rules.
 */
function doParse(
  rules: Record<string, Clause>,
  topRule: string,
  input: string,
  factories: CSTNodeFactory<CSTNode>[]
): [CSTNode, SyntaxError[]] {
  // Convert factories list to map, checking for duplicates
  const factoriesMap = buildFactoriesMap(factories);

  // Get the parse tree
  const [matchResult, syntaxErrors] = parseToMatchResultForTesting(rules, topRule, input);

  // Validate factories
  validateCSTFactories(rules, factoriesMap);

  // Build CST from parse tree
  const cst = buildCST(matchResult, input, factoriesMap, syntaxErrors, topRule);

  return [cst, syntaxErrors];
}

/**
 * Build a factories map from a list, checking for duplicate rule names.
 */
function buildFactoriesMap(factories: CSTNodeFactory<CSTNode>[]): Record<string, CSTNodeFactory<CSTNode>> {
  const result: Record<string, CSTNodeFactory<CSTNode>> = {};
  const counts: Record<string, number> = {};

  // Count occurrences
  for (const factory of factories) {
    counts[factory.ruleName] = (counts[factory.ruleName] ?? 0) + 1;
  }

  // Check for duplicates
  for (const [ruleName, count] of Object.entries(counts)) {
    if (count > 1) {
      throw new DuplicateRuleNameException(ruleName, count);
    }
  }

  // Build map
  for (const factory of factories) {
    result[factory.ruleName] = factory;
  }

  return result;
}

/**
 * Validate that CST factories cover all non-transparent grammar rules.
 */
function validateCSTFactories(
  rules: Record<string, Clause>,
  factories: Record<string, CSTNodeFactory<CSTNode>>
): void {
  const transparentRules = getTransparentRules(rules);
  const requiredRules = new Set(Object.keys(rules));
  for (const rule of transparentRules) {
    requiredRules.delete(rule);
  }

  const factoryRules = new Set(Object.keys(factories));

  // Check if any factories are for transparent rules
  const factoriesForTransparentRules = new Set<string>();
  for (const rule of factoryRules) {
    if (transparentRules.has(rule)) {
      factoriesForTransparentRules.add(rule);
    }
  }

  if (factoriesForTransparentRules.size > 0) {
    throw new CSTFactoryValidationException(factoriesForTransparentRules, new Set());
  }

  // Find missing and extra factories
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
}

/**
 * Get the set of transparent rule names from the grammar.
 */
function getTransparentRules(rules: Record<string, Clause>): Set<string> {
  const transparent = new Set<string>();

  for (const [ruleName, clause] of Object.entries(rules)) {
    if (clause.transparent) {
      transparent.add(ruleName);
    }
  }

  return transparent;
}

/**
 * Build a CST from a parse tree using the provided factories.
 */
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

  // Get the factory for the top-level rule
  const factory = factories[topRuleName];
  if (!factory) {
    throw new CSTConstructionException(`No factory found for rule: ${topRuleName}`);
  }

  // Build child CST nodes from this match result
  const clause = matchResult.clause;
  const children: CSTNode[] = [];

  // If the top-level clause is a non-transparent Ref, build a node for it
  if (clause instanceof Ref && !clause.transparent) {
    const childFactory = factories[clause.ruleName];
    if (childFactory) {
      const childChildren = buildCSTChildren(
        matchResult,
        input,
        factories,
        syntaxErrors,
        childFactory.expectedChildren
      );
      children.push(childFactory.factory(clause.ruleName, childFactory.expectedChildren, childChildren));
    }
  } else {
    // For non-Ref clauses, collect children normally
    children.push(
      ...buildCSTChildren(matchResult, input, factories, syntaxErrors, factory.expectedChildren)
    );
  }

  // Create the top-level CST node
  return factory.factory(topRuleName, factory.expectedChildren, children);
}

/**
 * Recursively build CST nodes from a parse tree.
 */
function buildCSTNode(
  matchResult: MatchResult,
  input: string,
  factories: Record<string, CSTNodeFactory<CSTNode>>,
  syntaxErrors: SyntaxError[]
): CSTNode {
  // Get the rule name from the clause
  const clause = matchResult.clause;
  if (!clause || !(clause instanceof Ref)) {
    throw new CSTConstructionException(`Expected Ref at top level, got ${clause?.constructor.name ?? 'null'}`);
  }

  const ruleName = clause.ruleName;

  // If this is a transparent rule, skip it and recurse into children
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

  // Get child matches
  const children = buildCSTChildren(matchResult, input, factories, syntaxErrors, factory.expectedChildren);

  // Call the factory to create the CST node
  return factory.factory(ruleName, factory.expectedChildren, children);
}

/**
 * Build CST nodes for children of a parse tree node.
 */
function buildCSTChildren(
  matchResult: MatchResult,
  input: string,
  factories: Record<string, CSTNodeFactory<CSTNode>>,
  syntaxErrors: SyntaxError[],
  _expectedChildren: string[]
): CSTNode[] {
  const children: CSTNode[] = [];

  for (const child of matchResult.subClauseMatches) {
    if (child.isMismatch) {
      continue;
    }

    const clause = child.clause;

    // Handle terminals - don't create CST nodes for terminals
    if (clause instanceof Str || clause instanceof Char || clause instanceof CharRange || clause instanceof AnyChar) {
      continue;
    }

    // Handle rule references
    if (clause instanceof Ref) {
      // Skip transparent rules - they're handled in buildCSTNode
      if (clause.transparent) {
        continue;
      }

      const childFactory = factories[clause.ruleName];
      if (childFactory) {
        // Recursively build this child node
        const cstChild = buildCSTNode(child, input, factories, syntaxErrors);
        children.push(cstChild);
      }
    }
  }

  return children;
}
