// ============================================================================
// Public Squirrel Parser API
// ============================================================================

import 'package:squirrel_parser/squirrel_parser.dart';

/// Parse input and return a Concrete Syntax Tree (CST).
///
/// Internally, the Abstract Syntax Tree (AST) is built from the parse tree, eliding all nodes that are
/// not rule references or terminals. (Transparent rule refs are elided too.)
///
/// The CST is then constructed from the Abstract Syntax Tree (AST) using the provided factory functions.
/// This allows for fully custom syntax tree representations. You can decide whether to include, process,
/// ignore, or transform any child nodes when your factory methods construct CST nodes from the AST.
///
/// You must define a [CSTNodeFactory] to handle terminals, with the rule name `'<Terminal>'`, in order to
/// construct CST nodes for terminal matches.
///
/// If [allowSyntaxErrors] is false, and a syntax error is encountered in the AST, an ArgumentError will be
/// thrown describing only the first syntax error encountered.
///
/// If [allowSyntaxErrors] is true, then you must define a [CSTNodeFactory] for the label `'<SyntaxError>'`,
/// in order to decide how to construct CST nodes when there are syntax errors.
///
/// Throws [ArgumentError] if the factory list is invalid or contains duplicate rule names.
/// Throws [StateError] if CST construction fails or returns null.
CSTNode squirrelParseCST({
  required String grammarSpec,
  required String topRuleName,
  required List<CSTNodeFactory> factories,
  required String input,
  bool allowSyntaxErrors = false,
}) =>
    buildCST(
      ast: squirrelParseAST(
        grammarSpec: grammarSpec,
        topRuleName: topRuleName,
        input: input,
      ),
      factories: factories,
      allowSyntaxErrors: allowSyntaxErrors,
    );

/// Call the Squirrel Parser with the given grammar, top rule, and input, and return the
/// Abstract Syntax Tree (AST), which consists of only non-transparent rule references and terminals.
/// Non-rule-ref AST nodes will have the label `'<Terminal>'` for terminals and `'<SyntaxError>'`
/// for syntax errors.
ASTNode squirrelParseAST({
  required String grammarSpec,
  required String topRuleName,
  required String input,
}) =>
    buildAST(
      parseResult: squirrelParsePT(
        grammarSpec: grammarSpec,
        topRuleName: topRuleName,
        input: input,
      ),
    );

/// Call the Squirrel Parser with the given grammar, top rule, and input, and return the raw parse tree (PT).
/// This is the lowest-level parsing function.
ParseResult squirrelParsePT({
  required String grammarSpec,
  required String topRuleName,
  required String input,
}) =>
    Parser(
      rules: MetaGrammar.parseGrammar(grammarSpec),
      topRuleName: topRuleName,
      input: input,
    ).parse();
