import 'package:squirrel_parser/squirrel_parser.dart';
import 'package:test/test.dart';

// ============================================================================
// Custom CST Node Classes for Testing
// ============================================================================

/// A simple CST node that includes all its children
class InclusiveNode extends CSTNode {
  final String? computedValue;

  InclusiveNode({
    required super.astNode,
    required super.children,
    this.computedValue,
  });
}

/// A CST node that computes from children without storing them
class ComputedNode extends CSTNode {
  final int childCount;
  final String concatenated;

  ComputedNode({
    required super.astNode,
    required List<CSTNode> children,
    required this.childCount,
    required this.concatenated,
  }) : super(children: []);
}

/// A CST node that transforms children
class TransformedNode extends CSTNode {
  final List<String> transformedLabels;

  TransformedNode({
    required super.astNode,
    required super.children,
    required this.transformedLabels,
  });
}

/// A CST node that selects specific children
class SelectiveNode extends CSTNode {
  final List<CSTNode> selectedChildren;

  SelectiveNode({
    required super.astNode,
    required List<CSTNode> children,
    required this.selectedChildren,
  }) : super(children: selectedChildren);
}

/// A CST node for terminals
class TerminalNode extends CSTNode {
  final String text;

  TerminalNode({
    required super.astNode,
    required this.text,
  }) : super(children: []);
}

/// A CST node for syntax errors
class ErrorNode extends CSTNode {
  final String errorMessage;

  ErrorNode({
    required super.astNode,
    required this.errorMessage,
  }) : super(children: []);
}

