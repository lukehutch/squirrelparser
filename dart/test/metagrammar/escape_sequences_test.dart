import 'package:squirrel_parser/squirrel_parser.dart';
import 'package:test/test.dart';

void main() {
  group('MetaGrammar - Escape Sequences', () {
    test('newline escape', () {
      const grammar = r'''
        Newline <- "\n";
      ''';

      final rules = MetaGrammar.parseGrammar(grammar);
      final parser = Parser(rules: rules, input: '\n');
      final (result, _) = parser.parse('Newline');
      expect(result, isNotNull);
      expect(result.len, equals(1));
    });

    test('tab escape', () {
      const grammar = r'''
        Tab <- "\t";
      ''';

      final rules = MetaGrammar.parseGrammar(grammar);
      final parser = Parser(rules: rules, input: '\t');
      final (result, _) = parser.parse('Tab');
      expect(result, isNotNull);
      expect(result.len, equals(1));
    });

    test('backslash escape', () {
      const grammar = r'''
        Backslash <- "\\";
      ''';

      final rules = MetaGrammar.parseGrammar(grammar);
      final parser = Parser(rules: rules, input: '\\');
      final (result, _) = parser.parse('Backslash');
      expect(result, isNotNull);
      expect(result.len, equals(1));
    });

    test('quote escapes', () {
      const grammar = r'''
        DoubleQuote <- "\"";
        SingleQuote <- '\'';
      ''';

      final rules = MetaGrammar.parseGrammar(grammar);

      var parser = Parser(rules: rules, input: '"');
      var (result, _) = parser.parse('DoubleQuote');
      expect(result, isNotNull);

      parser = Parser(rules: rules, input: "'");
      (result, _) = parser.parse('SingleQuote');
      expect(result, isNotNull);
    });

    test('escaped sequence in string', () {
      const grammar = r'''
        Message <- "Hello\nWorld";
      ''';

      final rules = MetaGrammar.parseGrammar(grammar);
      final parser = Parser(rules: rules, input: 'Hello\nWorld');
      final (result, _) = parser.parse('Message');
      expect(result, isNotNull);
      expect(result.len, equals(11));
    });
  });
}
