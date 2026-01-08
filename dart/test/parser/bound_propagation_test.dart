// ===========================================================================
// BOUND PROPAGATION TESTS (FIX #9 Verification)
// ===========================================================================
// These tests verify that bounds propagate through arbitrary nesting levels
// to correctly stop repetitions before consuming delimiters.

import 'package:squirrel_parser/squirrel_parser.dart';
import 'package:test/test.dart';

import 'test_utils.dart';

void main() {
  group('Bound Propagation Tests', () {
    test('BP-01-direct-repetition', () {
      // Baseline: Bound with direct Repetition child (was already working)
      final (ok, err, _) = testParse({
        'S': Seq([OneOrMore(Str('x')), Str('end')])
      }, 'xxxxend');
      expect(ok, isTrue, reason: 'should succeed');
      expect(err, equals(0), reason: 'should have 0 errors');
    });

    test('BP-02-through-ref', () {
      // FIX #9: Bound propagates through Ref
      final (ok, err, _) = testParse({
        'S': Seq([Ref('A'), Str('end')]),
        'A': OneOrMore(Str('x')),
      }, 'xxxxend');
      expect(ok, isTrue, reason: 'should succeed (bound through Ref)');
      expect(err, equals(0), reason: 'should have 0 errors');
    });

    test('BP-03-through-nested-refs', () {
      // FIX #9: Bound propagates through multiple Refs
      final (ok, err, _) = testParse({
        'S': Seq([Ref('A'), Str('end')]),
        'A': Ref('B'),
        'B': OneOrMore(Str('x')),
      }, 'xxxxend');
      expect(ok, isTrue, reason: 'should succeed (bound through 2 Refs)');
      expect(err, equals(0), reason: 'should have 0 errors');
    });

    test('BP-04-through-first', () {
      // FIX #9: Bound propagates through First alternatives
      final (ok, err, _) = testParse({
        'S': Seq([Ref('A'), Str('end')]),
        'A': First([OneOrMore(Str('x')), OneOrMore(Str('y'))]),
      }, 'xxxxend');
      expect(ok, isTrue, reason: 'should succeed (bound through First)');
      expect(err, equals(0), reason: 'should have 0 errors');
    });

    test('BP-05-left-recursive-with-repetition', () {
      // FIX #9: The EMERG-01 case - bound through LR + First + Seq + Repetition
      final (ok, err, _) = testParse({
        'S': Seq([Ref('E'), Str('end')]),
        'E': First([
          Seq([Ref('E'), Str('+'), OneOrMore(Str('n'))]),
          Str('n')
        ]),
      }, 'n+nnn+nnend');
      expect(ok, isTrue, reason: 'should succeed (bound through LR)');
      expect(err, equals(0), reason: 'should have 0 errors');
    });

    test('BP-06-with-recovery-inside-bounded-rep', () {
      // FIX #9 + recovery: Bound propagates AND recovery works inside repetition
      final (ok, err, skip) = testParse({
        'S': Seq([Ref('A'), Str('end')]),
        'A': OneOrMore(Str('ab')),
      }, 'abXabYabend');
      expect(ok, isTrue, reason: 'should succeed');
      expect(err, equals(2), reason: 'should have 2 errors (X and Y)');
      expect(skip.contains('X'), isTrue, reason: 'should skip X');
      expect(skip.contains('Y'), isTrue, reason: 'should skip Y');
    });

    test('BP-07-multiple-bounds-nested-seq', () {
      // Multiple bounds in nested Seq structures
      final (ok, err, _) = testParse({
        'S': Seq([Ref('A'), Str(';'), Ref('B'), Str('end')]),
        'A': OneOrMore(Str('x')),
        'B': OneOrMore(Str('y')),
      }, 'xxxx;yyyyend');
      expect(ok, isTrue, reason: 'should succeed');
      expect(err, equals(0), reason: 'should have 0 errors');
      // A stops at ';', B stops at 'end'
    });

    test('BP-08-bound-vs-eof', () {
      // Without explicit bound, should consume until EOF
      final (ok, err, _) = testParse({'S': OneOrMore(Str('x'))}, 'xxxx');
      expect(ok, isTrue, reason: 'should succeed');
      expect(err, equals(0), reason: 'should have 0 errors');
      // No bound, so consumes all x's
    });

    test('BP-09-zeoormore-with-bound', () {
      // Bound applies to ZeroOrMore too
      final (ok, err, _) = testParse({
        'S': Seq([ZeroOrMore(Str('x')), Str('end')])
      }, 'end');
      expect(ok, isTrue, reason: 'should succeed (ZeroOrMore matches 0)');
      expect(err, equals(0), reason: 'should have 0 errors');
    });

    test('BP-10-complex-nesting', () {
      // Deeply nested: Ref → First → Seq → Ref → Repetition
      final (ok, err, _) = testParse({
        'S': Seq([Ref('A'), Str('end')]),
        'A': First([
          Seq([Str('a'), Ref('B')]),
          Str('fallback')
        ]),
        'B': OneOrMore(Str('x')),
      }, 'axxxxend');
      expect(ok, isTrue,
          reason: 'should succeed (bound through complex nesting)');
      expect(err, equals(0), reason: 'should have 0 errors');
    });
  });
}