void main() {
  group('CST/AST Creation Scenarios', () {
    // ========================================================================
    // Scenario 1: Factory includes all children (inclusive)
    // ========================================================================

    test('factory includes all children', () {
      const grammar = '''
        Expr <- Term ('+' Term)*;
        Term <- [0-9]+;
      ''';

      final cst = squirrelParseCST(
        grammarSpec: grammar,
        topRuleName: 'Expr',
        factories: {
          'Expr': (astNode, children) => InclusiveNode(astNode: astNode, children: children),
          'Term': (astNode, children) => InclusiveNode(astNode: astNode, children: children),
          '<Terminal>': (astNode, children) => InclusiveNode(astNode: astNode, children: children),
        },
        input: '1+2',
      );

      expect(cst, isNotNull);
      expect(cst, isA<InclusiveNode>());
      expect(cst.label, equals('Expr'));
      expect(cst.children.length, greaterThan(0));
    });

    // ========================================================================
    // Scenario 2: Factory computes from children without storing them
    // ========================================================================

    test('factory computes from children without storing them', () {
      const grammar = '''
        Sum <- Number ('+' Number)*;
        Number <- [0-9]+;
      ''';

      final cst = squirrelParseCST(
        grammarSpec: grammar,
        topRuleName: 'Sum',
        factories: {
          'Sum': (astNode, children) {
            final childCount = children.length;
            final concatenated = children.map((c) => c.label).join(',');
            return ComputedNode(
              astNode: astNode,
              children: children,
              childCount: childCount,
              concatenated: concatenated,
            );
          },
          'Number': (astNode, children) => ComputedNode(
                astNode: astNode,
                children: children,
                childCount: 0,
                concatenated: 'Number',
              ),
          '<Terminal>': (astNode, children) => ComputedNode(
                astNode: astNode,
                children: children,
                childCount: 0,
                concatenated: 'Terminal',
              ),
        },
        input: '42',
      );

      expect(cst, isNotNull);
      expect(cst, isA<ComputedNode>());
      final computed = cst as ComputedNode;
      expect(computed.childCount, isNotNull);
      expect(computed.concatenated, isNotEmpty);
    });

    // ========================================================================
    // Scenario 3: Factory transforms children
    // ========================================================================

    test('factory transforms children', () {
      const grammar = '''
        List <- Element (',' Element)*;
        Element <- [a-z]+;
      ''';

      final cst = squirrelParseCST(
        grammarSpec: grammar,
        topRuleName: 'List',
        factories: {
          'List': (astNode, children) {
            final labels = children.map((c) => c.label.toUpperCase()).toList();
            return TransformedNode(
              astNode: astNode,
              children: children,
              transformedLabels: labels,
            );
          },
          'Element': (astNode, children) => TransformedNode(
                astNode: astNode,
                children: children,
                transformedLabels: ['ELEMENT'],
              ),
          '<Terminal>': (astNode, children) => TransformedNode(
                astNode: astNode,
                children: children,
                transformedLabels: ['TERMINAL'],
              ),
        },
        input: 'abc',
      );

      expect(cst, isNotNull);
      expect(cst, isA<TransformedNode>());
      final transformed = cst as TransformedNode;
      expect(transformed.transformedLabels, isNotEmpty);
    });

    // ========================================================================
    // Scenario 4: Factory selects specific children
    // ========================================================================

    test('factory selects specific children', () {
      const grammar = '''
        Pair <- '(' First ',' Second ')';
        First <- [a-z]+;
        Second <- [0-9]+;
      ''';

      final cst = squirrelParseCST(
        grammarSpec: grammar,
        topRuleName: 'Pair',
        factories: {
          'Pair': (astNode, children) {
            // Only keep First and Second, skip terminals
            final selected = children.where((c) => c.label == 'First' || c.label == 'Second').toList();
            return SelectiveNode(
              astNode: astNode,
              children: children,
              selectedChildren: selected,
            );
          },
          'First': (astNode, children) => SelectiveNode(
                astNode: astNode,
                children: children,
                selectedChildren: children,
              ),
          'Second': (astNode, children) => SelectiveNode(
                astNode: astNode,
                children: children,
                selectedChildren: children,
              ),
          '<Terminal>': (astNode, children) => SelectiveNode(
                astNode: astNode,
                children: children,
                selectedChildren: [],
              ),
        },
        input: '(abc,123)',
      );

      expect(cst, isNotNull);
      expect(cst, isA<SelectiveNode>());
      final selective = cst as SelectiveNode;
      // Should have 2 selected children: First and Second
      expect(selective.selectedChildren.length, equals(2));
    });

    // ========================================================================
    // Scenario 5: Terminal handling
    // ========================================================================

    test('terminals are handled by factory', () {
      const grammar = '''
        Text <- Word;
        Word <- [a-z]+;
      ''';

      final cst = squirrelParseCST(
        grammarSpec: grammar,
        topRuleName: 'Text',
        factories: {
          'Text': (astNode, children) => InclusiveNode(astNode: astNode, children: children),
          'Word': (astNode, children) => InclusiveNode(astNode: astNode, children: children),
          '<Terminal>': (astNode, children) => TerminalNode(astNode: astNode, text: 'terminal'),
        },
        input: 'hello',
      );

      expect(cst, isNotNull);
      // Text should have Word children, which have terminal children
      expect(cst.children.isNotEmpty, isTrue);
    });

    // ========================================================================
    // Scenario 6: Syntax error handling
    // ========================================================================

    test('syntax errors are handled when allowSyntaxErrors is true', () {
      const grammar = '''
        Expr <- Number;
        Number <- [0-9]+;
      ''';

      final cst = squirrelParseCST(
        grammarSpec: grammar,
        topRuleName: 'Expr',
        factories: {
          'Expr': (astNode, children) => InclusiveNode(astNode: astNode, children: children),
          'Number': (astNode, children) => InclusiveNode(astNode: astNode, children: children),
          '<Terminal>': (astNode, children) => InclusiveNode(astNode: astNode, children: children),
          '<SyntaxError>': (astNode, children) => ErrorNode(
                astNode: astNode,
                errorMessage: 'Syntax error at ${astNode.pos}',
              ),
        },
        input: 'abc',
        allowSyntaxErrors: true,
      );

      expect(cst, isNotNull);
      // With syntax errors allowed, we should get an error node
    });

    // ========================================================================
    // Scenario 7: Nested structures with mixed approaches
    // ========================================================================

    test('nested structures with mixed factory approaches', () {
      const grammar = '''
        Doc <- Section+;
        Section <- Title;
        Title <- [a-z]+;
      ''';

      final cst = squirrelParseCST(
        grammarSpec: grammar,
        topRuleName: 'Doc',
        factories: {
          // Inclusive factory
          'Doc': (astNode, children) => InclusiveNode(astNode: astNode, children: children),
          // Selective factory
          'Section': (astNode, children) {
            final selected = children.where((c) => c.label == 'Title').toList();
            return SelectiveNode(
              astNode: astNode,
              children: children,
              selectedChildren: selected,
            );
          },
          // Computed factory
          'Title': (astNode, children) => ComputedNode(
                astNode: astNode,
                children: children,
                childCount: children.length,
                concatenated: 'Title',
              ),
          // Terminal factory
          '<Terminal>': (astNode, children) => TerminalNode(astNode: astNode, text: 'terminal'),
        },
        input: 'abc',
      );

      expect(cst, isNotNull);
      expect(cst, isA<InclusiveNode>());
    });

    // ========================================================================
    // Scenario 8: Empty alternatives and optional matching
    // ========================================================================

    test('handles optional matches without errors', () {
      const grammar = '''
        Sentence <- Word (' ' Word)*;
        Word <- [a-z]+;
      ''';

      final cst = squirrelParseCST(
        grammarSpec: grammar,
        topRuleName: 'Sentence',
        factories: {
          'Sentence': (astNode, children) => InclusiveNode(astNode: astNode, children: children),
          'Word': (astNode, children) => InclusiveNode(astNode: astNode, children: children),
          '<Terminal>': (astNode, children) => InclusiveNode(astNode: astNode, children: children),
        },
        input: 'hello world test',
      );

      expect(cst, isNotNull);
    });
  });
}
