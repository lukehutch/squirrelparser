import 'combinators.dart';
import 'match_result.dart';
import 'terminals.dart';

/// An AST node representing either a rule match or a terminal match.
///
/// AST nodes have:
/// - A label (the rule name or terminal type)
/// - A position and length in the input
/// - Children (other AST nodes)
/// - The matched text
class ASTNode {
  /// The label for this node (rule name or terminal type).
  final String label;

  /// The position in the input where this match starts.
  final int pos;

  /// The length of the match.
  final int len;

  /// Child AST nodes. These are flattened - only rule matches and terminals appear.
  final List<ASTNode> children;

  /// The input string (shared reference).
  final String _input;

  ASTNode({
    required this.label,
    required this.pos,
    required this.len,
    required this.children,
    required String input,
  }) : _input = input;

  /// Get the text matched by this node.
  String get text => _input.substring(pos, pos + len);

  /// Get a child by index.
  ASTNode getChild(int index) => children[index];

  @override
  String toString() => 'ASTNode($label, "$text", children: ${children.length})';

  /// Pretty print the AST tree.
  String toPrettyString({int indent = 0}) {
    final buffer = StringBuffer();
    buffer.write('  ' * indent);
    buffer.write(label);
    if (children.isEmpty) {
      buffer.write(': "$text"');
    }
    buffer.writeln();
    for (final child in children) {
      buffer.write(child.toPrettyString(indent: indent + 1));
    }
    return buffer.toString();
  }
}

/// Build an AST from a parse tree.
///
/// The AST only includes:
/// - Ref nodes (rule references) with their rule name as label
/// - Terminal nodes (Str, Char, CharRange, AnyChar) with text as label
///
/// All intermediate combinator nodes (Seq, First, etc.) are flattened out,
/// with their children promoted to be children of the nearest ancestral rule.
///
/// For top-level combinator matches, creates a synthetic node with the given topRule label.
ASTNode? buildAST(MatchResult? match, String input, {String? topRule}) {
  if (match == null || match.isMismatch) return null;

  var ast = _buildASTNode(match, input);

  // If top-level match is a combinator and we have a topRule label, build synthetic node
  if (ast == null && topRule != null) {
    final children = collectChildrenForAST(match, input);
    ast = ASTNode(
      label: topRule,
      pos: match.pos,
      len: match.len,
      children: children,
      input: input,
    );
  }

  return ast;
}

ASTNode? _buildASTNode(MatchResult match, String input) {
  final clause = match.clause;

  // Handle Ref nodes - these become AST nodes with the rule name as label
  // UNLESS they're marked as transparent, in which case we flatten them
  if (clause is Ref) {
    if (clause.transparent) {
      // Transparent rule - don't create a node, just return children
      return null;
    }
    // Get children by recursively processing the wrapped match
    final children = _collectChildren(match, input);
    return ASTNode(
      label: clause.ruleName,
      pos: match.pos,
      len: match.len,
      children: children,
      input: input,
    );
  }

  // Handle terminal nodes - these become leaf AST nodes
  if (clause is Terminal) {
    return ASTNode(
      label: clause.runtimeType.toString(),
      pos: match.pos,
      len: match.len,
      children: [],
      input: input,
    );
  }

  // For all other nodes (combinators), flatten and collect children
  // This shouldn't normally be called at the top level, but handle it anyway
  return null;
}

/// Collect children for an AST node by flattening combinators.
List<ASTNode> _collectChildren(MatchResult match, String input) {
  final result = <ASTNode>[];

  for (final child in match.subClauseMatches) {
    if (child.isMismatch || child is SyntaxError) {
      continue; // Skip error nodes in AST
    }

    final clause = child.clause;

    // If child is a Ref, terminal, or syntax error, add it as an AST node
    if (clause is Ref || clause is Terminal) {
      final node = _buildASTNode(child, input);
      if (node != null) {
        result.add(node);
      }
    }
    // Otherwise, it's a combinator - recursively collect its children
    else {
      result.addAll(_collectChildren(child, input));
    }
  }

  return result;
}

/// Collect children for AST building when top-level match is a combinator.
/// This is used by squirrelParse to build synthetic AST nodes from top-level combinators.
List<ASTNode> collectChildrenForAST(MatchResult match, String input) {
  final result = <ASTNode>[];

  for (final child in match.subClauseMatches) {
    if (child.isMismatch || child is SyntaxError) {
      continue; // Skip error nodes in AST
    }

    final clause = child.clause;

    // If child is a Ref, create an AST node for it (unless transparent)
    if (clause is Ref) {
      if (!clause.transparent) {
        final children = _collectChildren(child, input);
        result.add(ASTNode(
          label: clause.ruleName,
          pos: child.pos,
          len: child.len,
          children: children,
          input: input,
        ));
      }
      // Transparent rules are completely skipped - don't create node and don't include their children
    }
    // Include terminals as leaf nodes
    else if (clause is Terminal) {
      final node = _buildASTNode(child, input);
      if (node != null) {
        result.add(node);
      }
    }
    // For other combinators, recursively collect their children
    else {
      result.addAll(collectChildrenForAST(child, input));
    }
  }

  return result;
}
