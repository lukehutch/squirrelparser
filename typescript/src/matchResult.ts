import type { Clause } from './clause.js';
import { Ref } from './combinators.js';

// -----------------------------------------------------------------------------------------------------------------

// Helper functions
function totalLength(children: MatchResult[]): number {
  if (children.length === 0) return 0;
  const first = children[0];
  const last = children[children.length - 1];
  return last.pos + last.len - first.pos;
}

function anyFromLR(children: MatchResult[]): boolean {
  return children.some((r) => r.isFromLRContext);
}

// -----------------------------------------------------------------------------------------------------------------

/**
 * Result of matching a clause at a position.
 *
 * All match types (terminals, single child, multiple children) are unified.
 * They differ only in |children|: terminals (0), single (1), multiple (n).
 */
export abstract class MatchResult {
  readonly clause: Clause | null;
  readonly pos: number;
  readonly len: number;
  readonly totDescendantErrors: number;

  /**
   * CONSTRAINT C6 (Completeness Propagation): Signals whether this is a
   * maximal parse. A complete result means the grammar matched all input
   * it could, with no recovery needed. Incomplete means parsing could
   * continue but was blocked.
   */
  readonly isComplete: boolean;

  /**
   * CONSTRAINT C10 (LR-Recovery Separation): Signals that this result came
   * from within a left-recursive expansion. Recovery must not be attempted
   * at results with this flag set.
   */
  readonly isFromLRContext: boolean;

  protected constructor(
    clause: Clause | null,
    pos: number,
    len: number,
    isComplete: boolean = true,
    isFromLRContext: boolean = false,
    totDescendantErrors: number = 0
  ) {
    this.clause = clause;
    this.pos = pos;
    this.len = len;
    this.isComplete = isComplete;
    this.isFromLRContext = isFromLRContext;
    this.totDescendantErrors = totDescendantErrors;
  }

  abstract get subClauseMatches(): MatchResult[];
  get isMismatch(): boolean {
    return false;
  }

  /**
   * Create a copy of this result with isFromLRContext=true.
   * Used by MemoEntry to mark results from left-recursive rules (C10).
   */
  abstract withLRContext(): MatchResult;

  abstract toPrettyString(input: string, indent?: number): string;
}

// -----------------------------------------------------------------------------------------------------------------

/**
 * A successful match (unified type for all match results).
 * Terminals have empty children list, combinators have one or more children.
 */
export class Match extends MatchResult {
  private readonly _subClauseMatches: MatchResult[];
  private readonly _isMismatch: boolean;

  constructor(
    clause: Clause | null,
    pos: number,
    len: number,
    options: {
      subClauseMatches?: MatchResult[];
      isComplete?: boolean;
      isFromLRContext?: boolean | null;
      numSyntaxErrors?: number;
      addSubClauseErrors?: boolean;
    } = {}
  ) {
    const subClauseMatches = options.subClauseMatches ?? [];
    const isComplete = options.isComplete ?? true;
    const numSyntaxErrors = options.numSyntaxErrors ?? 0;
    const addSubClauseErrors = options.addSubClauseErrors ?? true;

    const computedPos = subClauseMatches.length === 0 ? pos : subClauseMatches[0].pos;
    const computedLen = subClauseMatches.length === 0 ? len : totalLength(subClauseMatches);
    const computedIsFromLRContext =
      options.isFromLRContext ??
      (subClauseMatches.length === 0 ? false : anyFromLR(subClauseMatches));
    const computedTotDescendantErrors = addSubClauseErrors
      ? numSyntaxErrors + subClauseMatches.reduce((s, r) => s + r.totDescendantErrors, 0)
      : numSyntaxErrors;

    super(clause, computedPos, computedLen, isComplete, computedIsFromLRContext, computedTotDescendantErrors);
    this._subClauseMatches = subClauseMatches;
    this._isMismatch = pos === -1 && len === -1 && subClauseMatches.length === 0;
  }

  get subClauseMatches(): MatchResult[] {
    return this._subClauseMatches;
  }

  get isMismatch(): boolean {
    return this._isMismatch;
  }

  withLRContext(): MatchResult {
    if (this._isMismatch) {
      return lrPending;
    }
    if (this.isFromLRContext) {
      return this;
    }
    return new Match(this.clause, this.pos, this.len, {
      subClauseMatches: this._subClauseMatches,
      isComplete: this.isComplete,
      isFromLRContext: true,
      numSyntaxErrors: this.totDescendantErrors,
      addSubClauseErrors: false,
    });
  }

  toPrettyString(input: string, indent: number = 0): string {
    const buffer: string[] = [];
    buffer.push('  '.repeat(indent));
    if (this._isMismatch) {
      buffer.push('MISMATCH\n');
      return buffer.join('');
    }
    buffer.push(this.clause instanceof Ref ? this.clause.toString() : this.clause?.constructor.name ?? 'null');
    if (this._subClauseMatches.length === 0) {
      buffer.push(`: "${input.substring(this.pos, this.pos + this.len)}"`);
    }
    buffer.push('\n');
    for (const child of this._subClauseMatches) {
      buffer.push(child.toPrettyString(input, indent + 1));
    }
    return buffer.join('');
  }
}

// -----------------------------------------------------------------------------------------------------------------

/**
 * A syntax error node: records skipped input or deleted grammar elements.
 * if len == 0, then this was a deletion of a grammar element, and clause is the deleted clause.
 * if len > 0, then this was an insertion of skipped input.
 */
export class SyntaxError extends Match {
  /** The AST/CST node label for syntax errors. */
  static readonly nodeLabel = '<SyntaxError>';

  constructor(options: { pos: number; len: number; deletedClause?: Clause }) {
    super(options.deletedClause ?? null, options.pos, options.len, {
      isComplete: true,
      numSyntaxErrors: 1,
    });
  }

  override withLRContext(): MatchResult {
    return this; // SyntaxErrors don't need LR context
  }

  override toString(): string {
    // If len == 0, this is a deletion of a grammar element;
    // if len > 0, this is an insertion of skipped input.
    return this.len === 0
      ? `Missing grammar element ${this.clause?.constructor.name ?? 'unknown'} at pos ${this.pos}`
      : `${this.len} characters of unexpected input at pos ${this.pos}`;
  }

  override toPrettyString(input: string, indent: number = 0): string {
    return `${'  '.repeat(indent)}<SyntaxError>: ${this.toString()}\n`;
  }
}

// -----------------------------------------------------------------------------------------------------------------

/** Special mismatch sentinel. */
export const mismatch: MatchResult = new Match(null, -1, -1);

/** Special mismatch indicating LR cycle in progress. */
export const lrPending: MatchResult = new Match(null, -1, -1, { isFromLRContext: true });
