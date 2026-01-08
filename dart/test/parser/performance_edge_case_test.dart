// ===========================================================================
// PERFORMANCE & EDGE CASE TESTS
// ===========================================================================
// These tests verify performance characteristics and edge cases.

import 'package:squirrel_parser/squirrel_parser.dart';
import 'package:test/test.dart';

import 'test_utils.dart';

void main() {
  group('Performance Tests', () {
    test('PERF-01-very-long-input', () {
      // 10,000 character input should parse in reasonable time
      final input = 'x' * 10000;
      final stopwatch = Stopwatch()..start();
      final (ok, err, _) = testParse({'S': OneOrMore(Str('x'))}, input);
      stopwatch.stop();

      expect(ok, isTrue, reason: 'should succeed');
      expect(err, equals(0), reason: 'should have 0 errors');
      expect(stopwatch.elapsedMilliseconds < 1000, isTrue,
          reason:
              'should complete in less than 1 second (was ${stopwatch.elapsedMilliseconds}ms)');
    });

    test('PERF-02-deep-nesting', () {
      // 50 levels of Seq nesting
      Clause buildDeepSeq(int depth) {
        if (depth == 0) return Str('x');
        return Seq([buildDeepSeq(depth - 1), Str('y')]);
      }

      final grammar = {'S': buildDeepSeq(50)};
      final input = 'x${'y' * 50}';

      final (ok, _, _) = testParse(grammar, input);
      expect(ok, isTrue, reason: 'should handle 50 levels of nesting');
    });

    test('PERF-03-wide-first', () {
      // First with 50 alternatives (using padded numbers to avoid prefix issues)
      final alternatives =
          List.generate(50, (i) => Str('opt_${i.toString().padLeft(3, '0')}'));
      final (ok, _, _) =
          testParse({'S': First(alternatives)}, 'opt_049'); // Last alternative
      expect(ok, isTrue, reason: 'should try all 50 alternatives');
    });

    test('PERF-04-many-repetitions', () {
      // 1000 iterations of OneOrMore
      final input = 'x' * 1000;
      final (ok, _, _) = testParse({'S': OneOrMore(Str('x'))}, input);
      expect(ok, isTrue, reason: 'should handle 1000 repetitions');
    });

    test('PERF-05-many-errors', () {
      // 500 errors in input
      final input = List.generate(500, (i) => 'Xx').join();
      final (ok, err, _) = testParse({'S': OneOrMore(Str('x'))}, input);
      expect(ok, isTrue, reason: 'should succeed');
      expect(err, equals(500), reason: 'should count all 500 errors');
    });

    test('PERF-06-lr-expansion-depth', () {
      // LR with 100 expansions
      final input =
          List.generate(100, (i) => '+n').join().substring(1); // n+n+n+...
      final (ok, _, _) = testParse({
        'E': First([
          Seq([Ref('E'), Str('+'), Str('n')]),
          Str('n')
        ])
      }, input, 'E');
      expect(ok, isTrue, reason: 'should handle 100 LR expansions');
    });

    test('PERF-07-cache-efficiency', () {
      // Same clause at many positions - cache should help
      final input = 'x' * 100;
      final (ok, _, _) =
          testParse({'S': OneOrMore(Ref('X')), 'X': Str('x')}, input);
      expect(ok, isTrue, reason: 'should succeed (cache makes this efficient)');
    });
  });

  group('Edge Case Tests', () {
    test('EDGE-01-empty-input', () {
      // Various grammars with empty input
      final zm = testParse({'S': ZeroOrMore(Str('x'))}, '');
      expect(zm.$1, isTrue, reason: 'ZeroOrMore should succeed on empty');

      final om = testParse({'S': OneOrMore(Str('x'))}, '');
      expect(om.$1, isFalse, reason: 'OneOrMore should fail on empty');

      final opt = testParse({'S': Optional(Str('x'))}, '');
      expect(opt.$1, isTrue, reason: 'Optional should succeed on empty');

      final seq = testParse({'S': Seq([])}, '');
      expect(seq.$1, isTrue, reason: 'empty Seq should succeed on empty');
    });

    test('EDGE-02-input-with-only-errors', () {
      // Input is all garbage
      final (ok, _, _) = testParse({'S': Str('abc')}, 'XYZ');
      expect(ok, isFalse, reason: 'should fail (no valid content)');
    });

    test('EDGE-03-grammar-with-only-optional-zeoormore', () {
      // Grammar that accepts empty: Seq([ZeroOrMore(...), Optional(...)])
      final (ok, err, _) = testParse({
        'S': Seq([ZeroOrMore(Str('x')), Optional(Str('y'))])
      }, '');
      expect(ok, isTrue, reason: 'should succeed (both match empty)');
      expect(err, equals(0), reason: 'should have 0 errors');
    });

    test('EDGE-04-single-char-terminals', () {
      // All single-character terminals
      final (ok, err, _) = testParse({
        'S': Seq([Str('a'), Str('b'), Str('c')])
      }, 'abc');
      expect(ok, isTrue, reason: 'should succeed');
      expect(err, equals(0), reason: 'should have 0 errors');
    });

    test('EDGE-05-very-long-terminal', () {
      // Multi-hundred-char terminal
      final longStr = 'x' * 500;
      final (ok, _, _) = testParse({'S': Str(longStr)}, longStr);
      expect(ok, isTrue, reason: 'should match very long terminal');
    });

    test('EDGE-06-unicode-handling', () {
      // Unicode characters in terminals and input
      final (ok, err, _) = testParse({
        'S': Seq([Str('こんにちは'), Str('世界')])
      }, 'こんにちは世界');
      expect(ok, isTrue, reason: 'should handle Unicode');
      expect(err, equals(0), reason: 'should have 0 errors');
    });

    test('EDGE-07-mixed-unicode-and-ascii', () {
      // Mix of Unicode and ASCII with errors
      final (ok, err, skip) = testParse({
        'S': Seq([Str('hello'), Str('世界')])
      }, 'helloX世界');
      expect(ok, isTrue, reason: 'should succeed');
      expect(err, equals(1), reason: 'should have 1 error');
      expect(skip.contains('X'), isTrue, reason: 'should skip X');
    });

    test('EDGE-08-newlines-and-whitespace', () {
      // Newlines and whitespace as errors
      final (ok, err, _) = testParse({
        'S': Seq([Str('a'), Str('b')])
      }, 'a\n\tb');
      expect(ok, isTrue, reason: 'should succeed');
      expect(err, equals(1), reason: 'should have 1 error (newline+tab)');
    });

    test('EDGE-09-eof-at-various-positions', () {
      // EOF at different points in grammar
      final cases = [
        ('ab', 2), // EOF after full match
        ('a', 1), // EOF after partial match
        ('', 0), // EOF at start
      ];

      for (final (input, _) in cases) {
        final parser = Parser(
          rules: {
            'S': Seq([Str('a'), Str('b')])
          },
          input: input,
        );
        final (result, _) = parser.parse('S');
        expect(result is! SyntaxError || input.isEmpty, isTrue,
            reason: 'result should exist or input empty for "$input"');
      }
    });

    test('EDGE-10-recovery-with-moderate-skip', () {
      // Recovery with moderate skip distance
      final (ok, err, skip) = testParse({
        'S': Seq([Str('a'), Str('b'), Str('c')]),
      }, 'aXXXXXXXXXbc');
      expect(ok, isTrue, reason: 'should succeed (skip to find b)');
      expect(err, equals(1), reason: 'should have 1 error (skip region)');
      expect(skip[0].length, greaterThan(5),
          reason: 'should skip multiple chars');
    });

    test('EDGE-11-alternating-success-failure', () {
      // Pattern that alternates between success and failure
      final (ok, err, _) = testParse({
        'S': OneOrMore(Seq([Str('a'), Str('b')]))
      }, 'abXabYabZab');
      expect(ok, isTrue, reason: 'should succeed');
      expect(err, equals(3), reason: 'should have 3 errors');
    });

    test('EDGE-12-boundary-at-every-position', () {
      // Multiple sequences with delimiters
      final (ok, _, _) = testParse({
        'S': Seq([
          OneOrMore(Str('a')),
          Str(','),
          OneOrMore(Str('b')),
          Str(','),
          OneOrMore(Str('c'))
        ])
      }, 'aaa,bbb,ccc');
      expect(ok, isTrue, reason: 'should succeed (multiple boundaries)');
    });

    test('EDGE-13-no-grammar-rules', () {
      // Empty grammar (edge case that should fail gracefully)
      final parser = Parser(rules: {}, input: 'x');
      expect(() => parser.parse('NonExistent'), throwsA(isA<Error>()),
          reason: 'should throw error for non-existent rule');
    });

    test('EDGE-14-circular-ref-with-base-case', () {
      // A → A | 'x' (left-recursive with base case)
      // Should work correctly with LR detection
      final parser = Parser(
        rules: {
          'A': First([
            Seq([Ref('A'), Str('y')]),
            Str('x')
          ])
        },
        input: 'xy',
      );
      final (result, _) = parser.parse('A');
      // LR detection should handle this correctly
      expect(!result.isMismatch, isTrue,
          reason: 'left-recursive with base case should work');
    });

    test('EDGE-15-all-printable-ascii', () {
      // Test all printable ASCII characters
      final ascii =
          String.fromCharCodes(List.generate(95, (i) => i + 32) // ASCII 32-126
              );
      final (ok, _, _) = testParse({'S': Str(ascii)}, ascii);
      expect(ok, isTrue, reason: 'should handle all printable ASCII');
    });
  });
}
