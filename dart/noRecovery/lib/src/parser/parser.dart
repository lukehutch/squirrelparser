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
    if (pos > input.length) return mismatch;

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

  /// Parse the input, starting by matching the top rule at position 0.
  ///
  /// The core algorithm performs no error recovery. If the top rule does not
  /// match the whole input, [ParseResult.hasSyntaxErrors] is set, and any
  /// unmatched trailing input is wrapped in a [SyntaxError] node.
  ParseResult parse() {
    final result = matchRule(topRuleName, 0);
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
