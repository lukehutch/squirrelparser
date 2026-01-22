import 'clause.dart';
import 'match_result.dart';
import 'parser.dart';
import 'parser_stats.dart';
import 'terminals.dart';

/// Helper: check if all children are complete.
bool _allComplete(List<MatchResult> children) {
  return children.every((c) => c.isMismatch || c.isComplete);
}

// -----------------------------------------------------------------------------------------------------------------

abstract class HasOneSubClause extends Clause {
  final Clause subClause;
  const HasOneSubClause(this.subClause);

  @override
  void checkRuleRefs(Map<String, Clause> grammarMap) {
    subClause.checkRuleRefs(grammarMap);
  }
}

abstract class HasMultipleSubClauses extends Clause {
  final List<Clause> subClauses;
  const HasMultipleSubClauses(this.subClauses);

  @override
  void checkRuleRefs(Map<String, Clause> grammarMap) {
    for (final clause in subClauses) {
      clause.checkRuleRefs(grammarMap);
    }
  }
}

// -----------------------------------------------------------------------------------------------------------------

/// Sequence: matches all sub-clauses in order, with error recovery.
class Seq extends HasMultipleSubClauses {
  const Seq(super.subClauses);

  /// Find the first meaningful bound among remaining siblings.
  /// Skips over transparent rules (marked with ~) since they don't produce AST nodes
  /// and shouldn't be used as structural boundaries.
  /// [parser] is needed to check if rules are transparent.
  Clause? _findMeaningfulBound(int startIdx, Parser parser) {
    for (int j = startIdx; j < subClauses.length; j++) {
      final clause = subClauses[j];

      // Check if this clause is a Ref to a transparent rule
      if (clause is Ref && parser.transparentRules.contains(clause.ruleName)) {
        continue;
      }

      // Found a non-transparent clause - use as bound
      return clause;
    }
    return null;
  }

  @override
  MatchResult match(Parser parser, int pos, {Clause? bound}) {
    final children = <MatchResult>[];
    int curr = pos;
    int i = 0;

    while (i < subClauses.length) {
      final clause = subClauses[i];
      // Find meaningful bound by looking past nullable clauses like whitespace
      final siblingBound = _findMeaningfulBound(i + 1, parser);
      final effectiveBound = (parser.inRecoveryPhase && siblingBound != null) ? siblingBound : bound;
      final result = parser.match(clause, curr, bound: effectiveBound);

      if (result.isMismatch) {
        if (parser.inRecoveryPhase && !result.isFromLRContext) {
          final recovery = _recover(parser, curr, i);
          if (recovery != null) {
            final (inputSkip, grammarSkip, probe) = recovery;
            parserStats?.recordRecovery();

            if (inputSkip > 0) {
              // Add a syntax error for the skipped input
              children.add(SyntaxError(
                pos: curr,
                len: inputSkip,
              ));
            }

            for (int j = 0; j < grammarSkip; j++) {
              // Add a syntax error for each skipped grammar element
              children.add(SyntaxError(pos: curr + inputSkip, len: 0, deletedClause: subClauses[i + j]));
            }

            if (probe == null) {
              curr += inputSkip;
              break;
            }

            children.add(probe);
            curr += inputSkip + probe.len;
            i += grammarSkip + 1;
            continue;
          }
        }
        return mismatch;
      }

      children.add(result);
      curr += result.len;
      i++;
    }

    if (children.isEmpty) {
      return Match(this, pos, 0);
    }

    return Match(this, 0, 0, subClauseMatches: children, isComplete: _allComplete(children));
  }

  /// Attempt to recover from a mismatch.
  (int, int, MatchResult?)? _recover(Parser parser, int curr, int i) {
    final maxScan = parser.input.length - curr + 1;
    final maxGrammar = subClauses.length - i;

    for (int inputSkip = 0; inputSkip < maxScan; inputSkip++) {
      final probePos = curr + inputSkip;

      if (probePos >= parser.input.length) {
        if (inputSkip == 0) {
          return (inputSkip, maxGrammar, null);
        }
        continue;
      }

      for (int grammarSkip = 0; grammarSkip < maxGrammar; grammarSkip++) {
        if (grammarSkip == 0 && inputSkip == 0) continue;
        if (grammarSkip > 0) continue;

        final clauseIdx = i + grammarSkip;
        final clause = subClauses[clauseIdx];

        final failedClause = subClauses[i];
        if (failedClause is Str && failedClause.text.length == 1 && inputSkip > 1) {
          if (clauseIdx + 1 < subClauses.length) {
            final nextClause = subClauses[clauseIdx + 1];
            if (nextClause is Str) {
              final skipped = parser.input.substring(curr, curr + inputSkip);
              if (skipped.contains(nextClause.text)) {
                continue;
              }
            }
          }
        }
        final probe = parser.probe(clause, probePos);
        if (!probe.isMismatch) {
          if (clause is Str && inputSkip > clause.text.length) {
            if (clause.text.length > 1) {
              continue;
            }
            final skipped = parser.input.substring(curr, curr + inputSkip);
            if (skipped.contains(clause.text)) {
              continue;
            }
          }
          return (inputSkip, grammarSkip, probe);
        }
      }
    }
    return null;
  }

