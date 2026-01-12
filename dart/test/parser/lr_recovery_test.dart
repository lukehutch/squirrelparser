// ===========================================================================
// SECTION 13: LEFT RECURSION ERROR RECOVERY
// ===========================================================================

import 'package:squirrel_parser/squirrel_parser.dart';
import 'package:test/test.dart';

import '../test_utils.dart';

void main() {
  // directLR grammar for error recovery tests
  const directLR = '''
    S <- E ;
    E <- E "+n" / "n" ;
  ''';

  // precedenceLR grammar for error recovery tests
  const precedenceLR = '''
    S <- E ;
    E <- E "+" T / E "-" T / T ;
    T <- T "*" F / T "/" F / F ;
    F <- "(" E ")" / "n" ;
  ''';

  // Error recovery in direct LR grammar
  test('LR-Recovery-01-leading-error', () {
    // Input '+n+n+n+' starts with '+' which is invalid (need 'n' first)
    // and ends with '+' which is also invalid (need 'n' after)
    final (ok, err, _) = testParse(directLR, '+n+n+n+');
    // This should fail because we can't recover a valid parse
    // The leading '+' prevents any initial 'n' match
    expect(ok, isFalse, reason: 'should fail (leading + is unrecoverable)');
  });

  test('LR-Recovery-02-internal-error', () {
    // Input 'n+Xn+n' has garbage 'X' between + and n
    // '+n' is a 2-char terminal, so 'n+X' doesn't match '+n'
    // Grammar can only match 'n' at start, rest is captured as error
    final (ok, err, skip) = testParse(directLR, 'n+Xn+n');
    expect(ok, isTrue, reason: 'should capture trailing as error');
    expect(err, equals(1), reason: 'should have 1 error (unmatched +Xn+n)');
  });

  test('LR-Recovery-03-trailing-junk', () {
    // Input 'n+n+nXXX' has trailing garbage
    // With new invariant, trailing is captured as error in parse tree
    final (ok, err, skip) = testParse(directLR, 'n+n+nXXX');
    expect(ok, isTrue, reason: 'should succeed with trailing captured');
    expect(err, equals(1), reason: 'should have 1 error (trailing XXX)');
    expect(skip.contains('XXX'), isTrue, reason: 'should capture XXX');
  });

  // Error recovery in precedence grammar
  test('LR-Recovery-04-missing-operand', () {
    // Input 'n+*n' has missing operand between + and *
    // Parser recovers by skipping the extra '+' to parse as 'n*n'
    final (ok, err, skip) = testParse(precedenceLR, 'n+*n');
    expect(ok, isTrue, reason: 'should recover by skipping +');
    expect(err, equals(1), reason: 'one error: skip +');
    expect(skip, equals(['+']));
  });

  test('LR-Recovery-05-double-op', () {
    // Input 'n++n' has double operator
    // Parser recovers by skipping the extra '+' to parse as 'n+n'
    final (ok, err, skip) = testParse(precedenceLR, 'n++n');
    expect(ok, isTrue, reason: 'should recover by skipping +');
    expect(err, equals(1), reason: 'one error: skip +');
    expect(skip, equals(['+']));
  });

  test('LR-Recovery-06-unclosed-paren', () {
    // Input '(n+n' has unclosed paren
    final parseResult = squirrelParsePT(
      grammarSpec: precedenceLR,
      topRuleName: 'S',
      input: '(n+n',
    );
    final result = parseResult.root;
    // With recovery, should insert missing ')'
    expect(!result.isMismatch, isTrue, reason: 'should succeed with recovery');
  });

  test('LR-Recovery-07-extra-close-paren', () {
    // Input 'n+n)' has extra close paren
    // With new invariant, trailing is captured as error
    final (ok, err, skip) = testParse(precedenceLR, 'n+n)');
    expect(ok, isTrue, reason: 'should succeed with trailing captured');
    expect(err, equals(1), reason: 'should have 1 error (trailing ))');
    expect(skip.contains(')'), isTrue, reason: 'should capture )');
  });

  group('Ref LR Masking Tests', () {
    // F1-LR-05 case: T -> T*F | F. Input "n+n*Xn".
    // Error is at 'X'.
    // Optimal recovery: T matches "n", * matches "*", F fails on "X". F recovery skips "X" -> "n". Total 1 error.
    // Suboptimal (current): T fails. E matches "n+n". E recursion fails. E recovery skips "*X". Total 2 errors.

    const grammar = '''
      E <- E "+" T / T ;
      T <- T "*" F / F ;
      F <- "(" E ")" / "n" ;
    ''';

    test('MASK-01-error-at-T-level-after-star', () {
      // Current behavior: 2 errors (recovery at E level).
      // Optimal behavior (future goal): 1 error (recovery at F level).
      // This is a known limitation: Ref can mask deeper recovery opportunities.
      // The test expects current behavior, not optimal.
      final (ok, err, skip) = testParse(grammar, 'n+n*Xn', 'E');
      expect(ok, isTrue, reason: 'should recover');
      expect(err, equals(2),
          reason: 'current: 2 errors (suboptimal, but correct)');
      expect(skip.any((s) => s.contains('*') || s.contains('X')), isTrue,
          reason: 'should skip * and/or X');
    });
  });
}
