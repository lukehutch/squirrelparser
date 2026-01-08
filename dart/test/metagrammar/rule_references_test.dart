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
      final parser = Parser(rules: rules, input: 'ab');
      final (result, _) = parser.parse('Main');
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
      final parser = Parser(rules: rules, input: 'abc');
      final (result, _) = parser.parse('Main');
      expect(result, isNotNull);
      expect(result.len, equals(3));
    });

    test('recursive rule', () {
      const grammar = '''
        List <- "a" List / "a";
      ''';

      final rules = MetaGrammar.parseGrammar(grammar);

      var parser = Parser(rules: rules, input: 'a');
      var (result, _) = parser.parse('List');
      expect(result, isNotNull);
      expect(result.len, equals(1));

      parser = Parser(rules: rules, input: 'aaa');
      (result, _) = parser.parse('List');
      expect(result, isNotNull);
      expect(result.len, equals(3));
    });

    test('mutually recursive rules', () {
      const grammar = '''
        A <- "a" B / "a";
        B <- "b" A / "b";
      ''';

      final rules = MetaGrammar.parseGrammar(grammar);

      var parser = Parser(rules: rules, input: 'aba');
      var (result, _) = parser.parse('A');
      expect(result, isNotNull);
      expect(result.len, equals(3));

      parser = Parser(rules: rules, input: 'bab');
      (result, _) = parser.parse('B');
      expect(result, isNotNull);
      expect(result.len, equals(3));
    });

    test('left-recursive rule', () {
      const grammar = '''
        Expr <- Expr "+" "n" / "n";
      ''';

      final rules = MetaGrammar.parseGrammar(grammar);

      var parser = Parser(rules: rules, input: 'n');
      var (result, _) = parser.parse('Expr');
      expect(result, isNotNull);
      expect(result.len, equals(1));

      parser = Parser(rules: rules, input: 'n+n');
      (result, _) = parser.parse('Expr');
      expect(result, isNotNull);
      expect(result.len, equals(3));

      parser = Parser(rules: rules, input: 'n+n+n');
      (result, _) = parser.parse('Expr');
      expect(result, isNotNull);
      expect(result.len, equals(5));
    });
  });
}