  @override
  String toString() => '(${subClauses.join(' ')})';
}

// -----------------------------------------------------------------------------------------------------------------

/// Ordered choice: matches the first successful sub-clause.
class First extends HasMultipleSubClauses {
  const First(super.subClauses);

  @override
  MatchResult match(Parser parser, int pos, {Clause? bound}) {
    for (int i = 0; i < subClauses.length; i++) {
      final result = parser.match(subClauses[i], pos, bound: bound);
      if (!result.isMismatch) {
        if (parser.inRecoveryPhase && i == 0 && result.totDescendantErrors > 0) {
          var bestResult = result;
          var bestLen = result.len;
          var bestErrors = result.totDescendantErrors;

          for (int j = 1; j < subClauses.length; j++) {
            final altResult = parser.match(subClauses[j], pos, bound: bound);
            if (!altResult.isMismatch) {
              final altLen = altResult.len;
              final altErrors = altResult.totDescendantErrors;

              final bestErrorRate = bestLen > 0 ? bestErrors / bestLen : 0.0;
              final altErrorRate = altLen > 0 ? altErrors / altLen : 0.0;
              const errorRateThreshold = 0.5;

              if (bestErrorRate >= errorRateThreshold && altErrorRate < errorRateThreshold ||
                  altLen > bestLen ||
                  altLen == bestLen && altErrors < bestErrors) {
                bestResult = altResult;
                bestLen = altLen;
                bestErrors = altErrors;
              }
              if (altErrors == 0 && altLen >= bestLen) break;
            }
          }
          return Match(this, 0, 0, subClauseMatches: [bestResult], isComplete: bestResult.isComplete);
        }
        return Match(this, 0, 0, subClauseMatches: [result], isComplete: result.isComplete);
      }
    }
    return mismatch;
  }

  @override
  String toString() => '(${subClauses.join(' / ')})';
}

// -----------------------------------------------------------------------------------------------------------------

/// Base class for repetition (OneOrMore, ZeroOrMore).
class Repetition extends HasOneSubClause {
  final bool requireOne;

  const Repetition(super.subClause, {required this.requireOne});

  @override
  MatchResult match(Parser parser, int pos, {Clause? bound}) {
    final children = <MatchResult>[];
    int curr = pos;
    bool incomplete = false;

    while (curr <= parser.input.length) {
      if (parser.inRecoveryPhase && bound != null) {
        if (parser.canMatchNonzeroAt(bound, curr)) {
          break;
        }
      }

      final result = parser.match(subClause, curr);
      if (result.isMismatch) {
        if (!parser.inRecoveryPhase && curr < parser.input.length) {
          incomplete = true;
        }

        if (parser.inRecoveryPhase) {
          // Only pass hasValidMatch=true if we have at least one non-error child.
          final hasValidMatch = children.any((c) => c is! SyntaxError);
          final recovery = _recover(parser, curr, hasValidMatch, bound);
          if (recovery != null) {
            parserStats?.recordRecovery();
            final (skip, probe) = recovery;
            // Add a syntax error for the skipped input
            children.add(SyntaxError(pos: curr, len: skip));
            if (probe != null) {
              children.add(probe);
              curr += skip + probe.len;
              continue;
            } else {
              // No probe found (hit end of input), just skip and break
              curr += skip;
              break;
            }
          }
        }
        break;
      }
      if (result.len == 0) break;
      children.add(result);
      curr += result.len;
    }
    if (requireOne && children.isEmpty) {
      return mismatch;
    }
    if (children.isEmpty) {
      return Match(this, pos, 0, isComplete: !incomplete);
    }
    return Match(this, 0, 0, subClauseMatches: children, isComplete: !incomplete && _allComplete(children));
  }

