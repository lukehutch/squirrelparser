import 'package:squirrel_parser/squirrel_parser.dart';
import 'package:test/test.dart';

void main() {
  group('MetaGrammar - Stress Tests', () {
    test('deeply nested parentheses', () {
      // Test parser can handle deeply nested groupings
      const grammar = '''
        Rule <- ((((("a")))));
      ''';

      final rules = MetaGrammar.parseGrammar(grammar);
      final parser = Parser(topRuleName: 'Rule', rules: rules, input: 'a');
      var parseResult = parser.parse();
      final result = parseResult.root;
      expect(result, isNotNull);
      expect(result.len, equals(1));
    });

    test('many choice alternatives', () {
      // Stress test with 20 alternatives
      const grammar = '''
        Rule <- "a" / "b" / "c" / "d" / "e" / "f" / "g" / "h" / "i" / "j" /
                "k" / "l" / "m" / "n" / "o" / "p" / "q" / "r" / "s" / "t" ;
      ''';

      final rules = MetaGrammar.parseGrammar(grammar);

      // Test first alternative
      var parser = Parser(topRuleName: 'Rule', rules: rules, input: 'a');
      var parseResult = parser.parse();
      var result = parseResult.root;
      expect(result, isNotNull);

      // Test middle alternative
      parser = Parser(topRuleName: 'Rule', rules: rules, input: 'j');
      parseResult = parser.parse();
      result = parseResult.root;
      expect(result, isNotNull);

      // Test last alternative
      parser = Parser(topRuleName: 'Rule', rules: rules, input: 't');
      parseResult = parser.parse();
      result = parseResult.root;
      expect(result, isNotNull);
    });

    test('deeply nested choices and sequences', () {
      // Complex nesting: (a (b / c) d (e / f / g))
      const grammar = '''
        Rule <- "a" ("b" / "c") "d" ("e" / "f" / "g");
      ''';

      final rules = MetaGrammar.parseGrammar(grammar);

      var parser = Parser(topRuleName: 'Rule', rules: rules, input: 'abde');
      var parseResult = parser.parse();
      var result = parseResult.root;
      expect(result, isNotNull);

      parser = Parser(topRuleName: 'Rule', rules: rules, input: 'acdg');
      parseResult = parser.parse();
      result = parseResult.root;
      expect(result, isNotNull);

      parser = Parser(topRuleName: 'Rule', rules: rules, input: 'acdf');
      parseResult = parser.parse();
      result = parseResult.root;
      expect(result, isNotNull);
    });

    test('long sequence', () {
      // Test a very long sequence
      const grammar = '''
        Rule <- "a" "b" "c" "d" "e" "f" "g" "h" "i" "j"
                "k" "l" "m" "n" "o" "p" "q" "r" "s" "t";
      ''';

      final rules = MetaGrammar.parseGrammar(grammar);
      final parser = Parser(topRuleName: 'Rule', rules: rules, input: 'abcdefghijklmnopqrst');
      var parseResult = parser.parse();
      final result = parseResult.root;
      expect(result, isNotNull);
      expect(result.len, equals(20));
    });

    test('stacked repetition operators', () {
      // Test multiple suffix operators: (a+)?*
      // This is a bit pathological but should parse
      const grammar = '''
        Rule <- ("a"+)?;
      ''';

      final rules = MetaGrammar.parseGrammar(grammar);

      // Empty input (optional matches)
      var parser = Parser(topRuleName: 'Rule', rules: rules, input: '');
      var parseResult = parser.parse();
      var result = parseResult.root;
      expect(result, isNotNull);

      // One 'a'
      parser = Parser(topRuleName: 'Rule', rules: rules, input: 'a');
      parseResult = parser.parse();
      result = parseResult.root;
      expect(result, isNotNull);

      // Multiple 'a's
      parser = Parser(topRuleName: 'Rule', rules: rules, input: 'aaa');
      parseResult = parser.parse();
      result = parseResult.root;
      expect(result, isNotNull);
    });

    test('complex lookahead combinations', () {
      // Test &!&! pattern
      const grammar = '''
        Rule <- &![0-9] [a-z]+ ;
      ''';

      final rules = MetaGrammar.parseGrammar(grammar);

      // Should match letters not preceded by digits
      var parser = Parser(topRuleName: 'Rule', rules: rules, input: 'hello');
      var parseResult = parser.parse();
      var result = parseResult.root;
      expect(result, isNotNull);

      // Should fail on digit start
      parser = Parser(topRuleName: 'Rule', rules: rules, input: '5hello');
      var matchResult = parser.matchRule('Rule', 0);
      expect(matchResult.isMismatch, isTrue);
    });

    test('character class edge cases', () {
      // Test character classes with many ranges
      const grammar = '''
        Rule <- [a-zA-Z0-9_-.@]+ ;
      ''';

      final rules = MetaGrammar.parseGrammar(grammar);

      var parser = Parser(topRuleName: 'Rule', rules: rules, input: 'Test_123-name.email@');
      var parseResult = parser.parse();
      var result = parseResult.root;
      expect(result, isNotNull);
    });

    test('negated character class with multiple ranges', () {
      // Everything except digits and whitespace
      const grammar = '''
        Rule <- [^0-9 \t\n\r]+ ;
      ''';

      final rules = MetaGrammar.parseGrammar(grammar);

      var parser = Parser(topRuleName: 'Rule', rules: rules, input: 'hello');
      var parseResult = parser.parse();
      var result = parseResult.root;
      expect(result, isNotNull);

      // Should stop at first digit
      parser = Parser(topRuleName: 'Rule', rules: rules, input: 'test123');
      var matchResult = parser.matchRule('Rule', 0);
      expect(matchResult.len, equals(4)); // Matches 'test'
    });

    test('multiple transparent rules interacting', () {
      const grammar = '''
        ~Space <- " " ;
        ~Tab <- "\t" ;
        ~WS <- (Space / Tab)+ ;
        Main <- WS "hello" WS "world" WS ;
      ''';

      final rules = MetaGrammar.parseGrammar(grammar);
      final parser = Parser(topRuleName: 'Main', rules: rules, input: '  \thello\t  world \t');
      final parseResult = parser.parse();
      final ast = buildAST(parseResult: parseResult);

      expect(ast, isNotNull);
      // Should have 2 children: "hello" and "world" (WS nodes are transparent)
      expect(ast.children.length, equals(2));
    });

    test('deeply nested rule references', () {
      const grammar = '''
        A <- B ;
        B <- C ;
        C <- D ;
        D <- E ;
        E <- "x" ;
      ''';

      final rules = MetaGrammar.parseGrammar(grammar);
      final parser = Parser(topRuleName: 'A', rules: rules, input: 'x');
      var parseResult = parser.parse();
      final result = parseResult.root;
      expect(result, isNotNull);
    });

    test('complex escape sequences', () {
      // Test escape sequences: newline, tab, quotes
      const grammar = r'''
        Rule <- "line1\n\tquote\"test" ;
      ''';

      final rules = MetaGrammar.parseGrammar(grammar);
      final parser = Parser(topRuleName: 'Rule', rules: rules, input: 'line1\n\tquote"test');
      var parseResult = parser.parse();
      final result = parseResult.root;
      expect(result, isNotNull);
      expect(result.len, equals(17));
    });

    test('comments in various positions', () {
      const grammar = '''
        # Leading comment
        Rule <- # inline comment
                "a" # after token
                "b" # another
                ; # end comment
        # Trailing comment
      ''';

      final rules = MetaGrammar.parseGrammar(grammar);
      final parser = Parser(topRuleName: 'Rule', rules: rules, input: 'ab');
      var parseResult = parser.parse();
      final result = parseResult.root;
      expect(result, isNotNull);
    });

    test('mutual recursion between rules', () {
      const grammar = '''
        A <- "a" B / "a" ;
        B <- "b" A / "b" ;
      ''';

      final rules = MetaGrammar.parseGrammar(grammar);

      // Just 'a'
      var parser = Parser(topRuleName: 'A', rules: rules, input: 'a');
      var parseResult = parser.parse();
      var result = parseResult.root;
      expect(result, isNotNull);

      // 'aba'
      parser = Parser(topRuleName: 'A', rules: rules, input: 'aba');
      parseResult = parser.parse();
      result = parseResult.root;
      expect(result, isNotNull);

      // 'ababa'
      parser = Parser(topRuleName: 'A', rules: rules, input: 'ababa');
      parseResult = parser.parse();
      result = parseResult.root;
      expect(result, isNotNull);
    });

    test('complex lookahead in repetition', () {
      // Match characters until we see "end"
      const grammar = '''
        Rule <- (!"end" .)* "end" ;
      ''';

      final rules = MetaGrammar.parseGrammar(grammar);
      final parser = Parser(topRuleName: 'Rule', rules: rules, input: 'hello world end');
      var parseResult = parser.parse();
      final result = parseResult.root;
      expect(result, isNotNull);
      expect(result.len, equals(15)); // "hello world end"
    });

    test('optional with lookahead', () {
      // Optional digit followed by letter, but only if not followed by digit
      const grammar = '''
        Rule <- ([0-9] ![0-9])? [a-z]+ ;
      ''';

      final rules = MetaGrammar.parseGrammar(grammar);

      // Just letters
      var parser = Parser(topRuleName: 'Rule', rules: rules, input: 'hello');
      var parseResult = parser.parse();
      var result = parseResult.root;
      expect(result, isNotNull);

      // Digit then letters
      parser = Parser(topRuleName: 'Rule', rules: rules, input: '5hello');
      parseResult = parser.parse();
      result = parseResult.root;
      expect(result, isNotNull);
    });

    test('zero-or-more with complex content', () {
      // Pairs of letters and digits, zero or more times
      const grammar = '''
        Rule <- ([a-z] [0-9])* ;
      ''';

      final rules = MetaGrammar.parseGrammar(grammar);

      // Empty
      var parser = Parser(topRuleName: 'Rule', rules: rules, input: '');
      var parseResult = parser.parse();
      var result = parseResult.root;
      expect(result, isNotNull);

      // One pair
      parser = Parser(topRuleName: 'Rule', rules: rules, input: 'a5');
      parseResult = parser.parse();
      result = parseResult.root;
      expect(result, isNotNull);

      // Multiple pairs
      parser = Parser(topRuleName: 'Rule', rules: rules, input: 'a5b3c7');
      parseResult = parser.parse();
      result = parseResult.root;
      expect(result, isNotNull);
    });

    test('choice with lookahead conditions', () {
      // Match different patterns based on lookahead
      const grammar = '''
        Rule <- &[a-z] Lowercase / &[A-Z] Uppercase / Digit ;
        Lowercase <- [a-z]+ ;
        Uppercase <- [A-Z]+ ;
        Digit <- [0-9]+ ;
      ''';

      final rules = MetaGrammar.parseGrammar(grammar);

      var parser = Parser(topRuleName: 'Rule', rules: rules, input: 'hello');
      var parseResult = parser.parse();
      var result = parseResult.root;
      expect(result, isNotNull);

      parser = Parser(topRuleName: 'Rule', rules: rules, input: 'WORLD');
      parseResult = parser.parse();
      result = parseResult.root;
      expect(result, isNotNull);

      parser = Parser(topRuleName: 'Rule', rules: rules, input: '123');
      parseResult = parser.parse();
      result = parseResult.root;
      expect(result, isNotNull);
    });

    test('nested optional and repetition', () {
      // Optional groups with repetition inside
      const grammar = '''
        Rule <- ("a"+ "b"?)* ;
      ''';

      final rules = MetaGrammar.parseGrammar(grammar);

      var parser = Parser(topRuleName: 'Rule', rules: rules, input: '');
      var parseResult = parser.parse();
      var result = parseResult.root;
      expect(result, isNotNull);

      parser = Parser(topRuleName: 'Rule', rules: rules, input: 'abaab');
      parseResult = parser.parse();
      result = parseResult.root;
      expect(result, isNotNull);

      parser = Parser(topRuleName: 'Rule', rules: rules, input: 'aaabaaaa');
      parseResult = parser.parse();
      result = parseResult.root;
      expect(result, isNotNull);
    });

    test('any char with repetition and bounds', () {
      // Exactly 5 characters
      const grammar = '''
        Rule <- . . . . . ;
      ''';

      final rules = MetaGrammar.parseGrammar(grammar);
      final parser = Parser(topRuleName: 'Rule', rules: rules, input: 'hello');
      var parseResult = parser.parse();
      final result = parseResult.root;
      expect(result, isNotNull);
      expect(result.len, equals(5));
    });

    test('complex sequence with all operator types', () {
      // Combine all operators in one rule
      const grammar = '''
        Rule <- &[a-z] [a-z]+ ![0-9] ("_" [a-z]+)* ([0-9]+)? ;
      ''';

      final rules = MetaGrammar.parseGrammar(grammar);

      // Basic identifier
      var parser = Parser(topRuleName: 'Rule', rules: rules, input: 'hello');
      var parseResult = parser.parse();
      var result = parseResult.root;
      expect(result, isNotNull);

      // With underscores
      parser = Parser(topRuleName: 'Rule', rules: rules, input: 'hello_world_test');
      parseResult = parser.parse();
      result = parseResult.root;
      expect(result, isNotNull);

      // With trailing digits
      parser = Parser(topRuleName: 'Rule', rules: rules, input: 'test_var123');
      parseResult = parser.parse();
      result = parseResult.root;
      expect(result, isNotNull);
    });

    test('pathological backtracking case', () {
      // A pattern that could cause excessive backtracking in naive parsers
      const grammar = '''
        Rule <- "a"* "a"* "a"* "a"* "b" ;
      ''';

      final rules = MetaGrammar.parseGrammar(grammar);
      final parser = Parser(topRuleName: 'Rule', rules: rules, input: 'aaaaab');
      var parseResult = parser.parse();
      final result = parseResult.root;
      expect(result, isNotNull);
      expect(result.len, equals(6));
    });

    test('rule with mixed transparent and non-transparent references', () {
      const grammar = '''
        Main <- A ~B C ;
        A <- "a" ;
        ~B <- "b" ;
        C <- "c" ;
      ''';

      final rules = MetaGrammar.parseGrammar(grammar);
      final parser = Parser(topRuleName: 'Main', rules: rules, input: 'abc');
      final parseResult = parser.parse();
      final ast = buildAST(parseResult: parseResult);

      expect(ast, isNotNull);
      expect(ast.label, equals('Main'));
      // Transparent rules (marked with ~) should not appear in the AST
      // So only A and C should be present, not B
      expect(ast.children.length, equals(2));
      expect(ast.children[0].label, equals('A'));
      expect(ast.children[1].label, equals('C'));
    });

    test('character class with special characters', () {
      // Test characters including dot, underscore, hyphen
      const grammar = '''
        Rule <- [a-z.@_]+ ;
      ''';

      final rules = MetaGrammar.parseGrammar(grammar);
      final parser = Parser(topRuleName: 'Rule', rules: rules, input: 'test.name_value@');
      var parseResult = parser.parse();
      final result = parseResult.root;
      expect(result, isNotNull);
    });

    test('very long rule name', () {
      const grammar = '''
        ThisIsAVeryLongRuleNameToTestThatLongIdentifiersWork <- "test" ;
      ''';

      final rules = MetaGrammar.parseGrammar(grammar);
      expect(
          rules.containsKey(
              'ThisIsAVeryLongRuleNameToTestThatLongIdentifiersWork'),
          isTrue);
    });

    test('multiple consecutive lookaheads', () {
      // Multiple positive lookaheads in sequence
      const grammar = '''
        Rule <- &[a-z] &[a-c] "a" ;
      ''';

      final rules = MetaGrammar.parseGrammar(grammar);

      var parser = Parser(topRuleName: 'Rule', rules: rules, input: 'a');
      var parseResult = parser.parse();
      var result = parseResult.root;
      expect(result, isNotNull);

      // Should fail for 'd' (doesn't match second lookahead)
      parser = Parser(topRuleName: 'Rule', rules: rules, input: 'd');
      var matchResult = parser.matchRule('Rule', 0);
      expect(matchResult.isMismatch, isTrue);
    });

    test('choice with potentially empty matches', () {
      // Test choice where alternatives can match varying lengths
      const grammar = '''
        Rule <- "a"+ / "b"+ / "" ;
      ''';

      final rules = MetaGrammar.parseGrammar(grammar);

      // 'aaa' matches first alternative
      var parser = Parser(topRuleName: 'Rule', rules: rules, input: 'aaa');
      var parseResult = parser.parse();
      var result = parseResult.root;
      expect(result, isNotNull);

      // 'bbb' matches second alternative
      parser = Parser(topRuleName: 'Rule', rules: rules, input: 'bbb');
      parseResult = parser.parse();
      result = parseResult.root;
      expect(result, isNotNull);

      // Empty input matches third alternative
      parser = Parser(topRuleName: 'Rule', rules: rules, input: '');
      var matchResult = parser.matchRule('Rule', 0);
      expect(matchResult.isMismatch, isFalse);
      expect(matchResult.len, equals(0));
    });

    test('negated lookahead with alternatives', () {
      // Not followed by keyword
      const grammar = '''
        Rule <- !(Keyword ![a-z]) [a-z]+ ;
        Keyword <- "if" / "while" / "for" ;
      ''';

      final rules = MetaGrammar.parseGrammar(grammar);

      // Regular identifier works
      var parser = Parser(topRuleName: 'Rule', rules: rules, input: 'hello');
      var parseResult = parser.parse();
      var result = parseResult.root;
      expect(result, isNotNull);

      // Keyword prefix works (iffy)
      parser = Parser(topRuleName: 'Rule', rules: rules, input: 'iffy');
      parseResult = parser.parse();
      result = parseResult.root;
      expect(result, isNotNull);

      // Pure keyword should fail
      parser = Parser(topRuleName: 'Rule', rules: rules, input: 'if');
      var matchResult = parser.matchRule('Rule', 0);
      expect(matchResult.isMismatch, isTrue);
    });

    test('repetition of grouped alternation', () {
      // Repeat a choice multiple times
      const grammar = '''
        Rule <- ("a" / "b" / "c")+ ;
      ''';

      final rules = MetaGrammar.parseGrammar(grammar);
      final parser = Parser(topRuleName: 'Rule', rules: rules, input: 'abccbaabccc');
      var parseResult = parser.parse();
      final result = parseResult.root;
      expect(result, isNotNull);
      expect(result.len, equals(11));
    });
  });
}
