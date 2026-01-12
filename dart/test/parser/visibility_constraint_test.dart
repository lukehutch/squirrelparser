// ===========================================================================
// VISIBILITY CONSTRAINT TESTS (FIX #8 Verification)
// ===========================================================================
// These tests verify that parse trees match visible input structure and that
// grammar deletion (inserting missing elements) only occurs at EOF.

import 'package:squirrel_parser/squirrel_parser.dart';
import 'package:test/test.dart';

import '../test_utils.dart';

void main() {
  group('Visibility Constraint Tests', () {
    test('VIS-01-terminal-atomicity', () {
      // Multi-char terminals are atomic - can't skip through them
      final parseResult = squirrelParsePT(
        grammarSpec: 'S <- "abc" "def" ;',
        topRuleName: 'S',
        input: 'abXdef',
      );
      final result = parseResult.root;
      // Should fail - can't match 'abc' with 'abX', and can't skip 'X' mid-terminal
      // Total failure: result is a SyntaxError spanning entire input
      expect(result is SyntaxError, isTrue,
          reason: 'should fail (cannot skip within multi-char terminal)');
    });

    test('VIS-02-grammar-deletion-at-eof', () {
      // Grammar deletion (completion) allowed at EOF
      final (ok, del, _) = testParse(
        'S <- "a" "b" "c" ;',
        'ab',
      );
      expect(ok, isTrue, reason: 'should succeed (delete c at EOF)');
      expect(
          countDeletions([squirrelParsePT(
            grammarSpec: 'S <- "a" "b" "c" ;',
            topRuleName: 'S',
            input: 'ab',
          ).root]),
          equals(1),
          reason: 'should have 1 deletion');
    });

    test('VIS-03-grammar-deletion-mid-parse-forbidden', () {
      // Grammar deletion NOT allowed mid-parse (FIX #8)
      final parseResult = squirrelParsePT(
        grammarSpec: 'S <- "a" "b" "c" ;',
        topRuleName: 'S',
        input: 'ac',
      );
      final result = parseResult.root;
      // Should fail - cannot delete 'b' at position 1 (not EOF)
      // Total failure: result is a SyntaxError spanning entire input
      expect(result is SyntaxError, isTrue,
          reason:
              'should fail (mid-parse grammar deletion violates Visibility Constraint)');
    });

    test('VIS-04-tree-structure-matches-visible-input', () {
      // Parse tree structure should match visible input structure
      final (ok, err, skip) = testParse(
        'S <- "a" "b" "c" ;',
        'aXbc',
      );
      expect(ok, isTrue, reason: 'should succeed');
      expect(err, equals(1), reason: 'should have 1 error');
      expect(skip.contains('X'), isTrue, reason: 'should skip X');
      // Visible input: a, X, b, c (4 elements)
      // Tree: a, SyntaxError(X), b, c (4 nodes)
    });

    test('VIS-05-hidden-deletion-creates-mismatch', () {
      // First tries alternatives; Seq needs 'b' but input is just 'a'
      final parseResult = squirrelParsePT(
        grammarSpec: 'S <- "a" "b" / "c" ;',
        topRuleName: 'S',
        input: 'a',
      );
      final result = parseResult.root;
      // First alternative: Try Seq - 'a' matches, 'b' missing at EOF
      //   - Could delete 'b' at EOF, but that gives len=1
      // Second alternative: Try 'c' - fails (input is 'a')
      // Should pick first alternative with completion
      // Result always spans input, so check it's not a total failure
      expect(result is! SyntaxError, isTrue,
          reason: 'should succeed (first alternative with EOF deletion)');
      // With new invariant, result.len == input.length always
      expect(result.len, equals(1), reason: 'should consume 1 char (a)');
    });

    test('VIS-06-multiple-consecutive-skips', () {
      // Multiple consecutive errors should be merged into one region
      final (ok, err, skip) = testParse(
        'S <- "a" "b" "c" ;',
        'aXXXXbc',
      );
      expect(ok, isTrue, reason: 'should succeed');
      expect(err, equals(1),
          reason: 'should have 1 error (entire XXXX region)');
      expect(skip.contains('XXXX'), isTrue,
          reason: 'should skip XXXX as one region');
    });

    test('VIS-07-alternating-content-and-errors', () {
      // Pattern: valid, error, valid, error, valid, error, valid
      final (ok, err, skip) = testParse(
        'S <- "a" "b" "c" "d" ;',
        'aXbYcZd',
      );
      expect(ok, isTrue, reason: 'should succeed');
      expect(err, equals(3), reason: 'should have 3 errors');
      expect(skip.contains('X'), isTrue, reason: 'should skip X');
      expect(skip.contains('Y'), isTrue, reason: 'should skip Y');
      expect(skip.contains('Z'), isTrue, reason: 'should skip Z');
      // Tree: [a, SyntaxError(X), b, SyntaxError(Y), c, SyntaxError(Z), d]
    });

    test('VIS-08-completion-vs-correction', () {
      // Completion (EOF): "user hasn't finished typing" - allowed
      final comp = testParse(
        'S <- "if" "(" "x" ")" ;',
        'if(x',
      );
      expect(comp.$1, isTrue, reason: 'completion should succeed');

      // Correction (mid-parse): "user typed wrong thing" - NOT allowed via grammar deletion
      final corrResult = squirrelParsePT(
        grammarSpec: 'S <- "if" "(" "x" ")" ;',
        topRuleName: 'S',
        input: 'if()',
      );
      // Would need to delete 'x' at position 3, but ')' remains - not EOF
      final result = corrResult.root;
      // Total failure: result is a SyntaxError spanning entire input
      expect(result is SyntaxError, isTrue,
          reason: 'mid-parse correction should fail');
    });

    test('VIS-09-structural-integrity', () {
      // Tree must reflect what user sees, not what we wish they typed
      final (ok, err, _) = testParse(
        'S <- "(" "E" ")" ;',
        'E)',
      );
      // User sees: E, )
      // Should NOT reinterpret as: (, E, ) by "inserting" ( at start
      // Should fail - cannot delete '(' mid-parse
      expect(ok, isFalse,
          reason: 'should fail (cannot reorganize visible structure)');
    });

    test('VIS-10-visibility-with-nested-structures', () {
      // Nested Seq - errors at each level should preserve visibility
      final (ok, err, skip) = testParse(
        'S <- ("a" "b") "c" ;',
        'aXbc',
      );
      expect(ok, isTrue, reason: 'should succeed');
      expect(err, equals(1), reason: 'should have 1 error');
      expect(skip.contains('X'), isTrue, reason: 'should skip X in inner Seq');
    });
  });
}
