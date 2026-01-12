import { Ref } from './combinators.js';
import type { MatchResult } from './matchResult.js';
import { SyntaxError } from './matchResult.js';
import type { ParseResult } from './parser.js';
import { Terminal } from './terminals.js';

// -----------------------------------------------------------------------------------------------------------------

/**
 * Base class for AST and CST nodes.
 */
export abstract class Node<T extends Node<T>> {
  readonly label: string;
  readonly pos: number;
  readonly len: number;
  readonly syntaxError: SyntaxError | null;
  readonly children: readonly T[];

  protected constructor(
    label: string,
    pos: number,
    len: number,
    syntaxError: SyntaxError | null,
    children: readonly T[]
  ) {
    this.label = label;
    this.pos = pos;
    this.len = len;
    this.syntaxError = syntaxError;
    this.children = children;
  }

  getInputSpan(input: string): string {
    return input.substring(this.pos, this.pos + this.len);
  }

  toString(): string {
    return `${this.label}: pos: ${this.pos}, len: ${this.len}`;
  }

  toPrettyString(input: string): string {
    const buffer: string[] = [];
    this.buildTree(input, '', buffer, true);
    return buffer.join('');
  }

  private buildTree(input: string, prefix: string, buffer: string[], isRoot: boolean): void {
    if (!isRoot) {
      buffer.push('\n');
    }
    buffer.push(prefix);
    buffer.push(this.label);
    if (this.children.length === 0) {
      buffer.push(`: "${this.getInputSpan(input)}"`);
    }

    for (let i = 0; i < this.children.length; i++) {
      const isLast = i === this.children.length - 1;
      const childPrefix = prefix + (isRoot ? '' : isLast ? '    ' : '|   ');
      const connector = isLast ? '`---' : '|---';

      buffer.push('\n');
      buffer.push(prefix);
      buffer.push(isRoot ? '' : connector);

      this.children[i].buildTree(input, childPrefix, buffer, false);
    }
  }
}

// -----------------------------------------------------------------------------------------------------------------

/**
 * An AST node representing either a rule match or a terminal match.
 */
export class ASTNode extends Node<ASTNode> {
  private constructor(
    label: string,
    pos: number,
    len: number,
    syntaxError: SyntaxError | null,
    children: readonly ASTNode[]
  ) {
    super(label, pos, len, syntaxError, children);
  }

  static terminal(terminalMatch: MatchResult): ASTNode {
    return new ASTNode(Terminal.nodeLabel, terminalMatch.pos, terminalMatch.len, null, []);
  }

  static nonTerminal(label: string, children: readonly ASTNode[]): ASTNode {
    if (children.length === 0) {
      throw new Error('children must not be empty');
    }
    const pos = children[0].pos;
    const len = children[children.length - 1].pos + children[children.length - 1].len - pos;
    return new ASTNode(label, pos, len, null, children);
  }

  static syntaxErrorNode(se: SyntaxError): ASTNode {
    return new ASTNode(SyntaxError.nodeLabel, se.pos, se.len, se, []);
  }

  // Public factory for creating nodes in tests/CST building
  static of(label: string, pos: number, len: number, children: readonly ASTNode[]): ASTNode {
    return new ASTNode(label, pos, len, null, children);
  }
}

// -----------------------------------------------------------------------------------------------------------------

/**
 * Build an AST from a parse tree.
 */
export function buildAST(parseResult: ParseResult): ASTNode {
  const extraNode =
    parseResult.unmatchedInput !== undefined
      ? ASTNode.syntaxErrorNode(parseResult.unmatchedInput)
      : null;

  return newASTNode(parseResult.topRuleName, parseResult.root, parseResult.transparentRules, extraNode);
}

function newASTNode(
  label: string,
  refdMatchResult: MatchResult,
  transparentRules: Set<string>,
  addExtraASTNode: ASTNode | null
): ASTNode {
  const childASTNodes: ASTNode[] = [];
  collectChildASTNodes(refdMatchResult, childASTNodes, transparentRules);
  if (addExtraASTNode !== null) {
    childASTNodes.push(addExtraASTNode);
  }
  return ASTNode.nonTerminal(label, childASTNodes);
}

function collectChildASTNodes(
  matchResult: MatchResult,
  collectedAstNodes: ASTNode[],
  transparentRules: Set<string>
): void {
  if (matchResult.isMismatch) {
    return;
  }
  if (matchResult instanceof SyntaxError) {
    collectedAstNodes.push(ASTNode.syntaxErrorNode(matchResult));
  } else {
    const clause = matchResult.clause;
    if (clause instanceof Terminal) {
      collectedAstNodes.push(ASTNode.terminal(matchResult));
    } else if (clause instanceof Ref) {
      if (!transparentRules.has(clause.ruleName)) {
        collectedAstNodes.push(
          newASTNode(clause.ruleName, matchResult.subClauseMatches[0], transparentRules, null)
        );
      }
    } else {
      for (const subClauseMatch of matchResult.subClauseMatches) {
        collectChildASTNodes(subClauseMatch, collectedAstNodes, transparentRules);
      }
    }
  }
}

// -----------------------------------------------------------------------------------------------------------------

/**
 * Base class for CST nodes.
 */
export abstract class CSTNode extends Node<CSTNode> {
  protected constructor(astNode: ASTNode, children: readonly CSTNode[]) {
    super(astNode.label, astNode.pos, astNode.len, astNode.syntaxError, children);
  }
}

// -----------------------------------------------------------------------------------------------------------------

/**
 * Type alias for factory functions that create CST nodes from AST nodes.
 */
export type CSTNodeFactoryFn = (astNode: ASTNode, children: readonly CSTNode[]) => CSTNode;

// -----------------------------------------------------------------------------------------------------------------

/**
 * Build a CST from an AST.
 */
export function buildCST(
  ast: ASTNode,
  factories: Map<string, CSTNodeFactoryFn>,
  allowSyntaxErrors: boolean
): CSTNode {
  return buildCSTInternal(ast, factories, allowSyntaxErrors);
}

function buildCSTInternal(
  ast: ASTNode,
  factoriesMap: Map<string, CSTNodeFactoryFn>,
  allowSyntaxErrors: boolean
): CSTNode {
  if (ast.syntaxError !== null) {
    if (!allowSyntaxErrors) {
      throw new Error(`Syntax error: ${ast.syntaxError}`);
    }
    const errorFactory = factoriesMap.get('<SyntaxError>');
    if (errorFactory === undefined) {
      throw new Error('No factory found for <SyntaxError>');
    }
    return errorFactory(ast, []);
  }

  let factory = factoriesMap.get(ast.label);

  if (factory === undefined && ast.label === Terminal.nodeLabel) {
    factory = factoriesMap.get('<Terminal>');
  }

  if (factory === undefined) {
    throw new Error(`No factory found for rule "${ast.label}"`);
  }

  const childCSTNodes = ast.children.map((child) => buildCSTInternal(child, factoriesMap, allowSyntaxErrors));
  return factory(ast, childCSTNodes);
}
