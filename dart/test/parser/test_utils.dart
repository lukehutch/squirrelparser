// =============================================================================
// SQUIRREL PARSER TEST UTILITIES
// =============================================================================
// Shared helper functions for all test files.

import 'package:squirrel_parser/squirrel_parser.dart';

// =============================================================================
// TEST HELPER FUNCTIONS
// =============================================================================

/// Parse input with error recovery and return (success, errorCount, skipped).
/// [topRule] defaults to 'S'.
///
/// Success means the grammar matched something (even with errors).
/// Failure means the entire input is unmatched (top-level SyntaxError).
(bool, int, List<String>) testParse(Map<String, Clause> rules, String input,
    [String topRule = 'S']) {
  final (result, _) = Parser(rules: rules, input: input).parse(topRule);

  // Result always spans input with new invariant.
  // Check if the entire result is just a SyntaxError (total failure)
  if (result is SyntaxError) {
    return (false, 1, [result.skipped]);
  }

  return (true, countErrors(result), getSkippedStrings(result));
}

/// Count deletions in parse tree.
int countDeletions(MatchResult? result) {
  if (result == null || result.isMismatch) return 0;
  int count = (result is SyntaxError && result.isDeletion) ? 1 : 0;
  for (final child in result.subClauseMatches) {
    count += countDeletions(child);
  }
  return count;
}

/// Parse and return the MatchResult directly for tree structure verification.
/// [topRule] defaults to 'S'.
/// Returns null if the entire input is unmatched (top-level SyntaxError).
MatchResult? parseForTree(Map<String, Clause> rules, String input,
    [String topRule = 'S']) {
  final (result, _) = Parser(rules: rules, input: input).parse(topRule);
  // Result always spans input. Return null only for total failure.
  if (result is SyntaxError) return null;
  return result;
}

/// Debug: print tree structure
void printTree(MatchResult? result, [int indent = 0]) {
  if (result == null) {
    print('${' ' * indent}null');
    return;
  }
  final prefix = ' ' * indent;
  final clause = result.clause;
  final clauseType = clause.runtimeType.toString();
  String clauseInfo = clauseType;
  if (clause is Ref) {
    clauseInfo = 'Ref(${clause.ruleName})';
  } else if (clause is Str) {
    clauseInfo = 'Str("${clause.text}")';
  } else if (clause is CharRange) {
    clauseInfo = 'CharRange(${clause.lo}-${clause.hi})';
  }
  print('$prefix$clauseInfo pos=${result.pos} len=${result.len}');
  for (final child in result.subClauseMatches) {
    if (!child.isMismatch) {
      printTree(child, indent + 2);
    }
  }
}

/// Get a simplified tree representation showing rule structure.
/// Returns a string like "E(E(E(n),+n),+n)" for left-associative parse.
String getTreeShape(MatchResult? result, Map<String, Clause> rules) {
  if (result == null || result.isMismatch) return 'MISMATCH';
  return _buildTreeShape(result, rules);
}

String _buildTreeShape(MatchResult result, Map<String, Clause> rules) {
  final clause = result.clause;

  // For Ref clauses, show the rule name and recurse into the referenced match
  if (clause is Ref) {
    final children = result.subClauseMatches;
    if (children.isEmpty) {
      return clause.ruleName;
    }
    // Get the shape of what the ref matched
    final childShapes = children
        .where((c) => !c.isMismatch)
        .map((c) => _buildTreeShape(c, rules))
        .toList();
    if (childShapes.isEmpty) return clause.ruleName;
    if (childShapes.length == 1) return '${clause.ruleName}(${childShapes[0]})';
    return '${clause.ruleName}(${childShapes.join(",")})';
  }

  // For Str terminals, show the matched string in quotes
  if (clause is Str) {
    return "'${clause.text}'";
  }

  // For Char terminals, show the character
  if (clause is Char) {
    return "'${clause.char}'";
  }

  // For CharRange terminals, show the range
  if (clause is CharRange) {
    return "[${clause.lo}-${clause.hi}]";
  }

  // For Seq, First, show children
  if (clause is Seq || clause is First) {
    final children = result.subClauseMatches
        .where((c) => !c.isMismatch)
        .map((c) => _buildTreeShape(c, rules))
        .toList();
    if (children.isEmpty) return '()';
    if (children.length == 1) return children[0];
    return '(${children.join(",")})';
  }

  // For repetition operators
  if (clause is OneOrMore || clause is ZeroOrMore) {
    final children = result.subClauseMatches
        .where((c) => !c.isMismatch)
        .map((c) => _buildTreeShape(c, rules))
        .toList();
    if (children.isEmpty) return '[]';
    return '[${children.join(",")}]';
  }

  // For Optional
  if (clause is Optional) {
    final children = result.subClauseMatches
        .where((c) => !c.isMismatch)
        .map((c) => _buildTreeShape(c, rules))
        .toList();
    if (children.isEmpty) return '?()';
    return '?(${children.join(",")})';
  }

  // Default: show clause type
  return clause.runtimeType.toString();
}

