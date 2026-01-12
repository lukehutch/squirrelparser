// ===========================================================================
// SECTION 11: ALL SIX FIXES WITH MONOTONIC INVARIANT (20 tests)
// ===========================================================================
// Verify all six error recovery fixes work correctly with the monotonic
// invariant fix applied.

import 'package:squirrel_parser/squirrel_parser.dart';
import 'package:test/test.dart';

import '../test_utils.dart';

void main() {
  // --- FIX #1: isComplete propagation with LR ---
  const exprLR = '''
    E <- E "+" N / N ;
    N <- [0-9]+ ;
  ''';

  test('F1-LR-clean', () {
    final (ok, err, _) = testParse(exprLR, '1+2+3', 'E');
    expect(ok, isTrue, reason: 'should succeed');
    expect(err, equals(0), reason: 'should have 0 errors');
  });

  test('F1-LR-recovery', () {
    final (ok, err, skip) = testParse(exprLR, '1+Z2+3', 'E');
    expect(ok, isTrue, reason: 'should succeed');
    expect(err, greaterThanOrEqualTo(1),
        reason: 'should have at least 1 error');
    expect(skip.any((s) => s.contains('Z')), isTrue, reason: 'should skip Z');
  });

  // --- FIX #2: Discovery-only incomplete marking with LR ---
  const repLR = '''
    E <- E "+" T / T ;
    T <- "x"+ ;
  ''';

  test('F2-LR-clean', () {
    final (ok, err, _) = testParse(repLR, 'x+xx+xxx', 'E');
    expect(ok, isTrue, reason: 'should succeed');
    expect(err, equals(0), reason: 'should have 0 errors');
  });

  test('F2-LR-error', () {
    final (ok, err, skip) = testParse(repLR, 'x+xZx+xxx', 'E');
    expect(ok, isTrue, reason: 'should succeed');
    expect(err, greaterThanOrEqualTo(1),
        reason: 'should have at least 1 error');
  });

  // --- FIX #3: Cache isolation with LR ---
  const cacheLR = '''
    S <- "[" E "]" ;
    E <- E "+" N / N ;
    N <- "x"+ ;
  ''';

  test('F3-LR-clean', () {
    final (ok, err, _) = testParse(cacheLR, '[x+xx]');
    expect(ok, isTrue, reason: 'should succeed');
    expect(err, equals(0), reason: 'should have 0 errors');
  });

  test('F3-LR-recovery', () {
    final (ok, err, skip) = testParse(cacheLR, '[x+Zxx]');
    expect(ok, isTrue, reason: 'should succeed');
    expect(err, greaterThanOrEqualTo(1),
        reason: 'should have at least 1 error');
  });

  // --- FIX #4: Pre-element bound check with LR ---
  const boundLR = '''
    S <- ("[" E "]")+ ;
    E <- E "+" N / N ;
    N <- [0-9]+ ;
  ''';

  test('F4-LR-clean', () {
    final (ok, err, _) = testParse(boundLR, '[1+2][3+4]');
    expect(ok, isTrue, reason: 'should succeed');
    expect(err, equals(0), reason: 'should have 0 errors');
  });

  test('F4-LR-recovery', () {
    final (ok, err, skip) = testParse(boundLR, '[1+Z2][3+4]');
    expect(ok, isTrue, reason: 'should succeed');
    expect(err, greaterThanOrEqualTo(1),
        reason: 'should have at least 1 error');
  });

  // --- FIX #5: Optional fallback incomplete with LR ---
  const optLR = '''
    S <- E ";"? ;
    E <- E "+" N / N ;
    N <- [0-9]+ ;
  ''';

  test('F5-LR-with-opt', () {
    final (ok, err, _) = testParse(optLR, '1+2+3;');
    expect(ok, isTrue, reason: 'should succeed');
    expect(err, equals(0), reason: 'should have 0 errors');
  });

  test('F5-LR-without-opt', () {
    final (ok, err, _) = testParse(optLR, '1+2+3');
    expect(ok, isTrue, reason: 'should succeed');
    expect(err, equals(0), reason: 'should have 0 errors');
  });

  // --- FIX #6: Conservative EOF recovery with LR ---
  const eofLR = '''
    S <- E "!" ;
    E <- E "+" N / N ;
    N <- [0-9]+ ;
  ''';

  test('F6-LR-clean', () {
    final (ok, err, _) = testParse(eofLR, '1+2+3!');
    expect(ok, isTrue, reason: 'should succeed');
    expect(err, equals(0), reason: 'should have 0 errors');
  });

  test('F6-LR-deletion', () {
    final parseResult = squirrelParsePT(
      grammarSpec: eofLR,
      topRuleName: 'S',
      input: '1+2+3',
    );
    final result = parseResult.root;
    expect(!result.isMismatch, isTrue, reason: 'should succeed with recovery');
    expect(countDeletions([result]), greaterThanOrEqualTo(1),
        reason: 'should have at least 1 deletion');
  });

  // --- Combined: Expression grammar with all features ---
  const fullGrammar = '''
    Program <- (Expr ";"?)+ ;
    Expr <- Expr "+" Term / Term ;
    Term <- Term "*" Factor / Factor ;
    Factor <- "(" Expr ")" / Num ;
    Num <- [0-9]+ ;
  ''';

  test('FULL-clean-simple', () {
    final (ok, err, _) = testParse(fullGrammar, '1+2*3', 'Program');
    expect(ok, isTrue, reason: 'should succeed');
    expect(err, equals(0), reason: 'should have 0 errors');
  });

  test('FULL-clean-semi', () {
    final (ok, err, _) = testParse(fullGrammar, '1+2;3*4', 'Program');
    expect(ok, isTrue, reason: 'should succeed');
    expect(err, equals(0), reason: 'should have 0 errors');
  });

  test('FULL-clean-nested', () {
    final (ok, err, _) = testParse(fullGrammar, '(1+2)*(3+4)', 'Program');
    expect(ok, isTrue, reason: 'should succeed');
    expect(err, equals(0), reason: 'should have 0 errors');
  });

  test('FULL-recovery-skip', () {
    final (ok, err, skip) = testParse(fullGrammar, '1+Z2*3', 'Program');
    expect(ok, isTrue, reason: 'should succeed');
    expect(err, greaterThanOrEqualTo(1),
        reason: 'should have at least 1 error');
  });

  // --- Deep left recursion ---
  const deepLR = '''
    E <- E "+" N / N ;
    N <- [0-9] ;
  ''';

  test('DEEP-LR-clean', () {
    final (ok, err, _) = testParse(deepLR, '1+2+3+4+5+6+7+8+9', 'E');
    expect(ok, isTrue, reason: 'should succeed');
    expect(err, equals(0), reason: 'should have 0 errors');
  });

  test('DEEP-LR-recovery', () {
    final (ok, err, skip) = testParse(deepLR, '1+2+Z3+4+5', 'E');
    expect(ok, isTrue, reason: 'should succeed');
    expect(err, greaterThanOrEqualTo(1),
        reason: 'should have at least 1 error');
  });
}
