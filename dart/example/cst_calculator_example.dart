/// CST Example: Parse and display arithmetic expressions
///
/// This example demonstrates:
/// 1. Defining a grammar for arithmetic expressions with named operators
/// 2. Creating CST nodes that capture the operator symbols
/// 3. Building a parse tree that shows the structure of expressions
///
/// Grammar:
///   Expr   <- Term (AddOp Term)*
///   Term   <- Factor (MulOp Factor)*
///   Factor <- Number / '(' Expr ')'
///   Number <- [0-9]+
///   AddOp  <- '+' / '-'
///   MulOp  <- '*' / '/'
///   ~_     <- ' '*
///
/// Key insight: Operators are named rules (AddOp, MulOp) so they create CST nodes
/// that capture which operator was used, not just that an operator existed.
library;

import 'package:squirrel_parser/squirrel_parser.dart';

// ============================================================================
// CST Node Classes
// ============================================================================

/// Base node for expression tree
class ExprNode extends CSTNode {
  final List<CSTNode> children;

  ExprNode({required super.name, required this.children});

  @override
  String toString() => name;
}

/// Operator node (captures the operator symbol)
class OpNode extends CSTNode {
  final String symbol;

  OpNode({required super.name, required List<CSTNode> children})
      : symbol = children.isEmpty ? '' : children[0].toString();

  @override
  String toString() => symbol;
}

/// Terminal node (number or similar)
class TerminalNode extends CSTNode {
  final String value;

  TerminalNode({required super.name, required List<CSTNode> children})
      : value = children.isEmpty ? '' : children[0].toString();

  @override
  String toString() => value;
}

// ============================================================================
// Main Example
// ============================================================================

void main() {
  // Define the calculator grammar
  // Note: Operator rules (AddOp, MulOp) are named so they create CST nodes
  // This allows us to track which operator was used in the parse tree
  final calculatorGrammar = '''
    Expr   <- _ Term (_ AddOp _ Term)*;
    Term   <- Factor (_ MulOp _ Factor)*;
    Factor <- Number / '(' _ Expr _ ')';
    Number <- [0-9]+;
    AddOp  <- '+' / '-';
    MulOp  <- '*' / '/';
    ~_     <- [ \\t\\n\\r]*;
  ''';

  // Create CST factories
  // We need factories for all non-transparent rules
  final factories = [
    CSTNodeFactory<TerminalNode>(
      ruleName: 'Number',
      expectedChildren: ['<Terminal>'],
      factory: (ruleName, _expectedChildren, children) {
        return TerminalNode(name: ruleName, children: children);
      },
    ),
    CSTNodeFactory<OpNode>(
      ruleName: 'AddOp',
      expectedChildren: ['<Terminal>'],
      factory: (ruleName, _expectedChildren, children) {
        return OpNode(name: ruleName, children: children);
      },
    ),
    CSTNodeFactory<OpNode>(
      ruleName: 'MulOp',
      expectedChildren: ['<Terminal>'],
      factory: (ruleName, _expectedChildren, children) {
        return OpNode(name: ruleName, children: children);
      },
    ),
    CSTNodeFactory<ExprNode>(
      ruleName: 'Factor',
      expectedChildren: ['Number', 'Expr'],
      factory: (ruleName, _expectedChildren, children) {
        return ExprNode(name: ruleName, children: children);
      },
    ),
    CSTNodeFactory<ExprNode>(
      ruleName: 'Term',
      expectedChildren: ['Factor', 'MulOp'],
      factory: (ruleName, _expectedChildren, children) {
        return ExprNode(name: ruleName, children: children);
      },
    ),
    CSTNodeFactory<ExprNode>(
      ruleName: 'Expr',
      expectedChildren: ['Term', 'AddOp'],
      factory: (ruleName, _expectedChildren, children) {
        return ExprNode(name: ruleName, children: children);
      },
    ),
  ];

  // Test cases
  final testCases = [
    '42',
    '2 + 3',
    '10 - 5',
    '2 * 3 + 4',
    '(2 + 3) * 4',
  ];

  print('CST Calculator Example');
  print('='.padRight(50, '='));
  print('');

  for (final input in testCases) {
    print('Input: $input');

    try {
      final (cst, errors) = squirrelParse(
        calculatorGrammar,
        input,
        'Expr',
        factories,
      );

      if (errors.isEmpty) {
        print('Parsed successfully!');
        print('Root node: ${cst.name}');
      } else {
        print('Syntax Errors: ${errors.length}');
        for (final error in errors) {
          print('  - $error');
        }
      }
    } catch (e) {
      print('Error: $e');
    }

    print('');
  }

  print('='.padRight(50, '='));
  print('CST Example completed');
}
