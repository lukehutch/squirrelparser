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

  test('S04-insert mid', () {
    final (ok, err, skip) = testParse(
      'S <- "a" "b" "c" ;',
      'aXXbc',
    );
    expect(ok, isTrue, reason: 'should succeed');
    expect(err, equals(1), reason: 'should have 1 error');
    expect(skip.contains('XX'), isTrue, reason: 'should skip XX');
  });

  test('S05-insert end', () {
    final (ok, err, skip) = testParse(
      'S <- "a" "b" "c" ;',
      'abXXc',
    );
    expect(ok, isTrue, reason: 'should succeed');
    expect(err, equals(1), reason: 'should have 1 error');
    expect(skip.contains('XX'), isTrue, reason: 'should skip XX');
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

  test('S07-del end', () {
    final parseResult = squirrelParsePT(
      grammarSpec: 'S <- "a" "b" "c" ;',
      topRuleName: 'S',
      input: 'ab',
    );
    final result = parseResult.root;
    expect(!result.isMismatch, isTrue, reason: 'should succeed');
    expect(countDeletions([result]) == 1, isTrue,
        reason: 'should have 1 deletion');
  });

  test('S08-nested clean', () {
    final (ok, err, _) = testParse(
      'S <- ("a" "b") "c" ;',
      'abc',
    );
    expect(ok, isTrue, reason: 'should succeed');
    expect(err, equals(0), reason: 'should have 0 errors');
  });

  test('S09-nested insert', () {
    final (ok, err, skip) = testParse(
      'S <- ("a" "b") "c" ;',
      'aXbc',
    );
    expect(ok, isTrue, reason: 'should succeed');
    expect(err, equals(1), reason: 'should have 1 error');
    expect(skip.contains('X'), isTrue, reason: 'should skip X');
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
