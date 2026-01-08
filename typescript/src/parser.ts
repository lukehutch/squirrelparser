/**
 * Parser class with packrat memoization and left-recursion handling.
 */

import { ASTNode, buildAST, buildASTNode } from './ast';
import type { Clause } from './clause';
import { Ref } from './combinators';
import type { MatchResult } from './matchResult';
import { LR_PENDING, MISMATCH, SyntaxError, Match } from './matchResult';
import { AnyChar, Char, CharRange, Str } from './terminals';

/**
 * A memo table entry for a (clause, position) pair.
 * Handles memoization, left-recursion detection, and expansion.
 */
class MemoEntry {
  private result: MatchResult | null = null;
  private inRecPath = false;
  private foundLeftRec = false;
  private memoVersion = 0;
  private cachedInRecoveryPhase = false;

  /**
   * Match a clause at a position, handling left recursion and caching.
   */
  match(parser: Parser, clause: Clause, pos: number, bound: Clause | null): MatchResult {
    // Cache validation
    if (this.result !== null && this.memoVersion === parser.getMemoVersion(pos)) {
      const phaseMatches = this.cachedInRecoveryPhase === parser.inRecoveryPhase;

      // Top-level complete results that didn't reach EOF
      if (
        !this.result.isMismatch &&
        this.result.isComplete &&
        pos === 0 &&
        this.result.pos + this.result.len < parser.input.length &&
        !phaseMatches
      ) {
        // Phase 1 result didn't reach EOF; retry in Phase 2
      } else if (
        (!this.result.isMismatch && this.result.isComplete && !this.foundLeftRec) ||
        phaseMatches
      ) {
        return this.result; // Cache hit
      }
    }

    // Left recursion cycle detection
    if (this.inRecPath) {
      if (this.result === null) {
        this.foundLeftRec = true;
        this.result = MISMATCH;
      }
      return this.result.isMismatch ? LR_PENDING : this.result;
    }

    this.inRecPath = true;

    // Clear stale results before expansion loop
    if (
      this.result !== null &&
      (this.memoVersion !== parser.getMemoVersion(pos) ||
        (this.foundLeftRec && this.cachedInRecoveryPhase !== parser.inRecoveryPhase))
    ) {
      this.result = null;
    }

    // Left recursion expansion loop
    for (; ;) {
      const newResult = clause.match(parser, pos, bound);

      if (this.result !== null && newResult.len <= this.result.len) {
        break; // No progress - fixed point reached
      }

      this.result = newResult;

      if (!this.foundLeftRec) {
        break; // No left recursion - done in one iteration
      }

      parser.incrementMemoVersion(pos);
      this.memoVersion = parser.getMemoVersion(pos);
    }

    // Update cache metadata
    this.inRecPath = false;
    this.memoVersion = parser.getMemoVersion(pos);
    this.cachedInRecoveryPhase = parser.inRecoveryPhase;

    // Mark LR results
    if (this.foundLeftRec && !this.result.isMismatch && !this.result.isFromLRContext) {
      this.result = this.result.withLRContext();
    }

    return this.result;
  }
}

/**
 * Main parser class with packrat memoization and left-recursion handling.
 */
export class Parser {
  readonly rules: Record<string, Clause>;
  readonly input: string;
  private readonly memoTable = new Map<number, Map<number, MemoEntry>>();
  private readonly memoVersion: number[];
  inRecoveryPhase = false;

  constructor(rules: Record<string, Clause>, input: string) {
    this.rules = rules;
    this.input = input;
    this.memoVersion = new Array(input.length + 1).fill(0);
  }

  getMemoVersion(pos: number): number {
    return this.memoVersion[pos];
  }

  incrementMemoVersion(pos: number): void {
    this.memoVersion[pos]++;
  }

  /**
   * Match a clause at a position with memoization.
   */
  match(clause: Clause, pos: number, bound: Clause | null = null): MatchResult {
    if (pos > this.input.length) return MISMATCH;

    // C5 (Ref Transparency): Don't memoize Ref independently
    if (clause instanceof Ref) {
      return clause.match(this, pos, bound);
    }

    // Use object identity as key for memoization
    const key = getObjectId(clause);

    let posMap = this.memoTable.get(key);
    if (!posMap) {
      posMap = new Map();
      this.memoTable.set(key, posMap);
    }

    let entry = posMap.get(pos);
    if (!entry) {
      entry = new MemoEntry();
      posMap.set(pos, entry);
    }

    return entry.match(this, clause, pos, bound);
  }

  /**
   * Probe: match in discovery phase (no recovery).
   */
  probe(clause: Clause, pos: number): MatchResult {
    const wasInRecovery = this.inRecoveryPhase;
    this.inRecoveryPhase = false;
    const result = this.match(clause, pos, null);
    this.inRecoveryPhase = wasInRecovery;
    return result;
  }

  /**
   * Check if clause can match non-zero characters at position.
   */
  canMatchNonzeroAt(clause: Clause, pos: number): boolean {
    const result = this.probe(clause, pos);
    return !result.isMismatch && result.len > 0;
  }

  /**
   * Match a named rule at a position.
   */
  matchRule(ruleName: string, pos: number): MatchResult {
    const clause = this.rules[ruleName];
    if (!clause) {
      throw new Error(`Rule "${ruleName}" not found`);
    }
    return this.match(clause, pos, null);
  }

