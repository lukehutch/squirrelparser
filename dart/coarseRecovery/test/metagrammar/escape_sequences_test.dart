import 'package:squirrel_parser/squirrel_parser.dart';
import 'package:test/test.dart';

void main() {
  group('MetaGrammar - Escape Sequences', () {
    test('newline escape', () {
      const grammar = r'''
        Newline <- "\n";
      ''';

      final rules = MetaGrammar.parseGrammar(grammar);
      final parser = Parser(topRuleName: 'Newline', rules: rules, input: '\n');
      var parseResult = parser.parse();
      final result = parseResult.root;
      expect(result, isNotNull);
      expect(result.len, equals(1));
    });

    test('tab escape', () {
      const grammar = r'''
        Tab <- "\t";
      ''';

      final rules = MetaGrammar.parseGrammar(grammar);
      final parser = Parser(topRuleName: 'Tab', rules: rules, input: '\t');
      var parseResult = parser.parse();
      final result = parseResult.root;
      expect(result, isNotNull);
      expect(result.len, equals(1));
    });

    test('backslash escape', () {
      const grammar = r'''
        Backslash <- "\\";
      ''';

      final rules = MetaGrammar.parseGrammar(grammar);
      final parser = Parser(topRuleName: 'Backslash', rules: rules, input: '\\');
      var parseResult = parser.parse();
      final result = parseResult.root;
      expect(result, isNotNull);
      expect(result.len, equals(1));
    });

    test('quote escapes', () {
      const grammar = r'''
        DoubleQuote <- "\"";
        SingleQuote <- '\'';
      ''';

      final rules = MetaGrammar.parseGrammar(grammar);

      var parser = Parser(topRuleName: 'DoubleQuote', rules: rules, input: '"');
      var parseResult = parser.parse();
      var result = parseResult.root;
      expect(result, isNotNull);

      parser = Parser(topRuleName: 'SingleQuote', rules: rules, input: "'");
      parseResult = parser.parse();
      result = parseResult.root;
      expect(result, isNotNull);
    });

    test('escaped sequence in string', () {
      const grammar = r'''
        Message <- "Hello\nWorld";
      ''';

      final rules = MetaGrammar.parseGrammar(grammar);
      final parser = Parser(topRuleName: 'Message', rules: rules, input: 'Hello\nWorld');
      var parseResult = parser.parse();
      final result = parseResult.root;
      expect(result, isNotNull);
      expect(result.len, equals(11));
    });
  });
}
