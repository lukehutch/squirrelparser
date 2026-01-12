// ===========================================================================
// LEFT RECURSION + RECOVERY INTERACTION TESTS
// ===========================================================================
// These tests verify that error recovery works correctly during and after
// left-recursive expansion.

import 'package:test/test.dart';

import '../test_utils.dart';

void main() {
  group('LR + Recovery Interaction Tests', () {
    test('LR-INT-01-recovery-during-base-case', () {
      // Error during LR base case - trailing captured with new invariant
      const grammar = '''
        E <- E "+" "n" / "n" ;
      ''';
      final (ok, err, skip) = testParse(grammar, 'nX', 'E');
      // Base case matches 'n', 'X' captured as trailing error
      expect(ok, isTrue, reason: 'should succeed with trailing captured');
      expect(err, equals(1), reason: 'should have 1 error (trailing X)');
      expect(skip.contains('X'), isTrue, reason: 'should skip X');
    });

    test('LR-INT-02-recovery-during-growth', () {
      // Error during LR growth phase
      const grammar = '''
        E <- E "+" "n" / "n" ;
      ''';
      final (ok, err, skip) = testParse(grammar, 'n+Xn', 'E');
      expect(ok, isTrue, reason: 'should succeed');
      expect(err, equals(1), reason: 'should have 1 error');
      expect(skip.contains('X'), isTrue, reason: 'should skip X');
      // Base: n, Growth: n + [skip X] n
    });

    test('LR-INT-03-multiple-errors-during-expansion', () {
      // Multiple errors across multiple expansion iterations
      const grammar = '''
        E <- E "+" "n" / "n" ;
      ''';
      final (ok, err, skip) = testParse(grammar, 'n+Xn+Yn+Zn', 'E');
      expect(ok, isTrue, reason: 'should succeed');
      expect(err, equals(3), reason: 'should have 3 errors');
      expect(skip.contains('X'), isTrue, reason: 'should skip X');
      expect(skip.contains('Y'), isTrue, reason: 'should skip Y');
      expect(skip.contains('Z'), isTrue, reason: 'should skip Z');
    });

    test('LR-INT-04-nested-lr-with-recovery', () {
      // E -> E + T | T, T -> T * n | n
      const grammar = '''
        E <- E "+" T / T ;
        T <- T "*" "n" / "n" ;
      ''';
      final (ok, err, skip) = testParse(grammar, 'n*Xn+n*Yn', 'E');
      expect(ok, isTrue, reason: 'should succeed');
      expect(err, equals(2),
          reason: 'should have 2 errors (X in first term, Y in second term)');
      expect(skip.contains('X'), isTrue, reason: 'should skip X');
      expect(skip.contains('Y'), isTrue, reason: 'should skip Y');
    });

    test('LR-INT-05-lr-expansion-stops-on-trailing-error', () {
      // LR expands as far as possible, trailing captured with new invariant
      const grammar = '''
        E <- E "+" "n" / "n" ;
      ''';
      final (ok, err, skip) = testParse(grammar, 'n+n+nX', 'E');
      // Expansion: n, n+n, n+n+n (len=5), then 'X' captured as trailing
      expect(ok, isTrue, reason: 'should succeed with trailing captured');
      expect(err, equals(1), reason: 'should have 1 error (trailing X)');
      expect(skip.contains('X'), isTrue, reason: 'should skip X');
    });

    test('LR-INT-06-cache-invalidation-during-recovery', () {
      // Phase 1: E@0 marked incomplete
      // Phase 2: E@0 must re-expand with recovery
      const grammar = '''
        E <- E "+" "n" / "n" ;
      ''';
      final (ok, err, skip) = testParse(grammar, 'n+Xn', 'E');
      expect(ok, isTrue, reason: 'should succeed');
      expect(err, equals(1), reason: 'should have 1 error');
      expect(skip.contains('X'), isTrue, reason: 'should skip X');
      // FIX #6: Cache must be invalidated for LR re-expansion
    });

    test('LR-INT-07-lr-with-repetition-and-recovery', () {
      // E -> E + n+ | n (nested repetition in LR)
      const grammar = '''
        E <- E "+" "n"+ / "n" ;
      ''';
      final (ok, err, skip) = testParse(grammar, 'n+nXnn', 'E');
      expect(ok, isTrue, reason: 'should succeed');
      expect(err, equals(1), reason: 'should have 1 error');
      expect(skip.contains('X'), isTrue, reason: 'should skip X in n+');
    });

    test('LR-INT-08-isFromLRContext-flag', () {
      // Successful LR results are marked with isFromLRContext
      // But this shouldn't prevent parent recovery (FIX #1)
      const grammar = '''
        S <- E "end" ;
        E <- E "+" "n" / "n" ;
      ''';
      final (ok, _, _) = testParse(grammar, 'n+nend');
      expect(ok, isTrue, reason: 'should succeed');
      // E is left-recursive and successful, marked with isFromLRContext
      // But 'end' should still match (FIX #1: only MISMATCH blocks recovery)
    });

    test('LR-INT-09-failed-lr-doesnt-block-recovery', () {
      // Failed LR (MISMATCH) should NOT be marked isFromLRContext
      // This allows parent to attempt recovery
      const grammar = '''
        S <- E "x" ;
        E <- E "+" "n" / "n" ;
      ''';

      // Input where E succeeds with recovery, then x matches
      final (ok, err, skip) = testParse(grammar, 'nXnx');
      expect(ok, isTrue, reason: 'should succeed');
      expect(err, equals(1), reason: 'should have 1 error (skip X)');
      // E matches 'nXn' with recovery, then 'x' matches
    });

    test('LR-INT-10-deep-lr-nesting', () {
      // Multiple levels of LR with recovery at each level
      const grammar = '''
        S <- S "a" T / T ;
        T <- T "b" "x" / "x" ;
      ''';
      final (ok, err, _) = testParse(grammar, 'xbXxaXxbx', 'S');
      expect(ok, isTrue, reason: 'should succeed');
      expect(err, equals(2), reason: 'should have 2 errors (X at both levels)');
      // Complex nesting: S and T both left-recursive, errors at both levels
    });
  });
}
