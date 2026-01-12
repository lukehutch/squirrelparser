// ===========================================================================
// REPETITION EDGE CASE TESTS
// ===========================================================================
// These tests verify edge cases in repetition handling including nested
// repetitions, probe mechanics, and boundary interactions.

import 'package:test/test.dart';

import '../test_utils.dart';

void main() {
  group('Repetition Edge Case Tests', () {
    test('REP-01-zeoormore-empty-match', () {
      // ZeroOrMore can match zero times
      final (ok, err, _) = testParse(
        'S <- "x"* "y" ;',
        'y',
      );
      expect(ok, isTrue, reason: 'should succeed (ZeroOrMore matches 0)');
      expect(err, equals(0), reason: 'should have 0 errors');
    });

    test('REP-02-oneormore-vs-zeoormore-at-eof', () {
      // OneOrMore requires at least one match, ZeroOrMore doesn't
      final om = testParse('S <- "x"+ ;', '');
      expect(om.$1, isFalse, reason: 'OneOrMore should fail on empty input');

      final zm = testParse('S <- "x"* ;', '');
      expect(zm.$1, isTrue, reason: 'ZeroOrMore should succeed on empty input');
    });

    test('REP-03-nested-repetition', () {
      // OneOrMore(OneOrMore(x)) - nested repetitions
      final (ok, err, _) = testParse(
        'S <- ("x"+)+ ;',
        'xxxXxxXxxx',
      );
      expect(ok, isTrue, reason: 'should succeed');
      expect(err, equals(2), reason: 'should have 2 errors (two X gaps)');
      // Outer: matches 3 times (group1, skip X, group2, skip X, group3)
      // Each group is inner OneOrMore matching x's
    });

    test('REP-04-repetition-with-recovery-hits-bound', () {
      // Repetition with recovery, encounters bound
      final (ok, err, skip) = testParse(
        'S <- "x"+ "end" ;',
        'xXxXxend',
      );
      expect(ok, isTrue, reason: 'should succeed');
      expect(err, equals(2), reason: 'should have 2 errors');
      expect(skip.length, equals(2), reason: 'should skip 2 X\'s');
      // Repetition stops before 'end' (bound)
    });

    test('REP-05-repetition-recovery-vs-probe', () {
      // ZeroOrMore must probe ahead to avoid consuming boundary
      final (ok, err, _) = testParse(
        'S <- "x"* "y" ;',
        'xxxy',
      );
      expect(ok, isTrue, reason: 'should succeed');
      expect(err, equals(0), reason: 'should have 0 errors');
      // ZeroOrMore should match all x's, stop before 'y'
    });

    test('REP-06-alternating-match-skip-pattern', () {
      // Pattern: match, skip, match, skip, ...
      final (ok, err, _) = testParse(
        'S <- "ab"+ ;',
        'abXabXabXab',
      );
      expect(ok, isTrue, reason: 'should succeed');
      expect(err, equals(3), reason: 'should have 3 errors (3 X\'s)');
    });

    test('REP-07-repetition-of-complex-structure', () {
      // OneOrMore(Seq([...])) - repetition of sequences
      final (ok, err, _) = testParse(
        'S <- ("a" "b")+ ;',
        'ababab',
      );
      expect(ok, isTrue, reason: 'should succeed');
      expect(err, equals(0), reason: 'should have 0 errors');
      // Matches 3 times: (a,b), (a,b), (a,b)
    });

    test('REP-08-repetition-stops-on-non-match', () {
      // Repetition stops when element no longer matches
      final (ok, err, _) = testParse(
        'S <- "x"+ "y" ;',
        'xxxy',
      );
      expect(ok, isTrue, reason: 'should succeed');
      expect(err, equals(0), reason: 'should have 0 errors');
      // OneOrMore matches 3 x's, stops, then 'y' matches
    });

    test('REP-09-repetition-with-first-alternative', () {
      // OneOrMore(First([...])) - repetition of alternatives
      final (ok, err, _) = testParse(
        'S <- ("a" / "b")+ ;',
        'aabba',
      );
      expect(ok, isTrue, reason: 'should succeed');
      expect(err, equals(0), reason: 'should have 0 errors');
      // Matches 5 times: a, a, b, b, a
    });

    test('REP-10-zeoormore-with-recovery-inside', () {
      // ZeroOrMore element needs recovery
      final (ok, err, skip) = testParse(
        'S <- ("a" "b")* ;',
        'abXaYb',
      );
      expect(ok, isTrue, reason: 'should succeed');
      expect(err, equals(2), reason: 'should have 2 errors');
      // First iteration: a, b (clean)
      // Second iteration: a, [skip X], a, [skip Y], b
      // Wait, that's not right. Let me think...
      // Actually: ZeroOrMore tries Seq([a, b]) repeatedly
      // Iteration 1: "ab" matches cleanly
      // Iteration 2: tries at position 2, sees "Xa", Seq needs recovery
      //   Within Seq: 'a' expects 'a' at pos 2, sees 'X', skip X, match 'a' at pos 3
      //   Then 'b' expects 'b' at pos 4, sees 'Y', skip Y, match 'b' at pos 5
      // So yes, 2 errors total
    });

    test('REP-11-greedy-vs-non-greedy', () {
      // Repetitions are greedy - match as many as possible
      final (ok, err, _) = testParse(
        'S <- "x"* "y" "z" ;',
        'xxxxxyz',
      );
      expect(ok, isTrue, reason: 'should succeed');
      expect(err, equals(0), reason: 'should have 0 errors');
      // ZeroOrMore is greedy, matches all x's, then y and z
    });

    test('REP-12-repetition-at-eof-with-deletion', () {
      // Repetition at EOF can have grammar deletion (completion)
      final (ok, _, _) = testParse(
        'S <- "a" "b"+ ;',
        'a',
      );
      expect(ok, isTrue, reason: 'should succeed (delete b+ at EOF)');
      // At EOF, can delete the OneOrMore requirement
    });

    test('REP-13-very-long-repetition', () {
      // Performance test: many iterations
      final input = 'x' * 1000;
      final (ok, err, _) = testParse('S <- "x"+ ;', input);
      expect(ok, isTrue, reason: 'should succeed (1000 iterations)');
      expect(err, equals(0), reason: 'should have 0 errors');
    });

    test('REP-14-repetition-with-many-errors', () {
      // Many errors within repetition
      final input = List.generate(100, (i) => 'Xx').join();
      final (ok, err, _) = testParse('S <- "x"+ ;', input);
      expect(ok, isTrue, reason: 'should succeed');
      expect(err, equals(100), reason: 'should have 100 errors');
    });

    test('REP-15-nested-zeoormore', () {
      // ZeroOrMore(ZeroOrMore(...)) - both can match zero
      final (ok, err, _) = testParse(
        'S <- ("x"*)* "y" ;',
        'y',
      );
      expect(ok, isTrue, reason: 'should succeed (both match 0)');
      expect(err, equals(0), reason: 'should have 0 errors');
    });
  });
}
