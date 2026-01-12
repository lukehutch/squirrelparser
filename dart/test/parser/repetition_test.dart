// ===========================================================================
// SECTION 6: REPETITION COMPREHENSIVE (25 tests)
// ===========================================================================

import 'package:test/test.dart';

import '../test_utils.dart';

void main() {
  test('R01-between', () {
    final (ok, err, skip) = testParse('S <- "ab"+ ;', 'abXXab');
    expect(ok, isTrue, reason: 'should succeed');
    expect(err, equals(1), reason: 'should have 1 error');
    expect(skip.contains('XX'), isTrue, reason: 'should skip XX');
  });

  test('R02-multi', () {
    final (ok, err, skip) = testParse('S <- "ab"+ ;', 'abXabYab');
    expect(ok, isTrue, reason: 'should succeed');
    expect(err, equals(2), reason: 'should have 2 errors');
    expect(skip.contains('X') && skip.contains('Y'), isTrue,
        reason: 'should skip X and Y');
  });

  test('R03-long skip', () {
    final (ok, err, _) = testParse('S <- "ab"+ ;', 'ab${'X' * 50}ab');
    expect(ok, isTrue, reason: 'should succeed');
    expect(err, equals(1), reason: 'should have 1 error');
  });

  test('R04-ZeroOrMore start', () {
    final (ok, err, skip) = testParse('S <- "ab"* "!" ;', 'XXab!');
    expect(ok, isTrue, reason: 'should succeed');
    expect(err, equals(1), reason: 'should have 1 error');
    expect(skip.contains('XX'), isTrue, reason: 'should skip XX');
  });

  test('R05-before first', () {
    // FIX #10: OneOrMore now allows first-iteration recovery
    final (ok, err, skip) = testParse('S <- "ab"+ ;', 'XXab');
    expect(ok, isTrue, reason: 'should succeed (skip XX on first iteration)');
    expect(err, equals(1), reason: 'should have 1 error');
    expect(skip.contains('XX'), isTrue, reason: 'should skip XX');
  });

  test('R06-trailing captured', () {
    // With new invariant, trailing errors are captured in parse tree
    final (ok, err, skip) = testParse('S <- "ab"+ ;', 'ababXX');
    expect(ok, isTrue, reason: 'should succeed with trailing captured');
    expect(err, equals(1), reason: 'should have 1 error (trailing XX)');
    expect(skip.contains('XX'), isTrue, reason: 'should skip XX');
  });

  test('R07-single', () {
    final (ok, err, _) = testParse('S <- "ab"+ ;', 'ab');
    expect(ok, isTrue, reason: 'should succeed');
    expect(err, equals(0), reason: 'should have 0 errors');
  });

  test('R08-ZeroOrMore empty', () {
    final (ok, err, _) = testParse('S <- "ab"* ;', '');
    expect(ok, isTrue, reason: 'should succeed');
    expect(err, equals(0), reason: 'should have 0 errors');
  });

  test('R09-alternating', () {
    final (ok, err, _) = testParse('S <- "ab"+ ;', 'abXabXabXab');
    expect(ok, isTrue, reason: 'should succeed');
    expect(err, equals(3), reason: 'should have 3 errors');
  });

  test('R10-long clean', () {
    final (ok, err, _) = testParse('S <- "x"+ ;', 'x' * 100);
    expect(ok, isTrue, reason: 'should succeed');
    expect(err, equals(0), reason: 'should have 0 errors');
  });

  test('R11-long err', () {
    final (ok, err, skip) =
        testParse('S <- "x"+ ;', '${'x' * 50}Z${'x' * 49}');
    expect(ok, isTrue, reason: 'should succeed');
    expect(err, equals(1), reason: 'should have 1 error');
    expect(skip.contains('Z'), isTrue, reason: 'should skip Z');
  });

  test('R12-20 errors', () {
    final input = '${List.generate(20, (_) => 'abZ').join()}ab';
    final (ok, err, _) = testParse('S <- "ab"+ ;', input);
    expect(ok, isTrue, reason: 'should succeed');
    expect(err, equals(20), reason: 'should have 20 errors');
  });

  test('R13-very long', () {
    final (ok, err, _) = testParse('S <- "ab"+ ;', 'ab' * 500);
    expect(ok, isTrue, reason: 'should succeed');
    expect(err, equals(0), reason: 'should have 0 errors');
  });

  test('R14-very long err', () {
    final (ok, err, _) =
        testParse('S <- "ab"+ ;', '${'ab' * 250}ZZ${'ab' * 249}');
    expect(ok, isTrue, reason: 'should succeed');
    expect(err, equals(1), reason: 'should have 1 error');
  });

  // Tests for trailing error recovery (Issue: abxbxax failing completely)
  // These tests ensure that after recovering from errors in the middle,
  // the parser also captures trailing unmatched input as errors.

  test('R15-trailing single char after recovery', () {
    // After recovering from middle errors, trailing 'x' should also be caught as error
    final (ok, err, skip) = testParse('''
      S <- A ;
      A <- ("a" / "b")+ ;
    ''', 'abxbxax');
    expect(ok, isTrue, reason: 'should succeed with recovery');
    expect(err, equals(3),
        reason: 'should have 3 errors (x at positions 2, 4, 6)');
    expect(skip.length, equals(3), reason: 'should skip 3 chars total');
  });

  test('R16-trailing multiple chars after recovery', () {
    // Multiple trailing errors after recovery
    final (ok, err, skip) = testParse('S <- "ab"+ ;', 'abXabXabXX');
    expect(ok, isTrue, reason: 'should succeed with recovery');
    expect(err, equals(3), reason: 'should have 3 errors');
    expect(skip.length, equals(3), reason: 'should skip 3 occurrences');
  });

  test('R17-trailing long error after recovery', () {
    // Long trailing error after recovery
    final (ok, err, skip) =
        testParse('S <- "x"+ ;', '${'x' * 50}Z${'x' * 49}YYYY');
    expect(ok, isTrue, reason: 'should succeed with recovery');
    expect(err, equals(2), reason: 'should have 2 errors (Z and YYYY)');
  });

  test('R18-trailing after multiple alternating errors', () {
    // Multiple errors throughout, then trailing error
    final (ok, err, _) = testParse('S <- "ab"+ ;', 'abXabYabZabXX');
    expect(ok, isTrue, reason: 'should succeed with recovery');
    expect(err, equals(4), reason: 'should have 4 errors (X, Y, Z, XX)');
  });

  test('R19-single char after first recovery', () {
    // Recovery on first iteration, then trailing error
    final (ok, err, skip) = testParse('S <- "ab"+ ;', 'XXabX');
    expect(ok, isTrue, reason: 'should succeed');
    expect(err, equals(2), reason: 'should have 2 errors (XX and X)');
    expect(skip.contains('XX') && skip.contains('X'), isTrue,
        reason: 'should skip both XX and X');
  });

  test('R20-trailing error with single element', () {
    // Single valid element followed by recovery, then trailing
    final (ok, err, _) = testParse('S <- "a"+ ;', 'aXaY');
    expect(ok, isTrue, reason: 'should succeed');
    expect(err, equals(2), reason: 'should have 2 errors (X and Y)');
  });
}
