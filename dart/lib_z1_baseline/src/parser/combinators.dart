import 'clause.dart';
import 'match_result.dart';
import 'parser.dart';

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

/// Sequence: matches all sub-clauses in order.
class Seq extends HasMultipleSubClauses {
  const Seq(super.subClauses);

  @override
  MatchResult match(Parser parser, int pos) {
    final children = <MatchResult>[];
    int curr = pos;

    for (int i = 0; i < subClauses.length; i++) {
      final result = subClauses[i].match(parser, curr);
      if (result.isMismatch) {
        // THE SLOTS THAT DID MATCH ARE THE FRONTIER, and the one that did not
        // is where recovery has to look. Keep both: the matched prefix as the
        // input this sequence accounted for, and the failing slot's own
        // mismatch as the child to descend into. PEG stops at the first failing
        // slot, so there is exactly one of those, and it is always the last
        // child -- which is why it can be appended rather than copied into a
        // second list.
        children.add(result);
        return Mismatch(this, pos, curr - pos, subClauseMatches: children);
      }
      children.add(result);
      curr += result.len;
    }

    if (children.isEmpty) {
      return Match(this, pos, 0);
    }
    return Match(this, 0, 0, subClauseMatches: children);
  }

  @override
  String toString() => '(${subClauses.join(' ')})';
}

// -----------------------------------------------------------------------------------------------------------------

/// Ordered choice: matches the first successful sub-clause.
class First extends HasMultipleSubClauses {
  const First(super.subClauses);

  @override
  MatchResult match(Parser parser, int pos) {
    // Allocated only once an arm has failed, so an ordered choice that takes
    // its first arm allocates nothing it did not allocate before. (Measured on
    // its own this was inside run noise; the cost that did show up was the
    // per-memo-hit wrapper in [Ref], below.)
    List<MatchResult>? failed;
    var read = 0;
    for (int i = 0; i < subClauses.length; i++) {
      final result = subClauses[i].match(parser, pos);
      if (!result.isMismatch) {
        return Match(this, 0, 0, subClauseMatches: [result]);
      }
      // EVERY ARM IS KEPT, because a choice whose arms all failed is not itself
      // a place to repair -- the repair belongs in whichever arm got furthest,
      // and which that is cannot be known from here. So this reports the
      // furthest any arm read and hands all of them on to be descended into.
      (failed ??= <MatchResult>[]).add(result);
      if (result.len > read) read = result.len;
    }
    return Mismatch(this, pos, read, subClauseMatches: failed ?? const []);
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
  MatchResult match(Parser parser, int pos) {
    final children = <MatchResult>[];
    int curr = pos;
    MatchResult? stoppedBy;

    while (curr <= parser.input.length) {
      final result = subClause.match(parser, curr);
      if (result.isMismatch) {
        stoppedBy = result;
        break;
      }
      // Never consume more than one zero-length subclause match, to prevent
      // an infinite loop (e.g. for the pathological grammar "()*").
      if (result.len == 0) break;
      children.add(result);
      curr += result.len;
    }

    if (requireOne && children.isEmpty) {
      // Nothing repeated even once, so nothing was read; the body's own
      // mismatch is the whole account of why.
      return Mismatch(this, pos, 0, subClauseMatches: stoppedBy == null ? const [] : [stoppedBy]);
    }
    if (children.isEmpty) {
      return Match(this, pos, 0);
    }
    return Match(this, 0, 0, subClauseMatches: children);
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
  MatchResult match(Parser parser, int pos) {
    final result = subClause.match(parser, pos);
    if (result.isMismatch) {
      return Match(this, pos, 0);
    }
    return Match(this, 0, 0, subClauseMatches: [result]);
  }

  @override
  String toString() => '$subClause?';
}

// -----------------------------------------------------------------------------------------------------------------

/// Reference to a named rule.
///
/// Ref is the only clause type that recurses back through the memo table (by
/// calling [Parser.match]), so memoization is triggered only at the level of
/// rules, rather than at the level of individual clauses.
class Ref extends Clause {
  final String ruleName;
  const Ref(this.ruleName);

  @override
  MatchResult match(Parser parser, int pos) {
    // The Parser strips the '~' prefix from rule names, so we can look up directly
    final clause = parser.rules[ruleName];
    if (clause == null) {
      throw ArgumentError('Rule "$ruleName" not found');
    }
    final result = parser.match(clause, pos);
    // A FAILED REFERENCE IS NOT A SECOND FAILURE, so it is passed through
    // rather than wrapped. The rule's own mismatch already has this position,
    // this consumed length, and -- in [clause] -- the memo key that says which
    // cell to re-attempt, which is what a frontier walk actually needs; a `Ref`
    // node on top of it would only repeat the rule name. Wrapping cost 15% of
    // parse time (measured), because it allocated a node and a list on every
    // memo HIT for a failing rule, and a hit is meant to be free. The success
    // path still wraps: [buildAST] reads the rule name off that node.
    if (result.isMismatch) return result;
    return Match(this, 0, 0, subClauseMatches: [result]);
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
  MatchResult match(Parser parser, int pos) {
    final result = subClause.match(parser, pos);
    // A PREDICATE READS NOTHING, SO ITS FRONTIER IS ITS OWN POSITION. This one
    // fails because its body SUCCEEDED, and that success is not input this
    // clause accepted -- it is the reason for the failure. Reporting the body's
    // length here would claim a frontier past input the enclosing sequence
    // never consumed. The body is not carried either: a repair placed inside a
    // zero-width assertion would consume input the assertion does not.
    return result.isMismatch ? Match(this, pos, 0) : Mismatch(this, pos, 0);
  }

  @override
  String toString() => '!$subClause';
}

// -----------------------------------------------------------------------------------------------------------------

/// Positive lookahead: succeeds if sub-clause succeeds, consumes nothing.
class FollowedBy extends HasOneSubClause {
  const FollowedBy(super.subClause);

  @override
  MatchResult match(Parser parser, int pos) {
    final result = subClause.match(parser, pos);
    // Zero-width for the same reason as [NotFollowedBy], and the body is
    // withheld for the same reason -- even though here the body genuinely did
    // fail and looks like a frontier. It is not one: satisfying `&Foo` needs
    // input that this clause would then not consume, so a syntax error span
    // placed under it would be spanned by a node of width 0.
    return result.isMismatch ? Mismatch(this, pos, 0) : Match(this, pos, 0);
  }

  @override
  String toString() => '&$subClause';
}
