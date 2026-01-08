import 'package:squirrel_parser/squirrel_parser.dart';
import 'package:test/test.dart';

/// Simple test CST node for testing
class SimpleCST extends CSTNode {
  final List<CSTNode> children;
  final String? value;

  SimpleCST({
    required super.name,
    this.children = const [],
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

      final rules = MetaGrammar.parseGrammar(grammar);
      final (pt, errors) =
          parseToMatchResultForTesting(rules, 'Greeting', 'helloworld');

      expect(pt, isNotNull);
      expect(pt.isMismatch, isFalse);
      expect(errors, isEmpty);
    });

    test('CST factory validation catches missing factories', () {
      const grammar = '''
        Greeting <- "hello" Name;
        Name <- [a-z]+;
      ''';

      final rules = MetaGrammar.parseGrammar(grammar);

      // Only provide factory for Greeting, missing Name
      final factories = [
        CSTNodeFactory<SimpleCST>(
          ruleName: 'Greeting',
          expectedChildren: ['Name'],
          factory: (ruleName, expectedChildren, children) {
            return SimpleCST(name: ruleName, children: children);
          },
        ),
      ];

      expect(
        () => parseWithRuleMapForTesting(
            rules, 'Greeting', 'hello world', factories),
        throwsA(isA<CSTFactoryValidationException>()),
      );
    });

    test('CST factory validation catches extra factories', () {
      const grammar = '''
        Greeting <- "hello";
      ''';

      final rules = MetaGrammar.parseGrammar(grammar);

      // Provide factory for Greeting and extra Name
      final factories = [
        CSTNodeFactory<SimpleCST>(
          ruleName: 'Greeting',
          expectedChildren: [],
          factory: (ruleName, expectedChildren, children) {
            return SimpleCST(name: ruleName);
          },
        ),
        CSTNodeFactory<SimpleCST>(
          ruleName: 'ExtraRule',
          expectedChildren: [],
          factory: (ruleName, expectedChildren, children) {
            return SimpleCST(name: ruleName);
          },
        ),
      ];

      expect(
        () => parseWithRuleMapForTesting(rules, 'Greeting', 'hello', factories),
        throwsA(isA<CSTFactoryValidationException>()),
      );
    });

    test('basic CST construction works', () {
      const grammar = '''
        Main <- Item;
        Item <- "test";
      ''';

      final rules = MetaGrammar.parseGrammar(grammar);

      final factories = [
        CSTNodeFactory<SimpleCST>(
          ruleName: 'Main',
          expectedChildren: ['Item'],
          factory: (ruleName, expectedChildren, children) {
            return SimpleCST(name: ruleName, children: children);
          },
        ),
        CSTNodeFactory<SimpleCST>(
          ruleName: 'Item',
          expectedChildren: ['<Terminal>'],
          factory: (ruleName, expectedChildren, children) {
            return SimpleCST(name: ruleName, value: 'test');
          },
        ),
      ];

      final (cst, errors) = parseWithRuleMapForTesting(
        rules,
        'Main',
        'test',
        factories,
      );

      expect(cst, isNotNull);
      expect(cst.name, equals('Main'));
      expect(errors, isEmpty);
    });

    test('squirrelParse is the main public API', () {
      const grammar = '''
        Test <- "hello";
      ''';

      final factories = [
        CSTNodeFactory<SimpleCST>(
          ruleName: 'Test',
          expectedChildren: ['<Terminal>'],
          factory: (ruleName, expectedChildren, children) {
            return SimpleCST(name: ruleName, value: 'hello');
          },
        ),
      ];

      final (cst, errors) = squirrelParse(grammar, 'hello', 'Test', factories);

      expect(cst, isNotNull);
      expect(cst.name, equals('Test'));
      expect(errors, isEmpty);
    });

    test('duplicate rule names throw DuplicateRuleNameException', () {
      const grammar = '''
        Main <- "test";
      ''';

      final rules = MetaGrammar.parseGrammar(grammar);

      // Provide two factories with the same rule name
      final factories = [
        CSTNodeFactory<SimpleCST>(
          ruleName: 'Main',
          expectedChildren: [],
          factory: (ruleName, expectedChildren, children) {
            return SimpleCST(name: ruleName);
          },
        ),
        CSTNodeFactory<SimpleCST>(
          ruleName: 'Main',
          expectedChildren: [],
          factory: (ruleName, expectedChildren, children) {
            return SimpleCST(name: ruleName);
          },
        ),
      ];

      expect(
        () => parseWithRuleMapForTesting(rules, 'Main', 'test', factories),
        throwsA(isA<DuplicateRuleNameException>()),
      );
    });

    test('transparent rules are excluded from CST factories', () {
      const grammar = '''
        Expr <- ~Whitespace Term ~Whitespace;
        ~Whitespace <- ' '*;
        Term <- "x";
      ''';

      final rules = MetaGrammar.parseGrammar(grammar);

      // Should only need factories for Expr and Term, not Whitespace (which is transparent)
      final factories = [
        CSTNodeFactory<SimpleCST>(
          ruleName: 'Expr',
          expectedChildren: ['Term'],
          factory: (ruleName, expectedChildren, children) {
            return SimpleCST(name: ruleName, children: children);
          },
        ),
        CSTNodeFactory<SimpleCST>(
          ruleName: 'Term',
          expectedChildren: ['<Terminal>'],
          factory: (ruleName, expectedChildren, children) {
            return SimpleCST(name: ruleName, value: 'x');
          },
        ),
      ];

      // This should work without a factory for Whitespace
      final (cst, errors) = parseWithRuleMapForTesting(
        rules,
        'Expr',
        ' x ',
        factories,
      );

      expect(cst, isNotNull);
      expect(errors, isEmpty);
    });
  });
}
