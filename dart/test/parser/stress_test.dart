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

  test('ST04-100 groups err', () {
    final input =
        List.generate(100, (i) => i % 10 == 5 ? '(xZx)' : '(xx)').join();
    const grammar = 'S <- ("(" "x"+ ")")+ ;';
    final (ok, err, _) = testParse(grammar, input);
    expect(ok, isTrue, reason: 'should succeed');
    expect(err, equals(10), reason: 'should have 10 errors');
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

  test('ST08-500+5err', () {
    var input = 'x' * 100;
    for (int i = 0; i < 5; i++) {
      input += 'Z${'x' * 99}';
    }
    final (ok, err, _) = testParse('S <- "x"+ ;', input);
    expect(ok, isTrue, reason: 'should succeed');
    expect(err, equals(5), reason: 'should have 5 errors');
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

  test('ST13-many short err', () {
    final input = '${List.filled(30, 'abX').join()}ab';
    final (ok, err, _) = testParse('S <- "ab"+ ;', input);
    expect(ok, isTrue, reason: 'should succeed');
    expect(err, equals(30), reason: 'should have 30 errors');
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

  test('ST17-200 groups 20err', () {
    final input =
        List.generate(200, (i) => i % 10 == 0 ? '(xZx)' : '(xx)').join();
    const grammar = 'S <- ("(" "x"+ ")")+ ;';
    final (ok, err, _) = testParse(grammar, input);
    expect(ok, isTrue, reason: 'should succeed');
    expect(err, equals(20), reason: 'should have 20 errors');
  });

  test('ST18-50 errors', () {
    final input = '${List.filled(50, 'abZ').join()}ab';
    final (ok, err, _) = testParse('S <- "ab"+ ;', input);
    expect(ok, isTrue, reason: 'should succeed');
    expect(err, equals(50), reason: 'should have 50 errors');
  });

  test('ST19-deep L5', () {
    const grammar = '''
      S <- "1" (
        "2" (
          "3" (
            "4" (
              "5" "x"+ "5"
            ) "4"
          ) "3"
        ) "2"
      ) "1" ;
    ''';
    final (ok, err, skip) = testParse(grammar, '12345xZx54321');
    expect(ok, isTrue, reason: 'should succeed');
    expect(err, equals(1), reason: 'should have 1 error');
    expect(skip.contains('Z'), isTrue, reason: 'should skip Z');
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
