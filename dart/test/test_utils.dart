// Test utilities for Squirrel Parser tests.

import 'package:squirrel_parser/squirrel_parser.dart';

// ============================================================================
// Core Test Functions
// ============================================================================

/// Parse input with error recovery and return (success, errorCount, skippedStrings).
(bool, int, List<String>) testParse(String grammarSpec, String input, [String topRule = 'S']) {
  final parseResult = squirrelParsePT(
    grammarSpec: grammarSpec,
    topRuleName: topRule,
    input: input,
  );

  final result = parseResult.root;
  final isCompleteFailure = result is SyntaxError && result.len == parseResult.input.length;
  final ok = !isCompleteFailure;

  var totErrors = result.totDescendantErrors;
  if (parseResult.unmatchedInput != null && parseResult.unmatchedInput!.pos >= 0) {
    totErrors += 1;
  }

  var skippedStrings = getSkippedStrings([result], input);
  if (parseResult.unmatchedInput != null && parseResult.unmatchedInput!.pos >= 0) {
    final unmatched = parseResult.unmatchedInput!;
    skippedStrings.add(parseResult.input.substring(unmatched.pos, unmatched.pos + unmatched.len));
  }

  return (ok, totErrors, skippedStrings);
}

/// Collect all SyntaxError nodes from the parse tree.
List<SyntaxError> getSyntaxErrors(List<MatchResult> results) {
  final errors = <SyntaxError>[];
  void collect(MatchResult r) {
    if (!r.isMismatch) {
      if (r is SyntaxError) {
        errors.add(r);
      } else {
        for (final child in r.subClauseMatches) {
          collect(child);
        }
      }
    }
  }
  for (final result in results) {
    collect(result);
  }
  return errors;
}

/// Count deletions in parse tree (SyntaxErrors with len == 0).
int countDeletions(List<MatchResult> results) =>
    getSyntaxErrors(results).where((e) => e.len == 0).length;

/// Get list of skipped strings from syntax errors (SyntaxErrors with len > 0).
List<String> getSkippedStrings(List<MatchResult> results, String input) =>
    getSyntaxErrors(results)
        .where((e) => e.len > 0)
        .map((e) => input.substring(e.pos, e.pos + e.len))
        .toList();

// ============================================================================
// Tree Structure Verification
// ============================================================================

/// Parse and return the MatchResult for tree structure verification.
/// Returns null if the entire input is a SyntaxError.
MatchResult? parseForTree(String grammarSpec, String input, [String topRule = 'S']) {
  final parseResult = squirrelParsePT(
    grammarSpec: grammarSpec,
    topRuleName: topRule,
    input: input,
  );
  final result = parseResult.root;
  return result is SyntaxError ? null : result;
}

/// Count occurrences of a rule in the parse tree.
int countRuleDepth(MatchResult? result, String ruleName) {
  if (result == null || result.isMismatch) return 0;
  int count = 0;
  if (result.clause is Ref && (result.clause as Ref).ruleName == ruleName) {
    count = 1;
  }
  for (final child in result.subClauseMatches) {
    if (!child.isMismatch) {
      count += countRuleDepth(child, ruleName);
    }
  }
  return count;
}

/// Check if tree has left-associative binding for a rule.
bool isLeftAssociative(MatchResult? result, String ruleName) {
  if (result == null || result.isMismatch) return false;

  final instances = _findRuleInstances(result, ruleName);
  if (instances.length < 2) return false;

  for (final instance in instances) {
    final (firstChild, isSameRule) = _getFirstSemanticChild(instance, ruleName);
    if (!isSameRule || firstChild == null) continue;

    final (_, nestedIsSame) = _getFirstSemanticChild(firstChild, ruleName);
    if (nestedIsSame) return true;
  }
  return false;
}

/// Verify operator count in parse tree.
bool verifyOperatorCount(MatchResult? result, String opStr, int expectedOps) {
  if (result == null || result.isMismatch) return false;
  return _countOperators(result, opStr) == expectedOps;
}

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

