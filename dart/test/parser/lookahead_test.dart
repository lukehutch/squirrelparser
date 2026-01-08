import 'package:squirrel_parser/squirrel_parser.dart';
import 'package:test/test.dart';

void main() {
  group('Lookahead Operators - Direct Matching', () {
    // These tests use matchRule() directly to test the core functionality
    // without the parse() wrapper which expects all input to be consumed

    group('FollowedBy (&)', () {
      test('positive lookahead succeeds when pattern matches', () {
        final rules = {
          'Test': FollowedBy(Str('a')),
        };

        final parser = Parser(rules: rules, input: 'abc');
        final result = parser.matchRule('Test', 0);

        expect(result.isMismatch, isFalse);
        expect(result.len, equals(0)); // Lookahead doesn't consume
      });

      test('positive lookahead fails when pattern does not match', () {
        final rules = {
          'Test': FollowedBy(Str('a')),
        };

        final parser = Parser(rules: rules, input: 'b');
        final result = parser.matchRule('Test', 0);

        expect(result.isMismatch, isTrue);
      });

      test('positive lookahead in sequence', () {
        final rules = {
          'Test': Seq([Str('a'), FollowedBy(Str('b'))]),
        };

        // Should match 'a' and check for 'b', consuming only 'a'
        final parser = Parser(rules: rules, input: 'abc');
        final result = parser.matchRule('Test', 0);

        expect(result.isMismatch, isFalse);
        expect(result.len, equals(1)); // Only 'a' consumed
      });

      test('positive lookahead in sequence - fails when not followed', () {
        final rules = {
          'Test': Seq([Str('a'), FollowedBy(Str('b'))]),
        };

        final parser = Parser(rules: rules, input: 'ac');
        final result = parser.matchRule('Test', 0);

        expect(result.isMismatch, isTrue); // Fails because no 'b' after 'a'
      });

      test('positive lookahead with continuation', () {
        final rules = {
          'Test': Seq([Str('a'), FollowedBy(Str('b')), Str('b')]),
        };

        // Should match 'a', check for 'b', then consume 'b'
        final parser = Parser(rules: rules, input: 'abc');
        final result = parser.matchRule('Test', 0);

        expect(result.isMismatch, isFalse);
        expect(result.len, equals(2)); // 'a' and 'b' consumed
      });

      test('positive lookahead at end of input', () {
        final rules = {
          'Test': Seq([Str('a'), FollowedBy(Str('b'))]),
        };

        final parser = Parser(rules: rules, input: 'a');
        final result = parser.matchRule('Test', 0);

        expect(result.isMismatch, isTrue); // No 'b' to look ahead to
      });

      test('nested positive lookaheads', () {
        final rules = {
          'Test': Seq([
            FollowedBy(FollowedBy(Str('a'))),
            Str('a'),
          ]),
        };

        final parser = Parser(rules: rules, input: 'a');
        final result = parser.matchRule('Test', 0);

        expect(result.isMismatch, isFalse);
        expect(result.len, equals(1));
      });
    });

    group('NotFollowedBy (!)', () {
      test('negative lookahead succeeds when pattern does not match', () {
        final rules = {
          'Test': NotFollowedBy(Str('a')),
        };

        final parser = Parser(rules: rules, input: 'b');
        final result = parser.matchRule('Test', 0);

        expect(result.isMismatch, isFalse);
        expect(result.len, equals(0)); // Lookahead doesn't consume
      });

      test('negative lookahead fails when pattern matches', () {
        final rules = {
          'Test': NotFollowedBy(Str('a')),
        };

        final parser = Parser(rules: rules, input: 'a');
        final result = parser.matchRule('Test', 0);

        expect(result.isMismatch, isTrue);
      });

      test('negative lookahead in sequence', () {
        final rules = {
          'Test': Seq([Str('a'), NotFollowedBy(Str('b'))]),
        };

        // Should match 'a' when NOT followed by 'b'
        final parser = Parser(rules: rules, input: 'ac');
        final result = parser.matchRule('Test', 0);

        expect(result.isMismatch, isFalse);
        expect(result.len, equals(1)); // Only 'a' consumed
      });

      test('negative lookahead in sequence - fails when followed', () {
        final rules = {
          'Test': Seq([Str('a'), NotFollowedBy(Str('b'))]),
        };

        final parser = Parser(rules: rules, input: 'ab');
        final result = parser.matchRule('Test', 0);

        expect(
            result.isMismatch, isTrue); // Fails because 'a' IS followed by 'b'
      });

      test('negative lookahead with continuation', () {
        final rules = {
          'Test': Seq([Str('a'), NotFollowedBy(Str('b')), Str('c')]),
        };

        // Should match 'a', check NOT 'b', then consume 'c'
        final parser = Parser(rules: rules, input: 'ac');
        final result = parser.matchRule('Test', 0);

        expect(result.isMismatch, isFalse);
        expect(result.len, equals(2)); // 'a' and 'c' consumed
      });

      test('negative lookahead at end of input', () {
        final rules = {
          'Test': Seq([Str('a'), NotFollowedBy(Str('b'))]),
        };

        final parser = Parser(rules: rules, input: 'a');
        final result = parser.matchRule('Test', 0);

        expect(result.isMismatch, isFalse); // No 'b' following, so succeeds
        expect(result.len, equals(1));
      });

      test('nested negative lookaheads', () {
        final rules = {
          // !!"a" is the same as &"a"
          'Test': Seq([
            NotFollowedBy(NotFollowedBy(Str('a'))),
            Str('a'),
          ]),
        };

        final parser = Parser(rules: rules, input: 'a');
        final result = parser.matchRule('Test', 0);

        expect(result.isMismatch, isFalse);
        expect(result.len, equals(1));
      });
    });

    group('Mixed Lookaheads', () {
      test('positive then negative lookahead', () {
        final rules = {
          'Test': Seq([
            FollowedBy(CharRange('a', 'z')),
            NotFollowedBy(Str('x')),
            CharRange('a', 'z'),
          ]),
        };

        // Should match any lowercase letter except 'x'
        var parser = Parser(rules: rules, input: 'a');
        var result = parser.matchRule('Test', 0);
        expect(result.isMismatch, isFalse);

        parser = Parser(rules: rules, input: 'x');
        result = parser.matchRule('Test', 0);
        expect(result.isMismatch, isTrue);

        parser = Parser(rules: rules, input: 'A');
        result = parser.matchRule('Test', 0);
        expect(result.isMismatch, isTrue);
      });

      test('lookahead in choice', () {
        final rules = {
          'Test': First([
            Seq([FollowedBy(Str('a')), Str('a')]),
            Seq([FollowedBy(Str('b')), Str('b')]),
          ]),
        };

        var parser = Parser(rules: rules, input: 'a');
        var result = parser.matchRule('Test', 0);
        expect(result.isMismatch, isFalse);
        expect(result.len, equals(1));

        parser = Parser(rules: rules, input: 'b');
        result = parser.matchRule('Test', 0);
        expect(result.isMismatch, isFalse);
        expect(result.len, equals(1));

        parser = Parser(rules: rules, input: 'c');
        result = parser.matchRule('Test', 0);
        expect(result.isMismatch, isTrue);
      });

      test('lookahead with repetition', () {
        final rules = {
          'Test': ZeroOrMore(Seq([
            NotFollowedBy(Str('.')),
            CharRange('a', 'z'),
          ])),
        };

        // Match lowercase letters until '.'
        var parser = Parser(rules: rules, input: 'abc.def');
        var result = parser.matchRule('Test', 0);
        expect(result.isMismatch, isFalse);
        expect(result.len, equals(3)); // 'abc'

        parser = Parser(rules: rules, input: '.abc');
        result = parser.matchRule('Test', 0);
        expect(result.isMismatch, isFalse);
        expect(result.len, equals(0)); // Stops immediately at '.'
      });
    });

    group('Lookahead with References', () {
      test('positive lookahead with rule reference', () {
        final rules = {
          'Digit': CharRange('0', '9'),
          'Test': Seq([
            FollowedBy(Ref('Digit')),
            Ref('Digit'),
          ]),
        };

        final parser = Parser(rules: rules, input: '5');
        final result = parser.matchRule('Test', 0);

        expect(result.isMismatch, isFalse);
        expect(result.len, equals(1));
      });

      test('negative lookahead with rule reference', () {
        final rules = {
          'Digit': CharRange('0', '9'),
          'Test': Seq([
            NotFollowedBy(Ref('Digit')),
            CharRange('a', 'z'),
          ]),
        };

        var parser = Parser(rules: rules, input: 'a');
        var result = parser.matchRule('Test', 0);
        expect(result.isMismatch, isFalse);

        parser = Parser(rules: rules, input: '5');
        result = parser.matchRule('Test', 0);
        expect(result.isMismatch, isTrue);
      });
    });
  });

  group('Lookahead Operators - Integration with parse()', () {
    // These tests use parse() which expects all input to be consumed

    test('lookahead with full input consumption', () {
      final rules = {
        'Test': Seq([Str('a'), FollowedBy(Str('b')), Str('b')]),
      };

      // Should match and consume all input
      final parser = Parser(rules: rules, input: 'ab');
      final (result, _) = parser.parse('Test');

      expect(result, isNotNull);
      expect(result.len, equals(2)); // Both 'a' and 'b' consumed
    });

    test('negative lookahead with full input consumption', () {
      final rules = {
        'Test': Seq([Str('a'), NotFollowedBy(Str('b')), Str('c')]),
      };

      final parser = Parser(rules: rules, input: 'ac');
      final (result, _) = parser.parse('Test');

      expect(result, isNotNull);
      expect(result.len, equals(2)); // 'a' and 'c' consumed
    });

    test('identifier parser with lookahead - valid', () {
      // Parse identifiers that don't start with a digit
      final rules = {
        'Identifier': Seq([
          NotFollowedBy(CharRange('0', '9')),
          OneOrMore(First([
            CharRange('a', 'z'),
            CharRange('A', 'Z'),
            CharRange('0', '9'),
            Char('_'),
          ])),
        ]),
      };

      // Valid identifier (all input consumed)
      var parser = Parser(rules: rules, input: 'abc123');
      var (result, _) = parser.parse('Identifier');
      expect(result, isNotNull);
      expect(result.len, equals(6));
    });

    test('identifier parser with lookahead - using matchRule', () {
      // Parse identifiers that don't start with a digit
      final rules = {
        'Identifier': Seq([
          NotFollowedBy(CharRange('0', '9')),
          OneOrMore(First([
            CharRange('a', 'z'),
            CharRange('A', 'Z'),
            CharRange('0', '9'),
            Char('_'),
          ])),
        ]),
      };

      // Test with matchRule to avoid recovery
      final parser = Parser(rules: rules, input: '123abc');
      final result = parser.matchRule('Identifier', 0);
      expect(result.isMismatch, isTrue); // Starts with digit, should fail
    });

    test('keyword vs identifier with lookahead', () {
      // Parse 'if' only when not followed by alphanumeric (i.e., as keyword)
      final rules = {
        'Keyword': Seq([
          Str('if'),
          NotFollowedBy(First([
            CharRange('a', 'z'),
            CharRange('A', 'Z'),
            CharRange('0', '9'),
            Char('_'),
          ])),
        ]),
      };

      // Valid keyword (all input consumed)
      var parser = Parser(rules: rules, input: 'if');
      var (result, _) = parser.parse('Keyword');
      expect(result, isNotNull); // 'if' as keyword
      expect(result.len, equals(2));

      // Invalid - 'ifx' is not just 'if'
      parser = Parser(rules: rules, input: 'ifx');
      (result, _) = parser.parse('Keyword');
      // Total failure: result is SyntaxError spanning entire input
      expect(result is SyntaxError, isTrue);
    });

    test('comment parser with lookahead', () {
      // Parse // style comments until end of line
      final rules = {
        'Comment': Seq([
          Str('//'),
          ZeroOrMore(Seq([
            NotFollowedBy(Char('\n')),
            AnyChar(),
          ])),
          Char('\n'),
        ]),
      };

      final parser = Parser(rules: rules, input: '//hello world\n');
      final (result, _) = parser.parse('Comment');
      expect(result, isNotNull);
      expect(result.len, equals(14)); // All input consumed
    });

    test('string literal parser with lookahead', () {
      // Parse string literals with escape sequences
      final rules = {
        'String': Seq([
          Char('"'),
          ZeroOrMore(First([
            Seq([Str('\\'), AnyChar()]), // Escape sequence
            Seq([NotFollowedBy(Char('"')), AnyChar()]), // Non-quote char
          ])),
          Char('"'),
        ]),
      };

      var parser = Parser(rules: rules, input: '"hello"');
      var (result, _) = parser.parse('String');
      expect(result, isNotNull);

      parser = Parser(rules: rules, input: '"hello\\"world"');
      (result, _) = parser.parse('String');
      expect(result, isNotNull);
    });
  });
}
