import 'package:squirrel_parser/src/parser/parser.dart';

import 'combinators.dart';
import 'match_result.dart';
import 'terminals.dart';

/// Superclass of AST and CST nodes.
abstract class Node<T extends Node<dynamic>> {
  /// The label for this node (rule name or terminal type).
  final String label;

  /// The position in the input where this match starts.
  final int pos;

  /// The length of the match.
  final int len;

  /// Non-null if this node is a syntax error.
  final SyntaxError? syntaxError;

  /// Child nodes - all of type T.
  final List<T> children;

  Node({required this.label, required this.pos, required this.len, this.syntaxError, required this.children});

  String getInputSpan(String input) => input.substring(pos, pos + len);

  @override
  String toString() => '$label: pos: $pos, len: $len';

  /// Pretty print the tree.
  String toPrettyString(String input, {int indent = 0}) {
    final buffer = StringBuffer();
    _buildTree(input, '', buffer, true);
    return buffer.toString();
  }

  /// Recursively build a pretty string representation of the tree.
  void _buildTree(String input, String prefix, StringBuffer buffer, bool isRoot) {
    // Print current node
    if (!isRoot) {
      buffer.write('\n');
    }
    buffer.write(prefix);
    buffer.write(label);
    if (children.isEmpty) {
      buffer.write(': "${getInputSpan(input)}"');
    }

    // Print children
    for (int i = 0; i < children.length; i++) {
      final isLast = i == children.length - 1;
      final childPrefix = prefix + (isRoot ? '' : (isLast ? '    ' : '|   '));
      final connector = isLast ? '`---' : '|---';

      buffer.write('\n');
      buffer.write(prefix);
      buffer.write(isRoot ? '' : connector);

      children[i]._buildTree(input, childPrefix, buffer, false);
    }
  }
}

// -----------------------------------------------------------------------------------------------------------------

/// An AST node representing either a rule match or a terminal match.
///
/// AST nodes have:
/// - A label (the rule name or terminal type)
/// - A position and length in the input
/// - Children (other AST nodes)
/// - The matched text
class ASTNode extends Node<ASTNode> {
  ASTNode({
    required super.label,
    required super.children,
    required super.pos,
    required super.len,
    super.syntaxError,
  });

  /// Private constructor for terminal nodes (leaf nodes with text).
  ASTNode._terminal(MatchResult terminalMatch)
      : assert(terminalMatch.clause is Terminal, 'terminalMatch must be a terminal match'),
        super(
          label: Terminal.nodeLabel,
          pos: terminalMatch.pos,
          len: terminalMatch.len,
          children: const [],
          syntaxError: null,
        );

  /// Private constructor for non-terminal nodes (AST nodes with children).
  ASTNode._nonTerminal(String label, List<ASTNode> children)
      : assert(children.isNotEmpty, 'children must not be empty'),
        super(
          label: label,
          pos: children.first.pos,
          len: children.last.pos + children.last.len - children.first.pos,
          children: children,
          syntaxError: null,
        );

  ASTNode._syntaxError(SyntaxError syntaxError)
      : super(
          label: SyntaxError.nodeLabel,
          pos: syntaxError.pos,
          len: syntaxError.len,
          children: const [],
          syntaxError: syntaxError,
        );
}

// -----------------------------------------------------------------------------------------------------------------

/// Build an AST from a parse tree.
///
/// The AST only includes:
/// - Non-transparent Ref nodes (rule references) with their rule name as label (intermediate clauses that
///   are not at the top level of a rule are flattened out, and their children promoted to be children of
///   the nearest ancestral rule). Transparent rules and their descendants are skipped entirely.
/// - Terminal nodes (Str, Char, CharSet, AnyChar) with text as label
ASTNode buildAST({required ParseResult parseResult}) {
  return _newASTNode(
    label: parseResult.topRuleName,
    refdMatchResult: parseResult.root,
    transparentRules: parseResult.transparentRules,
    // addExtraASTNode is used to add another child to the toplevel AST node if there was any unmatched input
    addExtraASTNode: parseResult.unmatchedInput != null ? ASTNode._syntaxError(parseResult.unmatchedInput!) : null,
  );
}

/// Create a new labeled AST node, and recursively collect the child nodes
ASTNode _newASTNode({
  required String label,
  required MatchResult refdMatchResult,
  required Set<String> transparentRules,
  ASTNode? addExtraASTNode,
}) {
  final childASTNodes = <ASTNode>[];
  _collectChildASTNodes(
    matchResult: refdMatchResult,
    collectedAstNodes: childASTNodes,
    transparentRules: transparentRules,
  );
  if (addExtraASTNode != null) {
    childASTNodes.add(addExtraASTNode);
  }
  return ASTNode._nonTerminal(label, childASTNodes);
}

