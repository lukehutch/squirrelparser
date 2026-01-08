// ===========================================================================
// SECTION 11: STRESS TESTS (20 tests)
// ===========================================================================

import 'package:squirrel_parser/squirrel_parser.dart';
import 'package:test/test.dart';

import 'test_utils.dart';

void main() {
  test('ST01-1000 clean', () {
    final (ok, err, _) = testParse({'S': OneOrMore(Str('ab'))}, 'ab' * 500);
    expect(ok, isTrue, reason: 'should succeed');
    expect(err, equals(0), reason: 'should have 0 errors');
  });

  test('ST02-1000 err', () {
    final (ok, err, _) =
        testParse({'S': OneOrMore(Str('ab'))}, '${'ab' * 250}XX${'ab' * 249}');
    expect(ok, isTrue, reason: 'should succeed');
    expect(err, equals(1), reason: 'should have 1 error');
  });

  test('ST03-100 groups', () {
    final (ok, err, _) = testParse({
      'S': OneOrMore(Seq([Str('('), OneOrMore(Str('x')), Str(')')]))
    }, '(xx)' * 100);
    expect(ok, isTrue, reason: 'should succeed');
    expect(err, equals(0), reason: 'should have 0 errors');
  });

  test('ST04-100 groups err', () {
    final input =
        List.generate(100, (i) => i % 10 == 5 ? '(xZx)' : '(xx)').join();
    final (ok, err, _) = testParse({
      'S': OneOrMore(Seq([Str('('), OneOrMore(Str('x')), Str(')')]))
    }, input);
    expect(ok, isTrue, reason: 'should succeed');
    expect(err, equals(10), reason: 'should have 10 errors');
  });

  test('ST05-deep nesting', () {
    final (ok, err, _) = testParse({
      'S': Seq([Str('('), Ref('A'), Str(')')]),
      'A': First([
        Seq([Str('('), Ref('A'), Str(')')]),
        Str('x')
      ])
    }, '${'(' * 15}x${')' * 15}');
    expect(ok, isTrue, reason: 'should succeed');
    expect(err, equals(0), reason: 'should have 0 errors');
  });

  test('ST06-50 alts', () {
    final alts = List.generate(50, (i) => Str('opt$i')) + [Str('match')];
    final (ok, err, _) = testParse({'S': First(alts)}, 'match');
    expect(ok, isTrue, reason: 'should succeed');
    expect(err, equals(0), reason: 'should have 0 errors');
  });

  test('ST07-500 chars', () {
    final (ok, err, _) = testParse({'S': OneOrMore(Str('x'))}, 'x' * 500);
    expect(ok, isTrue, reason: 'should succeed');
    expect(err, equals(0), reason: 'should have 0 errors');
  });

  test('ST08-500+5err', () {
    var input = 'x' * 100;
    for (int i = 0; i < 5; i++) {
      input += 'Z${'x' * 99}';
    }
    final (ok, err, _) = testParse({'S': OneOrMore(Str('x'))}, input);
    expect(ok, isTrue, reason: 'should succeed');
    expect(err, equals(5), reason: 'should have 5 errors');
  });

  test('ST09-100 seq', () {
    final clauses = List.filled(100, Str('x'));
    final (ok, err, _) = testParse({'S': Seq(clauses)}, 'x' * 100);
    expect(ok, isTrue, reason: 'should succeed');
    expect(err, equals(0), reason: 'should have 0 errors');
  });

  test('ST10-50 optional', () {
    final clauses = List<Clause>.filled(50, Optional(Str('x'))) + [Str('!')];
    final (ok, err, _) = testParse({'S': Seq(clauses)}, '${'x' * 25}!');
    expect(ok, isTrue, reason: 'should succeed');
    expect(err, equals(0), reason: 'should have 0 errors');
  });

  test('ST11-nested rep', () {
    final (ok, err, _) =
        testParse({'S': OneOrMore(OneOrMore(Str('x')))}, 'x' * 200);
    expect(ok, isTrue, reason: 'should succeed');
    expect(err, equals(0), reason: 'should have 0 errors');
  });

  test('ST12-long err span', () {
    final (ok, err, _) =
        testParse({'S': OneOrMore(Str('ab'))}, 'ab${'X' * 200}ab');
    expect(ok, isTrue, reason: 'should succeed');
    expect(err, equals(1), reason: 'should have 1 error');
  });

  test('ST13-many short err', () {
    final input = '${List.filled(30, 'abX').join()}ab';
    final (ok, err, _) = testParse({'S': OneOrMore(Str('ab'))}, input);
    expect(ok, isTrue, reason: 'should succeed');
    expect(err, equals(30), reason: 'should have 30 errors');
  });

  test('ST14-2000 clean', () {
    final (ok, err, _) = testParse({'S': OneOrMore(Str('x'))}, 'x' * 2000);
    expect(ok, isTrue, reason: 'should succeed');
    expect(err, equals(0), reason: 'should have 0 errors');
  });

  test('ST15-2000 err', () {
    final (ok, err, _) =
        testParse({'S': OneOrMore(Str('x'))}, '${'x' * 1000}ZZ${'x' * 998}');
    expect(ok, isTrue, reason: 'should succeed');
    expect(err, equals(1), reason: 'should have 1 error');
  });

  test('ST16-200 groups', () {
    final (ok, err, _) = testParse({
      'S': OneOrMore(Seq([Str('('), OneOrMore(Str('x')), Str(')')]))
    }, '(xx)' * 200);
    expect(ok, isTrue, reason: 'should succeed');
    expect(err, equals(0), reason: 'should have 0 errors');
  });

  test('ST17-200 groups 20err', () {
    final input =
        List.generate(200, (i) => i % 10 == 0 ? '(xZx)' : '(xx)').join();
    final (ok, err, _) = testParse({
      'S': OneOrMore(Seq([Str('('), OneOrMore(Str('x')), Str(')')]))
    }, input);
    expect(ok, isTrue, reason: 'should succeed');
    expect(err, equals(20), reason: 'should have 20 errors');
  });

  test('ST18-50 errors', () {
    final input = '${List.filled(50, 'abZ').join()}ab';
    final (ok, err, _) = testParse({'S': OneOrMore(Str('ab'))}, input);
    expect(ok, isTrue, reason: 'should succeed');
    expect(err, equals(50), reason: 'should have 50 errors');
  });

  test('ST19-deep L5', () {
    final (ok, err, skip) = testParse({
      'S': Seq([
        Str('1'),
        Seq([
          Str('2'),
          Seq([
            Str('3'),
            Seq([
              Str('4'),
              Seq([Str('5'), OneOrMore(Str('x')), Str('5')]),
              Str('4')
            ]),
            Str('3')
          ]),
          Str('2')
        ]),
        Str('1')
      ])
    }, '12345xZx54321');
    expect(ok, isTrue, reason: 'should succeed');
    expect(err, equals(1), reason: 'should have 1 error');
    expect(skip.contains('Z'), isTrue, reason: 'should skip Z');
  });

  test('ST20-very deep nest', () {
    final (ok, err, _) = testParse({
      'S': Seq([Str('('), Ref('A'), Str(')')]),
      'A': First([
        Seq([Str('('), Ref('A'), Str(')')]),
        Str('x')
      ])
    }, '${'(' * 20}x${')' * 20}');
    expect(ok, isTrue, reason: 'should succeed');
    expect(err, equals(0), reason: 'should have 0 errors');
  });
}
