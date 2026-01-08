// ===========================================================================
// SECTION 8: FIRST (ORDERED CHOICE) (15 tests)
// ===========================================================================

import 'package:squirrel_parser/squirrel_parser.dart';
import 'package:test/test.dart';

import 'test_utils.dart';

void main() {
  test('FR01-match 1st', () {
    final (ok, err, _) = testParse({
      'S': First([Str('abc'), Str('ab'), Str('a')])
    }, 'abc');
    expect(ok, isTrue, reason: 'should succeed');
    expect(err, equals(0), reason: 'should have 0 errors');
  });

  test('FR02-match 2nd', () {
    final (ok, err, _) = testParse({
      'S': First([Str('xyz'), Str('abc')])
    }, 'abc');
    expect(ok, isTrue, reason: 'should succeed');
    expect(err, equals(0), reason: 'should have 0 errors');
  });

  test('FR03-match 3rd', () {
    final (ok, err, _) = testParse({
      'S': First([Str('x'), Str('y'), Str('z')])
    }, 'z');
    expect(ok, isTrue, reason: 'should succeed');
    expect(err, equals(0), reason: 'should have 0 errors');
  });

  test('FR04-with recovery', () {
    final (ok, err, skip) = testParse({
      'S': First([
        Seq([OneOrMore(Str('x')), Str('!')]),
        Str('fallback')
      ])
    }, 'xZx!');
    expect(ok, isTrue, reason: 'should succeed');
    expect(err, equals(1), reason: 'should have 1 error');
    expect(skip.contains('Z'), isTrue, reason: 'should skip Z');
  });

  test('FR05-fallback', () {
    final (ok, err, _) = testParse({
      'S': First([
        Seq([Str('a'), Str('b')]),
        Str('x')
      ])
    }, 'x');
    expect(ok, isTrue, reason: 'should succeed');
    expect(err, equals(0), reason: 'should have 0 errors');
  });

  test('FR06-none match', () {
    final (ok, _, _) = testParse({
      'S': First([Str('a'), Str('b'), Str('c')])
    }, 'x');
    expect(ok, isFalse, reason: 'should fail');
  });

  test('FR07-nested', () {
    final (ok, err, _) = testParse({
      'S': First([
        First([Str('a'), Str('b')]),
        Str('c')
      ])
    }, 'b');
    expect(ok, isTrue, reason: 'should succeed');
    expect(err, equals(0), reason: 'should have 0 errors');
  });

  test('FR08-deep nested', () {
    final (ok, err, _) = testParse({
      'S': First([
        First([
          First([Str('a')])
        ])
      ])
    }, 'a');
    expect(ok, isTrue, reason: 'should succeed');
    expect(err, equals(0), reason: 'should have 0 errors');
  });
}
