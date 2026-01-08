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

      final parser = Parser(rules: rules, input: 'hello');
      final (result, _) = parser.parse('Hello');
      expect(result, isNotNull);
      expect(result.len, equals(5));
    });

    test('rule with character literal', () {
      const grammar = '''
        A <- 'a';
      ''';

      final rules = MetaGrammar.parseGrammar(grammar);
      final parser = Parser(rules: rules, input: 'a');
      final (result, _) = parser.parse('A');
      expect(result, isNotNull);
      expect(result.len, equals(1));
    });

    test('sequence of literals', () {
      const grammar = '''
        AB <- "a" "b";
      ''';

      final rules = MetaGrammar.parseGrammar(grammar);
      final parser = Parser(rules: rules, input: 'ab');
      final (result, _) = parser.parse('AB');
      expect(result, isNotNull);
      expect(result.len, equals(2));
    });

    test('choice between alternatives', () {
      const grammar = '''
        AorB <- "a" / "b";
      ''';

      final rules = MetaGrammar.parseGrammar(grammar);

      var parser = Parser(rules: rules, input: 'a');
      var (result, _) = parser.parse('AorB');
      expect(result, isNotNull);
      expect(result.len, equals(1));

      parser = Parser(rules: rules, input: 'b');
      (result, _) = parser.parse('AorB');
      expect(result, isNotNull);
      expect(result.len, equals(1));
    });

    test('zero or more repetition', () {
      const grammar = '''
        As <- "a"*;
      ''';

      final rules = MetaGrammar.parseGrammar(grammar);

      var parser = Parser(rules: rules, input: '');
      var (result, _) = parser.parse('As');
      expect(result, isNotNull);
      expect(result.len, equals(0));

      parser = Parser(rules: rules, input: 'aaa');
      (result, _) = parser.parse('As');
      expect(result, isNotNull);
      expect(result.len, equals(3));
    });

    test('one or more repetition', () {
      const grammar = '''
        As <- "a"+;
      ''';

      final rules = MetaGrammar.parseGrammar(grammar);

      var parser = Parser(rules: rules, input: '');
      var (result, _) = parser.parse('As');
      expect(result is SyntaxError, isTrue);

      parser = Parser(rules: rules, input: 'aaa');
      (result, _) = parser.parse('As');
      expect(result, isNotNull);
      expect(result.len, equals(3));
    });

    test('optional', () {
      const grammar = '''
        OptA <- "a"?;
      ''';

      final rules = MetaGrammar.parseGrammar(grammar);

      var parser = Parser(rules: rules, input: '');
      var (result, _) = parser.parse('OptA');
      expect(result, isNotNull);
      expect(result.len, equals(0));

      parser = Parser(rules: rules, input: 'a');
      (result, _) = parser.parse('OptA');
      expect(result, isNotNull);
      expect(result.len, equals(1));
    });

    test('positive lookahead', () {
      const grammar = '''
        AFollowedByB <- "a" &"b" "b";
      ''';

      final rules = MetaGrammar.parseGrammar(grammar);

      var parser = Parser(rules: rules, input: 'ab');
      var (result, _) = parser.parse('AFollowedByB');
      expect(result, isNotNull);
      expect(result.len, equals(2)); // Both 'a' and 'b' consumed

      parser = Parser(rules: rules, input: 'ac');
      (result, _) = parser.parse('AFollowedByB');
      expect(result is SyntaxError, isTrue);
    });

    test('negative lookahead', () {
      const grammar = '''
        ANotFollowedByB <- "a" !"b" "c";
      ''';

      final rules = MetaGrammar.parseGrammar(grammar);

      var parser = Parser(rules: rules, input: 'ac');
      var (result, _) = parser.parse('ANotFollowedByB');
      expect(result, isNotNull);
      expect(result.len, equals(2)); // Both 'a' and 'c' consumed

      parser = Parser(rules: rules, input: 'ab');
      (result, _) = parser.parse('ANotFollowedByB');
      expect(result is SyntaxError, isTrue);
    });

    test('any character', () {
      const grammar = '''
        AnyOne <- .;
      ''';

      final rules = MetaGrammar.parseGrammar(grammar);

      var parser = Parser(rules: rules, input: 'x');
      var (result, _) = parser.parse('AnyOne');
      expect(result, isNotNull);
      expect(result.len, equals(1));

      parser = Parser(rules: rules, input: '9');
      (result, _) = parser.parse('AnyOne');
      expect(result, isNotNull);
      expect(result.len, equals(1));
    });

    test('grouping with parentheses', () {
      const grammar = '''
        Group <- ("a" / "b") "c";
      ''';

      final rules = MetaGrammar.parseGrammar(grammar);

      var parser = Parser(rules: rules, input: 'ac');
      var (result, _) = parser.parse('Group');
      expect(result, isNotNull);
      expect(result.len, equals(2));

      parser = Parser(rules: rules, input: 'bc');
      (result, _) = parser.parse('Group');
      expect(result, isNotNull);
      expect(result.len, equals(2));
    });
  });
}
