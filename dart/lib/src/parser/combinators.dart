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
        return mismatch;
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
    for (int i = 0; i < subClauses.length; i++) {
      final result = subClauses[i].match(parser, pos);
      if (!result.isMismatch) {
        return Match(this, 0, 0, subClauseMatches: [result]);
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
  MatchResult match(Parser parser, int pos) {
    final children = <MatchResult>[];
    int curr = pos;

    while (curr <= parser.input.length) {
      final result = subClause.match(parser, curr);
      if (result.isMismatch) {
        break;
      }
      // Never consume more than one zero-length subclause match, to prevent
      // an infinite loop (e.g. for the pathological grammar "()*").
      if (result.len == 0) break;
      children.add(result);
      curr += result.len;
    }

    if (requireOne && children.isEmpty) {
      return mismatch;
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
    if (result.isMismatch) {
      return mismatch;
    }
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
  MatchResult match(Parser parser, int pos) {
    final result = subClause.match(parser, pos);
    return result.isMismatch ? mismatch : Match(this, pos, 0);
  }

  @override
  String toString() => '&$subClause';
}
