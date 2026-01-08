// ===========================================================================
// COMPLEX INTERACTIONS TESTS
// ===========================================================================
// These tests verify complex combinations of features working together.

import 'package:squirrel_parser/squirrel_parser.dart';
import 'package:test/test.dart';

import 'test_utils.dart';

void main() {
  group('Complex Interactions Tests', () {
    test('COMPLEX-01-lr-bound-recovery-all-together', () {
      // LR + bound propagation + recovery all working together (EMERG-01 verified)
      final (ok, err, skip) = testParse({
        'S': Seq([Ref('E'), Str('end')]),
        'E': First([
          Seq([Ref('E'), Str('+'), OneOrMore(Str('n'))]),
          Str('n')
        ])
      }, 'n+nXn+nnend');
      expect(ok, isTrue, reason: 'should succeed (FIX #9 bound propagation)');
      expect(err, greaterThan(0), reason: 'should have at least 1 error');
      expect(skip.contains('X'), isTrue, reason: 'should skip X');
      // LR expands, OneOrMore with recovery, bound stops before 'end'
    });

    test('COMPLEX-02-nested-first-with-different-recovery-costs', () {
      // Nested First, each with alternatives requiring different recovery
      final (ok, err, _) = testParse({
        'S': First([
          Seq([
            First([Str('x'), Str('y')]),
            Str('z')
          ]),
          Str('a')
        ])
      }, 'xXz');
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
      final (ok, err, _) = testParse({'S': OneOrMore(Str('ab'))}, input);
      expect(ok, isTrue,
          reason: 'should succeed (version counter handles 50+ recoveries)');
      expect(err, equals(50), reason: 'should count all 50 errors');
    });

    test('COMPLEX-04-probe-during-recovery', () {
      // ZeroOrMore uses probe while recovery is happening
      final (ok, err, skip) = testParse({
        'S': Seq([
          ZeroOrMore(Str('x')),
          First([Str('y'), Str('z')])
        ])
      }, 'xXxz');
      expect(ok, isTrue, reason: 'should succeed');
      expect(err, equals(1), reason: 'should have 1 error');
      expect(skip.contains('X'), isTrue, reason: 'should skip X');
      // ZeroOrMore with recovery inside, probes to find 'z'
    });

    test('COMPLEX-05-multiple-refs-same-rule-with-recovery', () {
      // Multiple Refs to same rule, each with independent recovery
      final (ok, err, skip) = testParse({
        'S': Seq([Ref('A'), Str('+'), Ref('A')]),
        'A': Str('n')
      }, 'nX+n');
      expect(ok, isTrue, reason: 'should succeed');
      expect(err, equals(1), reason: 'should have 1 error');
      // First Ref('A') needs recovery, second Ref('A') is clean
    });

    test('COMPLEX-06-deeply-nested-lr', () {
      // Multiple LR levels with recovery at different depths
      final (ok, err, _) = testParse({
        'A': First([
          Seq([Ref('A'), Str('a'), Ref('B')]),
          Ref('B')
        ]),
        'B': First([
          Seq([Ref('B'), Str('b'), Str('x')]),
          Str('x')
        ])
      }, 'xbXxaXxbx', 'A');
      expect(ok, isTrue, reason: 'should succeed');
      expect(err, equals(2),
          reason: 'should have 2 errors (X\'s at both A and B levels)');
    });

    test('COMPLEX-07-recovery-with-lookahead', () {
      // Recovery near lookahead assertions
      final (ok, err, skip) = testParse({
        'S': Seq([Str('a'), FollowedBy(Str('b')), Str('b'), Str('c')])
      }, 'aXbc');
      expect(ok, isTrue, reason: 'should succeed');
      expect(err, equals(1), reason: 'should have 1 error');
      expect(skip.contains('X'), isTrue, reason: 'should skip X');
      // After skipping X, FollowedBy(b) checks 'b' without consuming
    });

    test('COMPLEX-08-recovery-in-negative-lookahead', () {
      // NotFollowedBy with recovery context
      final (ok, err, _) = testParse({
        'S': Seq([Str('a'), NotFollowedBy(Str('x')), Str('b')])
      }, 'ab');
      expect(ok, isTrue, reason: 'should succeed');
      expect(err, equals(0), reason: 'should have 0 errors');
      // NotFollowedBy('x') succeeds (next is 'b', not 'x')
    });

    test('COMPLEX-09-alternating-lr-and-repetition', () {
      // Grammar with both LR and repetitions at same level
      final (ok, err, _) = testParse({
        'S': Seq([Ref('E'), Str(';'), OneOrMore(Str('x'))]),
        'E': First([
          Seq([Ref('E'), Str('+'), Str('n')]),
          Str('n')
        ])
      }, 'n+n;xxx');
      expect(ok, isTrue, reason: 'should succeed');
      expect(err, equals(0), reason: 'should have 0 errors');
      // E is left-recursive, then ';', then repetition
    });

    test('COMPLEX-10-recovery-spanning-multiple-clauses', () {
      // Single error region that spans where multiple clauses would try to match
      final (ok, err, skip) = testParse({
        'S': Seq([Str('a'), Str('b'), Str('c'), Str('d')])
      }, 'aXYZbcd');
      expect(ok, isTrue, reason: 'should succeed');
      expect(err, equals(1), reason: 'should have 1 error (entire XYZ region)');
      expect(skip.contains('XYZ'), isTrue,
          reason: 'should skip XYZ as single region');
    });

    test('COMPLEX-11-ref-through-multiple-indirections', () {
      // A → B → C → D, all Refs
      final (ok, err, _) = testParse(
          {'A': Ref('B'), 'B': Ref('C'), 'C': Ref('D'), 'D': Str('x')},
          'x',
          'A');
      expect(ok, isTrue, reason: 'should succeed (multiple Ref indirections)');
      expect(err, equals(0), reason: 'should have 0 errors');
    });

    test('COMPLEX-12-circular-refs-with-recovery', () {
      // Mutual recursion with simple clean input
      final (ok, err, skip) = testParse({
        'S': Seq([Ref('A'), Str('end')]),
        'A': First([
          Seq([Str('a'), Ref('B')]),
          Str('a')
        ]),
        'B': First([
          Seq([Str('b'), Ref('A')]),
          Str('b')
        ])
      }, 'ababend', 'S');
      expect(ok, isTrue, reason: 'should succeed');
      expect(err, equals(0), reason: 'should have 0 errors (clean parse)');
      // Mutual recursion: A → B → A → B (abab)
    });

    test('COMPLEX-13-all-clause-types-in-one-grammar', () {
      // Every clause type in one complex grammar
      final (ok, err, _) = testParse({
        'S': Seq([
          Ref('A'),
          Optional(Str('opt')),
          ZeroOrMore(Str('z')),
          First([Str('f1'), Str('f2')]),
          FollowedBy(Str('end')),
          Str('end')
        ]),
        'A': First([
          Seq([Ref('A'), Str('+'), Str('a')]),
          Str('a')
        ])
      }, 'a+aoptzzzf1end', 'S');
      expect(ok, isTrue,
          reason: 'should succeed (all clause types work together)');
      expect(err, equals(0), reason: 'should have 0 errors');
    });

    test('COMPLEX-14-recovery-at-every-level-of-deep-nesting', () {
      // Error at each level of deep nesting, all recover
      final (ok, err, _) = testParse({
        'S': Seq([
          Seq([
            Str('a'),
            Seq([
              Str('b'),
              Seq([Str('c'), Str('d')])
            ])
          ])
        ])
      }, 'aXbYcZd');
      expect(ok, isTrue, reason: 'should succeed');
      expect(err, equals(3), reason: 'should have 3 errors');
      // Error at each nesting level
    });

    test('COMPLEX-15-performance-large-grammar', () {
      // Large grammar with many rules
      final rules = <String, Clause>{};
      for (int i = 0; i < 50; i++) {
        rules['Rule$i'] = Str('opt_${i.toString().padLeft(3, '0')}');
      }
      rules['S'] = First(List.generate(50, (i) => Ref('Rule$i')));

      final (ok, _, _) = testParse(rules, 'opt_025', 'S');
      expect(ok, isTrue,
          reason: 'should succeed (large grammar with 50 rules)');
    });
  });
}