(MatchResult?, bool) _getFirstSemanticChild(MatchResult result, String ruleName) {
  final children = result.subClauseMatches.where((c) => !c.isMismatch).toList();
  if (children.isEmpty) return (null, false);

  var firstChild = children.first;
  while (firstChild.clause is Seq || firstChild.clause is First) {
    final innerChildren = firstChild.subClauseMatches.where((c) => !c.isMismatch).toList();
    if (innerChildren.isEmpty) return (null, false);
    firstChild = innerChildren.first;
  }

  final isSameRule = firstChild.clause is Ref && (firstChild.clause as Ref).ruleName == ruleName;
  return (firstChild, isSameRule);
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

// ============================================================================
// CST Testing Utilities
// ============================================================================

/// Parse and return raw MatchResult with syntax errors.
(MatchResult, List<SyntaxError>) parseToMatchResultForTesting(
  String grammarSpec,
  String topRule,
  String input,
) {
  final parseResult = squirrelParsePT(
    grammarSpec: grammarSpec,
    topRuleName: topRule,
    input: input,
  );
  return (parseResult.root, parseResult.getSyntaxErrors());
}

/// Parse and build CST with factory validation.
(CSTNode, List<SyntaxError>) parseWithGrammarSpecForTesting(
  String grammarSpec,
  String topRule,
  String input,
  List<CSTNodeFactory> factories,
) {
  final rules = MetaGrammar.parseGrammar(grammarSpec);
  _validateCSTFactories(rules, factories);

  final parseResult = squirrelParsePT(
    grammarSpec: grammarSpec,
    topRuleName: topRule,
    input: input,
  );

  final ast = buildAST(parseResult: parseResult);
  final cleanAst = _filterOutTerminals(ast);
  final cst = buildCST(ast: cleanAst, factories: factories, allowSyntaxErrors: false);

  return (cst, parseResult.getSyntaxErrors());
}

void _validateCSTFactories(Map<String, Clause> rules, List<CSTNodeFactory> factories) {
  final factoriesMap = <String, int>{};
  for (final factory in factories) {
    factoriesMap[factory.ruleName] = (factoriesMap[factory.ruleName] ?? 0) + 1;
  }

  for (final entry in factoriesMap.entries) {
    if (entry.value > 1) {
      throw ArgumentError('Rule "${entry.key}" appears ${entry.value} times in factory list');
    }
  }

  final transparentRules = rules.keys.where((k) => k.startsWith('~')).toSet();
  final requiredRules = rules.keys.toSet()..removeAll(transparentRules);
  final factoryRules = factories.map((f) => f.ruleName).toSet();

  final specialFactories = {'<Terminal>', '<SyntaxError>'};
  final regularFactoryRules = factoryRules.difference(specialFactories);

  final factoriesForTransparentRules = regularFactoryRules.intersection(transparentRules);
  if (factoriesForTransparentRules.isNotEmpty) {
    throw ArgumentError('Extra factories: ${factoriesForTransparentRules.join(", ")}');
  }

  final missing = requiredRules.difference(regularFactoryRules);
  final extra = regularFactoryRules.difference(requiredRules);

  if (missing.isNotEmpty || extra.isNotEmpty) {
    final parts = <String>[];
    if (missing.isNotEmpty) parts.add('Missing factories: ${missing.join(", ")}');
    if (extra.isNotEmpty) parts.add('Extra factories: ${extra.join(", ")}');
    throw ArgumentError(parts.join("; "));
  }
}

/// Filter out terminal nodes from an AST, keeping only rule nodes.
/// Terminal nodes have label `<Terminal>`.
ASTNode _filterOutTerminals(ASTNode node) {
  if (node.label == '<Terminal>') {
    return ASTNode(label: node.label, pos: node.pos, len: node.len, children: []);
  }
  return ASTNode(
    label: node.label,
    pos: node.pos,
    len: node.len,
    children: node.children
        .where((child) => child.label != '<Terminal>')
        .map(_filterOutTerminals)
        .toList(),
  );
}

// ============================================================================
// Debug Utilities
// ============================================================================

/// Print parse tree structure (for debugging).
void printTree(MatchResult? result, [int indent = 0]) {
  if (result == null) {
    print('${' ' * indent}null');
    return;
  }
  final prefix = ' ' * indent;
  final clause = result.clause;
  String clauseInfo = clause.runtimeType.toString();
  if (clause is Ref) {
    clauseInfo = 'Ref(${clause.ruleName})';
  } else if (clause is Str) {
    clauseInfo = 'Str("${clause.text}")';
  } else if (clause is CharSet) {
    clauseInfo = clause.toString();
  }
  print('$prefix$clauseInfo pos=${result.pos} len=${result.len}');
  for (final child in result.subClauseMatches) {
    if (!child.isMismatch) {
      printTree(child, indent + 2);
    }
  }
}

/// Get a simplified tree representation showing rule structure.
String getTreeShape(MatchResult? result) {
  if (result == null || result.isMismatch) return 'MISMATCH';
  return _buildTreeShape(result);
}

String _buildTreeShape(MatchResult result) {
  final clause = result.clause;

  if (clause is Ref) {
    final children = result.subClauseMatches.where((c) => !c.isMismatch).toList();
    if (children.isEmpty) return clause.ruleName;
    final childShapes = children.map(_buildTreeShape).toList();
    return childShapes.length == 1
        ? '${clause.ruleName}(${childShapes[0]})'
        : '${clause.ruleName}(${childShapes.join(",")})';
  }

  if (clause is Str) return "'${clause.text}'";
  if (clause is Char) return "'${clause.char}'";
  if (clause is CharSet) return clause.toString();

  if (clause is Seq || clause is First) {
    final children = result.subClauseMatches.where((c) => !c.isMismatch).map(_buildTreeShape).toList();
    if (children.isEmpty) return '()';
    return children.length == 1 ? children[0] : '(${children.join(",")})';
  }

  if (clause is OneOrMore || clause is ZeroOrMore) {
    final children = result.subClauseMatches.where((c) => !c.isMismatch).map(_buildTreeShape).toList();
    return children.isEmpty ? '[]' : '[${children.join(",")}]';
  }

  if (clause is Optional) {
    final children = result.subClauseMatches.where((c) => !c.isMismatch).map(_buildTreeShape).toList();
    return children.isEmpty ? '?()' : '?(${children.join(",")})';
  }

  return clause.runtimeType.toString();
}
