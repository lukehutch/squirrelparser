import 'clause.dart';
import 'combinators.dart';
import 'match_result.dart';
import 'memo_entry.dart';

/// The squirrel parser with bounded error recovery.
class Parser {
  final Map<String, Clause> rules;
  final Set<String> transparentRules;
  final String topRuleName;
  final String input;
  final Map<Clause, Map<int, MemoEntry>> _memoTable = {};
  final List<int> memoVersion;

  /// Phase 1 (Discovery): inRecoveryPhase = false
  /// Phase 2 (Recovery): inRecoveryPhase = true
  bool inRecoveryPhase = false;

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

  /// Match a clause at a position, using memoization.
  MatchResult match(Clause clause, int pos, {Clause? bound}) {
    if (pos > input.length) return mismatch;

    // C5 (Ref Transparency): Don't memoize Ref independently
    if (clause is Ref) {
      return clause.match(this, pos, bound: bound);
    }

    var memoEntry = _memoTable.putIfAbsent(clause, () => {}).putIfAbsent(pos, MemoEntry.new);
    return memoEntry.match(this, clause, pos, bound);
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

  /// Probe: Temporarily switch out of recovery mode to check if clause can match.
  MatchResult probe(Clause clause, int pos) {
    final savedPhase = inRecoveryPhase;
    inRecoveryPhase = false;
    final result = match(clause, pos);
    inRecoveryPhase = savedPhase;
    return result;
  }

  /// Enable recovery mode (Phase 2).
  void enableRecovery() {
    inRecoveryPhase = true;
  }

  /// Check if clause can match non-zero characters at position.
  bool canMatchNonzeroAt(Clause clause, int pos) {
    final result = probe(clause, pos);
    return !result.isMismatch && result.len > 0;
  }

  /// Parse input with two-phase error recovery.
  ///
  /// Returns (result, hasSyntaxErrors) where:
  ///   - result contains one MatchResult if the whole input matched or was a syntax error, or a list of
  ///     two MatchResults if there was a match and then the parser did not consume all of the input
  ///     (in which case, the second MatchResult will be a syntax error for the unconsumed input).
  ///   - hasSyntaxErrors = true if there were syntax errors
  ///
  /// If the grammar cannot match the input at all, returns a SyntaxError
  /// spanning the entire input. If there is trailing unmatched input,
  /// it is wrapped in a SyntaxError and included in the result.
  ParseResult parse() {
    // Phase 1: Discovery (try to parse without recovery from syntax errors)
    var result = matchRule(topRuleName, 0);
    var hasSyntaxErrors = result.isMismatch || result.pos != 0 || result.len != input.length;
    if (hasSyntaxErrors) {
      // Phase 2: Attempt to recover from syntax errors
      enableRecovery();
      result = matchRule(topRuleName, 0);
    }
    return ParseResult(
      input: input,
      // If couldn't match the input even after recovery, return a SyntaxError spanning the entire input
      root: !result.isMismatch ? result : SyntaxError(pos: 0, len: input.length),
      // Save the name of the top rule
      topRuleName: topRuleName,
      // Record which rules are transparent for AST construction
      transparentRules: transparentRules,
      // If phase 2 was initiated, there must be at least one syntax error
      hasSyntaxErrors: hasSyntaxErrors,
      // If matched only part of the input, create an additional SyntaxError for the unmatched input
      unmatchedInput: hasSyntaxErrors && result.len < input.length
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

  /// True if there are syntax errors somewhere in the parse tree, or there was unmatched input.
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
    void collectErrors(MatchResult result) {
      if (result is SyntaxError) {
        errors.add(result);
      } else {
        for (final child in result.subClauseMatches) {
          collectErrors(child);
        }
      }
    }

    collectErrors(root);
    if (unmatchedInput != null) {
      errors.add(unmatchedInput!);
    }
    return errors;
  }
}
