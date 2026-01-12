// ===========================================================================
// SECTION 3: FIX #2/#3 - CACHE INTEGRITY (20 tests)
// ===========================================================================

import 'package:test/test.dart';

import '../test_utils.dart';

void main() {
  test('F2-01-Basic probe', () {
    final (ok, err, skip) = testParse(
      'S <- "(" "x"+ ")" ;',
      '(xZZx)',
    );
    expect(ok, isTrue, reason: 'should succeed');
    expect(err, equals(1), reason: 'should have 1 error');
    expect(skip.contains('ZZ'), isTrue, reason: 'should skip ZZ');
  });

  test('F2-02-Double probe', () {
    final (ok, err, _) = testParse(
      'S <- "a" "x"+ "b" "y"+ "c" ;',
      'axXxbyYyc',
    );
    expect(ok, isTrue, reason: 'should succeed');
    expect(err, equals(2), reason: 'should have 2 errors');
  });

  test('F2-03-Probe same clause', () {
    final (ok, err, skip) = testParse(
      'S <- ("(" "x"+ ")")+ ;',
      '(xZx)(xYx)',
    );
    expect(ok, isTrue, reason: 'should succeed');
    expect(err, equals(2), reason: 'should have 2 errors');
    expect(skip.contains('Z') && skip.contains('Y'), isTrue,
        reason: 'should skip Z and Y');
  });

  test('F2-04-Triple group', () {
    final (ok, err, _) = testParse(
      'S <- ("[" "x"+ "]")+ ;',
      '[xAx][xBx][xCx]',
    );
    expect(ok, isTrue, reason: 'should succeed');
    expect(err, equals(3), reason: 'should have 3 errors');
  });

  test('F2-05-Five groups', () {
    final (ok, err, _) = testParse(
      'S <- ("(" "x"+ ")")+ ;',
      '(xAx)(xBx)(xCx)(xDx)(xEx)',
    );
    expect(ok, isTrue, reason: 'should succeed');
    expect(err, equals(5), reason: 'should have 5 errors');
  });

  test('F2-06-Alternating clean/err', () {
    final (ok, err, _) = testParse(
      'S <- ("(" "x"+ ")")+ ;',
      '(xx)(xZx)(xx)(xYx)(xx)',
    );
    expect(ok, isTrue, reason: 'should succeed');
    expect(err, equals(2), reason: 'should have 2 errors');
  });

  test('F2-07-Long inner error', () {
    final (ok, err, _) = testParse(
      'S <- "(" "x"+ ")" ;',
      '(x${'Z' * 20}x)',
    );
    expect(ok, isTrue, reason: 'should succeed');
    expect(err, equals(1), reason: 'should have 1 error');
  });

  test('F2-08-Nested probe', () {
    final (ok, err, skip) = testParse(
      'S <- "{" "(" "x"+ ")" "}" ;',
      '{(xZx)}',
    );
    expect(ok, isTrue, reason: 'should succeed');
    expect(err, equals(1), reason: 'should have 1 error');
    expect(skip.contains('Z'), isTrue, reason: 'should skip Z');
  });

  test('F2-09-Triple nested', () {
    final (ok, err, skip) = testParse(
      'S <- "<" "{" "[" "x"+ "]" "}" ">" ;',
      '<{[xZx]}>',
    );
    expect(ok, isTrue, reason: 'should succeed');
    expect(err, equals(1), reason: 'should have 1 error');
    expect(skip.contains('Z'), isTrue, reason: 'should skip Z');
  });

  test('F2-10-Ref probe', () {
    final (ok, err, skip) = testParse(
      '''
      S <- "(" R ")" ;
      R <- "x"+ ;
      ''',
      '(xZx)',
    );
    expect(ok, isTrue, reason: 'should succeed');
    expect(err, equals(1), reason: 'should have 1 error');
    expect(skip.contains('Z'), isTrue, reason: 'should skip Z');
  });
}
