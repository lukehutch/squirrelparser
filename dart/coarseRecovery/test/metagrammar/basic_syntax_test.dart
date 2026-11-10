import 'package:squirrel_parser/squirrel_parser.dart';
import 'package:test/test.dart';

void main() {
  group('MetaGrammar - Basic Syntax', () {
    test('simple rule with string literal', () {
      const grammar = '''
        Hello <- "hello";
      ''';

      final rules = MetaGrammar.parseGrammar(grammar);
      expect(rules.containsKey('Hello'), isTrue);

      final parser = Parser(topRuleName: 'Hello', rules: rules, input: 'hello');
      var parseResult = parser.parse();
      final result = parseResult.root;
      expect(result, isNotNull);
      expect(result.len, equals(5));
    });

    test('rule with character literal', () {
      const grammar = '''
        A <- 'a';
      ''';

      final rules = MetaGrammar.parseGrammar(grammar);
      final parser = Parser(topRuleName: 'A', rules: rules, input: 'a');
      var parseResult = parser.parse();
      final result = parseResult.root;
      expect(result, isNotNull);
      expect(result.len, equals(1));
    });

    test('sequence of literals', () {
      const grammar = '''
        AB <- "a" "b";
      ''';

      final rules = MetaGrammar.parseGrammar(grammar);
      final parser = Parser(topRuleName: 'AB', rules: rules, input: 'ab');
      var parseResult = parser.parse();
      final result = parseResult.root;
      expect(result, isNotNull);
      expect(result.len, equals(2));
    });

    test('choice between alternatives', () {
      const grammar = '''
        AorB <- "a" / "b";
      ''';

      final rules = MetaGrammar.parseGrammar(grammar);

      var parser = Parser(topRuleName: 'AorB', rules: rules, input: 'a');
      var parseResult = parser.parse();
      var result = parseResult.root;
      expect(result, isNotNull);
      expect(result.len, equals(1));

      parser = Parser(topRuleName: 'AorB', rules: rules, input: 'b');
      parseResult = parser.parse();
      result = parseResult.root;
      expect(result, isNotNull);
      expect(result.len, equals(1));
    });

    test('zero or more repetition', () {
      const grammar = '''
        As <- "a"*;
      ''';

      final rules = MetaGrammar.parseGrammar(grammar);

      var parser = Parser(topRuleName: 'As', rules: rules, input: '');
      var parseResult = parser.parse();
      var result = parseResult.root;
      expect(result, isNotNull);
      expect(result.len, equals(0));

      parser = Parser(topRuleName: 'As', rules: rules, input: 'aaa');
      parseResult = parser.parse();
      result = parseResult.root;
      expect(result, isNotNull);
      expect(result.len, equals(3));
    });

    test('one or more repetition', () {
      const grammar = '''
        As <- "a"+;
      ''';

      final rules = MetaGrammar.parseGrammar(grammar);

      var parser = Parser(topRuleName: 'As', rules: rules, input: '');
      var parseResult = parser.parse();
      var result = parseResult.root;
      expect(result is SyntaxError, isTrue);

      parser = Parser(topRuleName: 'As', rules: rules, input: 'aaa');
      parseResult = parser.parse();
      result = parseResult.root;
      expect(result, isNotNull);
      expect(result.len, equals(3));
    });

    test('optional', () {
      const grammar = '''
        OptA <- "a"?;
      ''';

      final rules = MetaGrammar.parseGrammar(grammar);

      var parser = Parser(topRuleName: 'OptA', rules: rules, input: '');
      var parseResult = parser.parse();
      var result = parseResult.root;
      expect(result, isNotNull);
      expect(result.len, equals(0));

      parser = Parser(topRuleName: 'OptA', rules: rules, input: 'a');
      parseResult = parser.parse();
      result = parseResult.root;
      expect(result, isNotNull);
      expect(result.len, equals(1));
    });

    test('positive lookahead', () {
      const grammar = '''
        AFollowedByB <- "a" &"b" "b";
      ''';

      final rules = MetaGrammar.parseGrammar(grammar);

      var parser = Parser(topRuleName: 'AFollowedByB', rules: rules, input: 'ab');
      var parseResult = parser.parse();
      var result = parseResult.root;
      expect(result, isNotNull);
      expect(result.len, equals(2)); // Both 'a' and 'b' consumed

      parser = Parser(topRuleName: 'AFollowedByB', rules: rules, input: 'ac');
      parseResult = parser.parse();
      result = parseResult.root;
      expect(result is SyntaxError, isTrue);
    });

    test('negative lookahead', () {
      const grammar = '''
        ANotFollowedByB <- "a" !"b" "c";
      ''';

      final rules = MetaGrammar.parseGrammar(grammar);

      var parser = Parser(topRuleName: 'ANotFollowedByB', rules: rules, input: 'ac');
      var parseResult = parser.parse();
      var result = parseResult.root;
      expect(result, isNotNull);
      expect(result.len, equals(2)); // Both 'a' and 'c' consumed

      parser = Parser(topRuleName: 'ANotFollowedByB', rules: rules, input: 'ab');
      parseResult = parser.parse();
      result = parseResult.root;
      expect(result is SyntaxError, isTrue);
    });

    test('any character', () {
      const grammar = '''
        AnyOne <- .;
      ''';

      final rules = MetaGrammar.parseGrammar(grammar);

      var parser = Parser(topRuleName: 'AnyOne', rules: rules, input: 'x');
      var parseResult = parser.parse();
      var result = parseResult.root;
      expect(result, isNotNull);
      expect(result.len, equals(1));

      parser = Parser(topRuleName: 'AnyOne', rules: rules, input: '9');
      parseResult = parser.parse();
      result = parseResult.root;
      expect(result, isNotNull);
      expect(result.len, equals(1));
    });

    test('grouping with parentheses', () {
      const grammar = '''
        Group <- ("a" / "b") "c";
      ''';

      final rules = MetaGrammar.parseGrammar(grammar);

      var parser = Parser(topRuleName: 'Group', rules: rules, input: 'ac');
      var parseResult = parser.parse();
      var result = parseResult.root;
      expect(result, isNotNull);
      expect(result.len, equals(2));

      parser = Parser(topRuleName: 'Group', rules: rules, input: 'bc');
      parseResult = parser.parse();
      result = parseResult.root;
      expect(result, isNotNull);
      expect(result.len, equals(2));
    });
  });
}
