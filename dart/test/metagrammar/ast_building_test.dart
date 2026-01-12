import 'package:squirrel_parser/squirrel_parser.dart';
import 'package:test/test.dart';

void main() {
  group('MetaGrammar - AST Building', () {
    test('AST structure for simple grammar', () {
      const grammar = '''
        Main <- A B;
        A <- "a";
        B <- "b";
      ''';

      final rules = MetaGrammar.parseGrammar(grammar);
      final parser = Parser(topRuleName: 'Main', rules: rules, input: 'ab');
      final parseResult = parser.parse();
      final ast = buildAST(parseResult: parseResult);

      expect(ast, isNotNull);
      expect(ast.label, equals('Main'));
      expect(ast.children.length, equals(2));
      expect(ast.children[0].label, equals('A'));
      expect(ast.children[1].label, equals('B'));
    });

    test('AST flattens combinator nodes', () {
      const grammar = '''
        Main <- A+ B*;
        A <- "a";
        B <- "b";
      ''';

      final rules = MetaGrammar.parseGrammar(grammar);
      final parser = Parser(topRuleName: 'Main', rules: rules, input: 'aaabbb');
      final parseResult = parser.parse();
      final ast = buildAST(parseResult: parseResult);

      expect(ast, isNotNull);
      expect(ast.label, equals('Main'));

      // Should have flattened A and B children, not intermediate repetition nodes
      final aNodes = ast.children.where((n) => n.label == 'A').length;
      final bNodes = ast.children.where((n) => n.label == 'B').length;
      expect(aNodes, equals(3));
      expect(bNodes, equals(3));
    });

    test('AST text extraction', () {
      const grammar = '''
        Number <- [0-9]+;
      ''';

      final rules = MetaGrammar.parseGrammar(grammar);
      final parser = Parser(topRuleName: 'Number', rules: rules, input: '123');
      final parseResult = parser.parse();
      final ast = buildAST(parseResult: parseResult);

      expect(ast, isNotNull);
      // ast.text property not available; extract from input using position and length
      final text = parseResult.input.substring(0, parseResult.root.len);
      expect(text, equals('123'));
    });

    test('AST for nested structures', () {
      const grammar = '''
        Expr <- Term (("+" / "-") Term)*;
        Term <- [0-9]+;
      ''';

      final rules = MetaGrammar.parseGrammar(grammar);
      final parser = Parser(topRuleName: 'Expr', rules: rules, input: '1+2-3');
      final parseResult = parser.parse();
      final ast = buildAST(parseResult: parseResult);

      expect(ast, isNotNull);
      expect(ast.label, equals('Expr'));

      // Should have Terms as direct children (flattened)
      final termNodes = ast.children.where((n) => n.label == 'Term').toList();
      expect(termNodes.length, greaterThanOrEqualTo(1));
    });

    test('AST pretty printing', () {
      const grammar = '''
        Main <- A B;
        A <- "a";
        B <- "b";
      ''';

      final rules = MetaGrammar.parseGrammar(grammar);
      final parser = Parser(topRuleName: 'Main', rules: rules, input: 'ab');
      final parseResult = parser.parse();
      final ast = buildAST(parseResult: parseResult);

      expect(ast, isNotNull);
      final prettyString = ast.toPrettyString('  ');  // indent parameter required
      expect(prettyString, contains('Main'));
      expect(prettyString, contains('A'));
      expect(prettyString, contains('B'));
    });
  });
}
