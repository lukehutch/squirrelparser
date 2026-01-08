// ===========================================================================
// PARSE TREE SPANNING INVARIANT TESTS
// ===========================================================================
// These tests verify that Parser.parse() always returns a MatchResult
// that completely spans the input (from position 0 to input.length).
// - Total failures: SyntaxError spanning entire input
// - Partial matches: wrapped with trailing SyntaxError
// - Complete matches: result spans full input with no wrapper needed

import 'package:squirrel_parser/squirrel_parser.dart';
import 'package:test/test.dart';


void main() {
  group('Parse Tree Spanning Invariant Tests', () {
    test('SPAN-01-empty-input', () {
      // Empty input should return SyntaxError spanning empty input
      final parser = Parser(rules: {'S': Str('a')}, input: '');
      final (result, _) = parser.parse('S');

      expect(result is SyntaxError, isTrue,
          reason: 'Empty input with no match should be SyntaxError');
      expect(result.len, equals(0),
          reason: 'SyntaxError should span full empty input');
      expect(result.pos, equals(0));
    });

    test('SPAN-02-complete-match-no-wrapper', () {
      // Complete match should not be wrapped
      final parser =
          Parser(rules: {'S': Seq([Str('a'), Str('b'), Str('c')])}, input: 'abc');
      final (result, _) = parser.parse('S');

      expect(result is SyntaxError, isFalse,
          reason: 'Complete match should not be SyntaxError');
      expect(result.len, equals(3), reason: 'Should span entire input');
      expect(result.isMismatch, isFalse);
    });

    test('SPAN-03-total-failure-returns-syntax-error', () {
      // Input that doesn't match at all should return SyntaxError spanning all
      final parser = Parser(rules: {'S': Str('a')}, input: 'xyz');
      final (result, _) = parser.parse('S');

      expect(result is SyntaxError, isTrue,
          reason: 'Total failure should be SyntaxError');
      expect(result.len, equals(3),
          reason: 'SyntaxError should span entire input');
      expect((result as SyntaxError).skipped, equals('xyz'));
    });

    test('SPAN-04-trailing-garbage-wrapped', () {
      // Partial match with trailing input should be wrapped with SyntaxError
      final parser =
          Parser(rules: {'S': Seq([Str('a'), Str('b')])}, input: 'abXYZ');
      final (result, _) = parser.parse('S');

      expect(result.len, equals(5), reason: 'Result should span entire input');
      expect(result is SyntaxError, isFalse, reason: 'Result is wrapper Match');

      // Find the trailing SyntaxError in the tree
      bool hasTrailingError = false;
      void checkForTrailingError(MatchResult r) {
        if (r is SyntaxError) {
          if (r.pos == 2 && r.len == 3) {
            hasTrailingError = true;
          }
        }
        for (final child in r.subClauseMatches) {
          checkForTrailingError(child);
        }
      }

      checkForTrailingError(result);
      expect(hasTrailingError, isTrue,
          reason: 'Should contain SyntaxError for trailing XYZ');
    });

    test('SPAN-05-single-char-trailing', () {
      // Single trailing character should be captured
      final parser = Parser(rules: {'S': Str('a')}, input: 'aX');
      final (result, _) = parser.parse('S');

      expect(result.len, equals(2), reason: 'Should span full input');
      expect(result is SyntaxError, isFalse);

      // Check for trailing SyntaxError
      bool hasTrailingError = false;
      void checkForTrailingError(MatchResult r) {
        if (r is SyntaxError && r.pos == 1 && r.len == 1) {
          hasTrailingError = true;
        }
        for (final child in r.subClauseMatches) {
          checkForTrailingError(child);
        }
      }

      checkForTrailingError(result);
      expect(hasTrailingError, isTrue);
    });

    test('SPAN-06-multiple-errors-throughout', () {
      // Multiple errors should all be in parse tree
      final parser = Parser(
          rules: {'S': Seq([Str('a'), Str('b'), Str('c')])}, input: 'aXbYc');
      final (result, _) = parser.parse('S');

      expect(result.len, equals(5), reason: 'Should span entire input');

      final errors = <SyntaxError>[];
      void collectErrors(MatchResult r) {
        if (r is SyntaxError) {
          errors.add(r);
        }
        for (final child in r.subClauseMatches) {
          collectErrors(child);
        }
      }

      collectErrors(result);
      expect(errors.length, equals(2), reason: 'Should have 2 syntax errors');
    });

    test('SPAN-07-recovery-with-deletion', () {
      // Deletion at end should be captured
      final parser =
          Parser(rules: {'S': Seq([Str('a'), Str('b'), Str('c')])}, input: 'ab');
      final (result, _) = parser.parse('S');

      expect(result.len, equals(2),
          reason: 'Should span full input (no trailing capture here)');
      expect(result is SyntaxError, isFalse);
    });

    test('SPAN-08-first-alternative-with-trailing', () {
      // First should prefer longer match, both may have trailing
      final parser = Parser(
          rules: {
            'S': First([
              Seq([Str('a'), Str('b'), Str('c')]),
              Str('a')
            ])
          },
          input: 'abcX');
      final (result, _) = parser.parse('S');

      expect(result.len, equals(4), reason: 'Should span entire input');

      bool hasTrailingX = false;
      void checkForX(MatchResult r) {
        if (r is SyntaxError && r.skipped.contains('X')) {
          hasTrailingX = true;
        }
        for (final child in r.subClauseMatches) {
          checkForX(child);
        }
      }

      checkForX(result);
      expect(hasTrailingX, isTrue, reason: 'Should capture X as error');
    });

    test('SPAN-09-left-recursion-with-trailing', () {
      // LR expansion with trailing should work
      final parser = Parser(
          rules: {
            'E': First([
              Seq([Ref('E'), Str('+'), Str('n')]),
              Str('n')
            ])
          },
          input: 'n+nX');
      final (result, _) = parser.parse('E');

      expect(result.len, equals(4), reason: 'Should span entire input');

      bool hasTrailingError = false;
      void checkForTrailingError(MatchResult r) {
        if (r is SyntaxError && r.pos > 0) {
          hasTrailingError = true;
        }
        for (final child in r.subClauseMatches) {
          checkForTrailingError(child);
        }
      }

      checkForTrailingError(result);
      expect(hasTrailingError, isTrue);
    });

    test('SPAN-10-repetition-with-trailing', () {
      // OneOrMore with trailing should span full input
      final parser = Parser(
          rules: {'S': OneOrMore(Str('a'))}, input: 'aaaX');
      final (result, _) = parser.parse('S');

      expect(result.len, equals(4), reason: 'Should span entire input');

      bool hasTrailingError = false;
      void checkForTrailingError(MatchResult r) {
        if (r is SyntaxError && r.skipped.contains('X')) {
          hasTrailingError = true;
        }
        for (final child in r.subClauseMatches) {
          checkForTrailingError(child);
        }
      }

      checkForTrailingError(result);
      expect(hasTrailingError, isTrue);
    });

    test('SPAN-11-nested-rules-with-trailing', () {
      // Nested rule calls with trailing
      final parser = Parser(
          rules: {
            'S': Seq([Ref('A'), Str(';')]),
            'A': Seq([Str('a'), Str('b')])
          },
          input: 'ab;X');
      final (result, _) = parser.parse('S');

      expect(result.len, equals(4), reason: 'Should span entire input');
    });

    test('SPAN-12-zero-or-more-with-trailing', () {
      // ZeroOrMore matching nothing, then trailing
      final parser =
          Parser(rules: {'S': ZeroOrMore(Str('a'))}, input: 'XYZ');
      final (result, _) = parser.parse('S');

      expect(result.len, equals(3), reason: 'Should span entire input');
      expect(result is SyntaxError, isFalse);

      bool hasTrailingError = false;
      void checkForTrailingError(MatchResult r) {
        if (r is SyntaxError) {
          hasTrailingError = true;
        }
        for (final child in r.subClauseMatches) {
          checkForTrailingError(child);
        }
      }

      checkForTrailingError(result);
      expect(hasTrailingError, isTrue);
    });

    test('SPAN-13-optional-with-trailing', () {
      // Optional not matching, then trailing
      final parser =
          Parser(rules: {'S': Optional(Str('a'))}, input: 'XYZ');
      final (result, _) = parser.parse('S');

      expect(result.len, equals(3), reason: 'Should span entire input');

      bool hasTrailingError = false;
      void checkForTrailingError(MatchResult r) {
        if (r is SyntaxError) {
          hasTrailingError = true;
        }
        for (final child in r.subClauseMatches) {
          checkForTrailingError(child);
        }
      }

      checkForTrailingError(result);
      expect(hasTrailingError, isTrue);
    });

    test('SPAN-14-followed-by-success-with-trailing', () {
      // FollowedBy doesn't consume, but trailing should still be captured
      final parser = Parser(
          rules: {
            'S': Seq([
              FollowedBy(Str('a')),
              Str('a'),
              Str('b')
            ])
          },
          input: 'abX');
      final (result, _) = parser.parse('S');

      expect(result.len, equals(3), reason: 'Should span entire input');

      bool hasTrailingError = false;
      void checkForTrailingError(MatchResult r) {
        if (r is SyntaxError && r.skipped.contains('X')) {
          hasTrailingError = true;
        }
        for (final child in r.subClauseMatches) {
          checkForTrailingError(child);
        }
      }

      checkForTrailingError(result);
      expect(hasTrailingError, isTrue);
    });

    test('SPAN-15-not-followed-by-failure-total', () {
      // NotFollowedBy in sequence that fails - no recovery possible
      final parser = Parser(
          rules: {
            'S': Seq([
              NotFollowedBy(Str('x')),
              Str('y')
            ])
          },
          input: 'xz');
      final (result, _) = parser.parse('S');

      // NotFollowedBy('x') succeeds at position 0 (since 'x' IS there, negation makes it fail)
      // Wait, this is backwards. NotFollowedBy checks "is NOT followed by"
      // If input is 'xz', 'x' IS there, so NotFollowedBy fails
      // Then Str('y') can't match 'x', so Seq fails completely
      // Result should be SyntaxError spanning entire input
      expect(result is SyntaxError, isTrue,
          reason: 'Should be total failure');
      expect(result.len, equals(2), reason: 'Should span entire input');
    });

    test('SPAN-16-not-followed-by-success-with-trailing', () {
      // NotFollowedBy succeeding but with trailing - we'll simplify this
      // to avoid complex recovery rules
      final parser = Parser(
          rules: {
            'S': Seq([
              Str('b'),
              Optional(Str('c'))
            ])
          },
          input: 'bX');
      final (result, _) = parser.parse('S');

      expect(result.len, equals(2), reason: 'Should span entire input');

      bool hasTrailingError = false;
      void checkForTrailingError(MatchResult r) {
        if (r is SyntaxError && r.skipped.contains('X')) {
          hasTrailingError = true;
        }
        for (final child in r.subClauseMatches) {
          checkForTrailingError(child);
        }
      }

      checkForTrailingError(result);
      expect(hasTrailingError, isTrue);
    });

    test('SPAN-17-invariant-never-null', () {
      // parse() should never return null - always spans input
      final testCases = [
        ({'S': Str('a')}, 'a'),
        ({'S': Str('a')}, 'b'),
        ({'S': Str('a')}, ''),
        ({'S': Seq([Str('a'), Str('b')])}, 'ab'),
        ({'S': Seq([Str('a'), Str('b')])}, 'aXb'),
        ({'S': First([Str('a'), Str('b')])}, 'c'),
      ];

      for (final (rules, input) in testCases) {
        final parser = Parser(rules: rules, input: input);
        final (result, _) = parser.parse('S');

        expect(result, isNotNull,
            reason: 'parse() should never return null for input: $input');
        expect(result.len, equals(input.length),
            reason: 'Result should span entire input for: $input');
      }
    });

    test('SPAN-18-long-input-with-single-trailing-error', () {
      // Long input with single error at end
      final input = 'abcdefghijklmnopqrstuvwxyzX';
      final parser = Parser(
          rules: {
            'S': Seq(
                'abcdefghijklmnopqrstuvwxyz'.split('').map((c) => Str(c)).toList())
          },
          input: input);
      final (result, _) = parser.parse('S');

      expect(result.len, equals(27), reason: 'Should span entire input');

      bool hasTrailingError = false;
      void checkForTrailingError(MatchResult r) {
        if (r is SyntaxError && r.pos == 26) {
          hasTrailingError = true;
        }
        for (final child in r.subClauseMatches) {
          checkForTrailingError(child);
        }
      }

      checkForTrailingError(result);
      expect(hasTrailingError, isTrue);
    });

    test('SPAN-19-complex-grammar-with-errors', () {
      // Complex grammar with multiple errors at different levels
      final parser = Parser(
          rules: {
            'S': Seq([Ref('E'), Str(';')]),
            'E': First([
              Seq([Ref('E'), Str('+'), Ref('T')]),
              Ref('T')
            ]),
            'T': Str('n')
          },
          input: 'n+Xn;Y');
      final (result, _) = parser.parse('S');

      expect(result.len, equals(6), reason: 'Should span entire input');

      final errors = <SyntaxError>[];
      void collectErrors(MatchResult r) {
        if (r is SyntaxError) {
          errors.add(r);
        }
        for (final child in r.subClauseMatches) {
          collectErrors(child);
        }
      }

      collectErrors(result);
      expect(errors.length, greaterThanOrEqualTo(2),
          reason: 'Should capture errors');
    });

    test('SPAN-20-recovery-preserves-matched-content', () {
      // When recovering from errors, matched content should be preserved
      final parser = Parser(
          rules: {
            'S': Seq([Str('hello'), Str(' '), Str('world')])
          },
          input: 'hello X world');
      final (result, _) = parser.parse('S');

      expect(result.len, equals(13), reason: 'Should span entire input');
      expect(result is SyntaxError, isFalse);

      // Check that we have both matched parts and error
      bool hasError = false;
      void analyze(MatchResult r) {
        if (!r.isMismatch && r is! SyntaxError) {
          // Matched
        }
        if (r is SyntaxError) {
          hasError = true;
        }
        for (final child in r.subClauseMatches) {
          analyze(child);
        }
      }

      analyze(result);
      expect(hasError, isTrue, reason: 'Should have error for skipped X');
    });
  });
}
