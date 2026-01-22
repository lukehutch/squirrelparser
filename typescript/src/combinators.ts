import { Clause } from './clause.js';
import { Match, mismatch, SyntaxError, type MatchResult } from './matchResult.js';
import type { Parser } from './parser.js';
import { Str, CharSet, Char, AnyChar } from './terminals.js';
import { parserStats } from './parserStats.js';

// -----------------------------------------------------------------------------------------------------------------

/**
 * Helper: check if all children are complete.
 */
function allComplete(children: MatchResult[]): boolean {
  return children.every((c) => c.isMismatch || c.isComplete);
}

// -----------------------------------------------------------------------------------------------------------------

/**
 * Base class for clauses with one sub-clause.
 */
export abstract class HasOneSubClause extends Clause {
  readonly subClause: Clause;

  protected constructor(subClause: Clause) {
    super();
    this.subClause = subClause;
  }

  checkRuleRefs(grammarMap: Map<string, Clause>): void {
    this.subClause.checkRuleRefs(grammarMap);
  }
}

// -----------------------------------------------------------------------------------------------------------------

/**
 * Base class for clauses with multiple sub-clauses.
 */
export abstract class HasMultipleSubClauses extends Clause {
  readonly subClauses: readonly Clause[];

  protected constructor(subClauses: Clause[]) {
    super();
    this.subClauses = subClauses;
  }

  checkRuleRefs(grammarMap: Map<string, Clause>): void {
    for (const clause of this.subClauses) {
      clause.checkRuleRefs(grammarMap);
    }
  }
}

// -----------------------------------------------------------------------------------------------------------------

/**
 * Sequence: matches all sub-clauses in order, with error recovery.
 */
export class Seq extends HasMultipleSubClauses {
  constructor(subClauses: Clause[]) {
    super(subClauses);
  }

  /**
   * Find the first meaningful bound among remaining siblings.
   * Skips over transparent rules (marked with ~) since they don't produce AST nodes
   * and shouldn't be used as structural boundaries.
   */
  private findMeaningfulBound(startIdx: number, parser: Parser): Clause | undefined {
    for (let j = startIdx; j < this.subClauses.length; j++) {
      const clause = this.subClauses[j];

      // Check if this clause is a Ref to a transparent rule
      if (clause instanceof Ref && parser.transparentRules.has(clause.ruleName)) {
        continue;
      }

      // Found a non-transparent clause - use as bound
      return clause;
    }
    return undefined;
  }

  match(parser: Parser, pos: number, bound?: Clause): MatchResult {
    const children: MatchResult[] = [];
    let curr = pos;
    let i = 0;

    while (i < this.subClauses.length) {
      const clause = this.subClauses[i];
      // Find meaningful bound by looking past transparent rules
      const siblingBound = this.findMeaningfulBound(i + 1, parser);
      const effectiveBound = parser.inRecoveryPhase && siblingBound !== undefined ? siblingBound : bound;
      const result = parser.match(clause, curr, effectiveBound);

      if (result.isMismatch) {
        if (parser.inRecoveryPhase && !result.isFromLRContext) {
          const recovery = this.recover(parser, curr, i);
          if (recovery !== null) {
            parserStats?.recordRecovery();
            const { inputSkip, grammarSkip, probe } = recovery;

            if (inputSkip > 0) {
              children.push(new SyntaxError({ pos: curr, len: inputSkip }));
            }

            for (let j = 0; j < grammarSkip; j++) {
              children.push(new SyntaxError({ pos: curr + inputSkip, len: 0, deletedClause: this.subClauses[i + j] }));
            }

            if (probe === null) {
              curr += inputSkip;
              break;
            }

            children.push(probe);
            curr += inputSkip + probe.len;
            i += grammarSkip + 1;
            continue;
          }
        }
        return mismatch;
      }

      children.push(result);
      curr += result.len;
      i++;
    }

    if (children.length === 0) {
      return new Match(this, pos, 0);
    }

    return new Match(this, 0, 0, { subClauseMatches: children, isComplete: allComplete(children) });
  }

  private recover(
    parser: Parser,
    curr: number,
    i: number
  ): { inputSkip: number; grammarSkip: number; probe: MatchResult | null } | null {
    const maxScan = parser.input.length - curr + 1;
    const maxGrammar = this.subClauses.length - i;

    for (let inputSkip = 0; inputSkip < maxScan; inputSkip++) {
      const probePos = curr + inputSkip;

      if (probePos >= parser.input.length) {
        if (inputSkip === 0) {
          return { inputSkip, grammarSkip: maxGrammar, probe: null };
        }
        continue;
      }

      for (let grammarSkip = 0; grammarSkip < maxGrammar; grammarSkip++) {
        if (grammarSkip === 0 && inputSkip === 0) continue;
        if (grammarSkip > 0) continue;

        const clauseIdx = i + grammarSkip;
        const clause = this.subClauses[clauseIdx];

        const failedClause = this.subClauses[i];
        if (failedClause instanceof Str && failedClause.text.length === 1 && inputSkip > 1) {
          if (clauseIdx + 1 < this.subClauses.length) {
            const nextClause = this.subClauses[clauseIdx + 1];
            if (nextClause instanceof Str) {
              const skipped = parser.input.substring(curr, curr + inputSkip);
              if (skipped.includes(nextClause.text)) {
                continue;
              }
            }
          }
        }
        const probe = parser.probe(clause, probePos);
        if (!probe.isMismatch) {
          if (clause instanceof Str && inputSkip > clause.text.length) {
            if (clause.text.length > 1) {
              continue;
            }
            const skipped = parser.input.substring(curr, curr + inputSkip);
            if (skipped.includes(clause.text)) {
              continue;
            }
          }
          return { inputSkip, grammarSkip, probe };
        }
      }
    }
    return null;
  }

