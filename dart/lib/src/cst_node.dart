/// Concrete Syntax Tree (CST) node and related classes
///
/// CST nodes represent the structure of a parsed input with full syntactic detail,
/// including syntax error nodes for error recovery.
library;

/// Base class for all CST nodes.
///
/// CST nodes represent the concrete syntax structure of the input, with each node
/// corresponding to a grammar rule (non-transparent rules only) or a terminal.
abstract class CSTNode {
  /// The name of this node (rule name or `<Terminal>`)
  final String name;

  CSTNode({required this.name});

  @override
  String toString() => name;
}

/// A CST node representing a syntax error during parsing.
///
/// This node is used when the parser encounters an error and needs to represent
/// the span of invalid input. It can be included in the CST to show where errors occurred.
class CSTSyntaxErrorNode extends CSTNode {
  /// The text that caused the error
  final String text;

  /// The position in the input where the error starts
  final int pos;

  /// The length of the error span
  final int len;

  CSTSyntaxErrorNode({
    required super.name,
    required this.text,
    required this.pos,
    required this.len,
  });

  @override
  String toString() => '<SyntaxError: $name at $pos:$len>';
}

/// Metadata for creating a CST node from a parse tree node.
///
/// Each grammar rule (non-transparent) must have a corresponding factory.
/// The factory takes the rule name and actual child CST nodes,
/// and returns a CSTNode instance of type T.
///
/// Type parameter T is the specific CST node type that this factory produces.
/// It must be a subtype of CSTNode.
class CSTNodeFactory<T extends CSTNode> {
  /// The grammar rule name this factory corresponds to
  final String ruleName;

  /// Factory function that creates a CST node of type T from rule name
  /// and actual child CST nodes
  final T Function(
    String ruleName,
    List<CSTNode> children,
  ) factory;

  CSTNodeFactory({
    required this.ruleName,
    required this.factory,
  });
}

/// Exception thrown when CST factory validation fails
class CSTFactoryValidationException implements Exception {
  /// Missing rule names (rules in grammar but not in factories)
  final Set<String> missing;

  /// Extra rule names (factories provided but not in grammar)
  final Set<String> extra;

  CSTFactoryValidationException({
    required this.missing,
    required this.extra,
  });

  @override
  String toString() {
    final parts = <String>[];
    if (missing.isNotEmpty) {
      parts.add('Missing factories: ${missing.join(", ")}');
    }
    if (extra.isNotEmpty) {
      parts.add('Extra factories: ${extra.join(", ")}');
    }
    return 'CSTFactoryValidationException: ${parts.join("; ")}';
  }
}

/// Exception thrown when CST construction fails
class CSTConstructionException implements Exception {
  final String message;

  CSTConstructionException(this.message);

  @override
  String toString() => 'CSTConstructionException: $message';
}

/// Exception thrown when duplicate rule names are found in CST factories
class DuplicateRuleNameException implements Exception {
  /// The rule name that appeared more than once
  final String ruleName;

  /// The count of how many times it appeared
  final int count;

  DuplicateRuleNameException({
    required this.ruleName,
    required this.count,
  });

  @override
  String toString() =>
      'DuplicateRuleNameException: Rule "$ruleName" appears $count times in factory list';
}
