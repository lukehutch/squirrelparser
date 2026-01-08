/**
 * Combinator clause implementations for the Squirrel Parser.
 * WITH ERROR RECOVERY.
 */

import type { Clause } from './clause';
import type { Parser } from './parser';
import type { MatchResult } from './matchResult';
import { Match, MISMATCH, SyntaxError } from './matchResult';
import { Str } from './terminals';

/** Count syntax errors in a parse tree */
export function countErrors(result: MatchResult | null): number {
  if (result === null || result.isMismatch) return 0;
  let count = result instanceof SyntaxError ? 1 : 0;
  for (const child of result.subClauseMatches) {
    count += countErrors(child);
  }
  return count;
}

/** Get all syntax errors from parse tree.
 *
 * The parse tree is expected to span the entire input (invariant from Parser.parse()).
 * All syntax errors are already embedded in the tree as SyntaxError nodes.
 */
export function getSyntaxErrors(result: MatchResult, _input: string): SyntaxError[] {
  const syntaxErrors: SyntaxError[] = [];

  // Recursive collector - traverse tree and collect all SyntaxError nodes
  function collect(r: MatchResult) {
    if (r.isMismatch) return;
    if (r instanceof SyntaxError) {
      syntaxErrors.push(r);
    }
    for (const child of r.subClauseMatches) {
      collect(child);
    }
  }

  collect(result);
  return syntaxErrors;
}

function allComplete(children: readonly MatchResult[]): boolean {
  return children.every(r => r.isMismatch || r.isComplete);
}

/**
 * Sequence: matches all sub-clauses in order, with error recovery.
 */
export class Seq implements Clause {
  readonly transparent: boolean;

  constructor(
    readonly subClauses: readonly Clause[],
    transparent: boolean = false
  ) {
    this.transparent = transparent;
  }

