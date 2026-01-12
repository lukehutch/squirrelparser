import type { Clause } from './clause.js';
import { Ref } from './combinators.js';
import { mismatch, SyntaxError, type MatchResult } from './matchResult.js';
import { MemoEntry } from './memoEntry.js';

// -----------------------------------------------------------------------------------------------------------------

/**
 * The squirrel parser with bounded error recovery.
 */
export class Parser {
  readonly rules: Map<string, Clause>;
  readonly transparentRules: Set<string>;
  readonly topRuleName: string;
  readonly input: string;
  readonly memoVersion: number[];
  private readonly _memoTable: Map<Clause, Map<number, MemoEntry>>;
  private _inRecoveryPhase = false;

  constructor(options: { rules: Map<string, Clause>; topRuleName: string; input: string }) {
    this.rules = new Map();
    this.transparentRules = new Set();
    this.topRuleName = options.topRuleName;
    this.input = options.input;
    this._memoTable = new Map();
    this.memoVersion = new Array(options.input.length + 1).fill(0);

    // Process rules: strip '~' prefix indicating a transparent rule
    for (const [key, value] of options.rules.entries()) {
      if (key.startsWith('~')) {
        const ruleName = key.substring(1);
        this.rules.set(ruleName, value);
        this.transparentRules.add(ruleName);
      } else {
        this.rules.set(key, value);
      }
    }
  }

  get inRecoveryPhase(): boolean {
    return this._inRecoveryPhase;
  }

  /**
   * Match a clause at a position, using memoization.
   */
  match(clause: Clause, pos: number, bound?: Clause): MatchResult {
    if (pos > this.input.length) return mismatch;

    // C5 (Ref Transparency): Don't memoize Ref independently
    if (clause instanceof Ref) {
      return clause.match(this, pos, bound);
    }

    let clauseMap = this._memoTable.get(clause);
    if (!clauseMap) {
      clauseMap = new Map();
      this._memoTable.set(clause, clauseMap);
    }

    let memoEntry = clauseMap.get(pos);
    if (!memoEntry) {
      memoEntry = new MemoEntry();
      clauseMap.set(pos, memoEntry);
    }

    return memoEntry.match(this, clause, pos, bound);
  }

  /**
   * Match a named rule at a position.
   */
  matchRule(ruleName: string, pos: number): MatchResult {
    const clause = this.rules.get(ruleName);
    if (clause === undefined) {
      throw new Error(`Rule "${ruleName}" not found`);
    }
    return this.match(clause, pos);
  }

  /**
   * Get the MemoEntry for a clause at a position (if it exists).
   */
  getMemoEntry(clause: Clause, pos: number): MemoEntry | undefined {
    return this._memoTable.get(clause)?.get(pos);
  }

  /**
   * Probe: Temporarily switch out of recovery mode to check if clause can match.
   */
  probe(clause: Clause, pos: number): MatchResult {
    const savedPhase = this._inRecoveryPhase;
    this._inRecoveryPhase = false;
    const result = this.match(clause, pos);
    this._inRecoveryPhase = savedPhase;
    return result;
  }

  /**
   * Enable recovery mode (Phase 2).
   */
  enableRecovery(): void {
    this._inRecoveryPhase = true;
  }

  /**
   * Check if clause can match non-zero characters at position.
   */
  canMatchNonzeroAt(clause: Clause, pos: number): boolean {
    const result = this.probe(clause, pos);
    return !result.isMismatch && result.len > 0;
  }

  /**
   * Parse input with two-phase error recovery.
   */
  parse(): ParseResult {
    // Phase 1: Discovery (try to parse without recovery from syntax errors)
    let result = this.matchRule(this.topRuleName, 0);
    const hasSyntaxErrors = result.isMismatch || result.pos !== 0 || result.len !== this.input.length;
    if (hasSyntaxErrors) {
      // Phase 2: Attempt to recover from syntax errors
      this.enableRecovery();
      result = this.matchRule(this.topRuleName, 0);
    }

    return new ParseResult({
      input: this.input,
      root: !result.isMismatch ? result : new SyntaxError({ pos: 0, len: this.input.length }),
      topRuleName: this.topRuleName,
      transparentRules: this.transparentRules,
      hasSyntaxErrors,
      unmatchedInput:
        hasSyntaxErrors && result.len < this.input.length
          ? new SyntaxError({ pos: result.len, len: this.input.length - result.len })
          : undefined,
    });
  }
}

// -----------------------------------------------------------------------------------------------------------------

/**
 * The result of parsing the input.
 */
export class ParseResult {
  readonly input: string;
  readonly root: MatchResult;
  readonly topRuleName: string;
  readonly transparentRules: Set<string>;
  readonly hasSyntaxErrors: boolean;
  readonly unmatchedInput: SyntaxError | undefined;

  constructor(options: {
    input: string;
    root: MatchResult;
    topRuleName: string;
    transparentRules: Set<string>;
    hasSyntaxErrors: boolean;
    unmatchedInput?: SyntaxError;
  }) {
    this.input = options.input;
    this.root = options.root;
    this.topRuleName = options.topRuleName;
    this.transparentRules = options.transparentRules;
    this.hasSyntaxErrors = options.hasSyntaxErrors;
    this.unmatchedInput = options.unmatchedInput;
  }

  /**
   * Get the syntax errors from the parse.
   */
  getSyntaxErrors(): SyntaxError[] {
    if (!this.hasSyntaxErrors) {
      return [];
    }
    const errors: SyntaxError[] = [];
    const collectErrors = (result: MatchResult) => {
      if (result instanceof SyntaxError) {
        errors.push(result);
      } else {
        for (const child of result.subClauseMatches) {
          collectErrors(child);
        }
      }
    };
    collectErrors(this.root);
    if (this.unmatchedInput !== undefined) {
      errors.push(this.unmatchedInput);
    }
    return errors;
  }
}
