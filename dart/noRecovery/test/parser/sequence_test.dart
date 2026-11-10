// ===========================================================================
// SECTION 7: SEQUENCE COMPREHENSIVE (20 tests)
// ===========================================================================

import 'package:squirrel_parser/squirrel_parser.dart';
import 'package:test/test.dart';

import '../test_utils.dart';

void main() {
  test('S01-2 elem', () {
    final (ok, err, _) = testParse(
      'S <- "a" "b" ;',
      'ab',
    );
    expect(ok, isTrue, reason: 'should succeed');
    expect(err, equals(0), reason: 'should have 0 errors');
  });

  test('S02-3 elem', () {
    final (ok, err, _) = testParse(
      'S <- "a" "b" "c" ;',
      'abc',
    );
    expect(ok, isTrue, reason: 'should succeed');
    expect(err, equals(0), reason: 'should have 0 errors');
  });

  test('S03-5 elem', () {
    final (ok, err, _) = testParse(
      'S <- "a" "b" "c" "d" "e" ;',
      'abcde',
    );
    expect(ok, isTrue, reason: 'should succeed');
    expect(err, equals(0), reason: 'should have 0 errors');
  });

  test('S06-del mid', () {
    // Cannot delete grammar elements mid-parse (Fix #8 - Visibility Constraint)
    // Input "ac" with grammar "a" "b" "c" would require deleting "b" at position 1
    // Position 1 is not EOF (still have "c" to parse), so this violates constraints
    final parseResult = squirrelParsePT(
      grammarSpec: 'S <- "a" "b" "c" ;',
      topRuleName: 'S',
      input: 'ac',
    );
    final result = parseResult.root;
    // Should fail - cannot delete "b" mid-parse
    // Total failure: result is SyntaxError spanning entire input
    expect(result is SyntaxError, isTrue,
        reason:
            'should fail (mid-parse grammar deletion violates Visibility Constraint)');
  });

  test('S08-nested clean', () {
    final (ok, err, _) = testParse(
      'S <- ("a" "b") "c" ;',
      'abc',
    );
    expect(ok, isTrue, reason: 'should succeed');
    expect(err, equals(0), reason: 'should have 0 errors');
  });

  test('S10-long seq clean', () {
    final (ok, err, _) = testParse(
      'S <- "a" "b" "c" "d" "e" "f" "g" "h" "i" "j" "k" "l" "m" "n" "o" "p" ;',
      'abcdefghijklmnop',
    );
    expect(ok, isTrue, reason: 'should succeed');
    expect(err, equals(0), reason: 'should have 0 errors');
  });
}
