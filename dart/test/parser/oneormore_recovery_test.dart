// ===========================================================================
// ONEORMORE FIRST-ITERATION RECOVERY TESTS (FIX #10 Verification)
// ===========================================================================
// These tests verify that OneOrMore allows recovery on the first iteration
// while still maintaining "at least one match" semantics.

import 'package:test/test.dart';

import '../test_utils.dart';

void main() {
  group('OneOrMore First-Iteration Recovery Tests', () {
    test('OM-01-first-clean', () {
      // Baseline: First iteration succeeds cleanly
      final (ok, err, _) = testParse('S <- "ab"+ ;', 'ababab');
      expect(ok, isTrue, reason: 'should succeed');
      expect(err, equals(0), reason: 'should have 0 errors');
    });

    test('OM-02-no-match-anywhere', () {
      // OneOrMore still requires at least one match
      final (ok, _, _) = testParse('S <- "ab"+ ;', 'xyz');
      expect(ok, isFalse, reason: 'should fail (no match found)');
    });

    test('OM-03-skip-to-first-match', () {
      // FIX #10: Skip garbage to find first match
      final (ok, err, skip) = testParse('S <- "ab"+ ;', 'Xab');
      expect(ok, isTrue, reason: 'should succeed (skip X on first iteration)');
      expect(err, equals(1), reason: 'should have 1 error');
      expect(skip.contains('X'), isTrue, reason: 'should skip X');
    });

    test('OM-04-skip-multiple-to-first', () {
      // FIX #10: Skip multiple characters to find first match
      final (ok, err, skip) = testParse('S <- "ab"+ ;', 'XXXXXab');
      expect(ok, isTrue, reason: 'should succeed');
      expect(err, equals(1), reason: 'should have 1 error (entire skip)');
      expect(skip.contains('XXXXX'), isTrue, reason: 'should skip XXXXX');
    });

    test('OM-05-multiple-iterations-with-errors', () {
      // FIX #10: First iteration with error, then more iterations with errors
      final (ok, err, skip) = testParse('S <- "ab"+ ;', 'XabYabZab');
      expect(ok, isTrue, reason: 'should succeed');
      expect(err, equals(3), reason: 'should have 3 errors');
      expect(skip.contains('X'), isTrue, reason: 'should skip X');
      expect(skip.contains('Y'), isTrue, reason: 'should skip Y');
      expect(skip.contains('Z'), isTrue, reason: 'should skip Z');
    });

    test('OM-06-first-with-error-then-clean', () {
      // First iteration skips error, subsequent iterations clean
      final (ok, err, skip) = testParse('S <- "ab"+ ;', 'Xabababab');
      expect(ok, isTrue, reason: 'should succeed');
      expect(err, equals(1), reason: 'should have 1 error (only X)');
      expect(skip.contains('X'), isTrue, reason: 'should skip X');
    });

    test('OM-07-vs-zeoormore-semantics', () {
      // BOTH ZeroOrMore and OneOrMore fail on input with no matches
      // because parseWithRecovery requires parsing the ENTIRE input.
      // ZeroOrMore matches 0 times (len=0), leaving "XYZ" unparsed.
      // OneOrMore matches 0 times (fails "at least one"), also leaving input unparsed.

      // Key difference: Empty input
      final zrEmpty = testParse('S <- "ab"* ;', '');
      expect(zrEmpty.$1, isTrue,
          reason: 'ZeroOrMore should succeed on empty input');
      expect(zrEmpty.$2, equals(0), reason: 'should have 0 errors');

      final orEmpty = testParse('S <- "ab"+ ;', '');
      expect(orEmpty.$1, isFalse,
          reason: 'OneOrMore should fail on empty input');

      // Key difference: With valid matches
      final zrMatch = testParse('S <- "ab"* ;', 'ababab');
      expect(zrMatch.$1, isTrue, reason: 'ZeroOrMore succeeds with matches');

      final orMatch = testParse('S <- "ab"+ ;', 'ababab');
      expect(orMatch.$1, isTrue, reason: 'OneOrMore succeeds with matches');
    });

    test('OM-08-long-skip-performance', () {
      // Large skip distance should still complete quickly
      final input = 'X' * 100 + 'ab';
      final (ok, err, skip) = testParse('S <- "ab"+ ;', input);
      expect(ok, isTrue, reason: 'should succeed (performance test)');
      expect(err, equals(1), reason: 'should have 1 error');
      expect(skip[0].length, equals(100), reason: 'should skip 100 X\'s');
    });

    test('OM-09-exhaustive-search-no-match', () {
      // Try all positions, find nothing, fail cleanly
      final input = 'X' * 50 + 'Y' * 50; // No 'ab' anywhere
      final (ok, _, _) = testParse('S <- "ab"+ ;', input);
      expect(ok, isFalse,
          reason: 'should fail (exhaustive search finds nothing)');
    });

    test('OM-10-first-iteration-with-bound', () {
      // First iteration recovery + bound checking
      final (ok, err, skip) = testParse('S <- "ab"+ "end" ;', 'XabYabend');
      expect(ok, isTrue, reason: 'should succeed');
      expect(err, equals(2), reason: 'should have 2 errors (X and Y)');
      expect(skip.contains('X'), isTrue, reason: 'should skip X');
      expect(skip.contains('Y'), isTrue, reason: 'should skip Y');
    });

    test('OM-11-alternating-pattern', () {
      // Pattern: error, match, error, match, ...
      final (ok, err, _) = testParse('S <- "ab"+ ;', 'XabXabXabXab');
      expect(ok, isTrue, reason: 'should succeed');
      expect(err, equals(4), reason: 'should have 4 errors (4 X\'s)');
    });

    test('OM-12-multi-char-terminal-first', () {
      // Multi-character terminal with first-iteration recovery
      final (ok, err, skip) = testParse('S <- "hello"+ ;', 'XXXhellohello');
      expect(ok, isTrue, reason: 'should succeed');
      expect(err, equals(1), reason: 'should have 1 error');
      expect(skip.contains('XXX'), isTrue, reason: 'should skip XXX');
    });
  });
}