/// Check if tree has left-associative BINDING (not just left-recursive structure).
///
/// For true left-associativity like ((0+1)+2):
/// - The LEFT child E should itself be a recursive application (E op X), not just base case
/// - This means the left E's first child is also an E
///
/// For right-associative binding like 0+(1+2) from ambiguous grammar:
/// - The LEFT child E is just the base case (no E child)
/// - The RIGHT child E does all the work
bool isLeftAssociative(MatchResult? result, String ruleName) {
  if (result == null || result.isMismatch) return false;

  // Find all instances of the rule in the tree
  final instances = _findRuleInstances(result, ruleName);
  if (instances.length < 2) return false;

  // For left-associativity, check if ANY instance's LEFT CHILD E
  // is itself an application of the recursive pattern (not just base case)
  for (final instance in instances) {
    final (firstChild, isSameRule) = _getFirstSemanticChild(instance, ruleName);
    if (!isSameRule || firstChild == null) continue;

    // Now check if this first_child E is itself recursive (not just base case)
    // A recursive E will have another E as its first child
    final (nestedFirst, nestedIsSame) =
        _getFirstSemanticChild(firstChild, ruleName);
    if (nestedIsSame) {
      // The left E has another E as its first child -> truly left-associative
      return true;
    }
  }

  return false;
}

/// Get the first semantic child of a result, drilling through Seq/First wrappers.
/// Returns (child, isSameRule) where isSameRule indicates if child is Ref(ruleName).
(MatchResult?, bool) _getFirstSemanticChild(
    MatchResult result, String ruleName) {
  final children = result.subClauseMatches.where((c) => !c.isMismatch).toList();
  if (children.isEmpty) return (null, false);

  var firstChild = children.first;

  // Drill through Seq/First to find actual first element
  while (firstChild.clause is Seq || firstChild.clause is First) {
    final innerChildren =
        firstChild.subClauseMatches.where((c) => !c.isMismatch).toList();
    if (innerChildren.isEmpty) return (null, false);
    firstChild = innerChildren.first;
  }

  final isSameRule = firstChild.clause is Ref &&
      (firstChild.clause as Ref).ruleName == ruleName;
  return (firstChild, isSameRule);
}

/// Find all MatchResults where clause is Ref(ruleName)
List<MatchResult> _findRuleInstances(MatchResult result, String ruleName) {
  final instances = <MatchResult>[];

  if (result.clause is Ref && (result.clause as Ref).ruleName == ruleName) {
    instances.add(result);
  }

  for (final child in result.subClauseMatches.where((c) => !c.isMismatch)) {
    instances.addAll(_findRuleInstances(child, ruleName));
  }

  return instances;
}

/// Count the total occurrences of a rule in the parse tree.
int countRuleDepth(MatchResult? result, String ruleName) {
  if (result == null || result.isMismatch) return 0;
  return _countDepth(result, ruleName);
}

int _countDepth(MatchResult result, String ruleName) {
  final clause = result.clause;
  int count = 0;

  if (clause is Ref && clause.ruleName == ruleName) {
    count = 1;
  }

  // Recurse into ALL children to find all occurrences
  for (final child in result.subClauseMatches.where((c) => !c.isMismatch)) {
    count += _countDepth(child, ruleName);
  }

  return count;
}

/// Verify that for input with N operators, we have N+1 base terms and N operator applications.
/// For "n+n+n" we expect 3 'n' terms and 2 '+n' applications in a left-assoc tree.
bool verifyOperatorCount(MatchResult? result, String opStr, int expectedOps) {
  if (result == null || result.isMismatch) return false;
  int count = _countOperators(result, opStr);
  return count == expectedOps;
}

int _countOperators(MatchResult result, String opStr) {
  int count = 0;
  if (result.clause is Str && (result.clause as Str).text == opStr) {
    count = 1;
  }
  for (final child in result.subClauseMatches.where((c) => !c.isMismatch)) {
    count += _countOperators(child, opStr);
  }
  return count;
}
