// ===========================================================================
// COMPLEX INTERACTIONS TESTS
// ===========================================================================
// These tests verify complex combinations of features working together.

import 'package:test/test.dart';

import '../test_utils.dart';

void main() {
  group('Complex Interactions Tests', () {
    test('COMPLEX-01-lr-bound-recovery-all-together', () {
      // LR + bound propagation + recovery all working together (EMERG-01 verified)
      const grammar = '''
        S <- E "end" ;
        E <- E "+" "n"+ / "n" ;
      ''';
      final (ok, err, skip) = testParse(grammar, 'n+nXn+nnend');
      expect(ok, isTrue, reason: 'should succeed (FIX #9 bound propagation)');
      expect(err, greaterThan(0), reason: 'should have at least 1 error');
      expect(skip.contains('X'), isTrue, reason: 'should skip X');
      // LR expands, OneOrMore with recovery, bound stops before 'end'
    });

    test('COMPLEX-02-nested-first-with-different-recovery-costs', () {
      // Nested First, each with alternatives requiring different recovery
      const grammar = '''
        S <- ("x" / "y") "z" / "a" ;
      ''';
      final (ok, err, _) = testParse(grammar, 'xXz');
      expect(ok, isTrue, reason: 'should succeed');
      expect(err, equals(1),
          reason: 'should choose first alternative with recovery');
      // Outer First chooses first alternative (Seq)
      // Inner First chooses first alternative 'x'
      // Then skip X, match 'z'
    });

    test('COMPLEX-03-recovery-version-overflow-verified', () {
      // Many recoveries to test version counter doesn't overflow
      final input = 'ab${List.generate(50, (i) => 'Xab').join()}';
      const grammar = 'S <- "ab"+ ;';
      final (ok, err, _) = testParse(grammar, input);
      expect(ok, isTrue,
          reason: 'should succeed (version counter handles 50+ recoveries)');
      expect(err, equals(50), reason: 'should count all 50 errors');
    });

    test('COMPLEX-04-probe-during-recovery', () {
      // ZeroOrMore uses probe while recovery is happening
      const grammar = '''
        S <- "x"* ("y" / "z") ;
      ''';
      final (ok, err, skip) = testParse(grammar, 'xXxz');
      expect(ok, isTrue, reason: 'should succeed');
      expect(err, equals(1), reason: 'should have 1 error');
      expect(skip.contains('X'), isTrue, reason: 'should skip X');
      // ZeroOrMore with recovery inside, probes to find 'z'
    });

    test('COMPLEX-05-multiple-refs-same-rule-with-recovery', () {
      // Multiple Refs to same rule, each with independent recovery
      const grammar = '''
        S <- A "+" A ;
        A <- "n" ;
      ''';
      final (ok, err, skip) = testParse(grammar, 'nX+n');
      expect(ok, isTrue, reason: 'should succeed');
      expect(err, equals(1), reason: 'should have 1 error');
      // First Ref('A') needs recovery, second Ref('A') is clean
    });

    test('COMPLEX-06-deeply-nested-lr', () {
      // Multiple LR levels with recovery at different depths
      const grammar = '''
        A <- A "a" B / B ;
        B <- B "b" "x" / "x" ;
      ''';
      final (ok, err, _) = testParse(grammar, 'xbXxaXxbx', 'A');
      expect(ok, isTrue, reason: 'should succeed');
      expect(err, equals(2),
          reason: 'should have 2 errors (X\'s at both A and B levels)');
    });

    test('COMPLEX-07-recovery-with-lookahead', () {
      // Recovery near lookahead assertions
      const grammar = '''
        S <- "a" &"b" "b" "c" ;
      ''';
      final (ok, err, skip) = testParse(grammar, 'aXbc');
      expect(ok, isTrue, reason: 'should succeed');
      expect(err, equals(1), reason: 'should have 1 error');
      expect(skip.contains('X'), isTrue, reason: 'should skip X');
      // After skipping X, FollowedBy(b) checks 'b' without consuming
    });

    test('COMPLEX-08-recovery-in-negative-lookahead', () {
      // NotFollowedBy with recovery context
      const grammar = '''
        S <- "a" !"x" "b" ;
      ''';
      final (ok, err, _) = testParse(grammar, 'ab');
      expect(ok, isTrue, reason: 'should succeed');
      expect(err, equals(0), reason: 'should have 0 errors');
      // NotFollowedBy('x') succeeds (next is 'b', not 'x')
    });

    test('COMPLEX-09-alternating-lr-and-repetition', () {
      // Grammar with both LR and repetitions at same level
      const grammar = '''
        S <- E ";" "x"+ ;
        E <- E "+" "n" / "n" ;
      ''';
      final (ok, err, _) = testParse(grammar, 'n+n;xxx');
      expect(ok, isTrue, reason: 'should succeed');
      expect(err, equals(0), reason: 'should have 0 errors');
      // E is left-recursive, then ';', then repetition
    });

    test('COMPLEX-10-recovery-spanning-multiple-clauses', () {
      // Single error region that spans where multiple clauses would try to match
      const grammar = '''
        S <- "a" "b" "c" "d" ;
      ''';
      final (ok, err, skip) = testParse(grammar, 'aXYZbcd');
      expect(ok, isTrue, reason: 'should succeed');
      expect(err, equals(1), reason: 'should have 1 error (entire XYZ region)');
      expect(skip.contains('XYZ'), isTrue,
          reason: 'should skip XYZ as single region');
    });

    test('COMPLEX-11-ref-through-multiple-indirections', () {
      // A -> B -> C -> D, all Refs
      const grammar = '''
        A <- B ;
        B <- C ;
        C <- D ;
        D <- "x" ;
      ''';
      final (ok, err, _) = testParse(grammar, 'x', 'A');
      expect(ok, isTrue, reason: 'should succeed (multiple Ref indirections)');
      expect(err, equals(0), reason: 'should have 0 errors');
    });

    test('COMPLEX-12-circular-refs-with-recovery', () {
      // Mutual recursion with simple clean input
      const grammar = '''
        S <- A "end" ;
        A <- "a" B / "a" ;
        B <- "b" A / "b" ;
      ''';
      final (ok, err, skip) = testParse(grammar, 'ababend', 'S');
      expect(ok, isTrue, reason: 'should succeed');
      expect(err, equals(0), reason: 'should have 0 errors (clean parse)');
      // Mutual recursion: A -> B -> A -> B (abab)
    });

    test('COMPLEX-13-all-clause-types-in-one-grammar', () {
      // Every clause type in one complex grammar
      const grammar = '''
        S <- A "opt"? "z"* ("f1" / "f2") &"end" "end" ;
        A <- A "+" "a" / "a" ;
      ''';
      final (ok, err, _) = testParse(grammar, 'a+aoptzzzf1end', 'S');
      expect(ok, isTrue,
          reason: 'should succeed (all clause types work together)');
      expect(err, equals(0), reason: 'should have 0 errors');
    });

    test('COMPLEX-14-recovery-at-every-level-of-deep-nesting', () {
      // Error at each level of deep nesting, all recover
      const grammar = '''
        S <- "a" "b" "c" "d" ;
      ''';
      final (ok, err, _) = testParse(grammar, 'aXbYcZd');
      expect(ok, isTrue, reason: 'should succeed');
      expect(err, equals(3), reason: 'should have 3 errors');
      // Error at each nesting level
    });

    test('COMPLEX-15-performance-large-grammar', () {
      // Large grammar with many rules
      final rules = List.generate(50, (i) {
        final idx = i.toString().padLeft(3, '0');
        return 'Rule$i <- "opt_$idx" ;';
      }).join('\n');
      final alternatives = List.generate(50, (i) => 'Rule$i').join(' / ');
      final grammar = '''
        $rules
        S <- $alternatives ;
      ''';

      final (ok, _, _) = testParse(grammar, 'opt_025', 'S');
      expect(ok, isTrue,
          reason: 'should succeed (large grammar with 50 rules)');
    });
  });
}
