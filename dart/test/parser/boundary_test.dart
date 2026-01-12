// ===========================================================================
// SECTION 1: EMPTY AND BOUNDARY CONDITIONS (27 tests)
// ===========================================================================

import 'package:squirrel_parser/squirrel_parser.dart';
import 'package:test/test.dart';

import '../test_utils.dart';

void main() {
  group('Empty and Boundary Conditions', () {
    test('E01-ZeroOrMore empty', () {
      final (ok, err, _) = testParse('S <- "x"* ;', '');
      expect(ok, isTrue, reason: 'should succeed');
      expect(err, equals(0), reason: 'should have 0 errors');
    });

    test('E02-OneOrMore empty', () {
      final (ok, _, _) = testParse('S <- "x"+ ;', '');
      expect(ok, isFalse, reason: 'should fail');
    });

    test('E03-Optional empty', () {
      final (ok, err, _) = testParse('S <- "x"? ;', '');
      expect(ok, isTrue, reason: 'should succeed');
      expect(err, equals(0), reason: 'should have 0 errors');
    });

    test('E04-Seq empty recovery', () {
      final parseResult = squirrelParsePT(
        grammarSpec: 'S <- "a" "b" ;',
        topRuleName: 'S',
        input: '',
      );
      final result = parseResult.root;
      expect(!result.isMismatch, isTrue,
          reason: 'should succeed with recovery');
      expect(countDeletions([result]), equals(2),
          reason: 'should have 2 deletions');
    });

    test('E05-First empty', () {
      final (ok, _, _) = testParse('S <- "a" / "b" ;', '');
      expect(ok, isFalse, reason: 'should fail');
    });

    test('E06-Ref empty', () {
      final (ok, _, _) = testParse('S <- A ; A <- "x" ;', '');
      expect(ok, isFalse, reason: 'should fail');
    });

    test('E07-Single char match', () {
      final (ok, err, _) = testParse('S <- "x" ;', 'x');
      expect(ok, isTrue, reason: 'should succeed');
      expect(err, equals(0), reason: 'should have 0 errors');
    });

    test('E08-Single char mismatch', () {
      final (ok, _, _) = testParse('S <- "x" ;', 'y');
      expect(ok, isFalse, reason: 'should fail');
    });

    test('E09-ZeroOrMore single', () {
      final (ok, err, _) = testParse('S <- "x"* ;', 'x');
      expect(ok, isTrue, reason: 'should succeed');
      expect(err, equals(0), reason: 'should have 0 errors');
    });

    test('E10-OneOrMore single', () {
      final (ok, err, _) = testParse('S <- "x"+ ;', 'x');
      expect(ok, isTrue, reason: 'should succeed');
      expect(err, equals(0), reason: 'should have 0 errors');
    });

    test('E11-Optional match', () {
      final (ok, err, _) = testParse('S <- "x"? ;', 'x');
      expect(ok, isTrue, reason: 'should succeed');
      expect(err, equals(0), reason: 'should have 0 errors');
    });

    test('E12-Two chars match', () {
      final (ok, err, _) = testParse('S <- "xy" ;', 'xy');
      expect(ok, isTrue, reason: 'should succeed');
      expect(err, equals(0), reason: 'should have 0 errors');
    });

    test('E13-Two chars partial', () {
      final (ok, _, _) = testParse('S <- "xy" ;', 'x');
      expect(ok, isFalse, reason: 'should fail');
    });

    test('E14-CharRange match', () {
      final (ok, err, _) = testParse('S <- [a-z] ;', 'm');
      expect(ok, isTrue, reason: 'should succeed');
      expect(err, equals(0), reason: 'should have 0 errors');
    });

    test('E15-CharRange boundary low', () {
      final (ok, err, _) = testParse('S <- [a-z] ;', 'a');
      expect(ok, isTrue, reason: 'should succeed');
      expect(err, equals(0), reason: 'should have 0 errors');
    });

    test('E16-CharRange boundary high', () {
      final (ok, err, _) = testParse('S <- [a-z] ;', 'z');
      expect(ok, isTrue, reason: 'should succeed');
      expect(err, equals(0), reason: 'should have 0 errors');
    });

    test('E17-CharRange fail low', () {
      final (ok, _, _) = testParse('S <- [b-y] ;', 'a');
      expect(ok, isFalse, reason: 'should fail');
    });

    test('E18-CharRange fail high', () {
      final (ok, _, _) = testParse('S <- [b-y] ;', 'z');
      expect(ok, isFalse, reason: 'should fail');
    });

    test('E19-AnyChar match', () {
      final (ok, err, _) = testParse('S <- . ;', 'x');
      expect(ok, isTrue, reason: 'should succeed');
      expect(err, equals(0), reason: 'should have 0 errors');
    });

    test('E20-AnyChar empty', () {
      final (ok, _, _) = testParse('S <- . ;', '');
      expect(ok, isFalse, reason: 'should fail');
    });

    test('E21-Seq single', () {
      final (ok, err, _) = testParse('S <- ("x") ;', 'x');
      expect(ok, isTrue, reason: 'should succeed');
      expect(err, equals(0), reason: 'should have 0 errors');
    });

    test('E22-First single', () {
      final (ok, err, _) = testParse('S <- "x" ;', 'x');
      expect(ok, isTrue, reason: 'should succeed');
      expect(err, equals(0), reason: 'should have 0 errors');
    });

    test('E23-Nested empty', () {
      final (ok, err, _) = testParse('S <- "a"? "b"? ;', '');
      expect(ok, isTrue, reason: 'should succeed');
      expect(err, equals(0), reason: 'should have 0 errors');
    });

    test('E24-ZeroOrMore multi', () {
      final (ok, err, _) = testParse('S <- "x"* ;', 'xxx');
      expect(ok, isTrue, reason: 'should succeed');
      expect(err, equals(0), reason: 'should have 0 errors');
    });

    test('E25-OneOrMore multi', () {
      final (ok, err, _) = testParse('S <- "x"+ ;', 'xxx');
      expect(ok, isTrue, reason: 'should succeed');
      expect(err, equals(0), reason: 'should have 0 errors');
    });

    test('E26-Long string match', () {
      final (ok, err, _) = testParse('S <- "abcdefghij" ;', 'abcdefghij');
      expect(ok, isTrue, reason: 'should succeed');
      expect(err, equals(0), reason: 'should have 0 errors');
    });

    test('E27-Long string partial', () {
      final (ok, _, _) = testParse('S <- "abcdefghij" ;', 'abcdefghi');
      expect(ok, isFalse, reason: 'should fail');
    });
  });
}
