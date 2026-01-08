import 'package:squirrel_parser/squirrel_parser.dart';
import 'package:test/test.dart';

void main() {
  group('MetaGrammar - Complex Grammars', () {
    test('arithmetic expression grammar', () {
      const grammar = '''
        Expr <- Term ("+" Term / "-" Term)*;
        Term <- Factor ("*" Factor / "/" Factor)*;
        Factor <- Number / "(" Expr ")";
        Number <- [0-9]+;
      ''';

      final rules = MetaGrammar.parseGrammar(grammar);

      var parser = Parser(rules: rules, input: '42');
      var (result, _) = parser.parse('Expr');
      expect(result, isNotNull);
      expect(result.len, equals(2));

      parser = Parser(rules: rules, input: '1+2');
      (result, _) = parser.parse('Expr');
      expect(result, isNotNull);
      expect(result.len, equals(3));

      parser = Parser(rules: rules, input: '1+2*3');
      (result, _) = parser.parse('Expr');
      expect(result, isNotNull);
      expect(result.len, equals(5));

      parser = Parser(rules: rules, input: '(1+2)*3');
      (result, _) = parser.parse('Expr');
      expect(result, isNotNull);
      expect(result.len, equals(7));
    });

    test('identifier and keyword grammar', () {
      const grammar = '''
        Ident <- !Keyword [a-zA-Z_] [a-zA-Z0-9_]*;
        Keyword <- ("if" / "while" / "for") ![a-zA-Z0-9_];
      ''';

      final rules = MetaGrammar.parseGrammar(grammar);

      var parser = Parser(rules: rules, input: 'foo');
      var (result, _) = parser.parse('Ident');
      expect(result, isNotNull);

      // Use matchRule for negative test to avoid recovery
      parser = Parser(rules: rules, input: 'if');
      var matchResult = parser.matchRule('Ident', 0);
      expect(matchResult.isMismatch, isTrue); // 'if' is a keyword

      parser = Parser(rules: rules, input: 'iffy');
      (result, _) = parser.parse('Ident');
      expect(result, isNotNull); // 'iffy' is not a keyword
    });

    test('JSON grammar', () {
      const grammar = '''
        Value <- String / Number / Object / Array / "true" / "false" / "null";
        Object <- "{" _ (Pair (_ "," _ Pair)*)? _ "}";
        Pair <- String _ ":" _ Value;
        Array <- "[" _ (Value (_ "," _ Value)*)? _ "]";
        String <- "\\"" [^"]* "\\"";
        Number <- [0-9]+;
        _ <- [ \\t\\n\\r]*;
      ''';

      final rules = MetaGrammar.parseGrammar(grammar);

      var parser = Parser(rules: rules, input: '{}');
      var (result, _) = parser.parse('Object');
      expect(result, isNotNull);

      parser = Parser(rules: rules, input: '[]');
      (result, _) = parser.parse('Array');
      expect(result, isNotNull);

      parser = Parser(rules: rules, input: '"hello"');
      (result, _) = parser.parse('String');
      expect(result, isNotNull);

      parser = Parser(rules: rules, input: '123');
      (result, _) = parser.parse('Number');
      expect(result, isNotNull);
    });

    test('whitespace handling', () {
      const grammar = '''
        Main <- _ "hello" _ "world" _;
        _ <- [ \\t\\n\\r]*;
      ''';

      final rules = MetaGrammar.parseGrammar(grammar);

      var parser = Parser(rules: rules, input: 'helloworld');
      var (result, _) = parser.parse('Main');
      expect(result, isNotNull);

      parser = Parser(rules: rules, input: '  hello   world  ');
      (result, _) = parser.parse('Main');
      expect(result, isNotNull);

      parser = Parser(rules: rules, input: 'hello\\n\\tworld');
      (result, _) = parser.parse('Main');
      expect(result, isNotNull);
    });

    test('comment handling with metagrammar', () {
      const grammar = '''
        # This is a comment
        Main <- "test"; # trailing comment
        # Another comment
      ''';

      final rules = MetaGrammar.parseGrammar(grammar);
      expect(rules.containsKey('Main'), isTrue);

      final parser = Parser(rules: rules, input: 'test');
      final (result, _) = parser.parse('Main');
      expect(result, isNotNull);
    });
  });
}
