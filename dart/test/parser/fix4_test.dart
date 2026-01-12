// ===========================================================================
// SECTION 4: FIX #4 - MULTI-LEVEL BOUNDED RECOVERY (35 tests)
// ===========================================================================

import 'package:test/test.dart';

import '../test_utils.dart';

void main() {
  test('F4-L1-01-clean 2', () {
    final (ok, err, _) = testParse(
      'S <- ("(" "x"+ ")")+ ;',
      '(xx)(xx)',
    );
    expect(ok, isTrue, reason: 'should succeed');
    expect(err, equals(0), reason: 'should have 0 errors');
  });

  test('F4-L1-02-clean 5', () {
    final (ok, err, _) = testParse(
      'S <- ("(" "x"+ ")")+ ;',
      '(xx)' * 5,
    );
    expect(ok, isTrue, reason: 'should succeed');
    expect(err, equals(0), reason: 'should have 0 errors');
  });

  test('F4-L1-03-err first', () {
    final (ok, err, skip) = testParse(
      'S <- ("(" "x"+ ")")+ ;',
      '(xZx)(xx)',
    );
    expect(ok, isTrue, reason: 'should succeed');
    expect(err, equals(1), reason: 'should have 1 error');
    expect(skip.contains('Z'), isTrue, reason: 'should skip Z');
  });

  test('F4-L1-04-err mid', () {
    final (ok, err, skip) = testParse(
      'S <- ("(" "x"+ ")")+ ;',
      '(xx)(xZx)(xx)',
    );
    expect(ok, isTrue, reason: 'should succeed');
    expect(err, equals(1), reason: 'should have 1 error');
    expect(skip.contains('Z'), isTrue, reason: 'should skip Z');
  });

  test('F4-L1-05-err last', () {
    final (ok, err, skip) = testParse(
      'S <- ("(" "x"+ ")")+ ;',
      '(xx)(xZx)',
    );
    expect(ok, isTrue, reason: 'should succeed');
    expect(err, equals(1), reason: 'should have 1 error');
    expect(skip.contains('Z'), isTrue, reason: 'should skip Z');
  });

  test('F4-L1-06-err all 3', () {
    final (ok, err, skip) = testParse(
      'S <- ("(" "x"+ ")")+ ;',
      '(xAx)(xBx)(xCx)',
    );
    expect(ok, isTrue, reason: 'should succeed');
    expect(err, equals(3), reason: 'should have 3 errors');
    expect(
        skip.contains('A') && skip.contains('B') && skip.contains('C'), isTrue,
        reason: 'should skip A, B, C');
  });

  test('F4-L1-07-boundary', () {
    final (ok, err, skip) = testParse(
      'S <- ("(" "x"+ ")")+ ;',
      '(xx)Z(xx)',
    );
    expect(ok, isTrue, reason: 'should succeed');
    expect(err, equals(1), reason: 'should have 1 error');
    expect(skip.contains('Z'), isTrue, reason: 'should skip Z');
  });

  test('F4-L1-08-long boundary', () {
    final (ok, err, skip) = testParse(
      'S <- ("(" "x"+ ")")+ ;',
      '(xx)ZZZ(xx)',
    );
    expect(ok, isTrue, reason: 'should succeed');
    expect(err, equals(1), reason: 'should have 1 error');
    expect(skip.contains('ZZZ'), isTrue, reason: 'should skip ZZZ');
  });

  test('F4-L2-01-clean', () {
    final (ok, err, _) = testParse(
      'S <- "{" ("(" "x"+ ")")+ "}" ;',
      '{(xx)(xx)}',
    );
    expect(ok, isTrue, reason: 'should succeed');
    expect(err, equals(0), reason: 'should have 0 errors');
  });

  test('F4-L2-02-err inner', () {
    final (ok, err, skip) = testParse(
      'S <- "{" ("(" "x"+ ")")+ "}" ;',
      '{(xx)(xZx)}',
    );
    expect(ok, isTrue, reason: 'should succeed');
    expect(err, equals(1), reason: 'should have 1 error');
    expect(skip.contains('Z'), isTrue, reason: 'should skip Z');
  });

  test('F4-L2-03-err outer', () {
    final (ok, err, skip) = testParse(
      'S <- "{" ("(" "x"+ ")")+ "}" ;',
      '{(xx)Z(xx)}',
    );
    expect(ok, isTrue, reason: 'should succeed');
    expect(err, equals(1), reason: 'should have 1 error');
    expect(skip.contains('Z'), isTrue, reason: 'should skip Z');
  });

  test('F4-L2-04-both levels', () {
    final (ok, err, _) = testParse(
      'S <- "{" ("(" "x"+ ")")+ "}" ;',
      '{(xAx)B(xCx)}',
    );
    expect(ok, isTrue, reason: 'should succeed');
    expect(err, equals(3), reason: 'should have 3 errors');
  });

  test('F4-L3-01-clean', () {
    final (ok, err, _) = testParse(
      'S <- "[" "{" ("(" "x"+ ")")+ "}" "]" ;',
      '[{(xx)(xx)}]',
    );
    expect(ok, isTrue, reason: 'should succeed');
    expect(err, equals(0), reason: 'should have 0 errors');
  });

  test('F4-L3-02-err deepest', () {
    final (ok, err, skip) = testParse(
      'S <- "[" "{" ("(" "x"+ ")")+ "}" "]" ;',
      '[{(xx)(xZx)}]',
    );
    expect(ok, isTrue, reason: 'should succeed');
    expect(err, equals(1), reason: 'should have 1 error');
    expect(skip.contains('Z'), isTrue, reason: 'should skip Z');
  });

  test('F4-N1-10 groups', () {
    final (ok, err, _) = testParse(
      'S <- ("(" "x"+ ")")+ ;',
      '(xx)' * 10,
    );
    expect(ok, isTrue, reason: 'should succeed');
    expect(err, equals(0), reason: 'should have 0 errors');
  });

  test('F4-N2-10 groups 5 err', () {
    final input =
        List.generate(10, (i) => i % 2 == 0 ? '(xZx)' : '(xx)').join();
    final (ok, err, _) = testParse(
      'S <- ("(" "x"+ ")")+ ;',
      input,
    );
    expect(ok, isTrue, reason: 'should succeed');
    expect(err, equals(5), reason: 'should have 5 errors');
  });

  test('F4-N3-20 groups', () {
    final (ok, err, _) = testParse(
      'S <- ("(" "x"+ ")")+ ;',
      '(xx)' * 20,
    );
    expect(ok, isTrue, reason: 'should succeed');
    expect(err, equals(0), reason: 'should have 0 errors');
  });
}
