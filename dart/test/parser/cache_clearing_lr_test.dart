// =============================================================================
// CACHE CLEARING BUG TESTS (Document 4 fix) and LR RE-EXPANSION TESTS
// =============================================================================

import 'package:squirrel_parser/squirrel_parser.dart';
import 'package:test/test.dart';

import 'test_utils.dart';

void main() {
  // ===========================================================================
  // CACHE CLEARING BUG TESTS (Document 4 fix)
  // ===========================================================================

  // --- Non-LR incomplete result must be cleared when recovery state changes ---
  // Bug: foundLeftRec && condition prevents clearing non-LR incomplete results

  group('Cache Clearing Bug Tests', () {
    final staleClearGrammar = <String, Clause>{
      'S': Seq([OneOrMore(Ref('A')), Str('z')]),
      'A': First([Str('ab'), Str('a')]),
    };

    test('F4-01-stale-nonLR-incomplete', () {
      // Phase 1: A+ matches 'a' at 0, fails at 'X'. Incomplete, len=1.
      // Phase 2: A+ should skip 'X', match 'ab', get len=4
      // Bug: stale len=1 result returned without clearing
      final r = testParse(staleClearGrammar, 'aXabz');
      expect(r.$1, isTrue, reason: 'should recover by skipping X');
      expect(r.$2, equals(1), reason: 'should have 1 error');
      expect(r.$3.any((s) => s.contains('X')), isTrue, reason: 'should skip X');
    });

    test('F4-02-stale-nonLR-incomplete-multi', () {
      // Multiple recovery points in non-LR repetition
      final r = testParse(staleClearGrammar, 'aXaYabz');
      expect(r.$1, isTrue, reason: 'should recover from multiple errors');
      expect(r.$2, equals(2), reason: 'should have 2 errors');
    });

    // --- probe() during Phase 2 must get fresh results ---
    final probeContextGrammar = <String, Clause>{
      'S': Seq([Ref('A'), Ref('B')]),
      'A': OneOrMore(Str('a')),
      'B': Seq([ZeroOrMore(Str('a')), Str('z')]),
    };

    test('F4-03-probe-context-phase2', () {
      // Bounded repetition uses probe() to check if B can match
      // probe() must not reuse stale Phase 2 results
      final r = testParse(probeContextGrammar, 'aaaXz');
      expect(r.$1, isTrue, reason: 'should recover');
      expect(r.$2, equals(1), reason: 'should have 1 error');
    });

    test('F4-04-probe-at-boundary', () {
      // Edge case: probe at exact boundary between clauses
      final r = testParse(probeContextGrammar, 'aXaz');
      expect(r.$1, isTrue, reason: 'should recover at boundary');
    });
  });

  // ===========================================================================
  // LR RE-EXPANSION TESTS (Complete LR + recovery context change)
  // ===========================================================================

  group('LR Re-expansion Tests', () {
    // --- Direct LR must re-expand in Phase 2 ---
    // NOTE: Using Seq([Str('+'), Str('n')]) instead of Str('+n') to allow
    // recovery to skip characters between '+' and 'n'.
    final directLRReexpand = <String, Clause>{
      'E': First([
        Seq([Ref('E'), Str('+'), Str('n')]),
        Str('n')
      ]),
    };

    test('F1-LR-01-reexpand-simple', () {
      // Phase 1: E matches 'n' (len=1), complete
      // Phase 2: must re-expand to skip 'X' and get 'n+n+n' (len=6)
      final r = testParse(directLRReexpand, 'n+Xn+n', 'E');
      expect(r.$1, isTrue, reason: 'LR must re-expand in Phase 2');
      expect(r.$2, equals(1), reason: 'should have 1 error');
      expect(r.$3.any((s) => s.contains('X')), isTrue, reason: 'should skip X');
    });

    test('F1-LR-02-reexpand-multiple-errors', () {
      // Multiple errors in LR expansion
      final r = testParse(directLRReexpand, 'n+Xn+Yn+n', 'E');
      expect(r.$1, isTrue, reason: 'LR should handle multiple errors');
      expect(r.$2, equals(2), reason: 'should have 2 errors');
    });

    test('F1-LR-03-reexpand-at-start', () {
      // Error between base 'n' and '+' - recovery should skip X
      final r = testParse(directLRReexpand, 'nX+n+n', 'E');
      expect(r.$1, isTrue, reason: 'should recover by skipping X');
      expect(r.$2, equals(1), reason: 'should have 1 error');
    });

    // --- Indirect LR re-expansion ---
    final indirectLRReexpand = <String, Clause>{
      'E': First([Ref('F'), Str('n')]),
      'F': Seq([Ref('E'), Str('+'), Str('n')]),
    };

    test('F1-LR-04-indirect-reexpand', () {
      final r = testParse(indirectLRReexpand, 'n+Xn+n', 'E');
      expect(r.$1, isTrue, reason: 'indirect LR must re-expand');
      expect(r.$2, equals(1), reason: 'should have 1 error');
    });

    // --- Multi-level LR (precedence grammar) ---
    final precedenceLRReexpand = <String, Clause>{
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
        Str('n')
      ]),
    };

    test('F1-LR-05-multilevel-at-T', () {
      // Error at T level requires both E and T to re-expand
      final r = testParse(precedenceLRReexpand, 'n+n*Xn', 'E');
      expect(r.$1, isTrue, reason: 'multi-level LR must re-expand correctly');
      expect(r.$2, greaterThanOrEqualTo(1),
          reason: 'should have at least 1 error');
      expect(r.$3.any((s) => s.contains('X')), isTrue, reason: 'should skip X');
    });

    test('F1-LR-06-multilevel-at-E', () {
      // Error at E level
      final r = testParse(precedenceLRReexpand, 'n+Xn*n', 'E');
      expect(r.$1, isTrue, reason: 'should recover at E level');
      expect(r.$2, greaterThanOrEqualTo(1),
          reason: 'should have at least 1 error');
    });

    test('F1-LR-07-multilevel-nested-parens', () {
      // Error inside parentheses
      final r = testParse(precedenceLRReexpand, 'n+(nX*n)', 'E');
      expect(r.$1, isTrue, reason: 'should recover inside parens');
    });

    // --- LR with probe() interaction ---
    final lrProbeGrammar = <String, Clause>{
      'S': Seq([OneOrMore(Ref('E')), Str('z')]),
      'E': First([
        Seq([Ref('E'), Str('x')]),
        Str('a')
      ]),
    };

    test('F2-LR-01-probe-during-expansion', () {
      // Repetition probes LR rule E for bounds checking
      final r = testParse(lrProbeGrammar, 'axaXz');
      expect(r.$1, isTrue, reason: 'probe of LR during Phase 2 should work');
      expect(r.$2, equals(1), reason: 'should have 1 error');
    });

    test('F2-LR-02-probe-multiple-LR', () {
      final r = testParse(lrProbeGrammar, 'axaxXz');
      expect(r.$1, isTrue,
          reason: 'should handle multiple LR matches before error');
    });
  });

  // ===========================================================================
  // recoveryVersion NECESSITY TESTS
  // ===========================================================================

  group('Recovery Version Necessity Tests', () {
    // --- Distinguish Phase 1 (v=0,e=false) from probe() in Phase 2 (v=1,e=false) ---
    // NOTE: Grammar designed so A* and B don't compete for the same characters.
    // A matches 'a', B matches 'bz'. This way skipping X and matching 'abz' works.
    final recoveryVersionGrammar = <String, Clause>{
      'S': Seq([ZeroOrMore(Ref('A')), Ref('B')]),
      'A': Str('a'),
      'B': Seq([Str('b'), Str('z')]),
    };

    test('F3-RV-01-phase1-vs-probe', () {
      // Phase 1: A* matches empty at 0 (mismatch on 'X'). B fails.
      // Phase 2: skip X, A* matches 'a', B matches 'bz'.
      final r = testParse(recoveryVersionGrammar, 'Xabz');
      expect(r.$1, isTrue, reason: 'should skip X and match abz');
      expect(r.$2, equals(1), reason: 'should have 1 error');
      expect(r.$3.any((s) => s.contains('X')), isTrue, reason: 'should skip X');
    });

    test('F3-RV-02-cached-mismatch-reuse', () {
      // Mismatch cached in Phase 1 should not poison probe() in Phase 2
      final mismatchGrammar = <String, Clause>{
        'S': Seq([ZeroOrMore(Ref('A')), Ref('B'), Str('!')]),
        'A': Str('a'),
        'B': Str('bbb'),
      };
      final r = testParse(mismatchGrammar, 'aaXbbb!');
      expect(r.$1, isTrue,
          reason: 'mismatch from Phase 1 should not block Phase 2 probe');
    });

    test('F3-RV-03-incomplete-different-versions', () {
      // Incomplete result at (v=0,e=false) vs query at (v=1,e=false)
      final incompleteGrammar = <String, Clause>{
        'S': Seq([Optional(Ref('A')), Ref('B')]),
        'A': Str('aaa'),
        'B': Seq([Str('a'), Str('z')]),
      };
      // Phase 1: A? returns incomplete empty (can't match 'X')
      // Phase 2 probe: should recompute, not reuse Phase 1's incomplete
      final r = testParse(incompleteGrammar, 'Xaz');
      expect(r.$1, isTrue,
          reason: 'should recover despite incomplete from Phase 1');
    });
  });

  // ===========================================================================
  // DEEP INTERACTION TESTS
  // ===========================================================================

  group('Deep Interaction Tests', () {
    // --- LR + bounded repetition + recovery ---
    final deepInteractionGrammar = <String, Clause>{
      'S': Seq([Ref('E'), Str(';')]),
      'E': First([
        Seq([Ref('E'), Str('+'), Ref('T')]),
        Ref('T')
      ]),
      'T': OneOrMore(Ref('F')),
      'F': First([
        Str('n'),
        Seq([Str('('), Ref('E'), Str(')')])
      ]),
    };

    test('DEEP-01-LR-bounded-recovery', () {
      // LR at E level, bounded rep at T level, recovery needed
      final r = testParse(deepInteractionGrammar, 'n+nnXn;');
      expect(r.$1, isTrue, reason: 'should recover in bounded rep under LR');
    });

    test('DEEP-02-nested-LR-recovery', () {
      // Recovery inside parenthesized expression under LR
      final r = testParse(deepInteractionGrammar, 'n+(nXn);');
      expect(r.$1, isTrue, reason: 'should recover inside nested structure');
    });

    test('DEEP-03-multiple-levels', () {
      // Errors at multiple structural levels
      final r = testParse(deepInteractionGrammar, 'nXn+nYn;');
      expect(r.$1, isTrue, reason: 'should handle errors at multiple levels');
      expect(r.$2, greaterThanOrEqualTo(2),
          reason: 'should have at least 2 errors');
    });
  });
}