  /**
   * Ensure result spans entire input (parse tree spanning invariant).
   * - Total failure: return SyntaxError spanning all input
   * - Partial match: wrap with trailing SyntaxError
   * - Complete match: return as-is
   */
  private ensureSpansInput(result: MatchResult): MatchResult {
    if (result.isMismatch) {
      // Total failure: entire input is an error
      return new SyntaxError(0, this.input.length, this.input);
    }

    if (result.len === this.input.length) {
      // Already spans entire input
      return result;
    }

    // Partial match: wrap with trailing SyntaxError
    const trailing = new SyntaxError(
      result.len,
      this.input.length - result.len,
      this.input.substring(result.len)
    );

    return new Match(result.clause, 0, this.input.length, [result, trailing], false);
  }

  /**
   * Parse input with the top rule, using two-phase error recovery.
   * Returns [result, usedRecovery] where:
   *   - result = MatchResult spanning entire input (never null)
   *   - usedRecovery = true if Phase 2 was needed
   *   - result is SyntaxError if parse failed completely
   */
  parse(topRule: string): [MatchResult, boolean] {
    const rule = this.rules[topRule];

    if (!rule) {
      throw new Error(`Rule not found: ${topRule}`);
    }

    // Phase 1: Discovery (no recovery)
    this.inRecoveryPhase = false;
    let result = this.matchRule(topRule, 0);

    if (!result.isMismatch && result.len === this.input.length) {
      return [result, false];
    }

    // Phase 2: Recovery
    this.inRecoveryPhase = true;
    result = this.matchRule(topRule, 0);

    // Ensure result spans entire input
    result = this.ensureSpansInput(result);
    return [result, true];
  }

  /**
   * Parse input and return an AST instead of a parse tree.
   *
   * Returns [ast, usedRecovery] where:
   *   - ast = ASTNode spanning entire input (never null)
   *   - usedRecovery = true if Phase 2 was needed
   *   - For total failures (SyntaxError at top level), wraps it in a synthetic node
   */
  parseToAST(topRuleName: string): [ASTNode, boolean] {
    const [result, usedRecovery] = this.parse(topRuleName);

    // Result always spans input now, but may be total failure (SyntaxError)
    if (result instanceof SyntaxError) {
      // Total failure: create synthetic error node
      const errorAST = new ASTNode(
        topRuleName,
        result.pos,
        result.len,
        [],
        this.input
      );
      return [errorAST, usedRecovery];
    }

    // If the parse tree top-level is not a Ref (e.g., when matching the Grammar rule directly),
    // create a synthetic root AST node with the rule name
    const ast = buildAST(result, this.input);
    if (ast === null) {
      // Parse tree is a combinator at top level - wrap it in a synthetic rule node
      const children = this.collectChildrenForAST(result, this.input);
      const syntheticAST = new ASTNode(
        topRuleName,
        result.pos,
        result.len,
        children,
        this.input
      );
      return [syntheticAST, usedRecovery];
    }
    return [ast, usedRecovery];
  }

  /**
   * Helper to collect children for AST building (exposed for parseToAST).
   */
  private collectChildrenForAST(match: MatchResult, input: string): ASTNode[] {
    const result: ASTNode[] = [];

    for (const child of match.subClauseMatches) {
      if (child.isMismatch) continue;
      // Skip SyntaxError nodes (not implemented in TypeScript yet)

      const clause = child.clause;

      // If child is a Ref, create an AST node for it (unless transparent)
      if (clause instanceof Ref) {
        if (!clause.transparent) {
          const children = this.collectChildren(child, input);
          const node = new ASTNode(
            clause.ruleName,
            child.pos,
            child.len,
            children,
            input
          );
          result.push(node);
        }
        // Transparent rules are completely skipped - don't create node and don't include their children
      }
      // Include terminals as leaf nodes
      else if (
        clause instanceof Str ||
        clause instanceof Char ||
        clause instanceof CharRange ||
        clause instanceof AnyChar
      ) {
        const node = buildASTNode(child, input);
        if (node !== null) {
          result.push(node);
        }
      }
      // For other combinators, recursively collect their children
      else {
        result.push(...this.collectChildrenForAST(child, input));
      }
    }

    return result;
  }

  /**
   * Helper to collect children from a match result.
   */
  private collectChildren(match: MatchResult, input: string): ASTNode[] {
    const result: ASTNode[] = [];

    for (const child of match.subClauseMatches) {
      if (child.isMismatch) continue;
      // Skip SyntaxError nodes (not implemented in TypeScript yet)

      const clause = child.clause;

      // If child is a Ref or terminal, add it as an AST node
      if (
        clause instanceof Ref ||
        clause instanceof Str ||
        clause instanceof Char ||
        clause instanceof CharRange ||
        clause instanceof AnyChar
      ) {
        const node = buildASTNode(child, input);
        if (node !== null) {
          result.push(node);
        }
      }
      // Otherwise, it's a combinator - recursively collect its children
      else {
        result.push(...this.collectChildren(child, input));
      }
    }

    return result;
  }
}

// Object identity tracking for memoization keys
const objectIds = new WeakMap<object, number>();
let nextObjectId = 0;

function getObjectId(obj: object): number {
  let id = objectIds.get(obj);
  if (id === undefined) {
    id = nextObjectId++;
    objectIds.set(obj, id);
  }
  return id;
}
