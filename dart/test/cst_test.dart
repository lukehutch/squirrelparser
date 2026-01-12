import 'package:squirrel_parser/squirrel_parser.dart';
import 'package:test/test.dart';

import 'test_utils.dart' show parseToMatchResultForTesting, parseWithGrammarSpecForTesting;

/// Simple test CST node for testing
class SimpleCST extends CSTNode {
  final String? value;

  SimpleCST({
    required super.astNode,
    required super.children,
    this.value,
  });
}

void main() {
  group('CST - Concrete Syntax Tree', () {
    test('parse tree methods exist and work', () {
      const grammar = '''
        Greeting <- "hello" Name;
        Name <- [a-z]+;
      ''';

      final (pt, errors) = parseToMatchResultForTesting(grammar, 'Greeting', 'helloworld');

      expect(pt, isNotNull);
      expect(pt.isMismatch, isFalse);
      expect(errors, isEmpty);
    });

    test('CST factory validation catches missing factories', () {
      const grammar = '''
        Greeting <- "hello" Name;
        Name <- [a-z]+;
      ''';

      // Only provide factory for Greeting, missing Name and <Terminal>
      final factories = [
        CSTNodeFactory(
          ruleName: 'Greeting',
          factory: (astNode, children) {
            return SimpleCST(astNode: astNode, children: children);
          },
        ),
      ];

      expect(
        () => parseWithGrammarSpecForTesting(grammar, 'Greeting', 'hello world', factories),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('CST factory validation catches extra factories', () {
      const grammar = '''
        Greeting <- "hello";
      ''';

      // Provide factory for Greeting and extra Name
      final factories = [
        CSTNodeFactory(
          ruleName: 'Greeting',
          factory: (astNode, children) {
            return SimpleCST(astNode: astNode, children: children);
          },
        ),
        CSTNodeFactory(
          ruleName: 'ExtraRule',
          factory: (astNode, children) {
            return SimpleCST(astNode: astNode, children: children);
          },
        ),
      ];

      expect(
        () => parseWithGrammarSpecForTesting(grammar, 'Greeting', 'hello', factories),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('basic CST construction works', () {
      const grammar = '''
        Main <- Item;
        Item <- "test";
      ''';

      final factories = [
        CSTNodeFactory(
          ruleName: 'Main',
          factory: (astNode, children) {
            return SimpleCST(astNode: astNode, children: children);
          },
        ),
        CSTNodeFactory(
          ruleName: 'Item',
          factory: (astNode, children) {
            return SimpleCST(astNode: astNode, children: children, value: 'test');
          },
        ),
        CSTNodeFactory(
          ruleName: '<Terminal>',
          factory: (astNode, children) {
            return SimpleCST(astNode: astNode, children: children);
          },
        ),
      ];

      final (cst, errors) = parseWithGrammarSpecForTesting(
        grammar,
        'Main',
        'test',
        factories,
      );

      expect(cst, isNotNull);
      expect(cst.label, equals('Main'));
      expect(errors, isEmpty);
    });

    test('squirrelParse is the main public API', () {
      const grammar = '''
        Test <- "hello";
      ''';

      final factories = [
        CSTNodeFactory(
          ruleName: 'Test',
          factory: (astNode, children) {
            return SimpleCST(astNode: astNode, children: children, value: 'hello');
          },
        ),
        CSTNodeFactory(
          ruleName: '<Terminal>',
          factory: (astNode, children) {
            return SimpleCST(astNode: astNode, children: children);
          },
        ),
      ];

      final cst = squirrelParseCST(
        grammarSpec: grammar,
        topRuleName: 'Test',
        factories: factories,
        input: 'hello',
      );

      expect(cst, isNotNull);
      expect(cst.label, equals('Test'));
    });

    test('duplicate rule names throw ArgumentError', () {
      const grammar = '''
        Main <- "test";
      ''';

      // Provide two factories with the same rule name
      final factories = [
        CSTNodeFactory(
          ruleName: 'Main',
          factory: (astNode, children) {
            return SimpleCST(astNode: astNode, children: children);
          },
        ),
        CSTNodeFactory(
          ruleName: 'Main',
          factory: (astNode, children) {
            return SimpleCST(astNode: astNode, children: children);
          },
        ),
      ];

      expect(
        () => parseWithGrammarSpecForTesting(grammar, 'Main', 'test', factories),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('transparent rules are excluded from CST factories', () {
      const grammar = '''
        Expr <- ~Whitespace Term ~Whitespace;
        ~Whitespace <- ' '*;
        Term <- "x";
      ''';

      // Should only need factories for Expr and Term, not Whitespace (which is transparent)
      final factories = [
        CSTNodeFactory(
          ruleName: 'Expr',
          factory: (astNode, children) {
            return SimpleCST(astNode: astNode, children: children);
          },
        ),
        CSTNodeFactory(
          ruleName: 'Term',
          factory: (astNode, children) {
            return SimpleCST(astNode: astNode, children: children, value: 'x');
          },
        ),
        CSTNodeFactory(
          ruleName: '<Terminal>',
          factory: (astNode, children) {
            return SimpleCST(astNode: astNode, children: children);
          },
        ),
      ];

      // This should work without a factory for Whitespace
      final (cst, errors) = parseWithGrammarSpecForTesting(
        grammar,
        'Expr',
        ' x ',
        factories,
      );

      expect(cst, isNotNull);
      expect(errors, isEmpty);
    });
  });
}
