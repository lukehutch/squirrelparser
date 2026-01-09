// Test utilities for Squirrel Parser tests.
// Shared helper functions for all test files.

import 'package:squirrel_parser/squirrel_parser.dart';

/// Parse input with error recovery and return [success, errorCount, skipped].
/// topRule defaults to 'S' for backward compatibility.
(bool, int, List<String>) testParse(
  Map<String, Clause> rules,
  String input, [
  String topRule = 'S',
]) {
  final parser = Parser(rules: rules, input: input);
  final (result, _) = parser.parse(topRule);

  // Result always spans input with new invariant.
  // Check if the entire result is just a SyntaxError (total failure)
  if (result is SyntaxError) {
    return (false, 1, [result.skipped]);
  }

  return (true, _countErrors(result), _getSkippedStrings(result));
}

/// Count deletions in parse tree.
int countDeletions(MatchResult? result) {
  if (result == null || result.isMismatch) return 0;
  int count = result is SyntaxError && result.isDeletion ? 1 : 0;
  for (final child in result.subClauseMatches) {
    count += countDeletions(child);
  }
  return count;
}

/// Count total syntax errors in a parse tree.
int countErrors(MatchResult? result) {
  if (result == null || result.isMismatch) return 0;
  return _countErrors(result);
}

int _countErrors(MatchResult result) {
  int count = result is SyntaxError ? 1 : 0;
  for (final child in result.subClauseMatches) {
    count += countErrors(child);
  }
  return count;
}

/// Get list of skipped strings from syntax errors.
List<String> _getSkippedStrings(MatchResult? result) {
  final skipped = <String>[];
  void collect(MatchResult? r) {
    if (r == null || r.isMismatch) return;
    if (r is SyntaxError && !r.isDeletion) {
      skipped.add(r.skipped);
    }
    for (final child in r.subClauseMatches) {
      collect(child);
    }
  }
  collect(result);
  return skipped;
}

/// Parse and return the MatchResult directly for tree structure verification.
/// topRule defaults to 'S' for backward compatibility.
/// Returns null only if parse completely failed (result is SyntaxError covering all input).
MatchResult? parseForTree(
  Map<String, Clause> rules,
  String input, [
  String topRule = 'S',
]) {
  final parser = Parser(rules: rules, input: input);
  final (result, _) = parser.parse(topRule);
  // With new invariant, parse() always returns a MatchResult spanning input
  // Return null only if entire result is a SyntaxError (total failure)
  if (result is SyntaxError) return null;
  return result;
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
  for (final child in result.subClauseMatches) {
    if (!child.isMismatch) {
      count += _countDepth(child, ruleName);
    }
  }

  return count;
}

// ============================================================================
// CST Testing Utilities
// ============================================================================

/// Internal method for parsing with pre-parsed grammar rules and raw parse tree.
/// Test utility only - not part of public API.
(MatchResult, List<SyntaxError>) parseToMatchResultForTesting(
  Map<String, Clause> rules,
  String topRule,
  String input,
) {
  final parser = Parser(rules: rules, input: input);
  final (matchResult, _) = parser.parse(topRule);
  final syntaxErrors = getSyntaxErrors(matchResult);
  return (matchResult, syntaxErrors);
}

/// Internal method for parsing with pre-parsed grammar rules.
/// Test utility only - not part of public API.
(CSTNode, List<SyntaxError>) parseWithRuleMapForTesting(
  Map<String, Clause> rules,
  String topRule,
  String input,
  List<CSTNodeFactory<CSTNode>> factories,
) {
  final factoriesMap = _buildFactoriesMap(factories);
  final (matchResult, syntaxErrors) =
      parseToMatchResultForTesting(rules, topRule, input);
  _validateCSTFactories(rules, factoriesMap);
  final cst = _buildCST(matchResult, input, factoriesMap, syntaxErrors, topRule);
  return (cst, syntaxErrors);
}

Map<String, CSTNodeFactory<CSTNode>> _buildFactoriesMap(
  List<CSTNodeFactory<CSTNode>> factories,
) {
  final result = <String, CSTNodeFactory<CSTNode>>{};
  final counts = <String, int>{};

  for (final factory in factories) {
    counts[factory.ruleName] = (counts[factory.ruleName] ?? 0) + 1;
  }

  for (final entry in counts.entries) {
    if (entry.value > 1) {
      throw DuplicateRuleNameException(
        ruleName: entry.key,
        count: entry.value,
      );
    }
  }

  for (final factory in factories) {
    result[factory.ruleName] = factory;
  }

  return result;
}

