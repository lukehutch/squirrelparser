/**
 * Concrete Syntax Tree (CST) node and related classes
 *
 * CST nodes represent the structure of a parsed input with full syntactic detail,
 * including syntax error nodes for error recovery.
 */

/**
 * Base class for all CST nodes.
 *
 * CST nodes represent the concrete syntax structure of the input, with each node
 * corresponding to a grammar rule (non-transparent rules only) or a terminal.
 */
export abstract class CSTNode {
  /**
   * The name of this node (rule name or `<Terminal>`)
   */
  readonly name: string;

  constructor(name: string) {
    this.name = name;
  }

  toString(): string {
    return this.name;
  }
}

/**
 * A CST node representing a syntax error during parsing.
 *
 * This node is used when the parser encounters an error and needs to represent
 * the span of invalid input. It can be included in the CST to show where errors occurred.
 */
export class CSTSyntaxErrorNode extends CSTNode {
  /** The text that caused the error */
  readonly text: string;

  /** The position in the input where the error starts */
  readonly pos: number;

  /** The length of the error span */
  readonly len: number;

  constructor(name: string, text: string, pos: number, len: number) {
    super(name);
    this.text = text;
    this.pos = pos;
    this.len = len;
  }

  override toString(): string {
    return `<SyntaxError: ${this.name} at ${this.pos}:${this.len}>`;
  }
}

/**
 * Metadata for creating a CST node from a parse tree node.
 *
 * Each grammar rule (non-transparent) must have a corresponding factory.
 * The factory takes the rule name and actual child CST nodes,
 * and returns a CSTNode instance of type T.
 *
 * @template T The specific CST node type that this factory produces.
 *             Must be a subtype of CSTNode.
 */
export class CSTNodeFactory<T extends CSTNode> {
  /** The grammar rule name this factory corresponds to */
  readonly ruleName: string;

  /**
   * Factory function that creates a CST node of type T from rule name and actual child CST nodes
   */
  readonly factory: (
    ruleName: string,
    children: CSTNode[]
  ) => T;

  constructor(
    ruleName: string,
    factory: (ruleName: string, children: CSTNode[]) => T
  ) {
    this.ruleName = ruleName;
    this.factory = factory;
  }
}

/**
 * Exception thrown when CST factory validation fails
 */
export class CSTFactoryValidationException extends Error {
  /** Missing rule names (rules in grammar but not in factories) */
  readonly missing: Set<string>;

  /** Extra rule names (factories provided but not in grammar) */
  readonly extra: Set<string>;

  constructor(missing: Set<string>, extra: Set<string>) {
    const parts: string[] = [];
    if (missing.size > 0) {
      parts.push(`Missing factories: ${Array.from(missing).join(', ')}`);
    }
    if (extra.size > 0) {
      parts.push(`Extra factories: ${Array.from(extra).join(', ')}`);
    }
    super(`CSTFactoryValidationException: ${parts.join('; ')}`);
    this.missing = missing;
    this.extra = extra;
    this.name = 'CSTFactoryValidationException';
  }
}

/**
 * Exception thrown when CST construction fails
 */
export class CSTConstructionException extends Error {
  constructor(message: string) {
    super(`CSTConstructionException: ${message}`);
    this.name = 'CSTConstructionException';
  }
}

/**
 * Exception thrown when duplicate rule names are found in CST factories
 */
export class DuplicateRuleNameException extends Error {
  /** The rule name that appeared more than once */
  readonly ruleName: string;

  /** The count of how many times it appeared */
  readonly count: number;

  constructor(ruleName: string, count: number) {
    super(`DuplicateRuleNameException: Rule "${ruleName}" appears ${count} times in factory list`);
    this.ruleName = ruleName;
    this.count = count;
    this.name = 'DuplicateRuleNameException';
  }
}
