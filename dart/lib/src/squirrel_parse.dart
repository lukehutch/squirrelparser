// =============================================================================
// SQUIRREL PARSER ENTRY POINT
// =============================================================================

import 'package:squirrel_parser/squirrel_parser.dart';

// ============================================================================
// Public CST API
// ============================================================================

/// Parse input and return a Concrete Syntax Tree (CST), and any syntax errors.
///
/// The CST is constructed directly from the parse tree using the provided factory functions.
/// This allows for fully custom syntax tree representations.
///
/// Throws [CSTFactoryValidationException] if the factory list is invalid.
/// Throws [DuplicateRuleNameException] if any rule name appears more than once in the factories list.
/// Throws [CSTConstructionException] if CST construction fails.
///
/// Example:
/// ```dart
/// final factories = [
///   CSTNodeFactory<MyNode>(
///     ruleName: 'Expr',
///     childRuleNames: ['Term'],
///     factory: (ruleName, children) {
///       return MyNode(name: ruleName, children: children);
///     },
///   ),
///   CSTNodeFactory<MyNode>(
///     ruleName: 'Term',
///     childRuleNames: ['<Terminal>'],
///     factory: (ruleName, children) {
///       return MyNode(name: ruleName);
///     },
///   ),
/// ];
///
/// final (cst, errors) = squirrelParse(
///   grammarText: grammar,
///   topRule: 'Expr',
///   factories: factories,
///   input: input,
/// );
/// ```
(CSTNode, List<SyntaxError>) squirrelParse({
  required String grammarText,
  required String topRule,
  required List<CSTNodeFactory<CSTNode>> factories,
  required String input,
}) {
  final rules = MetaGrammar.parseGrammar(grammarText);

  // Convert factories list to map, checking for duplicates
  final factoriesMap = _buildFactoriesMap(factories);

  // Parse the input using the rules
  final parser = Parser(rules: rules, input: input);
  final (matchResult, _) = parser.parse(topRule);
  final syntaxErrors = getSyntaxErrors(matchResult);

  // Validate factories
  _validateCSTFactories(rules, factoriesMap);

  // Build CST from parse tree
  final cst =
      _buildCST(matchResult, input, factoriesMap, syntaxErrors, topRule);

  return (cst, syntaxErrors);
}

// ============================================================================
// Private helpers
// ============================================================================

/// Build a factories map from a list, checking for duplicate rule names.
///
/// Throws [DuplicateRuleNameException] if any rule name appears more than once.
Map<String, CSTNodeFactory<CSTNode>> _buildFactoriesMap(
  List<CSTNodeFactory<CSTNode>> factories,
) {
  final result = <String, CSTNodeFactory<CSTNode>>{};
  final counts = <String, int>{};

  for (final factory in factories) {
    counts[factory.ruleName] = (counts[factory.ruleName] ?? 0) + 1;
  }

  // Check for duplicates
  for (final entry in counts.entries) {
    if (entry.value > 1) {
      throw DuplicateRuleNameException(ruleName: entry.key, count: entry.value);
    }
  }

  // Build map
  for (final factory in factories) {
    result[factory.ruleName] = factory;
  }

  return result;
}

/// Validate that CST factories cover all non-transparent grammar rules.
void _validateCSTFactories(
    Map<String, Clause> rules, Map<String, CSTNodeFactory<CSTNode>> factories) {
  final transparentRules = _getTransparentRules(rules);
  final requiredRules = rules.keys.toSet()..removeAll(transparentRules);
  final factoryRules = factories.keys.toSet();

  // Check if any factories are for transparent rules
  final factoriesForTransparentRules =
      factoryRules.intersection(transparentRules);
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

/// Get the set of transparent rule names from the grammar.
Set<String> _getTransparentRules(Map<String, Clause> rules) {
  final transparent = <String>{};

  for (final entry in rules.entries) {
    if (entry.value.transparent) {
      transparent.add(entry.key);
    }
  }

  return transparent;
}

/// Build a CST from a parse tree using the provided factories.
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

  // Get the factory for the top-level rule
  final factory = factories[topRuleName];
  if (factory == null) {
    throw CSTConstructionException('No factory found for rule: $topRuleName');
  }

  // Build child CST nodes from this match result
  final clause = matchResult.clause;
  final children = <CSTNode>[];

  // If the top-level clause is a non-transparent Ref, build a node for it
  if (clause is Ref && !clause.transparent) {
    final childFactory = factories[clause.ruleName];
    if (childFactory != null) {
      final childChildren = _buildCSTChildren(matchResult, input, factories,
          syntaxErrors, childFactory.childRuleNames);
      children.add(
          childFactory.factory(clause.ruleName, childChildren));
    }
  } else {
    // For non-Ref clauses, collect children normally
    children.addAll(_buildCSTChildren(
        matchResult, input, factories, syntaxErrors, factory.childRuleNames));
  }

  // Create the top-level CST node
  return factory.factory(topRuleName, children);
}

/// Recursively build CST nodes from a parse tree.
CSTNode _buildCSTNode(
  MatchResult matchResult,
  String input,
  Map<String, CSTNodeFactory<CSTNode>> factories,
  List<SyntaxError> syntaxErrors,
) {
  // Get the rule name from the clause
  final clause = matchResult.clause;
  if (clause is! Ref) {
    throw CSTConstructionException(
        'Expected Ref at top level, got ${clause.runtimeType}');
  }

  final ruleName = clause.ruleName;

  // If this is a transparent rule, skip it and recurse into children
  if (clause.transparent) {
    final children = matchResult.subClauseMatches
        .where((m) =>
            !m.isMismatch && m.clause is Ref && !(m.clause as Ref).transparent)
        .toList();

    if (children.isEmpty) {
      throw CSTConstructionException(
          'Transparent rule $ruleName has no non-transparent children');
    }
    if (children.length == 1) {
      return _buildCSTNode(children[0], input, factories, syntaxErrors);
    } else {
      throw CSTConstructionException(
          'Transparent rule $ruleName has multiple non-transparent children');
    }
  }

  final factory = factories[ruleName];
  if (factory == null) {
    throw CSTConstructionException('No factory found for rule: $ruleName');
  }

  // Get child matches
  final children = _buildCSTChildren(
      matchResult, input, factories, syntaxErrors, factory.childRuleNames);

  // Call the factory to create the CST node
  return factory.factory(ruleName, children);
}

/// Build CST nodes for children of a parse tree node.
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

    // Handle terminals - don't create CST nodes for terminals
    if (clause is Str ||
        clause is Char ||
        clause is CharRange ||
        clause is AnyChar) {
      continue;
    }

    // Handle rule references
    if (clause is Ref) {
      // Skip transparent rules - they're handled in _buildCSTNode
      if (clause.transparent) {
        continue;
      }

      final childFactory = factories[clause.ruleName];
      if (childFactory != null) {
        // Recursively build this child node
        final cstChild = _buildCSTNode(child, input, factories, syntaxErrors);
        children.add(cstChild);
      }
    }
  }

  return children;
}
