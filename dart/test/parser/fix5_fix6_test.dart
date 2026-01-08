// ===========================================================================
// SECTION 5: FIX #5/#6 - OPTIONAL AND EOF (25 tests)
// ===========================================================================

import 'package:squirrel_parser/squirrel_parser.dart';
import 'package:test/test.dart';

import 'test_utils.dart';

void main() {
  // Mutual recursion grammar
  final mr = {
    'S': Ref('A'),
    'A': First([
      Seq([Str('a'), Ref('B')]),
      Str('y')
    ]),
    'B': First([
      Seq([Str('b'), Ref('A')]),
      Str('x')
    ]),
  };

  test('F5-01-aby', () {
    final (ok, err, _) = testParse(mr, 'aby');
    expect(ok, isTrue, reason: 'should succeed');
    expect(err, equals(0), reason: 'should have 0 errors');
  });

  test('F5-02-abZy', () {
    final (ok, err, skip) = testParse(mr, 'abZy');
    expect(ok, isTrue, reason: 'should succeed');
    expect(err, equals(1), reason: 'should have 1 error');
    expect(skip.contains('Z'), isTrue, reason: 'should skip Z');
  });

  test('F5-03-ababy', () {
    final (ok, err, _) = testParse(mr, 'ababy');
    expect(ok, isTrue, reason: 'should succeed');
    expect(err, equals(0), reason: 'should have 0 errors');
  });

  test('F5-04-ax', () {
    final (ok, err, _) = testParse(mr, 'ax');
    expect(ok, isTrue, reason: 'should succeed');
    expect(err, equals(0), reason: 'should have 0 errors');
  });

  test('F5-05-y', () {
    final (ok, err, _) = testParse(mr, 'y');
    expect(ok, isTrue, reason: 'should succeed');
    expect(err, equals(0), reason: 'should have 0 errors');
  });

  test('F5-06-abx', () {
    // 'abx' is NOT in the language: after 'ab' we need A which requires 'a' or 'y', not 'x'
    // Grammar produces: y, ax, aby, abax, ababy, etc.
    // So this requires error recovery (skip 'b' and match 'ax', or skip 'bx' and fail)
    final (ok, err, _) = testParse(mr, 'abx');
    expect(ok, isTrue, reason: 'should succeed with recovery');
    expect(err, greaterThanOrEqualTo(1),
        reason: 'should have at least 1 error');
  });

  test('F5-06b-abax', () {
    // 'abax' IS in the language: A → a B → a b A → a b a B → a b a x
    final (ok, err, _) = testParse(mr, 'abax');
    expect(ok, isTrue, reason: 'should succeed');
    expect(err, equals(0), reason: 'should have 0 errors');
  });

  test('F5-07-ababx', () {
    // 'ababx' is NOT in the language: after 'abab' we need A which requires 'a' or 'y', not 'x'
    // Grammar produces: y, ax, aby, abax, ababy, ababax, abababy, etc.
    // So this requires error recovery
    final (ok, err, _) = testParse(mr, 'ababx');
    expect(ok, isTrue, reason: 'should succeed with recovery');
    expect(err, greaterThanOrEqualTo(1),
        reason: 'should have at least 1 error');
  });

  test('F5-07b-ababax', () {
    // 'ababax' IS in the language: A → a B → a b A → a b a B → a b a b A → a b a b a B → a b a b a x
    final (ok, err, _) = testParse(mr, 'ababax');
    expect(ok, isTrue, reason: 'should succeed');
    expect(err, equals(0), reason: 'should have 0 errors');
  });

  test('F6-01-Optional wrapper', () {
    final (ok, err, skip) = testParse({
      'S': Optional(Seq([OneOrMore(Str('x')), Str('!')]))
    }, 'xZx!');
    expect(ok, isTrue, reason: 'should succeed');
    expect(err, equals(1), reason: 'should have 1 error');
    expect(skip.contains('Z'), isTrue, reason: 'should skip Z');
  });

  test('F6-02-Optional at EOF', () {
    final (ok, err, _) = testParse({'S': Optional(Str('x'))}, '');
    expect(ok, isTrue, reason: 'should succeed');
    expect(err, equals(0), reason: 'should have 0 errors');
  });

  test('F6-03-Nested optional', () {
    final (ok, err, skip) = testParse({
      'S': Optional(Optional(Seq([OneOrMore(Str('x')), Str('!')])))
    }, 'xZx!');
    expect(ok, isTrue, reason: 'should succeed');
    expect(err, equals(1), reason: 'should have 1 error');
    expect(skip.contains('Z'), isTrue, reason: 'should skip Z');
  });

  test('F6-04-Optional in Seq', () {
    final (ok, err, skip) = testParse({
      'S': Seq([
        Optional(Seq([OneOrMore(Str('x'))])),
        Str('!')
      ])
    }, 'xZx!');
    expect(ok, isTrue, reason: 'should succeed');
    expect(err, equals(1), reason: 'should have 1 error');
    expect(skip.contains('Z'), isTrue, reason: 'should skip Z');
  });

  test('F6-05-EOF del ok', () {
    final parser = Parser(
      rules: {
        'S': Seq([Str('a'), Str('b'), Str('c')])
      },
      input: 'ab',
    );
    final (result, _) = parser.parse('S');
    expect(!result.isMismatch, isTrue,
        reason: 'should succeed with recovery');
    expect(countDeletions(result) == 1, isTrue,
        reason: 'should have 1 deletion');
  });
}
