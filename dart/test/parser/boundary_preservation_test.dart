// ===========================================================================
// BOUNDARY PRESERVATION TESTS
// ===========================================================================
// These tests verify that recovery doesn't consume content meant for
// subsequent grammar elements (preserve structural boundaries).

import 'package:test/test.dart';

import '../test_utils.dart';

void main() {
  group('Boundary Preservation Tests', () {
    test('BND-01-dont-consume-next-terminal', () {
      // Recovery should skip 'X' but not consume 'b' (needed by next element)
      final (ok, err, skip) = testParse('S <- "a" "b" ;', 'aXb');
      expect(ok, isTrue, reason: 'should succeed');
      expect(err, equals(1), reason: 'should have 1 error');
      expect(skip.contains('X'), isTrue, reason: 'should skip X');
      // Verify 'b' was matched by second element, not consumed during recovery
    });

    test('BND-02-dont-partially-consume-next-terminal', () {
      // Multi-char terminals are atomic - recovery can't consume part of 'cd'
      final (ok, err, skip) = testParse('S <- "ab" "cd" ;', 'abXcd');
      expect(ok, isTrue, reason: 'should succeed');
      expect(err, equals(1), reason: 'should have 1 error');
      expect(skip.contains('X'), isTrue, reason: 'should skip X');
      // 'cd' should be matched atomically by second element
    });

    test('BND-03-recovery-in-first-doesnt-poison-alternatives', () {
      // First alternative fails cleanly, second succeeds
      final (ok, err, _) = testParse('S <- "a" "b" / "c" "d" ;', 'cd');
      expect(ok, isTrue, reason: 'should succeed (second alternative)');
      expect(err, equals(0), reason: 'should have 0 errors (clean match)');
    });

    test('BND-04-first-alternative-with-recovery-vs-second-clean', () {
      // First alternative needs recovery, second is clean
      // Should prefer first (longer match, see FIX #2)
      final (ok, err, _) = testParse('S <- "a" "b" "c" / "a" ;', 'aXbc');
      expect(ok, isTrue, reason: 'should succeed');
      // FIX #2: Prefer longer matches over fewer errors
      expect(err, equals(1),
          reason: 'should choose first alternative (longer despite error)');
    });

    test('BND-05-boundary-with-nested-repetition', () {
      // Repetition with bound should stop at delimiter
      final (ok, err, _) = testParse('S <- "x"+ ";" "y"+ ;', 'xxx;yyy');
      expect(ok, isTrue, reason: 'should succeed');
      expect(err, equals(0), reason: 'should have 0 errors');
      // x+ stops at ';', y+ stops at EOF
    });

    test('BND-06-boundary-with-recovery-before-delimiter', () {
      // Recovery happens, but delimiter is preserved
      final (ok, err, skip) = testParse('S <- "x"+ ";" "y"+ ;', 'xxXx;yyy');
      expect(ok, isTrue, reason: 'should succeed');
      expect(err, equals(1), reason: 'should have 1 error');
      expect(skip.contains('X'), isTrue, reason: 'should skip X');
      // ';' should not be consumed during recovery of x+
    });

    test('BND-07-probe-respects-boundaries', () {
      // ZeroOrMore probes ahead to find boundary
      final (ok, err, _) = testParse('S <- "x"* ("y" / "z") ;', 'xxxz');
      expect(ok, isTrue, reason: 'should succeed');
      expect(err, equals(0), reason: 'should have 0 errors');
      // ZeroOrMore should probe, find 'z' matches First, stop before it
    });

    test('BND-08-complex-boundary-nesting', () {
      // Nested sequences with multiple boundaries
      final (ok, err, _) = testParse('S <- ("a"+ "+") ("b"+ "=") ;', 'aaa+bbb=');
      expect(ok, isTrue, reason: 'should succeed');
      expect(err, equals(0), reason: 'should have 0 errors');
      // Each repetition stops at its delimiter
    });

    test('BND-09-boundary-with-eof', () {
      // No explicit boundary - should consume until EOF
      final (ok, err, _) = testParse('S <- "x"+ ;', 'xxxxx');
      expect(ok, isTrue, reason: 'should succeed');
      expect(err, equals(0), reason: 'should have 0 errors');
      // Consumes all x's (no boundary to stop at)
    });

    test('BND-10-recovery-near-boundary', () {
      // Error just before boundary - should not cross boundary
      final (ok, err, skip) = testParse('S <- "x"+ ";" ;', 'xxX;');
      expect(ok, isTrue, reason: 'should succeed');
      expect(err, equals(1), reason: 'should have 1 error');
      expect(skip.contains('X'), isTrue, reason: 'should skip X');
      // ';' should remain for second element
    });
  });
}
