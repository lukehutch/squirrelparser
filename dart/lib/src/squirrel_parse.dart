// =============================================================================
// SQUIRREL PARSER ENTRY POINT
// =============================================================================

import 'package:squirrel_parser/squirrel_parser.dart';

/// Parse input and return the AST, and any syntax errors.
///
/// The AST always spans the entire input (never null). If there are parse errors,
/// they are captured as SyntaxError nodes in the parse tree and returned
/// in the errors list.
///
/// Overload 1: With metagrammar string
(ASTNode, List<SyntaxError>) squirrelParse(String grammarText, String input, String topRule) {
  final rules = MetaGrammar.parseGrammar(grammarText);
  return _squirrelParseInternal(rules, topRule, input);
}

/// Overload 2: With grammar rules map
(ASTNode, List<SyntaxError>) squirrelParse(Map<String, Clause> rules, String topRule, String input) {
  return _squirrelParseInternal(rules, topRule, input);
}

/// Internal implementation shared by both overloads
(ASTNode, List<SyntaxError>) _squirrelParseInternal(Map<String, Clause> rules, String topRule, String input) {
  final parser = Parser(rules: rules, input: input);
  final (matchResult, _) = parser.parse(topRule);
  var ast = buildAST(matchResult, input, topRule: topRule);
  // Provide fallback empty AST node if buildAST returns null
  ast ??= ASTNode(label: topRule, pos: matchResult.pos, len: matchResult.len, children: [], input: input);
  final syntaxErrors = getSyntaxErrors(matchResult);
  return (ast, syntaxErrors);
}