  toString(): string {
    return `(${this.subClauses.map((c) => c.toString()).join(' ')})`;
  }
}

// -----------------------------------------------------------------------------------------------------------------

/**
 * Ordered choice: matches the first successful sub-clause.
 */
export class First extends HasMultipleSubClauses {
  constructor(subClauses: Clause[]) {
    super(subClauses);
  }

  match(parser: Parser, pos: number, bound?: Clause): MatchResult {
    for (let i = 0; i < this.subClauses.length; i++) {
      const result = parser.match(this.subClauses[i], pos, bound);
      if (!result.isMismatch) {
        if (parser.inRecoveryPhase && i === 0 && result.totDescendantErrors > 0) {
          let bestResult = result;
          let bestLen = result.len;
          let bestErrors = result.totDescendantErrors;

          for (let j = 1; j < this.subClauses.length; j++) {
            const altResult = parser.match(this.subClauses[j], pos, bound);
            if (!altResult.isMismatch) {
              const altLen = altResult.len;
              const altErrors = altResult.totDescendantErrors;

              const bestErrorRate = bestLen > 0 ? bestErrors / bestLen : 0.0;
              const altErrorRate = altLen > 0 ? altErrors / altLen : 0.0;
              const errorRateThreshold = 0.5;

              if (
                (bestErrorRate >= errorRateThreshold && altErrorRate < errorRateThreshold) ||
                altLen > bestLen ||
                (altLen === bestLen && altErrors < bestErrors)
              ) {
                bestResult = altResult;
                bestLen = altLen;
                bestErrors = altErrors;
              }
              if (altErrors === 0 && altLen >= bestLen) break;
            }
          }
          return new Match(this, 0, 0, { subClauseMatches: [bestResult], isComplete: bestResult.isComplete });
        }
        return new Match(this, 0, 0, { subClauseMatches: [result], isComplete: result.isComplete });
      }
    }
    return mismatch;
  }

  toString(): string {
    return `(${this.subClauses.map((c) => c.toString()).join(' / ')})`;
  }
}

// -----------------------------------------------------------------------------------------------------------------

/**
 * Base class for repetition (OneOrMore, ZeroOrMore).
 */
export class Repetition extends HasOneSubClause {
  protected readonly requireOne: boolean;

  constructor(subClause: Clause, requireOne: boolean) {
    super(subClause);
    this.requireOne = requireOne;
  }

  match(parser: Parser, pos: number, bound?: Clause): MatchResult {
    const children: MatchResult[] = [];
    let curr = pos;
    let incomplete = false;

    while (curr <= parser.input.length) {
      if (parser.inRecoveryPhase && bound !== undefined) {
        if (parser.canMatchNonzeroAt(bound, curr)) {
          break;
        }
      }

      const result = parser.match(this.subClause, curr);
      if (result.isMismatch) {
        if (!parser.inRecoveryPhase && curr < parser.input.length) {
          incomplete = true;
        }

        if (parser.inRecoveryPhase) {
          // Only pass hasValidMatch=true if we have at least one non-error child
          const hasValidMatch = children.some((c) => !(c instanceof SyntaxError));
          const recovery = this.recover(parser, curr, hasValidMatch, bound);
          if (recovery !== null) {
            parserStats?.recordRecovery();
            const { skip, probe } = recovery;
            children.push(new SyntaxError({ pos: curr, len: skip }));
            if (probe !== null) {
              children.push(probe);
              curr += skip + probe.len;
              continue;
            } else {
              curr += skip;
              break;
            }
          }
        }
        break;
      }
      if (result.len === 0) break;
      children.push(result);
      curr += result.len;
    }
    if (this.requireOne && children.length === 0) {
      return mismatch;
    }
    if (children.length === 0) {
      return new Match(this, pos, 0, { isComplete: !incomplete });
    }
    return new Match(this, 0, 0, { subClauseMatches: children, isComplete: !incomplete && allComplete(children) });
  }