  /// Attempt recovery within repetition.
  ///
  /// Key principle: Repetitions only do recovery for COMPLEX subClauses (Seq, First, Ref).
  /// For character-level terminals (CharSet, Char, AnyChar), the repetition should NOT
  /// try to extend itself by skipping over errors. Instead, return what we have and
  /// let the parent Seq handle errors with better structural context.
  ///
  /// This prevents whitespace repetitions (ZeroOrMore(CharSet)) from skipping over
  /// content that should be handled as structural errors by the parent.
  ///
  /// [hasValidMatch] indicates if we've already matched at least one valid element.
  /// Only skip trailing garbage if we have valid matches (otherwise OneOrMore fails).
  /// [bound] is the next sibling clause that must not be skipped over.
  (int, MatchResult?)? _recover(Parser parser, int curr, bool hasValidMatch, Clause? bound) {
    // For character-level terminals (CharSet, Char, AnyChar), don't do repetition recovery.
    // These are typically used for whitespace or single-character patterns where recovery
    // doesn't make sense. Let the parent Seq handle errors with better structural context.
    if (subClause is CharSet || subClause is Char || subClause is AnyChar) {
      return null;
    }

    // Scan for more matches
    for (int skip = 1; skip < parser.input.length - curr + 1; skip++) {
      final probePos = curr + skip;

      // Don't skip past the bound - let parent Seq handle recovery there
      if (bound != null && parser.canMatchNonzeroAt(bound, probePos)) {
        break;
      }

      // Use match to allow internal recovery within complex subClauses.
      final probe = parser.match(subClause, probePos);
      if (!probe.isMismatch && probe.len > 0) {
        return (skip, probe);
      }
    }

    // No more matches found.
    // Only skip remaining as error if we already have valid matches
    // (otherwise OneOrMore would incorrectly succeed with just errors).
    // But don't skip past the bound!
    if (hasValidMatch && curr < parser.input.length) {
      int skipToEnd = parser.input.length - curr;
      // Check if bound matches anywhere before end of input
      if (bound != null) {
        for (int skip = 1; skip <= skipToEnd; skip++) {
          if (parser.canMatchNonzeroAt(bound, curr + skip)) {
            // Bound matches at this position - only skip up to here
            if (skip > 0) {
              return (skip, null);
            }
            return null; // Can't skip anything without hitting bound
          }
        }
      }
      return (skipToEnd, null);
    }
    return null;
  }
}

/// One or more repetitions.
class OneOrMore extends Repetition {
  const OneOrMore(super.subClause) : super(requireOne: true);

  @override
  String toString() => '$subClause+';
}

/// Zero or more repetitions.
class ZeroOrMore extends Repetition {
  const ZeroOrMore(super.subClause) : super(requireOne: false);

  @override
  String toString() => '$subClause*';
}

// -----------------------------------------------------------------------------------------------------------------

/// Optional: matches zero or one instance.
class Optional extends HasOneSubClause {
  const Optional(super.subClause);

  @override
  MatchResult match(Parser parser, int pos, {Clause? bound}) {
    final result = parser.match(subClause, pos, bound: bound);

    if (result.isMismatch) {
      final incomplete = !parser.inRecoveryPhase && pos < parser.input.length;
      return Match(this, pos, 0, isComplete: !incomplete);
    }

    return Match(this, 0, 0, subClauseMatches: [result], isComplete: result.isComplete);
  }

  @override
  String toString() => '$subClause?';
}

// -----------------------------------------------------------------------------------------------------------------

/// Reference to a named rule.
class Ref extends Clause {
  final String ruleName;
  const Ref(this.ruleName);

  @override
  MatchResult match(Parser parser, int pos, {Clause? bound}) {
    final clause = parser.rules[ruleName];
    if (clause == null) {
      throw ArgumentError('Rule "$ruleName" not found');
    }
    final result = parser.match(clause, pos, bound: bound);
    if (result.isMismatch) return result;
    return Match(this, 0, 0, subClauseMatches: [result], isComplete: result.isComplete);
  }

  @override
  void checkRuleRefs(Map<String, Clause> grammarMap) {
    if (!grammarMap.containsKey(ruleName) && !grammarMap.containsKey('~$ruleName')) {
      throw FormatException('Rule "$ruleName" not found in grammar');
    }
  }

  @override
  String toString() => ruleName;
}

// -----------------------------------------------------------------------------------------------------------------

/// Negative lookahead: succeeds if sub-clause fails, consumes nothing.
class NotFollowedBy extends HasOneSubClause {
  const NotFollowedBy(super.subClause);

  @override
  MatchResult match(Parser parser, int pos, {Clause? bound}) {
    final result = parser.match(subClause, pos, bound: bound);
    return result.isMismatch ? Match(this, pos, 0) : mismatch;
  }

  @override
  String toString() => '!$subClause';
}

// -----------------------------------------------------------------------------------------------------------------

/// Positive lookahead: succeeds if sub-clause succeeds, consumes nothing.
class FollowedBy extends HasOneSubClause {
  const FollowedBy(super.subClause);

  @override
  MatchResult match(Parser parser, int pos, {Clause? bound}) {
    final result = parser.match(subClause, pos, bound: bound);
    return result.isMismatch ? mismatch : Match(this, pos, 0);
  }

  @override
  String toString() => '&$subClause';
}
