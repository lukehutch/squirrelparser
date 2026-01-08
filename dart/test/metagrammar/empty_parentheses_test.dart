import 'package:squirrel_parser/squirrel_parser.dart';
import 'package:test/test.dart';

void main() {
  group('MetaGrammar - Empty Parentheses (Nothing)', () {
    test('empty parentheses matches empty string', () {
      const grammar = '''
        Empty <- ();
      ''';

      final rules = MetaGrammar.parseGrammar(grammar);
      expect(rules.containsKey('Empty'), isTrue);

      final parser = Parser(rules: rules, input: '');
      final (result, _) = parser.parse('Empty');
      expect(result, isNotNull);
      expect(result.len, equals(0));
    });

    test('empty parentheses in sequence', () {
      const grammar = '''
        AB <- "a" () "b";
      ''';

      final rules = MetaGrammar.parseGrammar(grammar);
      final parser = Parser(rules: rules, input: 'ab');
      final (result, _) = parser.parse('AB');
      expect(result, isNotNull);
      expect(result.len, equals(2));
    });

    test('parenthesized expression with content', () {
      const grammar = '''
        Parens <- ("hello");
      ''';

      final rules = MetaGrammar.parseGrammar(grammar);
      final parser = Parser(rules: rules, input: 'hello');
      final (result, _) = parser.parse('Parens');
      expect(result, isNotNull);
      expect(result.len, equals(5));
    });

    test('nested empty parentheses', () {
      const grammar = '''
        Nested <- (());
      ''';

      final rules = MetaGrammar.parseGrammar(grammar);
      final parser = Parser(rules: rules, input: '');
      final (result, _) = parser.parse('Nested');
      expect(result, isNotNull);
      expect(result.len, equals(0));
    });

    test('empty parentheses with optional repetition', () {
      const grammar = '''
        Opt <- ()* "test";
      ''';

      final rules = MetaGrammar.parseGrammar(grammar);
      final parser = Parser(rules: rules, input: 'test');
      final (result, _) = parser.parse('Opt');
      expect(result, isNotNull);
      expect(result.len, equals(4));
    });

    test('empty parentheses in choice', () {
      const grammar = '''
        Choice <- "a" / ();
      ''';

      final rules = MetaGrammar.parseGrammar(grammar);

      // Should match 'a'
      final parser1 = Parser(rules: rules, input: 'a');
      final (result1, _) = parser1.parse('Choice');
      expect(result1, isNotNull);
      expect(result1.len, equals(1));

      // Should match empty string
      final parser2 = Parser(rules: rules, input: '');
      final (result2, __) = parser2.parse('Choice');
      expect(result2, isNotNull);
      expect(result2.len, equals(0));
    });

    test('rule referencing nothing', () {
      const grammar = '''
        Nothing <- ();
        A <- Nothing "a";
      ''';

      final rules = MetaGrammar.parseGrammar(grammar);
      final parser = Parser(rules: rules, input: 'a');
      final (result, _) = parser.parse('A');
      expect(result, isNotNull);
      expect(result.len, equals(1));
    });
  });
}
