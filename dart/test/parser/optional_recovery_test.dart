// ===========================================================================
// OPTIONAL WITH RECOVERY TESTS
// ===========================================================================
// These tests verify Optional behavior with and without recovery.

import 'package:test/test.dart';

import '../test_utils.dart';

void main() {
  group('Optional Recovery Tests', () {
    test('OPT-01-optional-matches-cleanly', () {
      // Optional matches its content cleanly
      final (ok, err, _) = testParse('S <- "a"? "b" ;', 'ab');
      expect(ok, isTrue, reason: 'should succeed');
      expect(err, equals(0), reason: 'should have 0 errors');
      // Optional matches 'a', then 'b'
    });

    test('OPT-02-optional-falls-through-cleanly', () {
      // Optional doesn't match, falls through
      final (ok, err, _) = testParse('S <- "a"? "b" ;', 'b');
      expect(ok, isTrue, reason: 'should succeed');
      expect(err, equals(0), reason: 'should have 0 errors');
      // Optional returns empty match (len=0), then 'b' matches
    });

    test('OPT-03-optional-with-recovery-attempt', () {
      // Optional content needs recovery - should Optional try recovery or fall through?
      // Current behavior: Optional tries recovery
      final (ok, err, skip) = testParse('S <- ("a" "b")? ;', 'aXb');
      expect(ok, isTrue, reason: 'should succeed');
      // If Optional attempts recovery: err=1, skip=['X']
      // If Optional falls through: err=0, but incomplete parse
      expect(err, equals(1), reason: 'Optional should attempt recovery');
      expect(skip.contains('X'), isTrue, reason: 'should skip X');
    });

    test('OPT-04-optional-in-sequence', () {
      // Optional in middle of sequence
      final (ok, err, _) = testParse('S <- "a" "b"? "c" ;', 'ac');
      expect(ok, isTrue, reason: 'should succeed');
      expect(err, equals(0), reason: 'should have 0 errors');
      // 'a' matches, Optional falls through, 'c' matches
    });

    test('OPT-05-nested-optional', () {
      // Optional(Optional(...))
      final (ok, err, _) = testParse('S <- "a"?? "b" ;', 'b');
      expect(ok, isTrue, reason: 'should succeed');
      expect(err, equals(0), reason: 'should have 0 errors');
      // Both optionals return empty
    });

    test('OPT-06-optional-with-first', () {
      // Optional(First([...]))
      final (ok, err, _) = testParse('S <- ("a" / "b")? "c" ;', 'bc');
      expect(ok, isTrue, reason: 'should succeed');
      expect(err, equals(0), reason: 'should have 0 errors');
      // Optional matches First's second alternative 'b'
    });

    test('OPT-07-optional-with-repetition', () {
      // Optional(OneOrMore(...))
      final (ok, err, _) = testParse('S <- "x"+? "y" ;', 'xxxy');
      expect(ok, isTrue, reason: 'should succeed');
      expect(err, equals(0), reason: 'should have 0 errors');
      // Optional matches OneOrMore which matches 3 x's
    });

    test('OPT-08-optional-at-eof', () {
      // Optional at end of grammar
      final (ok, err, _) = testParse('S <- "a" "b"? ;', 'a');
      expect(ok, isTrue, reason: 'should succeed');
      expect(err, equals(0), reason: 'should have 0 errors');
      // 'a' matches, Optional at EOF returns empty
    });

    test('OPT-09-multiple-optionals', () {
      // Multiple optionals in sequence
      final (ok, err, _) = testParse('S <- "a"? "b"? "c" ;', 'c');
      expect(ok, isTrue, reason: 'should succeed');
      expect(err, equals(0), reason: 'should have 0 errors');
      // Both optionals return empty, 'c' matches
    });

    test('OPT-10-optional-vs-zeoormore', () {
      // Optional(Str(x)) vs ZeroOrMore(Str(x))
      // Optional: matches 0 or 1 time
      // ZeroOrMore: matches 0 or more times
      final opt = testParse('S <- "x"? "y" ;', 'xxxy');
      // Optional matches first 'x', remaining "xxy" for rest
      // Str('y') sees "xxy", uses recovery to skip "xx", matches 'y'
      expect(opt.$1, isTrue,
          reason: 'Optional matches 1, recovery handles rest');
      expect(opt.$2, equals(1), reason: 'should have 1 error (skipped xx)');

      final zm = testParse('S <- "x"* "y" ;', 'xxxy');
      expect(zm.$1, isTrue, reason: 'ZeroOrMore matches all 3, then y');
      expect(zm.$2, equals(0), reason: 'should have 0 errors (clean match)');
    });

    test('OPT-11-optional-with-complex-content', () {
      // Optional(Seq([complex structure]))
      final (ok, err, _) = testParse(
        'S <- ("if" "(" "x" ")")? "body" ;',
        'if(x)body',
      );
      expect(ok, isTrue, reason: 'should succeed');
      expect(err, equals(0), reason: 'should have 0 errors');
    });

    test('OPT-12-optional-incomplete-phase1', () {
      // In Phase 1, if Optional's content is incomplete, should Optional be marked incomplete?
      // This is testing the "mark Optional fallback incomplete" (Modification 5)
      final (ok, _, _) = testParse('S <- "a"? "b" ;', 'Xb');
      // Phase 1: Optional tries 'a' at 0, sees 'X', fails
      //   Optional falls through (returns empty), marked incomplete
      // Phase 2: Re-evaluates, Optional might try recovery? Or still fall through?
      expect(ok, isTrue, reason: 'should succeed');
      // If Optional tries recovery in Phase 2, would skip X and fail to find 'a'
      // Then falls through, 'b' matches
    });
  });
}
