import 'package:squirrel_parser/squirrel_parser.dart';
import 'package:test/test.dart';

void main() {
  group('CharSet Terminal - Direct Construction', () {
    test('CharSet.range matches characters in range', () {
      final charSet = CharSet.range('a', 'z');
      final rules = {'S': charSet};

      var parser = Parser(topRuleName: 'S', rules: rules, input: 'a');
      expect(parser.parse().root is! SyntaxError, isTrue, reason: 'should match a');

      parser = Parser(topRuleName: 'S', rules: rules, input: 'm');
      expect(parser.parse().root is! SyntaxError, isTrue, reason: 'should match m');

      parser = Parser(topRuleName: 'S', rules: rules, input: 'z');
      expect(parser.parse().root is! SyntaxError, isTrue, reason: 'should match z');

      parser = Parser(topRuleName: 'S', rules: rules, input: 'A');
      expect(parser.parse().root is SyntaxError, isTrue, reason: 'should not match A');
    });

    test('CharSet.char matches single character', () {
      final charSet = CharSet.char('x');
      final rules = {'S': charSet};

      var parser = Parser(topRuleName: 'S', rules: rules, input: 'x');
      expect(parser.parse().root is! SyntaxError, isTrue, reason: 'should match x');

      parser = Parser(topRuleName: 'S', rules: rules, input: 'y');
      expect(parser.parse().root is SyntaxError, isTrue, reason: 'should not match y');
    });

    test('CharSet with multiple ranges', () {
      // [a-zA-Z0-9]
      final charSet = CharSet([
        ('a'.codeUnitAt(0), 'z'.codeUnitAt(0)),
        ('A'.codeUnitAt(0), 'Z'.codeUnitAt(0)),
        ('0'.codeUnitAt(0), '9'.codeUnitAt(0)),
      ]);
      final rules = {'S': charSet};

      // Test lowercase
      var parser = Parser(topRuleName: 'S', rules: rules, input: 'a');
      expect(parser.parse().root is! SyntaxError, isTrue);
      parser = Parser(topRuleName: 'S', rules: rules, input: 'z');
      expect(parser.parse().root is! SyntaxError, isTrue);

      // Test uppercase
      parser = Parser(topRuleName: 'S', rules: rules, input: 'A');
      expect(parser.parse().root is! SyntaxError, isTrue);
      parser = Parser(topRuleName: 'S', rules: rules, input: 'Z');
      expect(parser.parse().root is! SyntaxError, isTrue);

      // Test digits
      parser = Parser(topRuleName: 'S', rules: rules, input: '0');
      expect(parser.parse().root is! SyntaxError, isTrue);
      parser = Parser(topRuleName: 'S', rules: rules, input: '9');
      expect(parser.parse().root is! SyntaxError, isTrue);

      // Test non-alphanumeric
      parser = Parser(topRuleName: 'S', rules: rules, input: '!');
      expect(parser.parse().root is SyntaxError, isTrue);
      parser = Parser(topRuleName: 'S', rules: rules, input: ' ');
      expect(parser.parse().root is SyntaxError, isTrue);
    });

    test('CharSet with inversion', () {
      // [^a-z] - matches anything NOT a lowercase letter
      final charSet = CharSet([
        ('a'.codeUnitAt(0), 'z'.codeUnitAt(0)),
      ], inverted: true);
      final rules = {'S': charSet};

      // Should NOT match lowercase
      var parser = Parser(topRuleName: 'S', rules: rules, input: 'a');
      expect(parser.parse().root is SyntaxError, isTrue, reason: 'should not match a');
      parser = Parser(topRuleName: 'S', rules: rules, input: 'm');
      expect(parser.parse().root is SyntaxError, isTrue, reason: 'should not match m');
      parser = Parser(topRuleName: 'S', rules: rules, input: 'z');
      expect(parser.parse().root is SyntaxError, isTrue, reason: 'should not match z');

      // Should match uppercase, digits, symbols
      parser = Parser(topRuleName: 'S', rules: rules, input: 'A');
      expect(parser.parse().root is! SyntaxError, isTrue, reason: 'should match A');
      parser = Parser(topRuleName: 'S', rules: rules, input: '5');
      expect(parser.parse().root is! SyntaxError, isTrue, reason: 'should match 5');
      parser = Parser(topRuleName: 'S', rules: rules, input: '!');
      expect(parser.parse().root is! SyntaxError, isTrue, reason: 'should match !');
    });

    test('CharSet with inverted multiple ranges', () {
      // [^a-zA-Z] - matches anything NOT a letter
      final charSet = CharSet([
        ('a'.codeUnitAt(0), 'z'.codeUnitAt(0)),
        ('A'.codeUnitAt(0), 'Z'.codeUnitAt(0)),
      ], inverted: true);
      final rules = {'S': charSet};

      // Should NOT match letters
      var parser = Parser(topRuleName: 'S', rules: rules, input: 'a');
      expect(parser.parse().root is SyntaxError, isTrue, reason: 'should not match a');
      parser = Parser(topRuleName: 'S', rules: rules, input: 'Z');
      expect(parser.parse().root is SyntaxError, isTrue, reason: 'should not match Z');

      // Should match digits and symbols
      parser = Parser(topRuleName: 'S', rules: rules, input: '5');
      expect(parser.parse().root is! SyntaxError, isTrue, reason: 'should match 5');
      parser = Parser(topRuleName: 'S', rules: rules, input: '!');
      expect(parser.parse().root is! SyntaxError, isTrue, reason: 'should match !');
    });

    test('CharSet.notRange convenience constructor', () {
      final charSet = CharSet.notRange('0', '9');
      final rules = {'S': charSet};

      // Should NOT match digits
      var parser = Parser(topRuleName: 'S', rules: rules, input: '5');
      expect(parser.parse().root is SyntaxError, isTrue, reason: 'should not match 5');

      // Should match non-digits
      parser = Parser(topRuleName: 'S', rules: rules, input: 'a');
      expect(parser.parse().root is! SyntaxError, isTrue, reason: 'should match a');
    });

    test('CharSet toString formats correctly', () {
      expect(CharSet.range('a', 'z').toString(), equals('[a-z]'));
      expect(CharSet.char('x').toString(), equals('[x]'));
      expect(CharSet([
        ('a'.codeUnitAt(0), 'z'.codeUnitAt(0)),
        ('0'.codeUnitAt(0), '9'.codeUnitAt(0)),
      ]).toString(), equals('[a-z0-9]'));
      expect(CharSet([
        ('a'.codeUnitAt(0), 'z'.codeUnitAt(0)),
      ], inverted: true).toString(), equals('[^a-z]'));
    });

    test('CharSet handles empty input', () {
      final charSet = CharSet.range('a', 'z');
      final rules = {'S': charSet};

      final parser = Parser(topRuleName: 'S', rules: rules, input: '');
      expect(parser.parse().root is SyntaxError, isTrue, reason: 'should not match empty');
    });
  });

  group('MetaGrammar - Character Classes', () {
    test('simple character range', () {
      const grammar = '''
        Digit <- [0-9];
      ''';

      final rules = MetaGrammar.parseGrammar(grammar);

      var parser = Parser(topRuleName: 'Digit', rules: rules, input: '5');
      var parseResult = parser.parse();
      var result = parseResult.root;
      expect(result is! SyntaxError, isTrue, reason: 'should match digit');
      expect(result.len, equals(1));

      parser = Parser(topRuleName: 'Digit', rules: rules, input: 'a');
      parseResult = parser.parse();
      result = parseResult.root;
      expect(result is SyntaxError, isTrue, reason: 'should fail on non-digit');
    });

    test('multiple character ranges', () {
      const grammar = '''
        AlphaNum <- [a-zA-Z0-9];
      ''';

      final rules = MetaGrammar.parseGrammar(grammar);

      var parser = Parser(topRuleName: 'AlphaNum', rules: rules, input: 'a');
      var parseResult = parser.parse();
      var result = parseResult.root;
      expect(result is! SyntaxError, isTrue);

      parser = Parser(topRuleName: 'AlphaNum', rules: rules, input: 'Z');
      parseResult = parser.parse();
      result = parseResult.root;
      expect(result is! SyntaxError, isTrue);

      parser = Parser(topRuleName: 'AlphaNum', rules: rules, input: '5');
      parseResult = parser.parse();
      result = parseResult.root;
      expect(result is! SyntaxError, isTrue);

      parser = Parser(topRuleName: 'AlphaNum', rules: rules, input: '!');
      parseResult = parser.parse();
      result = parseResult.root;
      expect(result is SyntaxError, isTrue,
          reason: 'should fail on non-alphanumeric');
    });

    test('character class with individual characters', () {
      const grammar = '''
        Vowel <- [aeiou];
      ''';

      final rules = MetaGrammar.parseGrammar(grammar);

      var parser = Parser(topRuleName: 'Vowel', rules: rules, input: 'a');
      var parseResult = parser.parse();
      var result = parseResult.root;
      expect(result is! SyntaxError, isTrue);

      parser = Parser(topRuleName: 'Vowel', rules: rules, input: 'e');
      parseResult = parser.parse();
      result = parseResult.root;
      expect(result is! SyntaxError, isTrue);

      parser = Parser(topRuleName: 'Vowel', rules: rules, input: 'b');
      parseResult = parser.parse();
      result = parseResult.root;
      expect(result is SyntaxError, isTrue, reason: 'should fail on consonant');
    });

    test('negated character class', () {
      const grammar = '''
        NotDigit <- [^0-9];
      ''';

      final rules = MetaGrammar.parseGrammar(grammar);

      var parser = Parser(topRuleName: 'NotDigit', rules: rules, input: 'a');
      var parseResult = parser.parse();
      var result = parseResult.root;
      expect(result is! SyntaxError, isTrue);

      parser = Parser(topRuleName: 'NotDigit', rules: rules, input: '5');
      parseResult = parser.parse();
      result = parseResult.root;
      expect(result is SyntaxError, isTrue, reason: 'should fail on digit');
    });

    test('escaped characters in character class', () {
      const grammar = r'''
        Special <- [\t\n];
      ''';

      final rules = MetaGrammar.parseGrammar(grammar);

      var parser = Parser(topRuleName: 'Special', rules: rules, input: '\t');
      var parseResult = parser.parse();
      var result = parseResult.root;
      expect(result is! SyntaxError, isTrue);

      parser = Parser(topRuleName: 'Special', rules: rules, input: '\n');
      parseResult = parser.parse();
      result = parseResult.root;
      expect(result is! SyntaxError, isTrue);

      parser = Parser(topRuleName: 'Special', rules: rules, input: ' ');
      parseResult = parser.parse();
      result = parseResult.root;
      expect(result is SyntaxError, isTrue, reason: 'should fail on space');
    });
  });
}
