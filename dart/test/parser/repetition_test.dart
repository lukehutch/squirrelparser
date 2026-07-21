// ===========================================================================
// SECTION 6: REPETITION COMPREHENSIVE (25 tests)
// ===========================================================================

import 'package:test/test.dart';

import '../test_utils.dart';

void main() {
  test('R03-long skip', () {
    final (ok, err, _) = testParse('S <- "ab"+ ;', 'ab${'X' * 50}ab');
    expect(ok, isTrue, reason: 'should succeed');
    expect(err, equals(1), reason: 'should have 1 error');
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

  test('R10-long clean', () {
    final (ok, err, _) = testParse('S <- "x"+ ;', 'x' * 100);
    expect(ok, isTrue, reason: 'should succeed');
    expect(err, equals(0), reason: 'should have 0 errors');
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

}
