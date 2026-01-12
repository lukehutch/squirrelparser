// ===========================================================================
// FIRST ALTERNATIVE SELECTION TESTS (FIX #2 Verification)
// ===========================================================================
// These tests verify that First correctly selects alternatives based on
// length priority (longer matches preferred) with error count as tiebreaker.

import 'package:test/test.dart';

import '../test_utils.dart';

void main() {
  group('First Alternative Selection Tests', () {
    test('FIRST-01-all-alternatives-fail-cleanly', () {
      // All alternatives mismatch, no recovery possible
      final (ok, _, _) = testParse('S <- "a" / "b" / "c" ;', 'x');
      expect(ok, isFalse, reason: 'should fail (no alternative matches)');
    });

    test('FIRST-02-first-needs-recovery-second-clean', () {
      // FIX #2: Prefer longer matches, so first alternative wins despite error
      final (ok, err, _) = testParse(
        'S <- "a" "b" / "c" ;',
        'aXb',
      );
      expect(ok, isTrue, reason: 'should succeed');
      expect(err, equals(1),
          reason: 'first alternative chosen (longer despite error)');
    });

    test('FIRST-03-all-alternatives-need-recovery', () {
      // Multiple alternatives with recovery, choose best
      final (ok, err, _) = testParse(
        'S <- "a" "b" "c" / "a" "y" "z" ;',
        'aXbc',
      );
      expect(ok, isTrue, reason: 'should succeed');
      expect(err, equals(1),
          reason: 'should choose first alternative (matches with recovery)');
    });

    test('FIRST-04-longer-with-error-vs-shorter-clean', () {
      // FIX #2: Length priority - longer wins even with error
      final (ok, err, _) = testParse(
        'S <- "a" "b" "c" / "a" ;',
        'aXbc',
      );
      expect(ok, isTrue, reason: 'should succeed');
      expect(err, equals(1),
          reason: 'should choose first (longer despite error)');
    });

    test('FIRST-05-same-length-fewer-errors-wins', () {
      // Same length, fewer errors wins
      final (ok, err, _) = testParse(
        'S <- "a" "b" "c" "d" / "a" "b" "c" ;',
        'aXbc',
      );
      expect(ok, isTrue, reason: 'should succeed');
      expect(err, equals(1), reason: 'should choose second (fewer errors)');
    });

    test('FIRST-06-multiple-clean-alternatives', () {
      // Multiple alternatives match cleanly, first wins
      final (ok, err, _) = testParse(
        'S <- "abc" / "abc" / "ab" ;',
        'abc',
      );
      expect(ok, isTrue, reason: 'should succeed');
      expect(err, equals(0), reason: 'should have 0 errors (clean match)');
      // First alternative wins
    });

    test('FIRST-07-prefer-longer-clean-over-shorter-clean', () {
      // Two clean alternatives, different lengths
      final (ok, err, _) = testParse(
        'S <- "abc" / "ab" ;',
        'abc',
      );
      expect(ok, isTrue, reason: 'should succeed');
      expect(err, equals(0), reason: 'should have 0 errors');
      // First matches full input (len=3), second would match len=2
      // But First tries in order, so first wins anyway
    });

    test('FIRST-08-fallback-after-all-longer-fail', () {
      // Longer alternatives fail, shorter succeeds
      final (ok, err, _) = testParse(
        'S <- "x" "y" "z" / "a" ;',
        'a',
      );
      expect(ok, isTrue, reason: 'should succeed');
      expect(err, equals(0),
          reason: 'should have 0 errors (clean second alternative)');
    });

    test('FIRST-09-left-recursive-alternative', () {
      // First contains left-recursive alternative
      final (ok, err, _) = testParse(
        'E <- E "+" "n" / "n" ;',
        'n+Xn',
        'E',
      );
      expect(ok, isTrue, reason: 'should succeed');
      expect(err, equals(1), reason: 'should have 1 error');
      // LR expansion with recovery
    });

    test('FIRST-10-nested-first', () {
      // First containing another First
      final (ok, err, _) = testParse(
        'S <- ("a" / "b") / "c" ;',
        'b',
      );
      expect(ok, isTrue, reason: 'should succeed');
      expect(err, equals(0), reason: 'should have 0 errors');
      // Outer First tries first alternative (inner First), which matches 'b'
    });

    test('FIRST-11-all-alternatives-incomplete', () {
      // All alternatives incomplete (don't consume full input)
      // With new invariant, best match selected, trailing captured
      final (ok, err, skip) = testParse(
        'S <- "a" / "b" ;',
        'aXXX',
      );
      expect(ok, isTrue, reason: 'should succeed with trailing captured');
      expect(err, equals(1), reason: 'should have 1 error (trailing XXX)');
      expect(skip.contains('XXX'), isTrue, reason: 'should capture XXX');
    });

    test('FIRST-12-recovery-with-complex-alternatives', () {
      // Complex alternatives with nested structures
      final (ok, err, _) = testParse(
        'S <- "x"+ "y" / "a"+ "b" ;',
        'xxxXy',
      );
      expect(ok, isTrue, reason: 'should succeed');
      expect(err, equals(1), reason: 'should choose first alternative');
    });
  });
}
