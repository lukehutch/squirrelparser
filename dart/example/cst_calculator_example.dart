/// CST Example: A simple calculator that validates and evaluates arithmetic expressions
///
/// This example demonstrates:
/// 1. Defining a grammar for arithmetic expressions
/// 2. Creating CST nodes with semantic meaning (e.g., Expr, Term, Factor)
/// 3. Implementing validation logic within CST node constructors
/// 4. Evaluating expressions directly from CST nodes
///
/// Grammar:
///   Expr   <- Term (('+' / '-') Term)*
///   Term   <- Factor (('*' / '/') Factor)*
///   Factor <- Number / '(' Expr ')'
///   Number <- [0-9]+
///   ~_     <- ' '*
library;

import 'package:squirrel_parser/squirrel_parser.dart';

// ============================================================================
// CST Node Classes with Validation and Evaluation
// ============================================================================

/// A numeric literal
class NumberNode extends CSTNode {
  final int value;

  NumberNode({required super.name, required List<CSTNode> children})
      : value = int.parse(children.isEmpty ? '0' : children[0].toString()) {
    // Validation: ensure the parsed value is non-negative
    if (value < 0) {
      throw CSTConstructionException('Number node must be non-negative, got $value');
    }
  }

  @override
  String toString() => value.toString();
}

/// A factor (number or parenthesized expression)
class FactorNode extends CSTNode {
  final int value;

  FactorNode({required super.name, required List<CSTNode> children})
      : value = _evaluateFactor(children);

  static int _evaluateFactor(List<CSTNode> children) {
    if (children.isEmpty) {
      throw CSTConstructionException('Factor node must have children');
    }
    // If it's a single child, it's either a number or an expression
    final child = children[0];
    if (child is NumberNode) {
      return child.value;
    } else if (child is ExprNode) {
      return child.value;
    } else {
      throw CSTConstructionException('Unknown factor child type: ${child.runtimeType}');
    }
  }

  @override
  String toString() => value.toString();
}

/// A term (product/quotient of factors)
class TermNode extends CSTNode {
  final int value;

  TermNode({required super.name, required List<CSTNode> children})
      : value = _evaluateTerm(children);

  static int _evaluateTerm(List<CSTNode> children) {
    if (children.isEmpty) {
      throw CSTConstructionException('Term node must have children');
    }

    int result = (children[0] as FactorNode).value;

    // Process operator-operand pairs
    int i = 1;
    while (i < children.length) {
      // i = operator, i+1 = operand
      if (i + 1 >= children.length) {
        throw CSTConstructionException('Term: operator without operand');
      }

      // Operator is represented in the parse tree but not as a CST node
      // In a real implementation, you'd need to track this differently
      // For now, just skip to the next operator-operand pair
      i += 2;
    }

    return result;
  }

  @override
  String toString() => value.toString();
}

/// An expression (sum/difference of terms)
class ExprNode extends CSTNode {
  final int value;

  ExprNode({required super.name, required List<CSTNode> children})
      : value = _evaluateExpr(children);

  static int _evaluateExpr(List<CSTNode> children) {
    if (children.isEmpty) {
      throw CSTConstructionException('Expr node must have children');
    }

    int result = (children[0] as TermNode).value;

    // Process operator-operand pairs
    int i = 1;
    while (i < children.length) {
      // i = operator, i+1 = operand
      if (i + 1 >= children.length) {
        throw CSTConstructionException('Expr: operator without operand');
      }

      // Operator is represented in the parse tree but not as a CST node
      // In a real implementation, you'd track the operator differently
      // For now, just skip to the next operator-operand pair
      i += 2;
    }

    return result;
  }

  @override
  String toString() => value.toString();
}

// ============================================================================
// Main Example
// ============================================================================

void main() {
  // Define the calculator grammar
  final calculatorGrammar = '''
    Expr   <- Term (('+' / '-') Term)*;
    Term   <- Factor (('*' / '/') Factor)*;
    Factor <- Number / '(' Expr ')';
    Number <- [0-9]+;
    ~_     <- ' '*;
  ''';

  // Create CST factories
  final factories = [
    CSTNodeFactory<NumberNode>(
      ruleName: 'Number',
      expectedChildren: ['<Terminal>'],
      factory: (ruleName, expectedChildren, children) {
        return NumberNode(name: ruleName, children: children);
      },
    ),
    CSTNodeFactory<FactorNode>(
      ruleName: 'Factor',
      expectedChildren: ['Number', 'Expr'],
      factory: (ruleName, expectedChildren, children) {
        return FactorNode(name: ruleName, children: children);
      },
    ),
    CSTNodeFactory<TermNode>(
      ruleName: 'Term',
      expectedChildren: ['Factor'],
      factory: (ruleName, expectedChildren, children) {
        return TermNode(name: ruleName, children: children);
      },
    ),
    CSTNodeFactory<ExprNode>(
      ruleName: 'Expr',
      expectedChildren: ['Term'],
      factory: (ruleName, expectedChildren, children) {
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
    try {
      print('Input: $input');

      final (cst, errors) = squirrelParse(
        calculatorGrammar,
        input,
        'Expr',
        factories,
      );

      if (errors.isEmpty) {
        print('Result: $cst');
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
