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

      final parser = Parser(topRuleName: 'Empty', rules: rules, input: '');
      var parseResult = parser.parse();
      final result = parseResult.root;
      expect(result, isNotNull);
      expect(result.len, equals(0));
    });

    test('empty parentheses in sequence', () {
      const grammar = '''
        AB <- "a" () "b";
      ''';

      final rules = MetaGrammar.parseGrammar(grammar);
      final parser = Parser(topRuleName: 'AB', rules: rules, input: 'ab');
      var parseResult = parser.parse();
      final result = parseResult.root;
      expect(result, isNotNull);
      expect(result.len, equals(2));
    });

    test('parenthesized expression with content', () {
      const grammar = '''
        Parens <- ("hello");
      ''';

      final rules = MetaGrammar.parseGrammar(grammar);
      final parser = Parser(topRuleName: 'Parens', rules: rules, input: 'hello');
      var parseResult = parser.parse();
      final result = parseResult.root;
      expect(result, isNotNull);
      expect(result.len, equals(5));
    });

    test('nested empty parentheses', () {
      const grammar = '''
        Nested <- (());
      ''';

      final rules = MetaGrammar.parseGrammar(grammar);
      final parser = Parser(topRuleName: 'Nested', rules: rules, input: '');
      var parseResult = parser.parse();
      final result = parseResult.root;
      expect(result, isNotNull);
      expect(result.len, equals(0));
    });

    test('empty parentheses with optional repetition', () {
      const grammar = '''
        Opt <- ()* "test";
      ''';

      final rules = MetaGrammar.parseGrammar(grammar);
      final parser = Parser(topRuleName: 'Opt', rules: rules, input: 'test');
      var parseResult = parser.parse();
      final result = parseResult.root;
      expect(result, isNotNull);
      expect(result.len, equals(4));
    });

    test('empty parentheses in choice', () {
      const grammar = '''
        Choice <- "a" / ();
      ''';

      final rules = MetaGrammar.parseGrammar(grammar);

      // Should match 'a'
      final parser1 = Parser(topRuleName: 'Choice', rules: rules, input: 'a');
      final parseResult1 = parser1.parse();
      final result1 = parseResult1.root;
      expect(result1, isNotNull);
      expect(result1.len, equals(1));

      // Should match empty string
      final parser2 = Parser(topRuleName: 'Choice', rules: rules, input: '');
      final parseResult2 = parser2.parse();
      final result2 = parseResult2.root;
      expect(result2, isNotNull);
      expect(result2.len, equals(0));
    });

    test('rule referencing nothing', () {
      const grammar = '''
        Nothing <- ();
        A <- Nothing "a";
      ''';

      final rules = MetaGrammar.parseGrammar(grammar);
      final parser = Parser(topRuleName: 'A', rules: rules, input: 'a');
      var parseResult = parser.parse();
      final result = parseResult.root;
      expect(result, isNotNull);
      expect(result.len, equals(1));
    });
  });
}
