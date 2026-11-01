import 'dart:math';

import 'clause.dart';
import 'combinators.dart';
import 'match_result.dart';
import 'memo_entry.dart';

/// The squirrel parser: a memoizing recursive descent (packrat) parser that
/// directly supports left recursive PEG grammars.
class Parser {
  final Map<String, Clause> rules;
  final Set<String> transparentRules;
  final String topRuleName;
  final String input;
  final Map<Clause, Map<int, MemoEntry>> _memoTable = {};

  /// Records how many times a left recursive cycle has been expanded at each
  /// input position ("cycleDepthForPos" in the paper). A match attempt may be
  /// made past the end of the input, hence size input.length + 1.
  final List<int> memoVersion;

  /// Error recovery: `gaps[(r, pos)] = g` makes the repetition `r`, when its
  /// body fails at `pos`, skip the next `g` characters as a syntax error and
  /// carry on.
  final Map<(Clause, int), int> gaps = {};

  /// While recovering, each place a repetition stopped: the repetition, the
  /// position, and the body's mismatch there. Inner repetitions come first.
  List<(Repetition, int, MatchResult)>? stops;

  /// Set by recovery when no gap completes the parse: see [Seq].
  bool fillAtEnd = false;

  /// The furthest position at which a repetition tried its body in the match
  /// attempt under way: a gap at a later position cannot change its result.
  int reach = -1;

  Parser({required Map<String, Clause> rules, required this.topRuleName, required this.input})
      : rules = {},
        transparentRules = {},
        memoVersion = List.filled(input.length + 1, 0) {
    // Process rules: strip '~' prefix indicating a transparent rule
    for (final entry in rules.entries) {
      if (entry.key.startsWith('~')) {
        final ruleName = entry.key.substring(1);
        this.rules[ruleName] = entry.value;
        transparentRules.add(ruleName);
      } else {
        this.rules[entry.key] = entry.value;
      }
    }
  }

  /// Match a rule's top clause at a position, using memoization.
  ///
  /// Memoization is applied only at the granularity of rules (this method is
  /// only reached via [Ref.match] or the top-level [parse] call); clauses
  /// within a rule's clause tree recurse directly without memoization.
  MatchResult match(Clause clause, int pos) {
    if (pos > input.length) return Mismatch(clause, pos, 0);

    var memoEntry = _memoTable.putIfAbsent(clause, () => {}).putIfAbsent(pos, MemoEntry.new);
    return memoEntry.match(this, clause, pos);
  }

  /// Match a named rule at a position.
  MatchResult matchRule(String ruleName, int pos) {
    final clause = rules[ruleName];
    if (clause == null) {
      throw ArgumentError('Rule "$ruleName" not found');
    }
    return match(clause, pos);
  }

  /// Get the MemoEntry for a clause at a position (if it exists).
  MemoEntry? getMemoEntry(Clause clause, int pos) {
    return _memoTable[clause]?[pos];
  }

  /// The approximate position of the first syntax error: the largest input
  /// position of any mismatch recorded in the memo table, or -1 if there is
  /// none. (See the paper: the location of the first syntax error can
  /// generally be identified by searching the memo table for the largest
  /// position of any mismatch.)
  int syntaxErrorPosition() {
    var maxPos = -1;
    for (final entriesForClause in _memoTable.values) {
      for (final entry in entriesForClause.entries) {
        if (entry.value.result?.isMismatch == true && entry.key > maxPos) {
          maxPos = entry.key;
        }
      }
    }
    return maxPos;
  }

  /// The furthest position the last parse read: over [stops] and [result].
  int _frontier(MatchResult result) => stops!.fold(_far(result), (f, s) => max(f, _far(s.$3)));

  /// The furthest position a match attempt read, as far as its mismatches show.
  int _far(MatchResult m) => m.subClauseMatches.fold(m.pos + m.len, (f, c) => c.isMismatch ? max(f, _far(c)) : f);

