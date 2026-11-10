import 'package:squirrel_parser/squirrel_parser.dart';
import 'package:test/test.dart';

void main() {
  group('MetaGrammar - Rule References', () {
    test('simple rule reference', () {
      const grammar = '''
        Main <- A "b";
        A <- "a";
      ''';

      final rules = MetaGrammar.parseGrammar(grammar);
      final parser = Parser(topRuleName: 'Main', rules: rules, input: 'ab');
      var parseResult = parser.parse();
      final result = parseResult.root;
      expect(result, isNotNull);
      expect(result.len, equals(2));
    });

    test('multiple rule references', () {
      const grammar = '''
        Main <- A B C;
        A <- "a";
        B <- "b";
        C <- "c";
      ''';

      final rules = MetaGrammar.parseGrammar(grammar);
      final parser = Parser(topRuleName: 'Main', rules: rules, input: 'abc');
      var parseResult = parser.parse();
      final result = parseResult.root;
      expect(result, isNotNull);
      expect(result.len, equals(3));
    });

    test('recursive rule', () {
      const grammar = '''
        List <- "a" List / "a";
      ''';

      final rules = MetaGrammar.parseGrammar(grammar);

      var parser = Parser(topRuleName: 'List', rules: rules, input: 'a');
      var parseResult = parser.parse();
      var result = parseResult.root;
      expect(result, isNotNull);
      expect(result.len, equals(1));

      parser = Parser(topRuleName: 'List', rules: rules, input: 'aaa');
      parseResult = parser.parse();
      result = parseResult.root;
      expect(result, isNotNull);
      expect(result.len, equals(3));
    });

    test('mutually recursive rules', () {
      const grammar = '''
        A <- "a" B / "a";
        B <- "b" A / "b";
      ''';

      final rules = MetaGrammar.parseGrammar(grammar);

      var parser = Parser(topRuleName: 'A', rules: rules, input: 'aba');
      var parseResult = parser.parse();
      var result = parseResult.root;
      expect(result, isNotNull);
      expect(result.len, equals(3));

      parser = Parser(topRuleName: 'A', rules: rules, input: 'bab');
      parseResult = parser.parse();
      result = parseResult.root;
      expect(result, isNotNull);
      expect(result.len, equals(3));
    });

    test('left-recursive rule', () {
      const grammar = '''
        Expr <- Expr "+" "n" / "n";
      ''';

      final rules = MetaGrammar.parseGrammar(grammar);

      var parser = Parser(topRuleName: 'Expr', rules: rules, input: 'n');
      var parseResult = parser.parse();
      var result = parseResult.root;
      expect(result, isNotNull);
      expect(result.len, equals(1));

      parser = Parser(topRuleName: 'Expr', rules: rules, input: 'n+n');
      parseResult = parser.parse();
      result = parseResult.root;
      expect(result, isNotNull);
      expect(result.len, equals(3));

      parser = Parser(topRuleName: 'Expr', rules: rules, input: 'n+n+n');
      parseResult = parser.parse();
      result = parseResult.root;
      expect(result, isNotNull);
      expect(result.len, equals(5));
    });
  });
}
