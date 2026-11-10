import 'package:squirrel_parser/squirrel_parser.dart';
import 'package:test/test.dart';

void main() {
  group('Lookahead Operators - Direct Matching', () {
    // These tests use squirrelParsePT to test the core functionality

    group('FollowedBy (&)', () {
      test('positive lookahead succeeds when pattern matches', () {
        final result = squirrelParsePT(
          grammarSpec: 'Test <- &"a" ;',
          topRuleName: 'Test',
          input: 'abc',
        );

        expect(result.root.isMismatch, isFalse);
        expect(result.root.len, equals(0)); // Lookahead doesn't consume
      });

      test('positive lookahead fails when pattern does not match', () {
        final result = squirrelParsePT(
          grammarSpec: 'Test <- &"a" ;',
          topRuleName: 'Test',
          input: 'b',
        );

        expect(result.root is SyntaxError, isTrue);
      });

      test('positive lookahead in sequence', () {
        final result = squirrelParsePT(
          grammarSpec: 'Test <- "a" &"b" ;',
          topRuleName: 'Test',
          input: 'abc',
        );

        expect(result.root.isMismatch, isFalse);
        expect(result.root.len, equals(1)); // Only 'a' consumed
      });

      test('positive lookahead in sequence - fails when not followed', () {
        final result = squirrelParsePT(
          grammarSpec: 'Test <- "a" &"b" ;',
          topRuleName: 'Test',
          input: 'ac',
        );

        expect(result.root is SyntaxError, isTrue); // Fails because no 'b' after 'a'
      });

      test('positive lookahead with continuation', () {
        final result = squirrelParsePT(
          grammarSpec: 'Test <- "a" &"b" "b" ;',
          topRuleName: 'Test',
          input: 'abc',
        );

        expect(result.root.isMismatch, isFalse);
        expect(result.root.len, equals(2)); // 'a' and 'b' consumed
      });

      test('positive lookahead at end of input', () {
        final result = squirrelParsePT(
          grammarSpec: 'Test <- "a" &"b" ;',
          topRuleName: 'Test',
          input: 'a',
        );

        // With error recovery, this succeeds but has syntax errors
        expect(result.hasSyntaxErrors, isTrue); // No 'b' to look ahead to
      });

      test('nested positive lookaheads', () {
        final result = squirrelParsePT(
          grammarSpec: 'Test <- &&"a" "a" ;',
          topRuleName: 'Test',
          input: 'a',
        );

        expect(result.root.isMismatch, isFalse);
        expect(result.root.len, equals(1));
      });
    });

    group('NotFollowedBy (!)', () {
      test('negative lookahead succeeds when pattern does not match', () {
        final result = squirrelParsePT(
          grammarSpec: 'Test <- !"a" ;',
          topRuleName: 'Test',
          input: 'b',
        );

        expect(result.root.isMismatch, isFalse);
        expect(result.root.len, equals(0)); // Lookahead doesn't consume
      });

      test('negative lookahead fails when pattern matches', () {
        final result = squirrelParsePT(
          grammarSpec: 'Test <- !"a" ;',
          topRuleName: 'Test',
          input: 'a',
        );

        expect(result.root is SyntaxError, isTrue);
      });

      test('negative lookahead in sequence', () {
        final result = squirrelParsePT(
          grammarSpec: 'Test <- "a" !"b" ;',
          topRuleName: 'Test',
          input: 'ac',
        );

        expect(result.root.isMismatch, isFalse);
        expect(result.root.len, equals(1)); // Only 'a' consumed
      });

      test('negative lookahead in sequence - fails when followed', () {
        final result = squirrelParsePT(
          grammarSpec: 'Test <- "a" !"b" ;',
          topRuleName: 'Test',
          input: 'ab',
        );

        expect(result.root is SyntaxError, isTrue); // Fails because 'a' IS followed by 'b'
      });

      test('negative lookahead with continuation', () {
        final result = squirrelParsePT(
          grammarSpec: 'Test <- "a" !"b" "c" ;',
          topRuleName: 'Test',
          input: 'ac',
        );

        expect(result.root.isMismatch, isFalse);
        expect(result.root.len, equals(2)); // 'a' and 'c' consumed
      });

      test('negative lookahead at end of input', () {
        final result = squirrelParsePT(
          grammarSpec: 'Test <- "a" !"b" ;',
          topRuleName: 'Test',
          input: 'a',
        );

        expect(result.root.isMismatch, isFalse); // No 'b' following, so succeeds
        expect(result.root.len, equals(1));
      });

      test('nested negative lookaheads', () {
        // !!"a" is the same as &"a"
        final result = squirrelParsePT(
          grammarSpec: 'Test <- !!"a" "a" ;',
          topRuleName: 'Test',
          input: 'a',
        );

        expect(result.root.isMismatch, isFalse);
        expect(result.root.len, equals(1));
      });
    });

    group('Mixed Lookaheads', () {
      test('positive then negative lookahead', () {
        const grammar = 'Test <- &[a-z] !"x" [a-z] ;';

        // Should match any lowercase letter except 'x'
        var result = squirrelParsePT(
          grammarSpec: grammar,
          topRuleName: 'Test',
          input: 'a',
        );
        expect(result.root.isMismatch, isFalse);

        result = squirrelParsePT(
          grammarSpec: grammar,
          topRuleName: 'Test',
          input: 'x',
        );
        expect(result.root is SyntaxError, isTrue);

        result = squirrelParsePT(
          grammarSpec: grammar,
          topRuleName: 'Test',
          input: 'A',
        );
        expect(result.root is SyntaxError, isTrue);
      });

      test('lookahead in choice', () {
        const grammar = 'Test <- &"a" "a" / &"b" "b" ;';

        var result = squirrelParsePT(
          grammarSpec: grammar,
          topRuleName: 'Test',
          input: 'a',
        );
        expect(result.root.isMismatch, isFalse);
        expect(result.root.len, equals(1));

        result = squirrelParsePT(
          grammarSpec: grammar,
          topRuleName: 'Test',
          input: 'b',
        );
        expect(result.root.isMismatch, isFalse);
        expect(result.root.len, equals(1));

        result = squirrelParsePT(
          grammarSpec: grammar,
          topRuleName: 'Test',
          input: 'c',
        );
        expect(result.root is SyntaxError, isTrue);
      });

      test('lookahead with repetition', () {
        const grammar = 'Test <- (!"." [a-z])* ;';

        // Match lowercase letters until '.', then parser has unmatched input
        var result = squirrelParsePT(
          grammarSpec: grammar,
          topRuleName: 'Test',
          input: 'abc.def',
        );
        expect(result.root.isMismatch, isFalse);
        // The grammar itself only matches 'abc', but error recovery captures trailing '.def'
        expect(result.hasSyntaxErrors, isTrue);

        result = squirrelParsePT(
          grammarSpec: grammar,
          topRuleName: 'Test',
          input: '.abc',
        );
        expect(result.root.isMismatch, isFalse);
        // With error recovery, unmatched '.abc' is captured as syntax error
        expect(result.hasSyntaxErrors, isTrue);
      });
    });

    group('Lookahead with References', () {
      test('positive lookahead with rule reference', () {
        final result = squirrelParsePT(
          grammarSpec: '''
            Test <- &Digit Digit ;
            Digit <- [0-9] ;
          ''',
          topRuleName: 'Test',
          input: '5',
        );

        expect(result.root.isMismatch, isFalse);
        expect(result.root.len, equals(1));
      });

      test('negative lookahead with rule reference', () {
        const grammar = '''
          Test <- !Digit [a-z] ;
          Digit <- [0-9] ;
        ''';

        var result = squirrelParsePT(
          grammarSpec: grammar,
          topRuleName: 'Test',
          input: 'a',
        );
        expect(result.root.isMismatch, isFalse);

        result = squirrelParsePT(
          grammarSpec: grammar,
          topRuleName: 'Test',
          input: '5',
        );
        expect(result.root is SyntaxError, isTrue);
      });
    });
  });

  group('Lookahead Operators - Integration with parse()', () {
    // These tests use squirrelParsePT which expects all input to be consumed

    test('lookahead with full input consumption', () {
      final result = squirrelParsePT(
        grammarSpec: 'Test <- "a" &"b" "b" ;',
        topRuleName: 'Test',
        input: 'ab',
      );

      expect(result.root, isNotNull);
      expect(result.root.len, equals(2)); // Both 'a' and 'b' consumed
    });

    test('negative lookahead with full input consumption', () {
      final result = squirrelParsePT(
        grammarSpec: 'Test <- "a" !"b" "c" ;',
        topRuleName: 'Test',
        input: 'ac',
      );

      expect(result.root, isNotNull);
      expect(result.root.len, equals(2)); // 'a' and 'c' consumed
    });

    test('identifier parser with lookahead - valid', () {
      // Parse identifiers that don't start with a digit
      final result = squirrelParsePT(
        grammarSpec: r'''
          Identifier <- ![0-9] [a-zA-Z0-9_]+ ;
        ''',
        topRuleName: 'Identifier',
        input: 'abc123',
      );

      expect(result.root, isNotNull);
      expect(result.root.len, equals(6));
    });

    test('identifier parser with lookahead - invalid starts with digit', () {
      // Parse identifiers that don't start with a digit
      final result = squirrelParsePT(
        grammarSpec: r'''
          Identifier <- ![0-9] [a-zA-Z0-9_]+ ;
        ''',
        topRuleName: 'Identifier',
        input: '123abc',
      );

      // With error recovery, this may recover by skipping digits, so check for errors
      expect(result.hasSyntaxErrors, isTrue); // Starts with digit, should have errors
    });

    test('keyword vs identifier with lookahead', () {
      // Parse 'if' only when not followed by alphanumeric (i.e., as keyword)
      const grammar = r'''
        Keyword <- "if" ![a-zA-Z0-9_] ;
      ''';

      // Valid keyword (all input consumed)
      var result = squirrelParsePT(
        grammarSpec: grammar,
        topRuleName: 'Keyword',
        input: 'if',
      );
      expect(result.root, isNotNull); // 'if' as keyword
      expect(result.root.len, equals(2));

      // Invalid - 'ifx' is not just 'if'
      result = squirrelParsePT(
        grammarSpec: grammar,
        topRuleName: 'Keyword',
        input: 'ifx',
      );
      // Total failure: result is SyntaxError spanning entire input
      expect(result.root is SyntaxError, isTrue);
    });

    test('comment parser with lookahead', () {
      // Parse // style comments until end of line
      final result = squirrelParsePT(
        grammarSpec: r'''
          Comment <- "//" (!'\n' .)* '\n' ;
        ''',
        topRuleName: 'Comment',
        input: '//hello world\n',
      );

      expect(result.root, isNotNull);
      expect(result.root.len, equals(14)); // All input consumed
    });

    test('string literal parser with lookahead', () {
      // Parse string literals with escape sequences
      const grammar = r'''
        String <- '"' ("\\" . / !'"' .)* '"' ;
      ''';

      var result = squirrelParsePT(
        grammarSpec: grammar,
        topRuleName: 'String',
        input: '"hello"',
      );
      expect(result.root, isNotNull);

      result = squirrelParsePT(
        grammarSpec: grammar,
        topRuleName: 'String',
        input: '"hello\\"world"',
      );
      expect(result.root, isNotNull);
    });
  });
}
