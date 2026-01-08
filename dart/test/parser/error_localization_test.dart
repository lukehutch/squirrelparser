// ===========================================================================
// ERROR LOCALIZATION TESTS (Non-Cascading Verification)
// ===========================================================================
// These tests verify that errors don't cascade - each error is localized
// to its specific location without affecting subsequent parsing.

import 'package:squirrel_parser/squirrel_parser.dart';
import 'package:test/test.dart';

import 'test_utils.dart';

void main() {
  group('Error Localization (Non-Cascading) Tests', () {
    test('CASCADE-01-error-in-first-element-doesnt-affect-second', () {
      // Error in first element, second element parses cleanly
      final (ok, err, skip) = testParse({
        'S': Seq([Str('a'), Str('b'), Str('c')])
      }, 'aXbc');
      expect(ok, isTrue, reason: 'should succeed');
      expect(err, equals(1),
          reason: 'should have exactly 1 error (at position 1)');
      expect(skip.contains('X'), isTrue, reason: 'should skip X');
      // Error localized to position 1, doesn't cascade to 'b' or 'c'
    });

    test('CASCADE-02-error-in-nested-structure', () {
      // Error inside inner Seq, doesn't affect outer Seq
      final (ok, err, skip) = testParse({
        'S': Seq([
          Seq([Str('a'), Str('b')]),
          Str('c')
        ])
      }, 'aXbc');
      expect(ok, isTrue, reason: 'should succeed');
      expect(err, equals(1), reason: 'should have exactly 1 error');
      expect(skip.contains('X'), isTrue, reason: 'should skip X');
      // Error in inner Seq (between 'a' and 'b'), outer Seq continues normally
    });

    test('CASCADE-03-lr-error-doesnt-cascade-to-next-expansion', () {
      // Error in one LR expansion iteration, next iteration clean
      final (ok, err, skip) = testParse({
        'E': First([
          Seq([Ref('E'), Str('+'), Str('n')]),
          Str('n')
        ])
      }, 'n+Xn+n', 'E');
      expect(ok, isTrue, reason: 'should succeed');
      expect(err, equals(1), reason: 'should have exactly 1 error');
      expect(skip.contains('X'), isTrue, reason: 'should skip X');
      // Expansion: n (base), n+[skip X]n, n+Xn+n
      // First '+' clean, second '+' has error, third '+' clean
      // Error localized to second iteration
    });

    test('CASCADE-04-multiple-independent-errors', () {
      // Multiple errors in different parts of parse, all localized
      final (ok, err, skip) = testParse({
        'S': Seq([
          Seq([Str('a'), Str('b')]),
          Seq([Str('c'), Str('d')]),
          Seq([Str('e'), Str('f')])
        ])
      }, 'aXbcYdeZf');
      expect(ok, isTrue, reason: 'should succeed');
      expect(err, equals(3), reason: 'should have 3 independent errors');
      expect(skip.contains('X'), isTrue, reason: 'should skip X');
      expect(skip.contains('Y'), isTrue, reason: 'should skip Y');
      expect(skip.contains('Z'), isTrue, reason: 'should skip Z');
      // Each error localized to its respective Seq
    });

    test('CASCADE-05-error-before-repetition', () {
      // Error before repetition, repetition parses cleanly
      final (ok, err, skip) = testParse({
        'S': Seq([Str('a'), OneOrMore(Str('b'))])
      }, 'aXbbb');
      expect(ok, isTrue, reason: 'should succeed');
      expect(err, equals(1), reason: 'should have 1 error');
      expect(skip.contains('X'), isTrue, reason: 'should skip X');
      // Error at position 1, OneOrMore starts cleanly at position 2
    });

    test('CASCADE-06-error-after-repetition', () {
      // Repetition clean, error after it
      final (ok, err, skip) = testParse({
        'S': Seq([OneOrMore(Str('a')), Str('b')])
      }, 'aaaXb');
      expect(ok, isTrue, reason: 'should succeed');
      expect(err, equals(1), reason: 'should have 1 error');
      expect(skip.contains('X'), isTrue, reason: 'should skip X');
      // OneOrMore matches 3 a's cleanly, then error, then 'b'
    });

    test('CASCADE-07-error-in-first-alternative-doesnt-poison-second', () {
      // First alternative has error, second alternative clean
      final (ok, err, _) = testParse({
        'S': First([
          Seq([Str('a'), Str('b')]),
          Str('c')
        ])
      }, 'c');
      expect(ok, isTrue, reason: 'should succeed');
      expect(err, equals(0),
          reason: 'should have 0 errors (second alternative clean)');
      // First tries and fails, second succeeds cleanly - no cascade
    });

    test('CASCADE-08-recovery-version-increments-correctly', () {
      // Each recovery increments version, ensuring proper cache invalidation
      final (ok, err, _) = testParse({
        'S': Seq([
          Seq([Str('a'), Str('b')]),
          Seq([Str('c'), Str('d')])
        ])
      }, 'aXbcYd');
      expect(ok, isTrue, reason: 'should succeed');
      expect(err, equals(2), reason: 'should have 2 errors');
      // Two recoveries, each increments version, no cache pollution
    });

    test('CASCADE-09-error-at-deeply-nested-level', () {
      // Error very deep in nesting, doesn't affect outer levels
      final (ok, err, skip) = testParse({
        'S': Seq([
          Seq([
            Seq([
              Seq([Str('a'), Str('b')]),
              Str('c')
            ]),
            Str('d')
          ]),
          Str('e')
        ])
      }, 'aXbcde');
      expect(ok, isTrue, reason: 'should succeed');
      expect(err, equals(1), reason: 'should have 1 error at deepest level');
      expect(skip.contains('X'), isTrue, reason: 'should skip X');
      // Error localized despite 4 levels of nesting
    });

    test('CASCADE-10-error-recovery-doesnt-leave-parser-in-bad-state', () {
      // After recovery, parser continues with clean state
      final (ok, err, _) = testParse({
        'S': Seq([
          Seq([Str('a'), Str('b')]),
          Str('c'), // Expects 'c' at position 2
          Seq([Str('d'), Str('e')])
        ])
      }, 'abXcde');
      expect(ok, isTrue, reason: 'should succeed');
      expect(err, equals(1), reason: 'should have 1 error');
      // After skipping X at position 2, matches 'c' at position 3, then 'de'
    });
  });
}
