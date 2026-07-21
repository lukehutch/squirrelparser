/// Instrumentation for error recovery: wraps the terminals (and rule
/// references) of a grammar in observer clauses that record match failures.
///
/// This leaves the core parsing algorithm completely untouched: the recovery
/// machinery obtains "what was expected where" information by running the
/// pure parser over an instrumented *grammar*, not by modifying the parser.
library;

import '../parser/clause.dart';
import '../parser/combinators.dart';
import '../parser/match_result.dart';
import '../parser/parser.dart';
import '../parser/terminals.dart';

/// Records, for each input position, which terminals failed there (and which
/// characters they expected), and which named rules failed there.
class FailureObserver {
  /// For each position, characters that are *exactly* determined by a failed
  /// terminal at that position (from Char/Str literals, or single-character
  /// character sets): structural "glue" the grammar demands verbatim.
  final Map<int, Set<String>> exactExpectedAt = {};

  /// For each position, representative "filler" characters from failed
  /// character-class terminals: some member of the class, chosen arbitrarily.
  final Map<int, Set<String>> fillerExpectedAt = {};

  /// For each position, the names of rules whose match attempt failed there.
  final Map<int, Set<String>> failedRulesAt = {};

  /// Spans (pos, len) where a NotFollowedBy lookahead failed because its
  /// subclause *matched*: repairing may require perturbing a character
  /// inside such a span to break the unwanted match.
  final List<(int, int)> blockedSpans = [];

  /// The farthest position at which any terminal failed.
  int farthestFail = -1;

  /// The farthest input position consulted by ANY character test, successful
  /// or failed (the "horizon"). Successful lookaheads read input beyond the
  /// farthest failure, so edits up to the horizon (not just the failure
  /// frontier) can change the parse; a string that agrees with the input on
  /// every consulted position parses identically.
  int horizon = -1;

  void recordTerminalSuccess(int pos, int len) {
    final last = len > 0 ? pos + len - 1 : pos - 1;
    if (last > horizon) horizon = last;
  }

  void recordTerminalFailure(int pos, ExpectedChar? expected) {
    if (pos > farthestFail) farthestFail = pos;
    if (pos > horizon) horizon = pos;
    if (expected != null) {
      (expected.isExact ? exactExpectedAt : fillerExpectedAt).putIfAbsent(pos, () => {}).add(expected.char);
    }
  }

  void recordRuleFailure(int pos, String ruleName) {
    failedRulesAt.putIfAbsent(pos, () => {}).add(ruleName);
  }

  void recordLookaheadBlock(int pos, int len) {
    blockedSpans.add((pos, len));
    if (pos + len > farthestFail) farthestFail = pos + len;
  }

  void reset() {
    exactExpectedAt.clear();
    fillerExpectedAt.clear();
    failedRulesAt.clear();
    blockedSpans.clear();
    farthestFail = -1;
    horizon = -1;
  }
}

/// A character expectation extracted from a failed terminal. [isExact] is
/// true when the grammar demands exactly this character (Char/Str literal or
/// single-character set); false when it is an arbitrary representative of a
/// character class.
class ExpectedChar {
  final String char;
  final bool isExact;
  const ExpectedChar(this.char, this.isExact);
}

/// Pick a character that the given terminal could accept at [pos] of [input],
/// or null if there is no meaningful single-character expectation.
ExpectedChar? expectedCharOf(Terminal t, String input, int pos) {
  if (t is Char) return ExpectedChar(t.char, true);
  if (t is Str) {
    // Find the first divergence between the expected text and the input.
    var k = 0;
    while (k < t.text.length && pos + k < input.length && input.codeUnitAt(pos + k) == t.text.codeUnitAt(k)) {
      k++;
    }
    return k < t.text.length ? ExpectedChar(t.text[k], true) : null;
  }
  if (t is CharSet) {
    if (!t.inverted) {
      if (t.ranges.isEmpty) return null;
      final (lo, hi) = t.ranges.first;
      // A single-character set is an exact expectation.
      final isExact = t.ranges.length == 1 && lo == hi;
      return ExpectedChar(String.fromCharCode(lo), isExact);
    }
    // Inverted set: find a printable character not in the set.
    for (var c = 0x20; c <= 0x7e; c++) {
      var inSet = false;
      for (final (lo, hi) in t.ranges) {
        if (c >= lo && c <= hi) {
          inSet = true;
          break;
        }
      }
      if (!inSet) return ExpectedChar(String.fromCharCode(c), false);
    }
    return null;
  }
  // AnyChar fails only at end of input; Nothing never fails.
  return null;
}