  match(parser: Parser, pos: number, bound: Clause | null): MatchResult {
    const children: MatchResult[] = [];
    let curr = pos;
    let i = 0;

    while (i < this.subClauses.length) {
      const clause = this.subClauses[i];
      const next = (i + 1 < this.subClauses.length) ? this.subClauses[i + 1] : null;
      const effectiveBound = (parser.inRecoveryPhase && next !== null) ? next : bound;
      const result = parser.match(clause, curr, effectiveBound);

      if (result.isMismatch) {
        if (parser.inRecoveryPhase && !result.isFromLRContext) {
          const recovery = this._recover(parser, curr, i);
          if (recovery !== null) {
            const [inputSkip, grammarSkip, probe] = recovery;

            if (inputSkip > 0) {
              children.push(new SyntaxError(
                curr,
                inputSkip,
                parser.input.substring(curr, curr + inputSkip),
                false
              ));
            }

            for (let j = 0; j < grammarSkip; j++) {
              children.push(new SyntaxError(curr + inputSkip, 0, '', true));
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
        return MISMATCH;
      }

      children.push(result);
      curr += result.len;
      i++;
    }

    if (children.length === 0) {
      return new Match(this, pos, 0, []);
    }

    return new Match(this, 0, 0, children, allComplete(children));
  }

  /** Attempt to recover from a mismatch. */
  private _recover(parser: Parser, curr: number, i: number): [number, number, MatchResult | null] | null {
    const maxScan = parser.input.length - curr + 1;
    const maxGrammar = this.subClauses.length - i;

    for (let inputSkip = 0; inputSkip < maxScan; inputSkip++) {
      const probePos = curr + inputSkip;

      if (probePos >= parser.input.length) {
        if (inputSkip === 0) {
          return [inputSkip, maxGrammar, null];
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

          return [inputSkip, grammarSkip, probe];
        }
      }
    }

    return null;
  }

  toString(): string {
    return `Seq(${this.subClauses})`;
  }
}

/**
 * First/Choice: tries alternatives in order, returns first match.
 * In recovery phase, compares alternatives to find best match.
 */
export class First implements Clause {
  readonly transparent: boolean;

  constructor(
    readonly subClauses: readonly Clause[],
    transparent: boolean = false
  ) {
    this.transparent = transparent;
  }

  match(parser: Parser, pos: number, bound: Clause | null): MatchResult {
    for (let i = 0; i < this.subClauses.length; i++) {
      const result = parser.match(this.subClauses[i], pos, bound);
      if (!result.isMismatch) {
        // In recovery phase, if first alternative has errors, try others
        if (parser.inRecoveryPhase && i === 0 && countErrors(result) > 0) {
          let bestResult = result;
          let bestLen = result.len;
          let bestErrors = countErrors(result);

          for (let j = 1; j < this.subClauses.length; j++) {
            const altResult = parser.match(this.subClauses[j], pos, bound);
            if (!altResult.isMismatch) {
              const altLen = altResult.len;
              const altErrors = countErrors(altResult);

              const bestErrorRate = bestLen > 0 ? bestErrors / bestLen : 0.0;
              const altErrorRate = altLen > 0 ? altErrors / altLen : 0.0;
              const errorRateThreshold = 0.5;

              let shouldSwitch = false;

              if (bestErrorRate >= errorRateThreshold && altErrorRate < errorRateThreshold) {
                shouldSwitch = true;
              } else if (altLen > bestLen) {
                shouldSwitch = true;
              } else if (altLen === bestLen && altErrors < bestErrors) {
                shouldSwitch = true;
              }

              if (shouldSwitch) {
                bestResult = altResult;
                bestLen = altLen;
                bestErrors = altErrors;
              }

              if (altErrors === 0 && altLen >= bestLen) break;
            }
          }

          return new Match(this, 0, 0, [bestResult], bestResult.isComplete);
        }

        return new Match(this, 0, 0, [result], result.isComplete);
      }
    }
    return MISMATCH;
  }

  toString(): string {
    return `First(${this.subClauses})`;
  }
}

/**
 * OneOrMore: matches one or more repetitions, with error recovery.
 */
export class OneOrMore implements Clause {
  readonly transparent: boolean;

  constructor(
    readonly subClause: Clause,
    transparent: boolean = false
  ) {
    this.transparent = transparent;
  }

  match(parser: Parser, pos: number, bound: Clause | null): MatchResult {
    const children: MatchResult[] = [];
    let curr = pos;
    let incomplete = false;
    let hasRecovered = false;

    while (curr <= parser.input.length) {
      // Check bound in recovery phase
      if (parser.inRecoveryPhase && bound !== null) {
        if (parser.canMatchNonzeroAt(bound, curr)) {
          break;
        }
      }

      const result = parser.match(this.subClause, curr, null);

      if (result.isMismatch) {
        if (!parser.inRecoveryPhase && curr < parser.input.length) {
          incomplete = true;
        }

        if (parser.inRecoveryPhase) {
          const recovery = this._recover(parser, curr, hasRecovered);
          if (recovery !== null) {
            const [skip, probe] = recovery;
            children.push(new SyntaxError(
              curr,
              skip,
              parser.input.substring(curr, curr + skip),
              false
            ));
            hasRecovered = true;
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

    if (children.length === 0) {
      return MISMATCH;
    }

    return new Match(this, 0, 0, children, !incomplete && allComplete(children));
  }

  /** Attempt recovery within repetition. */
  private _recover(parser: Parser, curr: number, hasRecovered: boolean): [number, MatchResult | null] | null {
    for (let skip = 1; skip < parser.input.length - curr + 1; skip++) {
      const probe = parser.probe(this.subClause, curr + skip);
      if (!probe.isMismatch) {
        return [skip, probe];
      }
    }

    // If we've already recovered from previous errors and we're at or near
    // end of input, try to skip to end of input as a recovery
    if (hasRecovered && curr < parser.input.length) {
      const skipToEnd = parser.input.length - curr;
      return [skipToEnd, null];
    }

    return null;
  }

  toString(): string {
    return `${this.subClause}+`;
  }
}

/**
 * ZeroOrMore: matches zero or more repetitions, with error recovery.
 */
export class ZeroOrMore implements Clause {
  readonly transparent: boolean;

  constructor(
    readonly subClause: Clause,
    transparent: boolean = false
  ) {
    this.transparent = transparent;
  }

  match(parser: Parser, pos: number, bound: Clause | null): MatchResult {
    const children: MatchResult[] = [];
    let curr = pos;
    let incomplete = false;
    let hasRecovered = false;

    while (curr <= parser.input.length) {
      // Check bound in recovery phase
      if (parser.inRecoveryPhase && bound !== null) {
        if (parser.canMatchNonzeroAt(bound, curr)) {
          break;
        }
      }

      const result = parser.match(this.subClause, curr, null);

      if (result.isMismatch) {
        if (!parser.inRecoveryPhase && curr < parser.input.length) {
          incomplete = true;
        }

        if (parser.inRecoveryPhase) {
          const recovery = this._recover(parser, curr, hasRecovered);
          if (recovery !== null) {
            const [skip, probe] = recovery;
            children.push(new SyntaxError(
              curr,
              skip,
              parser.input.substring(curr, curr + skip),
              false
            ));
            hasRecovered = true;
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

    if (children.length === 0) {
      return new Match(this, pos, 0, [], !incomplete);
    }

    return new Match(this, 0, 0, children, !incomplete && allComplete(children));
  }

  /** Attempt recovery within repetition. */
  private _recover(parser: Parser, curr: number, hasRecovered: boolean): [number, MatchResult | null] | null {
    for (let skip = 1; skip < parser.input.length - curr + 1; skip++) {
      const probe = parser.probe(this.subClause, curr + skip);
      if (!probe.isMismatch) {
        return [skip, probe];
      }
    }

    // If we've already recovered from previous errors and we're at or near
    // end of input, try to skip to end of input as a recovery
    if (hasRecovered && curr < parser.input.length) {
      const skipToEnd = parser.input.length - curr;
      return [skipToEnd, null];
    }

    return null;
  }

  toString(): string {
    return `${this.subClause}*`;
  }
}

/**
 * Optional: matches zero or one occurrence.
 */
export class Optional implements Clause {
  readonly transparent: boolean;

  constructor(
    readonly subClause: Clause,
    transparent: boolean = false
  ) {
    this.transparent = transparent;
  }

  match(parser: Parser, pos: number, bound: Clause | null): MatchResult {
    const result = parser.match(this.subClause, pos, bound);

    if (result.isMismatch) {
      const incomplete = !parser.inRecoveryPhase && pos < parser.input.length;
      return new Match(this, pos, 0, [], !incomplete);
    }

    return new Match(this, 0, 0, [result], result.isComplete);
  }

  toString(): string {
    return `${this.subClause}?`;
  }
}

/**
 * NotFollowedBy: negative lookahead (doesn't consume input).
 */
export class NotFollowedBy implements Clause {
  readonly transparent: boolean;

  constructor(
    readonly subClause: Clause,
    transparent: boolean = false
  ) {
    this.transparent = transparent;
  }

  match(parser: Parser, pos: number, bound: Clause | null): MatchResult {
    const result = parser.match(this.subClause, pos, bound);
    if (result.isMismatch) {
      return new Match(this, pos, 0);
    }
    return MISMATCH;
  }

  toString(): string {
    return `!${this.subClause}`;
  }
}

/**
 * FollowedBy: positive lookahead (doesn't consume input).
 */
export class FollowedBy implements Clause {
  readonly transparent: boolean;

  constructor(
    readonly subClause: Clause,
    transparent: boolean = false
  ) {
    this.transparent = transparent;
  }

  match(parser: Parser, pos: number, bound: Clause | null): MatchResult {
    const result = parser.match(this.subClause, pos, bound);
    if (!result.isMismatch) {
      return new Match(this, pos, 0);
    }
    return MISMATCH;
  }

  toString(): string {
    return `&${this.subClause}`;
  }
}

/**
 * Ref: reference to a named rule (enables memoization and left-recursion handling).
 */
export class Ref implements Clause {
  readonly transparent: boolean;

  constructor(
    readonly ruleName: string,
    transparent: boolean = false
  ) {
    this.transparent = transparent;
  }

  match(parser: Parser, pos: number, bound: Clause | null): MatchResult {
    if (!(this.ruleName in parser.rules)) {
      throw new Error(`Rule not found: ${this.ruleName}`);
    }
    const rule = parser.rules[this.ruleName];
    const result = parser.match(rule, pos, bound);
    if (result.isMismatch) {
      return result;
    }
    return new Match(this, 0, 0, [result], result.isComplete, result.isFromLRContext);
  }

  toString(): string {
    return this.ruleName;
  }
}
