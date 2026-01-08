/**
 * AST Node and AST building utilities for the Squirrel Parser.
 */

import type { MatchResult } from './matchResult';
import type { Terminal } from './terminals';
import type { Clause } from './clause';
import { Ref } from './combinators';
import { Str, Char, CharRange, AnyChar } from './terminals';

/**
 * Check if a clause is a Terminal.
 */
function isTerminal(clause: Clause | null): clause is Terminal {
  return (
    clause instanceof Str ||
    clause instanceof Char ||
    clause instanceof CharRange ||
    clause instanceof AnyChar
  );
}

/**
 * An AST node representing either a rule match or a terminal match.
 *
 * AST nodes have:
 * - A label (the rule name or terminal type)
 * - A position and length in the input
 * - Children (other AST nodes)
 * - The matched text
 */
export class ASTNode {
  /** The label for this node (rule name or terminal type). */
  readonly label: string;

  /** The position in the input where this match starts. */
  readonly pos: number;

  /** The length of the match. */
  readonly len: number;

  /** Child AST nodes. These are flattened - only rule matches and terminals appear. */
  readonly children: readonly ASTNode[];

  /** The input string (shared reference). */
  private readonly _input: string;

  constructor(
    label: string,
    pos: number,
    len: number,
    children: readonly ASTNode[],
    input: string
  ) {
    this.label = label;
    this.pos = pos;
    this.len = len;
    this.children = children;
    this._input = input;
  }

  /** Get the text matched by this node. */
  get text(): string {
    return this._input.substring(this.pos, this.pos + this.len);
  }

  /** Get a child by index. */
  getChild(index: number): ASTNode {
    return this.children[index];
  }

  toString(): string {
    return `ASTNode(${this.label}, "${this.text}", children: ${this.children.length})`;
  }

  /** Pretty print the AST tree. */
  toPrettyString(indent: number = 0): string {
    let result = '  '.repeat(indent) + this.label;
    if (this.children.length === 0) {
      result += `: "${this.text}"`;
    }
    result += '\n';
    for (const child of this.children) {
      result += child.toPrettyString(indent + 1);
    }
    return result;
  }
}

/**
 * Build an AST from a parse tree.
 *
 * The AST only includes:
 * - Ref nodes (rule references) with their rule name as label
 * - Terminal nodes (Str, Char, CharRange, AnyChar) with text as label
 *
 * All intermediate combinator nodes (Seq, First, etc.) are flattened out,
 * with their children promoted to be children of the nearest ancestral rule.
 *
 * For top-level combinator matches, creates a synthetic node with the given topRule label.
 */
export function buildAST(match: MatchResult | null, input: string, topRule?: string): ASTNode | null {
  if (match === null || match.isMismatch) {
    return null;
  }

  let ast = buildASTNode(match, input);

  // If top-level match is a combinator and we have a topRule label, build synthetic node
  if (ast === null && topRule) {
    const children = collectChildrenForAST(match, input);
    ast = new ASTNode(topRule, match.pos, match.len, children, input);
  }

  return ast;
}

export function buildASTNode(match: MatchResult, input: string): ASTNode | null {
  const clause = match.clause;

  // Handle Ref nodes - these become AST nodes with the rule name as label
  // UNLESS they're marked as transparent, in which case we flatten them
  if (clause instanceof Ref) {
    if (clause.transparent) {
      // Transparent rule - don't create a node, just return children
      return null;
    }
    // Get children by recursively processing the wrapped match
    const children = collectChildren(match, input);
    return new ASTNode(
      clause.ruleName,
      match.pos,
      match.len,
      children,
      input
    );
  }

  // Handle terminal nodes - these become leaf AST nodes
  if (isTerminal(clause)) {
    return new ASTNode(
      clause.constructor.name,
      match.pos,
      match.len,
      [],
      input
    );
  }

  // For all other nodes (combinators), flatten and collect children
  // This shouldn't normally be called at the top level, but handle it anyway
  return null;
}

/**
 * Collect children for an AST node by flattening combinators.
 */
function collectChildren(match: MatchResult, input: string): ASTNode[] {
  const result: ASTNode[] = [];

  for (const child of match.subClauseMatches) {
    if (child.isMismatch) continue;
    // Skip SyntaxError nodes in AST (TypeScript doesn't have SyntaxError class yet)

    const clause = child.clause;

    // If child is a Ref or terminal, add it as an AST node
    if (clause instanceof Ref || isTerminal(clause)) {
      const node = buildASTNode(child, input);
      if (node !== null) {
        result.push(node);
      }
    }
    // Otherwise, it's a combinator - recursively collect its children
    else {
      result.push(...collectChildren(child, input));
    }
  }

  return result;
}

/**
 * Collect children for AST building when top-level match is a combinator.
 * This is used internally by buildAST to build synthetic AST nodes from top-level combinators.
 */
function collectChildrenForAST(match: MatchResult, input: string): ASTNode[] {
  const result: ASTNode[] = [];

  for (const child of match.subClauseMatches) {
    if (child.isMismatch) continue;
    // Skip SyntaxError nodes in AST

    const clause = child.clause;

    // If child is a Ref, create an AST node for it (unless transparent)
    if (clause instanceof Ref) {
      if (!clause.transparent) {
        const children = collectChildren(child, input);
        result.push(
          new ASTNode(
            clause.ruleName,
            child.pos,
            child.len,
            children,
            input
          )
        );
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
      result.push(...collectChildrenForAST(child, input));
    }
  }

  return result;
}
