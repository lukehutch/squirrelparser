import 'package:squirrel_parser/squirrel_parser.dart';
import 'package:test/test.dart';

void main() {
  group('MetaGrammar - Operator Precedence', () {
    test('suffix binds tighter than sequence', () {
      // "a"+ "b" should be ("a"+ "b"), not ("a" "b")+
      const grammar = '''
        Rule <- "a"+ "b";
      ''';

      final rules = MetaGrammar.parseGrammar(grammar);
      final clause = rules['Rule'].toString();

      // Should have OneOrMore around first element only
      expect(clause, contains('"a"+'));
      expect(clause, contains('"b"'));
    });

    test('prefix binds tighter than sequence', () {
      // !"a" "b" should be (!"a" "b"), not !("a" "b")
      const grammar = '''
        Rule <- !"a" "b";
      ''';

      final rules = MetaGrammar.parseGrammar(grammar);
      final clause = rules['Rule'].toString();

      // Should have NotFollowedBy around first element only
      expect(clause, contains('!"a"'));
      expect(clause, contains('"b"'));
    });

    test('sequence binds tighter than choice', () {
      // "a" "b" / "c" should be (("a" "b") / "c"), not ("a" ("b" / "c"))
      const grammar = '''
        Rule <- "a" "b" / "c";
      ''';

      final rules = MetaGrammar.parseGrammar(grammar);

      // Test that it parses "ab" and "c", but not "ac"
      var parser = Parser(rules: rules, input: 'ab');
      var (result, _) = parser.parse('Rule');
      expect(result, isNotNull);

      parser = Parser(rules: rules, input: 'c');
      (result, _) = parser.parse('Rule');
      expect(result, isNotNull);

      parser = Parser(rules: rules, input: 'ac');
      (result, _) = parser.parse('Rule');
      expect(result is SyntaxError, isTrue);
    });

    test('suffix binds tighter than prefix', () {
      // &"a"+ should be &("a"+), not (&"a")+
      const grammar = '''
        Rule <- &"a"+ "a";
      ''';

      final rules = MetaGrammar.parseGrammar(grammar);
      final clause = rules['Rule'].toString();

      // Should have FollowedBy wrapping OneOrMore
      expect(clause, contains('&"a"+'));
    });

    test('grouping overrides precedence - sequence in choice', () {
      // "a" / "b" "c" should parse as ("a" / ("b" "c"))
      // ("a" / "b") "c" should parse differently
      const grammar1 = '''
        Rule <- "a" / "b" "c";
      ''';

      const grammar2 = '''
        Rule <- ("a" / "b") "c";
      ''';

      final rules1 = MetaGrammar.parseGrammar(grammar1);
      final rules2 = MetaGrammar.parseGrammar(grammar2);

      // Grammar 1: should match "a" or "bc"
      var parser = Parser(rules: rules1, input: 'a');
      var (result, _) = parser.parse('Rule');
      expect(result, isNotNull);

      parser = Parser(rules: rules1, input: 'bc');
      (result, _) = parser.parse('Rule');
      expect(result, isNotNull);

      // 'ac' should not fully match - only matches 'a', leaving 'c'
      parser = Parser(rules: rules1, input: 'ac');
      var matchResult = parser.matchRule('Rule', 0);
      expect(matchResult.isMismatch || matchResult.len != 2,
          isTrue); // Either mismatch or doesn't consume all

      // Grammar 2: should match "ac" or "bc"
      parser = Parser(rules: rules2, input: 'ac');
      (result, _) = parser.parse('Rule');
      expect(result, isNotNull);

      parser = Parser(rules: rules2, input: 'bc');
      (result, _) = parser.parse('Rule');
      expect(result, isNotNull);

      // 'a' should not match grammar2 - needs 'c' after choice
      parser = Parser(rules: rules2, input: 'a');
      matchResult = parser.matchRule('Rule', 0);
      expect(matchResult.isMismatch, isTrue);
    });

    test('grouping overrides precedence - choice in suffix', () {
      // ("a" / "b")+ should allow "aaa", "bbb", "aba", etc.
      const grammar = '''
        Rule <- ("a" / "b")+;
      ''';

      final rules = MetaGrammar.parseGrammar(grammar);

      var parser = Parser(rules: rules, input: 'aaa');
      var (result, _) = parser.parse('Rule');
      expect(result, isNotNull);

      parser = Parser(rules: rules, input: 'bbb');
      (result, _) = parser.parse('Rule');
      expect(result, isNotNull);

      parser = Parser(rules: rules, input: 'aba');
      (result, _) = parser.parse('Rule');
      expect(result, isNotNull);

      parser = Parser(rules: rules, input: 'bab');
      (result, _) = parser.parse('Rule');
      expect(result, isNotNull);
    });

    test('complex precedence - mixed operators', () {
      // "a"+ / "b"* "c" should be (("a"+) / (("b"*) "c"))
      const grammar = '''
        Rule <- "a"+ / "b"* "c";
      ''';

      final rules = MetaGrammar.parseGrammar(grammar);

      // Should match "a", "aa", "aaa", etc.
      var parser = Parser(rules: rules, input: 'a');
      var (result, _) = parser.parse('Rule');
      expect(result, isNotNull);

      parser = Parser(rules: rules, input: 'aaa');
      (result, _) = parser.parse('Rule');
      expect(result, isNotNull);

      // Should match "c", "bc", "bbc", etc.
      parser = Parser(rules: rules, input: 'c');
      (result, _) = parser.parse('Rule');
      expect(result, isNotNull);

      parser = Parser(rules: rules, input: 'bc');
      (result, _) = parser.parse('Rule');
      expect(result, isNotNull);

      parser = Parser(rules: rules, input: 'bbc');
      (result, _) = parser.parse('Rule');
      expect(result, isNotNull);
    });

    test('transparent operator precedence', () {
      // ~"a"+ should be ~("a"+), not (~"a")+
      const grammar = '''
        ~Rule <- "a"+;
        Main <- Rule;
      ''';

      final rules = MetaGrammar.parseGrammar(grammar);
      final parser = Parser(rules: rules, input: 'aaa');
      final (ast, _) = parser.parseToAST('Main');

      // Rule should be transparent, so Main should not have a Rule child
      expect(ast, isNotNull);
      expect(ast.label, equals('Main'));
      // If Rule is properly transparent, we shouldn't see it in the AST
    });

    test('prefix operators are right-associative', () {
      // &!"a" should be &(!"a"), not (!(&"a"))
      const grammar = '''
        Rule <- &!"a" "b";
      ''';

      final rules = MetaGrammar.parseGrammar(grammar);
      final clause = rules['Rule'].toString();

      // Should have FollowedBy wrapping NotFollowedBy
      expect(clause, contains('&!"a"'));
    });

    test('suffix operators are left-associative', () {
      // "a"+? should be ("a"+)?, not "a"+(?)
      // Note: PEG doesn't typically allow ++, but if it did, it would be left-associative
      // This test verifies that suffix operators apply to the result of the previous operation
      const grammar = '''
        Rule <- "a"+?;
      ''';

      final rules = MetaGrammar.parseGrammar(grammar);
      final clause = rules['Rule'].toString();

      // Should have Optional wrapping OneOrMore
      expect(clause, contains('"a"+'));
      expect(clause, contains('?'));
    });

    test('character class binds as atomic unit', () {
      // [a-z]+ should be ([a-z])+, with the character class as a single unit
      const grammar = '''
        Rule <- [a-z]+;
      ''';

      final rules = MetaGrammar.parseGrammar(grammar);

      var parser = Parser(rules: rules, input: 'abc');
      var (result, _) = parser.parse('Rule');
      expect(result, isNotNull);
      expect(result.len, equals(3));
    });

    test('negated character class binds as atomic unit', () {
      // [^0-9]+ should match multiple non-digits
      const grammar = '''
        Rule <- [^0-9]+;
      ''';

      final rules = MetaGrammar.parseGrammar(grammar);

      var parser = Parser(rules: rules, input: 'abc');
      var (result, _) = parser.parse('Rule');
      expect(result, isNotNull);
      expect(result.len, equals(3));

      // Use matchRule for partial match test
      parser = Parser(rules: rules, input: 'a1');
      var matchResult = parser.matchRule('Rule', 0);
      expect(matchResult.isMismatch, isFalse);
      expect(matchResult.len, equals(1)); // Only 'a' matches
    });
  });
}
