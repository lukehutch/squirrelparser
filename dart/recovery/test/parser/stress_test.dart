// ===========================================================================
// SECTION 11: STRESS TESTS (20 tests)
// ===========================================================================

import 'package:test/test.dart';

import '../test_utils.dart';

void main() {
  test('ST01-1000 clean', () {
    final (ok, err, _) = testParse('S <- "ab"+ ;', 'ab' * 500);
    expect(ok, isTrue, reason: 'should succeed');
    expect(err, equals(0), reason: 'should have 0 errors');
  });

  test('ST02-1000 err', () {
    final (ok, err, _) =
        testParse('S <- "ab"+ ;', '${'ab' * 250}XX${'ab' * 249}');
    expect(ok, isTrue, reason: 'should succeed');
    expect(err, equals(1), reason: 'should have 1 error');
  });

  test('ST03-100 groups', () {
    const grammar = 'S <- ("(" "x"+ ")")+ ;';
    final (ok, err, _) = testParse(grammar, '(xx)' * 100);
    expect(ok, isTrue, reason: 'should succeed');
    expect(err, equals(0), reason: 'should have 0 errors');
  });

  test('ST05-deep nesting', () {
    const grammar = '''
      S <- "(" A ")" ;
      A <- "(" A ")" / "x" ;
    ''';
    final (ok, err, _) = testParse(grammar, '${'(' * 15}x${')' * 15}');
    expect(ok, isTrue, reason: 'should succeed');
    expect(err, equals(0), reason: 'should have 0 errors');
  });

  test('ST06-50 alts', () {
    final alts = List.generate(50, (i) => '"opt$i"').join(' / ');
    final grammar = 'S <- $alts / "match" ;';
    final (ok, err, _) = testParse(grammar, 'match');
    expect(ok, isTrue, reason: 'should succeed');
    expect(err, equals(0), reason: 'should have 0 errors');
  });

  test('ST07-500 chars', () {
    final (ok, err, _) = testParse('S <- "x"+ ;', 'x' * 500);
    expect(ok, isTrue, reason: 'should succeed');
    expect(err, equals(0), reason: 'should have 0 errors');
  });

  test('ST09-100 seq', () {
    final elems = List.filled(100, '"x"').join(' ');
    final grammar = 'S <- $elems ;';
    final (ok, err, _) = testParse(grammar, 'x' * 100);
    expect(ok, isTrue, reason: 'should succeed');
    expect(err, equals(0), reason: 'should have 0 errors');
  });

  test('ST10-50 optional', () {
    final elems = List.filled(50, '"x"?').join(' ');
    final grammar = 'S <- $elems "!" ;';
    final (ok, err, _) = testParse(grammar, '${'x' * 25}!');
    expect(ok, isTrue, reason: 'should succeed');
    expect(err, equals(0), reason: 'should have 0 errors');
  });

  test('ST11-nested rep', () {
    const grammar = 'S <- ("x"+)+ ;';
    final (ok, err, _) = testParse(grammar, 'x' * 200);
    expect(ok, isTrue, reason: 'should succeed');
    expect(err, equals(0), reason: 'should have 0 errors');
  });

  test('ST12-long err span', () {
    final (ok, err, _) = testParse('S <- "ab"+ ;', 'ab${'X' * 200}ab');
    expect(ok, isTrue, reason: 'should succeed');
    expect(err, equals(1), reason: 'should have 1 error');
  });

  test('ST14-2000 clean', () {
    final (ok, err, _) = testParse('S <- "x"+ ;', 'x' * 2000);
    expect(ok, isTrue, reason: 'should succeed');
    expect(err, equals(0), reason: 'should have 0 errors');
  });

  test('ST15-2000 err', () {
    final (ok, err, _) =
        testParse('S <- "x"+ ;', '${'x' * 1000}ZZ${'x' * 998}');
    expect(ok, isTrue, reason: 'should succeed');
    expect(err, equals(1), reason: 'should have 1 error');
  });

  test('ST16-200 groups', () {
    const grammar = 'S <- ("(" "x"+ ")")+ ;';
    final (ok, err, _) = testParse(grammar, '(xx)' * 200);
    expect(ok, isTrue, reason: 'should succeed');
    expect(err, equals(0), reason: 'should have 0 errors');
  });

  test('ST20-very deep nest', () {
    const grammar = '''
      S <- "(" A ")" ;
      A <- "(" A ")" / "x" ;
    ''';
    final (ok, err, _) = testParse(grammar, '${'(' * 20}x${')' * 20}');
    expect(ok, isTrue, reason: 'should succeed');
    expect(err, equals(0), reason: 'should have 0 errors');
  });
}
