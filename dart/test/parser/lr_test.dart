// ===========================================================================
// SECTION 9: LEFT RECURSION (10 tests)
// ===========================================================================

import 'package:squirrel_parser/squirrel_parser.dart';
import 'package:test/test.dart';

import 'test_utils.dart';

void main() {
  final lr1 = {
    'S': First([
      Seq([Ref('S'), Str('+'), Ref('T')]),
      Ref('T')
    ]),
    'T': OneOrMore(CharRange('0', '9')),
  };

  test('LR01-simple', () {
    final (ok, err, _) = testParse(lr1, '1+2+3');
    expect(ok, isTrue, reason: 'should succeed');
    expect(err, equals(0), reason: 'should have 0 errors');
  });

  test('LR02-single', () {
    final (ok, err, _) = testParse(lr1, '42');
    expect(ok, isTrue, reason: 'should succeed');
    expect(err, equals(0), reason: 'should have 0 errors');
  });

  test('LR03-chain 5', () {
    final (ok, err, _) = testParse(lr1, List.filled(5, '1').join('+'));
    expect(ok, isTrue, reason: 'should succeed');
    expect(err, equals(0), reason: 'should have 0 errors');
  });

  test('LR04-chain 10', () {
    final (ok, err, _) = testParse(lr1, List.filled(10, '1').join('+'));
    expect(ok, isTrue, reason: 'should succeed');
    expect(err, equals(0), reason: 'should have 0 errors');
  });

  final expr = {
    'S': Ref('E'),
    'E': First([
      Seq([Ref('E'), Str('+'), Ref('T')]),
      Ref('T')
    ]),
    'T': First([
      Seq([Ref('T'), Str('*'), Ref('F')]),
      Ref('F')
    ]),
    'F': First([
      Seq([Str('('), Ref('E'), Str(')')]),
      CharRange('0', '9')
    ]),
  };

  test('LR05-with mult', () {
    final (ok, err, _) = testParse(expr, '1+2*3');
    expect(ok, isTrue, reason: 'should succeed');
    expect(err, equals(0), reason: 'should have 0 errors');
  });

  test('LR06-parens', () {
    final (ok, err, _) = testParse(expr, '(1+2)*3');
    expect(ok, isTrue, reason: 'should succeed');
    expect(err, equals(0), reason: 'should have 0 errors');
  });

  test('LR07-nested parens', () {
    final (ok, err, _) = testParse(expr, '((1+2))');
    expect(ok, isTrue, reason: 'should succeed');
    expect(err, equals(0), reason: 'should have 0 errors');
  });

  test('LR08-direct', () {
    final (ok, err, _) = testParse({
      'S': First([
        Seq([Ref('S'), Str('x')]),
        Str('y')
      ])
    }, 'yxxx');
    expect(ok, isTrue, reason: 'should succeed');
    expect(err, equals(0), reason: 'should have 0 errors');
  });

  test('LR09-multi-digit', () {
    final (ok, err, _) = testParse(lr1, '12+345+6789');
    expect(ok, isTrue, reason: 'should succeed');
    expect(err, equals(0), reason: 'should have 0 errors');
  });

  test('LR10-complex expr', () {
    final (ok, err, _) = testParse(expr, '1+2*3+4*5');
    expect(ok, isTrue, reason: 'should succeed');
    expect(err, equals(0), reason: 'should have 0 errors');
  });
}
