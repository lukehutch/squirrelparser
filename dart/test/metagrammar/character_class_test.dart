import 'package:squirrel_parser/squirrel_parser.dart';
import 'package:test/test.dart';

void main() {
  group('MetaGrammar - Character Classes', () {
    test('simple character range', () {
      const grammar = '''
        Digit <- [0-9];
      ''';

      final rules = MetaGrammar.parseGrammar(grammar);

      var parser = Parser(rules: rules, input: '5');
      var (result, _) = parser.parse('Digit');
      expect(result is! SyntaxError, isTrue, reason: 'should match digit');
      expect(result.len, equals(1));

      parser = Parser(rules: rules, input: 'a');
      (result, _) = parser.parse('Digit');
      expect(result is SyntaxError, isTrue, reason: 'should fail on non-digit');
    });

    test('multiple character ranges', () {
      const grammar = '''
        AlphaNum <- [a-zA-Z0-9];
      ''';

      final rules = MetaGrammar.parseGrammar(grammar);

      var parser = Parser(rules: rules, input: 'a');
      var (result, _) = parser.parse('AlphaNum');
      expect(result is! SyntaxError, isTrue);

      parser = Parser(rules: rules, input: 'Z');
      (result, _) = parser.parse('AlphaNum');
      expect(result is! SyntaxError, isTrue);

      parser = Parser(rules: rules, input: '5');
      (result, _) = parser.parse('AlphaNum');
      expect(result is! SyntaxError, isTrue);

      parser = Parser(rules: rules, input: '!');
      (result, _) = parser.parse('AlphaNum');
      expect(result is SyntaxError, isTrue, reason: 'should fail on non-alphanumeric');
    });

    test('character class with individual characters', () {
      const grammar = '''
        Vowel <- [aeiou];
      ''';

      final rules = MetaGrammar.parseGrammar(grammar);

      var parser = Parser(rules: rules, input: 'a');
      var (result, _) = parser.parse('Vowel');
      expect(result is! SyntaxError, isTrue);

      parser = Parser(rules: rules, input: 'e');
      (result, _) = parser.parse('Vowel');
      expect(result is! SyntaxError, isTrue);

      parser = Parser(rules: rules, input: 'b');
      (result, _) = parser.parse('Vowel');
      expect(result is SyntaxError, isTrue, reason: 'should fail on consonant');
    });

    test('negated character class', () {
      const grammar = '''
        NotDigit <- [^0-9];
      ''';

      final rules = MetaGrammar.parseGrammar(grammar);

      var parser = Parser(rules: rules, input: 'a');
      var (result, _) = parser.parse('NotDigit');
      expect(result is! SyntaxError, isTrue);

      parser = Parser(rules: rules, input: '5');
      (result, _) = parser.parse('NotDigit');
      expect(result is SyntaxError, isTrue, reason: 'should fail on digit');
    });

    test('escaped characters in character class', () {
      const grammar = r'''
        Special <- [\t\n];
      ''';

      final rules = MetaGrammar.parseGrammar(grammar);

      var parser = Parser(rules: rules, input: '\t');
      var (result, _) = parser.parse('Special');
      expect(result is! SyntaxError, isTrue);

      parser = Parser(rules: rules, input: '\n');
      (result, _) = parser.parse('Special');
      expect(result is! SyntaxError, isTrue);

      parser = Parser(rules: rules, input: ' ');
      (result, _) = parser.parse('Special');
      expect(result is SyntaxError, isTrue, reason: 'should fail on space');
    });
  });
}
