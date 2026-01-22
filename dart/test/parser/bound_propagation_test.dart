// ===========================================================================
// BOUND PROPAGATION TESTS
// ===========================================================================
// These tests verify that structural bounds (like closing delimiters) are
// correctly propagated through the parse tree, especially:
// 1. Repetitions should stop at sibling boundaries
// 2. Whitespace patterns should be skipped when finding meaningful bounds
// 3. Refs should be dereferenced when checking for whitespace patterns
// 4. Recovery should not skip past structural boundaries

import 'package:squirrel_parser/squirrel_parser.dart';
import 'package:test/test.dart';

import '../test_utils.dart';

void main() {
  group('Repetition Bound Respect Tests', () {
    // These tests verify that repetitions stop at sibling boundaries
    // and don't consume content that siblings should match.

    test('BPR-01-repetition-stops-at-sibling-terminal', () {
      // OneOrMore should stop when sibling terminal can match
      // Input: "xxY" - repetition of "x" should stop at "Y"
      final (ok, err, skip) = testParse('S <- "x"+ "Y" ;', 'xxY');
      expect(ok, isTrue, reason: 'should succeed');
      expect(err, equals(0), reason: 'should have no errors');
    });

    test('BPR-02-repetition-stops-at-sibling-after-error', () {
      // After recovering from error, repetition should still respect sibling
      // Input: "xZxY" - skip Z, match x, then stop at Y (not consume Y as error)
      final (ok, err, skip) = testParse('S <- "x"+ "Y" ;', 'xZxY');
      expect(ok, isTrue, reason: 'should succeed');
      expect(err, equals(1), reason: 'should have 1 error (Z)');
      expect(skip.contains('Z'), isTrue, reason: 'should skip Z');
      expect(skip.contains('Y'), isFalse, reason: 'should NOT skip Y');
    });

    test('BPR-03-repetition-stops-at-optional-sibling', () {
      // Repetition should stop when optional sibling can match
      // Input: "xx!" - repetition stops, optional matches "!"
      final (ok, err, skip) = testParse('S <- "x"+ "!"? ;', 'xx!');
      expect(ok, isTrue, reason: 'should succeed');
      expect(err, equals(0), reason: 'should have no errors');
    });

    test('BPR-04-repetition-with-error-stops-at-optional-sibling', () {
      // After error recovery, repetition should stop at optional sibling
      // Input: "xZx!" - skip Z, then stop at "!" (not consume it)
      final (ok, err, skip) = testParse('S <- "x"+ "!"? ;', 'xZx!');
      expect(ok, isTrue, reason: 'should succeed');
      expect(err, equals(1), reason: 'should have 1 error (Z)');
      expect(skip.contains('!'), isFalse, reason: 'should NOT skip !');
    });

    test('BPR-05-nested-repetition-respects-outer-bound', () {
      // Inner repetition should respect bounds from outer structure
      const grammar = '''
        S <- "[" Items "]" ;
        Items <- Item* ;
        Item <- "x" ;
      ''';
      final (ok, err, skip) = testParse(grammar, '[xx]');
      expect(ok, isTrue, reason: 'should succeed');
      expect(err, equals(0), reason: 'should have no errors');
    });

    test('BPR-06-nested-repetition-with-error-respects-bound', () {
      // After error, inner repetition should still stop at outer bound
      const grammar = '''
        S <- "[" Items "]" ;
        Items <- Item* ;
        Item <- "x" ;
      ''';
      final (ok, err, skip) = testParse(grammar, '[xZx]');
      expect(ok, isTrue, reason: 'should succeed');
      expect(err, equals(1), reason: 'should have 1 error (Z)');
      expect(skip.contains(']'), isFalse, reason: 'should NOT skip ]');
    });
  });

  group('Whitespace Bound Skipping Tests', () {
    // These tests verify that whitespace (ZeroOrMore of CharSet) is skipped
    // when finding meaningful bounds, so structural delimiters are used.

    test('WBS-01-bracket-bound-through-whitespace', () {
      // The "]" should be the effective bound, not WS
      const grammar = '''
        S <- "[" WS Items WS "]" ;
        Items <- Item* ;
        Item <- "x" ;
        ~WS <- [ ]* ;
      ''';
      final (ok, err, skip) = testParse(grammar, '[xx]');
      expect(ok, isTrue, reason: 'should succeed');
      expect(err, equals(0), reason: 'should have no errors');
    });

    test('WBS-02-bracket-bound-with-actual-whitespace', () {
      // With actual whitespace in input, should still work
      const grammar = '''
        S <- "[" WS Items WS "]" ;
        Items <- (WS Item)* ;
        Item <- "x" ;
        ~WS <- [ ]* ;
      ''';
      final (ok, err, skip) = testParse(grammar, '[ x x ]');
      expect(ok, isTrue, reason: 'should succeed');
      expect(err, equals(0), reason: 'should have no errors');
    });

    test('WBS-03-bracket-bound-with-error-before-close', () {
      // Error recovery should stop at "]", not consume it
      const grammar = '''
        S <- "[" WS Items WS "]" ;
        Items <- Item* ;
        Item <- "x" ;
        ~WS <- [ ]* ;
      ''';
      final (ok, err, skip) = testParse(grammar, '[xZx]');
      expect(ok, isTrue, reason: 'should succeed');
      expect(err, equals(1), reason: 'should have 1 error (Z)');
      expect(skip.contains(']'), isFalse, reason: 'should NOT skip ]');
    });

    test('WBS-04-brace-bound-through-whitespace', () {
      // Same test with braces
      const grammar = '''
        S <- "{" WS Items WS "}" ;
        Items <- Item* ;
        Item <- "x" ;
        ~WS <- [ ]* ;
      ''';
      final (ok, err, skip) = testParse(grammar, '{xZx}');
      expect(ok, isTrue, reason: 'should succeed');
      expect(err, equals(1), reason: 'should have 1 error (Z)');
      expect(skip.contains('}'), isFalse, reason: 'should NOT skip }');
    });

    test('WBS-05-multiple-whitespace-layers', () {
      // Multiple WS elements before the real bound
      const grammar = '''
        S <- "[" WS1 WS2 Items WS1 WS2 "]" ;
        Items <- Item* ;
        Item <- "x" ;
        ~WS1 <- [ ]* ;
        ~WS2 <- [\t]* ;
      ''';
      final (ok, err, skip) = testParse(grammar, '[xZx]');
      expect(ok, isTrue, reason: 'should succeed');
      expect(err, equals(1), reason: 'should have 1 error (Z)');
      expect(skip.contains(']'), isFalse, reason: 'should NOT skip ]');
    });
  });

  group('Array-like Structure Tests', () {
    // These tests verify correct parsing of array-like structures
    // where a repetition of comma-separated values should stop at "]"

    test('ALS-01-simple-array-valid', () {
      const grammar = '''
        S <- "[" (V ("," V)*)? "]" ;
        V <- [0-9]+ ;
      ''';
      final (ok, err, _) = testParse(grammar, '[1,2,3]');
      expect(ok, isTrue, reason: 'should succeed');
      expect(err, equals(0), reason: 'should have no errors');
    });

    test('ALS-02-array-with-whitespace-valid', () {
      const grammar = '''
        S <- "[" WS (V (WS "," WS V)*)? WS "]" ;
        V <- [0-9]+ ;
        ~WS <- [ ]* ;
      ''';
      final (ok, err, _) = testParse(grammar, '[ 1 , 2 , 3 ]');
      expect(ok, isTrue, reason: 'should succeed');
      expect(err, equals(0), reason: 'should have no errors');
    });

    test('ALS-03-array-with-error-in-middle', () {
      // Error between values should be recovered, ] should still match
      const grammar = '''
        S <- "[" WS (V (WS "," WS V)*)? WS "]" ;
        V <- [0-9]+ ;
        ~WS <- [ ]* ;
      ''';
      final (ok, err, skip) = testParse(grammar, '[1,2X,3]');
      expect(ok, isTrue, reason: 'should succeed');
      expect(err, equals(1), reason: 'should have 1 error (X)');
      expect(skip.contains('X'), isTrue, reason: 'should skip X');
      expect(skip.contains(']'), isFalse, reason: 'should NOT skip ]');
    });

    test('ALS-04-array-repetition-stops-at-bracket', () {
      // The comma-value repetition should stop at ], not try to consume it
      const grammar = '''
        S <- "[" WS (V (WS "," WS V)*)? WS "]" ;
        V <- [0-9]+ ;
        ~WS <- [ ]* ;
      ''';
      final (ok, err, skip) = testParse(grammar, '[1,2,3]');
      expect(ok, isTrue, reason: 'should succeed');
      expect(err, equals(0), reason: 'no errors - ] is matched, not skipped');
    });

    test('ALS-05-array-error-at-end-before-bracket', () {
      // Error right before ] should be captured, ] should still match
      const grammar = '''
        S <- "[" WS (V (WS "," WS V)*)? WS "]" ;
        V <- [0-9]+ ;
        ~WS <- [ ]* ;
      ''';
      final (ok, err, skip) = testParse(grammar, '[1,2,X]');
      expect(ok, isTrue, reason: 'should succeed');
      // X is captured as error, ] matches
      expect(skip.contains(']'), isFalse, reason: 'should NOT skip ]');
    });

    test('ALS-06-nested-arrays', () {
      // Nested arrays - inner ] should not be consumed by outer repetition
      const grammar = '''
        S <- "[" WS (V (WS "," WS V)*)? WS "]" ;
        V <- S / [0-9]+ ;
        ~WS <- [ ]* ;
      ''';
      final (ok, err, _) = testParse(grammar, '[[1,2],3]');
      expect(ok, isTrue, reason: 'should succeed');
      expect(err, equals(0), reason: 'should have no errors');
    });
  });

  group('Object-like Structure Tests', () {
    // Similar tests for object-like structures with key:value pairs

    test('OLS-01-simple-object-valid', () {
      const grammar = '''
        S <- "{" (M ("," M)*)? "}" ;
        M <- K ":" V ;
        K <- [a-z]+ ;
        V <- [0-9]+ ;
      ''';
      final (ok, err, _) = testParse(grammar, '{a:1,b:2}');
      expect(ok, isTrue, reason: 'should succeed');
      expect(err, equals(0), reason: 'should have no errors');
    });

    test('OLS-02-object-with-whitespace', () {
      const grammar = '''
        S <- "{" WS (M (WS "," WS M)*)? WS "}" ;
        M <- K WS ":" WS V ;
        K <- [a-z]+ ;
        V <- [0-9]+ ;
        ~WS <- [ ]* ;
      ''';
      final (ok, err, _) = testParse(grammar, '{ a : 1 , b : 2 }');
      expect(ok, isTrue, reason: 'should succeed');
      expect(err, equals(0), reason: 'should have no errors');
    });

    test('OLS-03-object-with-error', () {
      const grammar = '''
        S <- "{" WS (M (WS "," WS M)*)? WS "}" ;
        M <- K WS ":" WS V ;
        K <- [a-z]+ ;
        V <- [0-9]+ ;
        ~WS <- [ ]* ;
      ''';
      final (ok, err, skip) = testParse(grammar, '{a:1,bX:2}');
      expect(ok, isTrue, reason: 'should succeed');
      expect(skip.contains('}'), isFalse, reason: 'should NOT skip }');
    });

    test('OLS-04-object-repetition-stops-at-brace', () {
      const grammar = '''
        S <- "{" WS (M (WS "," WS M)*)? WS "}" ;
        M <- K WS ":" WS V ;
        K <- [a-z]+ ;
        V <- [0-9]+ ;
        ~WS <- [ ]* ;
      ''';
      final (ok, err, _) = testParse(grammar, '{a:1}');
      expect(ok, isTrue, reason: 'should succeed');
      expect(err, equals(0), reason: 'should have no errors');
    });
  });

  group('Ref Dereferencing Tests', () {
    // These tests verify that Refs are properly dereferenced when
    // determining if a clause is a whitespace pattern

    test('RDR-01-ref-to-whitespace-skipped', () {
      // Transparent WS should be skipped, non-transparent RBRACKET should be bound
      const grammar = '''
        S <- "[" WS Items WS RBRACKET ;
        Items <- Item* ;
        Item <- "x" ;
        ~WS <- [ ]* ;
        RBRACKET <- "]" ;
      ''';
      final (ok, err, skip) = testParse(grammar, '[xZx]');
      expect(ok, isTrue, reason: 'should succeed');
      expect(err, equals(1), reason: 'should have 1 error (Z)');
      expect(skip.contains(']'), isFalse, reason: 'should NOT skip ]');
    });

    test('RDR-02-multiple-refs-whitespace-all-skipped', () {
      // Multiple transparent whitespace rules before non-transparent delimiter
      const grammar = '''
        S <- "[" SP TAB Items SP TAB RBRACKET ;
        Items <- Item* ;
        Item <- "x" ;
        ~SP <- [ ]* ;
        ~TAB <- [\t]* ;
        RBRACKET <- "]" ;
      ''';
      final (ok, err, skip) = testParse(grammar, '[xZx]');
      expect(ok, isTrue, reason: 'should succeed');
      expect(err, equals(1), reason: 'should have 1 error (Z)');
      expect(skip.contains(']'), isFalse, reason: 'should NOT skip ]');
    });

    test('RDR-03-ref-to-non-whitespace-not-skipped', () {
      // A ref to a meaningful clause should NOT be skipped
      const grammar = '''
        S <- "[" Items SEP "]" ;
        Items <- Item* ;
        Item <- "x" ;
        SEP <- ";" ;
      ''';
      // Items should stop at SEP, not at ]
      final (ok, err, _) = testParse(grammar, '[xx;]');
      expect(ok, isTrue, reason: 'should succeed');
      expect(err, equals(0), reason: 'should have no errors');
    });
  });

  group('Recovery Near Structural Boundaries', () {
    // Tests that verify recovery doesn't consume structural delimiters

    test('RSB-01-no-trailing-skip-past-delimiter', () {
      // Trailing garbage recovery should stop at delimiter
      const grammar = '''
        S <- "[" Items "]" ;
        Items <- "x"+ ;
      ''';
      final (ok, err, skip) = testParse(grammar, '[xZ]');
      expect(ok, isTrue, reason: 'should succeed');
      // Z should be error, ] should match
      expect(skip.contains(']'), isFalse, reason: 'should NOT skip ]');
    });

    test('RSB-02-recovery-scan-stops-at-delimiter', () {
      // When scanning for recovery point, stop at delimiter
      const grammar = '''
        S <- "[" Items "]" ;
        Items <- ("ab")+ ;
      ''';
      final (ok, err, skip) = testParse(grammar, '[abZ]');
      expect(ok, isTrue, reason: 'should succeed');
      expect(skip.contains(']'), isFalse, reason: 'should NOT skip ]');
    });

    test('RSB-03-multiple-delimiters-nested', () {
      // With nested structures, each level's delimiter should be respected
      const grammar = '''
        S <- "[" Inner "]" ;
        Inner <- "{" Items "}" ;
        Items <- "x"+ ;
      ''';
      final (ok, err, skip) = testParse(grammar, '[{xZ}]');
      expect(ok, isTrue, reason: 'should succeed');
      expect(skip.contains('}'), isFalse, reason: 'should NOT skip }');
      expect(skip.contains(']'), isFalse, reason: 'should NOT skip ]');
    });

    test('RSB-04-error-right-before-delimiter', () {
      // Error immediately before delimiter - recovery skips error, matches delimiter
      const grammar = '''
        S <- "[" "x"+ "]" ;
      ''';
      // xZ] - x matches, Z is error, ] should match
      final (ok, err, skip) = testParse(grammar, '[xZ]');
      expect(ok, isTrue, reason: 'should succeed');
      expect(err, equals(1), reason: 'should have 1 error');
      expect(skip.contains(']'), isFalse, reason: '] should match, not be skipped');
    });

    test('RSB-05-comma-separated-with-trailing-error', () {
      // Error after last value, before delimiter
      const grammar = '''
        S <- "[" (V ("," V)*)? "]" ;
        V <- [0-9] ;
      ''';
      final (ok, err, skip) = testParse(grammar, '[1,2Z]');
      expect(ok, isTrue, reason: 'should succeed');
      expect(skip.contains(']'), isFalse, reason: '] should match');
    });
  });

  group('Character-level Terminal Recovery Disabled', () {
    // Tests that verify CharSet/Char/AnyChar repetitions don't do recovery
    // (they should let parent Seq handle it for better structural context)

    test('CTR-01-charset-repetition-no-recovery', () {
      // CharSet repetition should NOT try to skip over non-matching content
      const grammar = '''
        S <- [a-z]+ "!" ;
      ''';
      final (ok, err, skip) = testParse(grammar, 'abXcd!');
      expect(ok, isTrue, reason: 'should succeed');
      // The Seq should handle recovery, not the [a-z]+ repetition
      expect(err, equals(1), reason: 'should have 1 error');
    });

    test('CTR-02-whitespace-repetition-no-recovery', () {
      // Whitespace repetition should not extend by skipping errors
      const grammar = '''
        S <- "a" WS "b" ;
        ~WS <- [ ]* ;
      ''';
      final (ok, err, skip) = testParse(grammar, 'a X b');
      expect(ok, isTrue, reason: 'should succeed');
      // WS should match " ", then Seq should handle "X " as error before "b"
      expect(err, equals(1), reason: 'should have 1 error');
      expect(skip.contains('b'), isFalse, reason: 'should NOT skip b');
    });

    test('CTR-03-complex-subclause-does-recovery', () {
      // Repetition of complex clauses (Seq) SHOULD do recovery
      const grammar = '''
        S <- ("ab")+ "!" ;
      ''';
      final (ok, err, skip) = testParse(grammar, 'abXab!');
      expect(ok, isTrue, reason: 'should succeed');
      expect(err, equals(1), reason: 'should have 1 error (X)');
      expect(skip.contains('!'), isFalse, reason: 'should NOT skip !');
    });
  });
}
