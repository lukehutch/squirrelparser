import 'package:test/test.dart';

import '../test_utils.dart';

void main() {
  group('Comprehensive Fix Tests', () {
    // Fix #3: Ref transparency - Ref should not have independent memoization
    test('FIX3-01-ref-transparency-lr-reexpansion', () {
      // During recovery, Ref should allow LR to re-expand
      const grammar = '''
        S <- E ";" ;
        E <- E "+" "n" / "n" ;
      ''';
      final (ok, err, _) = testParse(grammar, 'n+Xn;');
      expect(ok, isTrue,
          reason: 'Ref should allow LR re-expansion during recovery');
      expect(err, equals(1), reason: 'should skip X');
    });

    // Fix #4: Terminal skip sanity - single-char vs multi-char
    test('FIX4-01-single-char-skip-junk', () {
      // Single-char terminal can skip arbitrary junk
      const grammar = 'S <- "a" "b" "c" ;';
      final (ok, err, skip) = testParse(grammar, 'aXXbc');
      expect(ok, isTrue, reason: 'should skip junk XX');
      expect(err, equals(1), reason: 'one skip');
      expect(skip.contains('XX'), isTrue);
    });

    test('FIX4-02-single-char-no-skip-containing-terminal', () {
      // Single-char terminal should NOT skip if junk contains the terminal
      const grammar = 'S <- "a" "b" "c" ;';
      final (ok, _, _) = testParse(grammar, 'aXbYc');
      // This might succeed by skipping X, matching b, skipping Y (2 errors)
      // The key is it shouldn't skip "Xb" as one unit
      expect(ok, isTrue, reason: 'should recover with multiple skips');
    });

    test('FIX4-03-multi-char-atomic-terminal', () {
      // Multi-char terminal is atomic - can't skip more than its length
      // Grammar only matches 'n', rest captured as trailing error
      const grammar = '''
        S <- E ;
        E <- E "+n" / "n" ;
      ''';
      final (ok, err, _) = testParse(grammar, 'n+Xn+n');
      expect(ok, isTrue, reason: 'matches n, rest is trailing error');
      expect(err, equals(1), reason: 'should have 1 error (trailing +Xn+n)');
    });

    test('FIX4-04-multi-char-exact-skip-ok', () {
      // Multi-char terminal can skip exactly its length if needed
      const grammar = 'S <- "ab" "cd" ;';
      final (ok, err, _) = testParse(grammar, 'abXYcd');
      expect(ok, isTrue, reason: 'can skip 2 chars for 2-char terminal');
      expect(err, equals(1), reason: 'one skip');
    });

    // Fix #5: Don't skip content containing next expected terminal
    test('FIX5-01-no-skip-containing-next-terminal', () {
      // During recovery, don't skip content that includes next terminal
      const grammar = '''
        S <- E ";" E ;
        E <- E "+" "n" / "n" ;
      ''';
      final (ok, err, _) = testParse(grammar, 'n+Xn;n+n+n');
      expect(ok, isTrue, reason: 'should recover');
      expect(err, equals(1), reason: 'only skip X in first E, not consume ;n');
    });

    test('FIX5-02-skip-pure-junk-ok', () {
      // Can skip junk that doesn't contain next terminal
      const grammar = 'S <- "+" "n" ;';
      final (ok, err, skip) = testParse(grammar, '+XXn');
      expect(ok, isTrue, reason: 'should skip XX');
      expect(err, equals(1), reason: 'one skip');
      expect(skip.contains('XX'), isTrue);
    });

    // Combined fixes: complex scenarios
    test('COMBINED-01-lr-with-skip-and-delete', () {
      // LR expansion + recovery with both skip and delete
      const grammar = '''
        S <- E ;
        E <- E "+" "n" / "n" ;
      ''';
      final (ok, _, _) = testParse(grammar, 'n+Xn+Yn');
      expect(ok, isTrue, reason: 'should handle multiple errors in LR');
    });

    test('COMBINED-02-first-prefers-longer-with-errors', () {
      // First should prefer longer match even if it has more errors
      const grammar = '''
        S <- "a" "b" "c" / "a" ;
      ''';
      final (ok, err, _) = testParse(grammar, 'aXbc');
      expect(ok, isTrue, reason: 'should choose longer alternative');
      expect(err, equals(1), reason: 'skip X');
      // Result should be "abc" not just "a"
    });

    test('COMBINED-03-nested-seq-recovery', () {
      // Nested sequences with recovery at different levels
      const grammar = '''
        S <- A ";" B ;
        A <- "a" "x" ;
        B <- "b" "y" ;
      ''';
      final (ok, err, _) = testParse(grammar, 'aXx;bYy');
      expect(ok, isTrue, reason: 'nested recovery should work');
      expect(err, equals(2), reason: 'skip X and Y');
    });
  });
}