  /**
   * Attempt recovery within repetition.
   *
   * Key principle: Repetitions only do recovery for COMPLEX subClauses (Seq, First, Ref).
   * For character-level terminals (CharSet, Char, AnyChar), the repetition should NOT
   * try to extend itself by skipping over errors. Instead, return what we have and
   * let the parent Seq handle errors with better structural context.
   *
   * @param hasValidMatch indicates if we've already matched at least one valid element.
   * @param bound is the next sibling clause that must not be skipped over.
   */
  private recover(
    parser: Parser,
    curr: number,
    hasValidMatch: boolean,
    bound: Clause | undefined
  ): { skip: number; probe: MatchResult | null } | null {
    // For character-level terminals, don't do repetition recovery
    if (this.subClause instanceof CharSet || this.subClause instanceof Char || this.subClause instanceof AnyChar) {
      return null;
    }

    // Scan for more matches
    for (let skip = 1; skip < parser.input.length - curr + 1; skip++) {
      const probePos = curr + skip;

      // Don't skip past the bound - let parent Seq handle recovery there
      if (bound !== undefined && parser.canMatchNonzeroAt(bound, probePos)) {
        break;
      }

      // Use match to allow internal recovery within complex subClauses
      const probe = parser.match(this.subClause, probePos);
      if (!probe.isMismatch && probe.len > 0) {
        return { skip, probe };
      }
    }

    // No more matches found.
    // Only skip remaining as error if we already have valid matches
    // (otherwise OneOrMore would incorrectly succeed with just errors).
    // But don't skip past the bound!
    if (hasValidMatch && curr < parser.input.length) {
      const skipToEnd = parser.input.length - curr;
      // Check if bound matches anywhere before end of input
      if (bound !== undefined) {
        for (let skip = 1; skip <= skipToEnd; skip++) {
          if (parser.canMatchNonzeroAt(bound, curr + skip)) {
            // Bound matches at this position - only skip up to here
            if (skip > 0) {
              return { skip, probe: null };
            }
            return null; // Can't skip anything without hitting bound
          }
        }
      }
      return { skip: skipToEnd, probe: null };
    }
    return null;
  }
}

// -----------------------------------------------------------------------------------------------------------------

/**
 * One or more repetitions.
 */
export class OneOrMore extends Repetition {
  constructor(subClause: Clause) {
    super(subClause, true);
  }

  toString(): string {
    return `${this.subClause}+`;
  }
}

// -----------------------------------------------------------------------------------------------------------------

/**
 * Zero or more repetitions.
 */
export class ZeroOrMore extends Repetition {
  constructor(subClause: Clause) {
    super(subClause, false);
  }

  toString(): string {
    return `${this.subClause}*`;
  }
}

// -----------------------------------------------------------------------------------------------------------------

/**
 * Optional: matches zero or one instance.
 */
export class Optional extends HasOneSubClause {
  constructor(subClause: Clause) {
    super(subClause);
  }

  match(parser: Parser, pos: number, bound?: Clause): MatchResult {
    const result = parser.match(this.subClause, pos, bound);

    if (result.isMismatch) {
      const incomplete = !parser.inRecoveryPhase && pos < parser.input.length;
      return new Match(this, pos, 0, { isComplete: !incomplete });
    }

    return new Match(this, 0, 0, { subClauseMatches: [result], isComplete: result.isComplete });
  }

  toString(): string {
    return `${this.subClause}?`;
  }
}

// -----------------------------------------------------------------------------------------------------------------

/**
 * Reference to a named rule.
 */
export class Ref extends Clause {
  readonly ruleName: string;

  constructor(ruleName: string) {
    super();
    this.ruleName = ruleName;
  }

  match(parser: Parser, pos: number, bound?: Clause): MatchResult {
    const clause = parser.rules.get(this.ruleName);
    if (clause === undefined) {
      throw new Error(`Rule "${this.ruleName}" not found`);
    }
    const result = parser.match(clause, pos, bound);
    if (result.isMismatch) return result;
    return new Match(this, 0, 0, { subClauseMatches: [result], isComplete: result.isComplete });
  }

  checkRuleRefs(grammarMap: Map<string, Clause>): void {
    if (!grammarMap.has(this.ruleName) && !grammarMap.has(`~${this.ruleName}`)) {
      throw new Error(`Rule "${this.ruleName}" not found in grammar`);
    }
  }

  toString(): string {
    return this.ruleName;
  }
}

// -----------------------------------------------------------------------------------------------------------------

/**
 * Negative lookahead: succeeds if sub-clause fails, consumes nothing.
 */
export class NotFollowedBy extends HasOneSubClause {
  constructor(subClause: Clause) {
    super(subClause);
  }

  match(parser: Parser, pos: number, bound?: Clause): MatchResult {
    const result = parser.match(this.subClause, pos, bound);
    return result.isMismatch ? new Match(this, pos, 0) : mismatch;
  }

  toString(): string {
    return `!${this.subClause}`;
  }
}

// -----------------------------------------------------------------------------------------------------------------

/**
 * Positive lookahead: succeeds if sub-clause succeeds, consumes nothing.
 */
export class FollowedBy extends HasOneSubClause {
  constructor(subClause: Clause) {
    super(subClause);
  }

  match(parser: Parser, pos: number, bound?: Clause): MatchResult {
    const result = parser.match(this.subClause, pos, bound);
    return result.isMismatch ? mismatch : new Match(this, pos, 0);
  }

  toString(): string {
    return `&${this.subClause}`;
  }
}
