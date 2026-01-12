// ===========================================================================
// SECTION 2: FIX #1 - isComplete PROPAGATION (25 tests)
// ===========================================================================

import 'package:test/test.dart';

import '../test_utils.dart';

void main() {
  test('F1-01-Rep+Seq basic', () {
    final (ok, err, skip) = testParse('S <- "ab"+ "!" ;', 'abXXab!');
    expect(ok, isTrue, reason: 'should succeed');
    expect(err, equals(1), reason: 'should have 1 error, got $err');
    expect(skip.contains('XX'), isTrue, reason: 'should skip XX');
  });

  test('F1-02-Rep+Optional', () {
    final (ok, err, skip) = testParse('S <- "ab"+ "!"? ;', 'abXXab');
    expect(ok, isTrue, reason: 'should succeed');
    expect(err, equals(1), reason: 'should have 1 error');
    expect(skip.contains('XX'), isTrue, reason: 'should skip XX');
  });

  test('F1-03-Rep+Optional+match', () {
    final (ok, err, skip) = testParse('S <- "ab"+ "!"? ;', 'abXXab!');
    expect(ok, isTrue, reason: 'should succeed');
    expect(err, equals(1), reason: 'should have 1 error');
    expect(skip.contains('XX'), isTrue, reason: 'should skip XX');
  });

  test('F1-04-First wrapping', () {
    final (ok, err, _) = testParse('S <- ("ab"+ "!") ;', 'abXXab!');
    expect(ok, isTrue, reason: 'should succeed');
    expect(err, equals(1), reason: 'should have 1 error');
  });

  test('F1-05-Nested Seq L1', () {
    final (ok, err, skip) = testParse('S <- (("x"+)) ;', 'xZx');
    expect(ok, isTrue, reason: 'should succeed');
    expect(err, equals(1), reason: 'should have 1 error');
    expect(skip.contains('Z'), isTrue, reason: 'should skip Z');
  });

  test('F1-06-Nested Seq L2', () {
    final (ok, err, skip) = testParse('S <- ((("x"+))) ;', 'xZx');
    expect(ok, isTrue, reason: 'should succeed');
    expect(err, equals(1), reason: 'should have 1 error');
    expect(skip.contains('Z'), isTrue, reason: 'should skip Z');
  });

  test('F1-07-Nested Seq L3', () {
    final (ok, err, skip) = testParse('S <- (((("x"+)))) ;', 'xZx');
    expect(ok, isTrue, reason: 'should succeed');
    expect(err, equals(1), reason: 'should have 1 error');
    expect(skip.contains('Z'), isTrue, reason: 'should skip Z');
  });

  test('F1-08-Optional wrapping', () {
    final (ok, err, skip) = testParse('S <- (("x"+))? ;', 'xZx');
    expect(ok, isTrue, reason: 'should succeed');
    expect(err, equals(1), reason: 'should have 1 error');
    expect(skip.contains('Z'), isTrue, reason: 'should skip Z');
  });

  test('F1-09-ZeroOrMore in Seq', () {
    final (ok, err, skip) = testParse('S <- "ab"* "!" ;', 'abXXab!');
    expect(ok, isTrue, reason: 'should succeed');
    expect(err, equals(1), reason: 'should have 1 error');
    expect(skip.contains('XX'), isTrue, reason: 'should skip XX');
  });

  test('F1-10-Multiple Reps', () {
    final (ok, err, _) = testParse('S <- "a"+ "b"+ ;', 'aXabYb');
    expect(ok, isTrue, reason: 'should succeed');
    expect(err, equals(2), reason: 'should have 2 errors');
  });

  test('F1-11-Rep+Rep+Term', () {
    final (ok, err, _) = testParse('S <- "a"+ "b"+ "!" ;', 'aXabYb!');
    expect(ok, isTrue, reason: 'should succeed');
    expect(err, equals(2), reason: 'should have 2 errors');
  });

  test('F1-12-Long error span', () {
    final (ok, err, _) = testParse('S <- "x"+ "!" ;', 'x${'Z' * 20}x!');
    expect(ok, isTrue, reason: 'should succeed');
    expect(err, equals(1), reason: 'should have 1 error');
  });

  test('F1-13-Multiple long errors', () {
    final (ok, err, _) =
        testParse('S <- "ab"+ ;', 'ab${'X' * 10}ab${'Y' * 10}ab');
    expect(ok, isTrue, reason: 'should succeed');
    expect(err, equals(2), reason: 'should have 2 errors');
  });

  test('F1-14-Interspersed errors', () {
    final (ok, err, _) = testParse('S <- "ab"+ ;', 'abXabYabZab');
    expect(ok, isTrue, reason: 'should succeed');
    expect(err, equals(3), reason: 'should have 3 errors');
  });

  test('F1-15-Five errors', () {
    final (ok, err, _) =
        testParse('S <- "ab"+ ;', 'abAabBabCabDabEab');
    expect(ok, isTrue, reason: 'should succeed');
    expect(err, equals(5), reason: 'should have 5 errors');
  });
}