void _validateCSTFactories(
  Map<String, Clause> rules,
  Map<String, CSTNodeFactory<CSTNode>> factories,
) {
  final transparentRules = _getTransparentRules(rules);
  final requiredRules = rules.keys.toSet()..removeAll(transparentRules);
  final factoryRules = factories.keys.toSet();

  final factoriesForTransparentRules = factoryRules.intersection(transparentRules);
  if (factoriesForTransparentRules.isNotEmpty) {
    throw CSTFactoryValidationException(
      extra: factoriesForTransparentRules,
      missing: {},
    );
  }

  final missing = requiredRules.difference(factoryRules);
  final extra = factoryRules.difference(requiredRules);

  if (missing.isNotEmpty || extra.isNotEmpty) {
    throw CSTFactoryValidationException(missing: missing, extra: extra);
  }
}

Set<String> _getTransparentRules(Map<String, Clause> rules) {
  final transparent = <String>{};

  for (final entry in rules.entries) {
    if (entry.value.transparent) {
      transparent.add(entry.key);
    }
  }

  return transparent;
}

CSTNode _buildCST(
  MatchResult matchResult,
  String input,
  Map<String, CSTNodeFactory<CSTNode>> factories,
  List<SyntaxError> syntaxErrors,
  String topRuleName,
) {
  if (matchResult.isMismatch) {
    throw CSTConstructionException('Cannot build CST from mismatch result');
  }

  final factory = factories[topRuleName];
  if (factory == null) {
    throw CSTConstructionException('No factory found for rule: $topRuleName');
  }

  final clause = matchResult.clause;
  final children = <CSTNode>[];

  if (clause is Ref && !clause.transparent) {
    final childFactory = factories[clause.ruleName];
    if (childFactory != null) {
      final childChildren = _buildCSTChildren(
        matchResult,
        input,
        factories,
        syntaxErrors,
        childFactory.expectedChildren,
      );
      children.add(childFactory.factory(
        clause.ruleName,
        childFactory.expectedChildren,
        childChildren,
      ));
    }
  } else {
    children.addAll(_buildCSTChildren(
      matchResult,
      input,
      factories,
      syntaxErrors,
      factory.expectedChildren,
    ));
  }

  return factory.factory(topRuleName, factory.expectedChildren, children);
}

CSTNode _buildCSTNode(
  MatchResult matchResult,
  String input,
  Map<String, CSTNodeFactory<CSTNode>> factories,
  List<SyntaxError> syntaxErrors,
) {
  final clause = matchResult.clause;
  if (clause is! Ref) {
    throw CSTConstructionException(
      'Expected Ref at top level, got ${clause.runtimeType}',
    );
  }

  final ruleName = clause.ruleName;

  if (clause.transparent) {
    final children = matchResult.subClauseMatches
        .where((m) =>
            !m.isMismatch && m.clause is Ref && !(m.clause as Ref).transparent)
        .toList();

    if (children.isEmpty) {
      throw CSTConstructionException(
        'Transparent rule $ruleName has no non-transparent children',
      );
    }
    if (children.length == 1) {
      return _buildCSTNode(children[0], input, factories, syntaxErrors);
    } else {
      throw CSTConstructionException(
        'Transparent rule $ruleName has multiple non-transparent children',
      );
    }
  }

  final factory = factories[ruleName];
  if (factory == null) {
    throw CSTConstructionException('No factory found for rule: $ruleName');
  }

  final children = _buildCSTChildren(
    matchResult,
    input,
    factories,
    syntaxErrors,
    factory.expectedChildren,
  );

  return factory.factory(ruleName, factory.expectedChildren, children);
}

List<CSTNode> _buildCSTChildren(
  MatchResult matchResult,
  String input,
  Map<String, CSTNodeFactory<CSTNode>> factories,
  List<SyntaxError> syntaxErrors,
  List<String> expectedChildren,
) {
  final children = <CSTNode>[];

  for (final child in matchResult.subClauseMatches) {
    if (child.isMismatch) {
      continue;
    }

    final clause = child.clause;

    if (clause is Str ||
        clause is Char ||
        clause is CharRange ||
        clause is AnyChar) {
      continue;
    }

    if (clause is Ref) {
      if (clause.transparent) {
        continue;
      }

      final childFactory = factories[clause.ruleName];
      if (childFactory != null) {
        final cstChild = _buildCSTNode(child, input, factories, syntaxErrors);
        children.add(cstChild);
      }
    }
  }

  return children;
}