/// Wrapper around a terminal that reports failures to the observer.
class ObservedTerminal extends Clause {
  final Terminal terminal;
  final FailureObserver observer;
  const ObservedTerminal(this.terminal, this.observer);

  @override
  MatchResult match(Parser parser, int pos) {
    final result = terminal.match(parser, pos);
    if (!result.isMismatch) {
      observer.recordTerminalSuccess(pos, result.len);
      return result;
    }
    if (result.isMismatch) {
      // For multi-character Str terminals, the failure position is the point
      // of divergence from the expected text, not the terminal's start.
      var failPos = pos;
      final t = terminal;
      if (t is Str) {
        final input = parser.input;
        var k = 0;
        while (k < t.text.length &&
            pos + k < input.length &&
            input.codeUnitAt(pos + k) == t.text.codeUnitAt(k)) {
          k++;
        }
        failPos = pos + k;
      }
      observer.recordTerminalFailure(failPos, expectedCharOf(terminal, parser.input, pos));
    }
    return result;
  }

  @override
  void checkRuleRefs(Map<String, Clause> grammarMap) {}

  @override
  String toString() => terminal.toString();
}

/// Wrapper around a rule reference that reports rule failures to the observer.
class ObservedRef extends Clause {
  final Ref ref;
  final FailureObserver observer;
  const ObservedRef(this.ref, this.observer);

  @override
  MatchResult match(Parser parser, int pos) {
    final result = ref.match(parser, pos);
    if (result.isMismatch) {
      observer.recordRuleFailure(pos, ref.ruleName);
    }
    return result;
  }

  @override
  void checkRuleRefs(Map<String, Clause> grammarMap) => ref.checkRuleRefs(grammarMap);

  @override
  String toString() => ref.toString();
}

/// Replacement for NotFollowedBy that reports "blocked" spans: when the
/// lookahead fails because its subclause matched, a repair may need to
/// perturb a character inside the matched span.
class ObservedNotFollowedBy extends Clause {
  final Clause subClause;
  final FailureObserver observer;
  const ObservedNotFollowedBy(this.subClause, this.observer);

  @override
  MatchResult match(Parser parser, int pos) {
    final result = subClause.match(parser, pos);
    if (result.isMismatch) {
      return Match(this, pos, 0);
    }
    observer.recordLookaheadBlock(pos, result.len > 0 ? result.len : 1);
    return mismatch;
  }

  @override
  void checkRuleRefs(Map<String, Clause> grammarMap) => subClause.checkRuleRefs(grammarMap);

  @override
  String toString() => '!$subClause';
}

/// Rewrite a grammar's clause trees so that every terminal and rule reference
/// is wrapped in an observer clause. The core parser runs the instrumented
/// grammar unmodified.
Map<String, Clause> instrumentGrammar(Map<String, Clause> rules, FailureObserver observer) {
  final cache = <Clause, Clause>{};

  Clause wrap(Clause c) {
    final cached = cache[c];
    if (cached != null) return cached;
    Clause wrapped;
    if (c is Terminal) {
      wrapped = ObservedTerminal(c, observer);
    } else if (c is Ref) {
      wrapped = ObservedRef(c, observer);
    } else if (c is Seq) {
      wrapped = Seq(c.subClauses.map(wrap).toList());
    } else if (c is First) {
      wrapped = First(c.subClauses.map(wrap).toList());
    } else if (c is OneOrMore) {
      wrapped = OneOrMore(wrap(c.subClause));
    } else if (c is ZeroOrMore) {
      wrapped = ZeroOrMore(wrap(c.subClause));
    } else if (c is Optional) {
      wrapped = Optional(wrap(c.subClause));
    } else if (c is NotFollowedBy) {
      wrapped = ObservedNotFollowedBy(wrap(c.subClause), observer);
    } else if (c is FollowedBy) {
      wrapped = FollowedBy(wrap(c.subClause));
    } else {
      throw ArgumentError('Unknown clause type: ${c.runtimeType}');
    }
    cache[c] = wrapped;
    return wrapped;
  }

  return rules.map((name, clause) => MapEntry(name, wrap(clause)));
}
