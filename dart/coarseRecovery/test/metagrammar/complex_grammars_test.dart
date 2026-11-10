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

      var parser = Parser(topRuleName: 'Expr', rules: rules, input: '42');
      var parseResult = parser.parse();
      var result = parseResult.root;
      expect(result, isNotNull);
      expect(result.len, equals(2));

      parser = Parser(topRuleName: 'Expr', rules: rules, input: '1+2');
      parseResult = parser.parse();
      result = parseResult.root;
      expect(result, isNotNull);
      expect(result.len, equals(3));

      parser = Parser(topRuleName: 'Expr', rules: rules, input: '1+2*3');
      parseResult = parser.parse();
      result = parseResult.root;
      expect(result, isNotNull);
      expect(result.len, equals(5));

      parser = Parser(topRuleName: 'Expr', rules: rules, input: '(1+2)*3');
      parseResult = parser.parse();
      result = parseResult.root;
      expect(result, isNotNull);
      expect(result.len, equals(7));
    });

    test('identifier and keyword grammar', () {
      const grammar = '''
        Ident <- !Keyword [a-zA-Z_] [a-zA-Z0-9_]*;
        Keyword <- ("if" / "while" / "for") ![a-zA-Z0-9_];
      ''';

      final rules = MetaGrammar.parseGrammar(grammar);

      var parser = Parser(topRuleName: 'Ident', rules: rules, input: 'foo');
      var parseResult = parser.parse();
      var result = parseResult.root;
      expect(result, isNotNull);

      // Use matchRule for negative test to avoid recovery
      parser = Parser(topRuleName: 'Ident', rules: rules, input: 'if');
      var matchResult = parser.matchRule('Ident', 0);
      expect(matchResult.isMismatch, isTrue); // 'if' is a keyword

      parser = Parser(topRuleName: 'Ident', rules: rules, input: 'iffy');
      parseResult = parser.parse();
      result = parseResult.root;
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

      var parser = Parser(topRuleName: 'Value', rules: rules, input: '{}');
      var parseResult = parser.parse();
      var result = parseResult.root;
      expect(result, isNotNull);

      parser = Parser(topRuleName: 'Value', rules: rules, input: '[]');
      parseResult = parser.parse();
      result = parseResult.root;
      expect(result, isNotNull);

      parser = Parser(topRuleName: 'Value', rules: rules, input: '"hello"');
      parseResult = parser.parse();
      result = parseResult.root;
      expect(result, isNotNull);

      parser = Parser(topRuleName: 'Value', rules: rules, input: '123');
      parseResult = parser.parse();
      result = parseResult.root;
      expect(result, isNotNull);
    });

    test('whitespace handling', () {
      const grammar = '''
        Main <- _ "hello" _ "world" _;
        _ <- [ \\t\\n\\r]*;
      ''';

      final rules = MetaGrammar.parseGrammar(grammar);

      var parser = Parser(topRuleName: 'Main', rules: rules, input: 'helloworld');
      var parseResult = parser.parse();
      var result = parseResult.root;
      expect(result, isNotNull);

      parser = Parser(topRuleName: 'Main', rules: rules, input: '  hello   world  ');
      parseResult = parser.parse();
      result = parseResult.root;
      expect(result, isNotNull);

      parser = Parser(topRuleName: 'Main', rules: rules, input: 'hello\\n\\tworld');
      parseResult = parser.parse();
      result = parseResult.root;
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

      final parser = Parser(topRuleName: 'Main', rules: rules, input: 'test');
      var parseResult = parser.parse();
      final result = parseResult.root;
      expect(result, isNotNull);
    });
  });
}