  /// Reparses with the gap [parse] describes, or with no new gap if there is
  /// none.
  MatchResult _retry(int far, List<(Repetition, int, MatchResult)> at) {
    for (var g = 1; g <= input.length; g++) {
      (Repetition, int, int)? best;
      for (final (r, pos, m) in at) {
        if (pos + g >= input.length || pos + g < far && _far(m) < far || gaps.containsKey((r, pos))) continue;
        gaps[(r, pos)] = g;
        final result = _reparse(pos);
        final f = !result.isMismatch && result.len == input.length ? input.length + 1 : _frontier(result);
        if (f > max(far, pos + g) && (best == null || f > best.$3)) best = (r, pos, f);
        gaps.remove((r, pos));
        _drop(pos);
      }
      if (best != null) {
        gaps[(best.$1, best.$2)] = g;
        return _reparse(best.$2);
      }
    }
    return _reparse(input.length + 1);
  }

  /// Parses again, after the gaps at [from] changed, reusing every memo entry
  /// that never reached [from] or starts after it; with no [from], from scratch.
  MatchResult _reparse([int? from]) {
    if (from == null) {
      _memoTable.clear();
      memoVersion.fillRange(0, memoVersion.length, 0);
    } else {
      _drop(from);
    }
    stops!.clear();
    return matchRule(topRuleName, 0);
  }

  void _drop(int from) {
    for (final entries in _memoTable.values) {
      entries.removeWhere((pos, e) => pos <= from && e.reach >= from);
    }
  }

  /// Parse the input, starting by matching the top rule at position 0.
  ///
  /// The core algorithm performs no error recovery. If the top rule does not
  /// match the whole input, [ParseResult.hasSyntaxErrors] is set, and any
  /// unmatched trailing input is wrapped in a [SyntaxError] node.
  ///
  /// With [recover], a parse that fails is retried with one more gap (see
  /// [gaps]) until it matches the whole input or no gap gets it further. The
  /// gaps tried are at the repetitions whose body read up to the furthest
  /// point any parse attempt read, or that reach it with the gap, for
  /// g = 1, 2, ... characters. For the smallest g at which some gap lets the
  /// parse read past both the old frontier and the gap, or match the whole
  /// input, the gap kept is the one after which the parse reads furthest (the
  /// innermost repetition on a tie).
  /// When no gap helps, elements missing at the end of the input are filled
  /// in (see [fillAtEnd]) and the search goes on.
  ParseResult parse({bool recover = false}) {
    stops = recover ? [] : null;
    var result = matchRule(topRuleName, 0);
    while (recover && (result.isMismatch || result.len < input.length)) {
      final far = _frontier(result), at = [...stops!];
      result = _retry(far, at);
      if (_frontier(result) <= far) {
        if (fillAtEnd || !result.isMismatch) break;
        fillAtEnd = true;
        result = _reparse();
      }
    }
    final hasSyntaxErrors = result.isMismatch || result.len != input.length;
    return ParseResult(
      input: input,
      // If the top rule didn't match at all, return a SyntaxError spanning the entire input
      root: !result.isMismatch ? result : SyntaxError(pos: 0, len: input.length),
      // Save the name of the top rule
      topRuleName: topRuleName,
      // Record which rules are transparent for AST construction
      transparentRules: transparentRules,
      hasSyntaxErrors: hasSyntaxErrors,
      // If matched only part of the input, create an additional SyntaxError for the unmatched input
      unmatchedInput: !result.isMismatch && result.len < input.length
          ? SyntaxError(pos: result.len, len: input.length - result.len)
          : null,
    );
  }
}

// -----------------------------------------------------------------------------------------------------------------

/// The result of parsing the input.
class ParseResult {
  /// The input string that was parsed.
  final String input;

  /// The top-level MatchResult obtained from parsing the input.
  final MatchResult root;

  /// The rule name of the toplevel match
  final String topRuleName;

  /// The set of transparent rules in the grammar (rules that do not generate AST or CST nodes).
  final Set<String> transparentRules;

  /// True if the top rule failed to match the entire input.
  final bool hasSyntaxErrors;

  /// Contains a SyntaxError for any unmatched input if the whole input was not matched.
  final SyntaxError? unmatchedInput;

  ParseResult(
      {required this.input,
      required this.root,
      required this.topRuleName,
      required this.transparentRules,
      required this.hasSyntaxErrors,
      this.unmatchedInput});

  /// Get the syntax errors from the parse.
  List<SyntaxError> getSyntaxErrors() {
    if (!hasSyntaxErrors) {
      return [];
    }
    var errors = <SyntaxError>[];
    if (root is SyntaxError) {
      errors.add(root as SyntaxError);
    }
    if (unmatchedInput != null) {
      errors.add(unmatchedInput!);
    }
    return errors;
  }
}