/// Recursively collect child AST nodes from a MatchResult, skipping transparent rules and mismatches
void _collectChildASTNodes({
  required MatchResult matchResult,
  required List<ASTNode> collectedAstNodes,
  required Set<String> transparentRules,
}) {
  if (matchResult.isMismatch) {
    return; // Mismatches don't have child matches so cannot create an AST node
  }
  if (matchResult is SyntaxError) {
    collectedAstNodes.add(ASTNode._syntaxError(matchResult));
  } else {
    var clause = matchResult.clause;
    if (clause is Terminal) {
      // Include terminals as leaf nodes
      collectedAstNodes.add(ASTNode._terminal(matchResult));
    } else if (clause is Ref) {
      // If node is a Ref, create an AST node for it (unless the ref'd rule is transparent).
      if (!transparentRules.contains(clause.ruleName)) {
        collectedAstNodes.add(_newASTNode(
          label: clause.ruleName,
          refdMatchResult: matchResult.subClauseMatches.first,
          transparentRules: transparentRules,
        ));
      }
      // Transparent rules are skipped -- don't create an AST node, and don't recurse to children.
    } else {
      // For other combinators, recursively collect their children
      for (final subClauseMatch in matchResult.subClauseMatches) {
        _collectChildASTNodes(
          matchResult: subClauseMatch,
          collectedAstNodes: collectedAstNodes,
          transparentRules: transparentRules,
        );
      }
    }
  }
}

// -----------------------------------------------------------------------------------------------------------------

/// Base class for all CST nodes.
///
/// CST nodes represent the concrete syntax structure of the input, with each node
/// corresponding to a grammar rule (non-transparent rules only) or a terminal.
/// Children are always CSTNode instances, allowing heterogeneous trees where different
/// rule types can be children of each other.
abstract class CSTNode extends Node<CSTNode> {
  CSTNode({
    required ASTNode astNode,
    required super.children,
  }) : super(
          label: astNode.label,
          pos: astNode.pos,
          len: astNode.len,
          syntaxError: astNode.syntaxError,
        );
}

// -----------------------------------------------------------------------------------------------------------------

/// Metadata for creating a CST node from an AST node, and child CST nodes that have already been converted.
/// Allows you to intercept AST nodes and transform them in some way (e.g. evaluating child nodes, or
/// modifying structure) when forming the CST from the AST.
class CSTNodeFactory {
  /// The grammar rule name this factory corresponds to
  final String ruleName;

  /// Factory function that creates a CST node from an AST node, and the children that have already
  /// been converted to CST nodes.
  final CSTNode Function(ASTNode astNode, List<CSTNode> children) factory;

  CSTNodeFactory({
    required this.ruleName,
    required this.factory,
  });
}

// -----------------------------------------------------------------------------------------------------------------

/// Build a CST from an AST, using the provided factories to create CST nodes for each rule.
///
/// If allowSyntaxErrors is false, and a syntax error is encountered in the AST, an ArgumentError will be
/// thrown describing only the first syntax error encountered.
///
/// If allowSyntaxErrors is true, then you must define a [CSTNodeFactory] for the label `'<SyntaxError>'`,
/// in order to decide how to construct CST nodes when there are syntax errors.
CSTNode buildCST({required ASTNode ast, required List<CSTNodeFactory> factories, required bool allowSyntaxErrors}) {
  var factoriesMap = <String, CSTNodeFactory>{};
  for (final factory in factories) {
    if (factoriesMap.containsKey(factory.ruleName)) {
      throw ArgumentError('Duplicate factory for rule "${factory.ruleName}"');
    }
    factoriesMap[factory.ruleName] = factory;
  }
  return _buildCST(ast, factoriesMap, allowSyntaxErrors);
}

CSTNode _buildCST(ASTNode ast, Map<String, CSTNodeFactory> factoriesMap, bool allowSyntaxErrors) {
  // Handle syntax errors
  if (ast.syntaxError != null) {
    if (!allowSyntaxErrors) {
      throw ArgumentError('Syntax error: ${ast.syntaxError}');
    }
    // If syntax errors are allowed, use the <SyntaxError> factory
    var errorFactory = factoriesMap['<SyntaxError>'];
    if (errorFactory == null) {
      throw ArgumentError('No factory found for <SyntaxError>');
    }
    return errorFactory.factory(ast, []);
  }

  // Look up factory by label
  var factory = factoriesMap[ast.label];

  // For terminals, use the <Terminal> factory if no specific factory exists
  if (factory == null && ast.label == Terminal.nodeLabel) {
    factory = factoriesMap['<Terminal>'];
  }

  if (factory == null) {
    throw ArgumentError('No factory found for rule "${ast.label}"');
  }

  final childCSTNodes =
      ast.children.map((childAstNode) => _buildCST(childAstNode, factoriesMap, allowSyntaxErrors)).toList();
  return factory.factory(ast, childCSTNodes);
}
