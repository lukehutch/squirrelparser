// ===========================================================================
// SECTION 10: MONOTONIC INVARIANT TESTS (50 tests)
// ===========================================================================
// These tests verify that the monotonic improvement check only applies to
// left-recursive clauses, not to all clauses. Without this fix, indirect
// and interwoven left recursion would fail.

import 'package:squirrel_parser/squirrel_parser.dart';
import 'package:test/test.dart';

import '../test_utils.dart';

void main() {
  // ===========================================================================
  // ADDITIONAL LR PATTERNS (from Pegged wiki examples)
  // ===========================================================================
  // These test cases cover various left recursion patterns documented at:
  // https://github.com/PhilippeSigaud/Pegged/wiki/Left-Recursion

  // --- Direct LR: E <- E '+n' / 'n' ---
  const directLRSimple = '''
    E <- E "+n" / "n" ;
  ''';

  test('LR-Direct-01-n', () {
    final r = parseForTree(directLRSimple, 'n', 'E');
    expect(r != null && r.len == 1, isTrue, reason: 'should parse n');
  });

  test('LR-Direct-02-n+n', () {
    final r = parseForTree(directLRSimple, 'n+n', 'E');
    expect(r != null && r.len == 3, isTrue, reason: 'should parse n+n');
  });

  test('LR-Direct-03-n+n+n', () {
    final r = parseForTree(directLRSimple, 'n+n+n', 'E');
    expect(r != null && r.len == 5, isTrue, reason: 'should parse n+n+n');
  });

  // --- Indirect LR: E <- F / 'n'; F <- E '+n' ---
  const indirectLRSimple = '''
    E <- F / "n" ;
    F <- E "+n" ;
  ''';

  test('LR-Indirect-01-n', () {
    final r = parseForTree(indirectLRSimple, 'n', 'E');
    expect(r != null && r.len == 1, isTrue, reason: 'should parse n');
  });

  test('LR-Indirect-02-n+n', () {
    final r = parseForTree(indirectLRSimple, 'n+n', 'E');
    expect(r != null && r.len == 3, isTrue, reason: 'should parse n+n');
  });

  test('LR-Indirect-03-n+n+n', () {
    final r = parseForTree(indirectLRSimple, 'n+n+n', 'E');
    expect(r != null && r.len == 5, isTrue, reason: 'should parse n+n+n');
  });

  // --- Direct Hidden LR: E <- F? E '+n' / 'n'; F <- 'f' ---
  // The optional F? can match empty, making E left-recursive
  const directHiddenLR = '''
    E <- F? E "+n" / "n" ;
    F <- "f" ;
  ''';

  test('LR-DirectHidden-01-n', () {
    final r = parseForTree(directHiddenLR, 'n', 'E');
    expect(r != null && r.len == 1, isTrue, reason: 'should parse n');
  });

  test('LR-DirectHidden-02-n+n', () {
    final r = parseForTree(directHiddenLR, 'n+n', 'E');
    expect(r != null && r.len == 3, isTrue, reason: 'should parse n+n');
  });

  test('LR-DirectHidden-03-n+n+n', () {
    final r = parseForTree(directHiddenLR, 'n+n+n', 'E');
    expect(r != null && r.len == 5, isTrue, reason: 'should parse n+n+n');
  });

  test('LR-DirectHidden-04-fn+n', () {
    // With the 'f' prefix, right-recursive path
    final r = parseForTree(directHiddenLR, 'fn+n', 'E');
    expect(r != null && r.len == 4, isTrue, reason: 'should parse fn+n');
  });

  // --- Indirect Hidden LR: E <- F E '+n' / 'n'; F <- "abc" / 'd'* ---
  // F can match empty (via 'd'*), making E left-recursive
  const indirectHiddenLR = '''
    E <- F E "+n" / "n" ;
    F <- "abc" / "d"* ;
  ''';

  test('LR-IndirectHidden-01-n', () {
    final r = parseForTree(indirectHiddenLR, 'n', 'E');
    expect(r != null && r.len == 1, isTrue, reason: 'should parse n');
  });

  test('LR-IndirectHidden-02-n+n', () {
    final r = parseForTree(indirectHiddenLR, 'n+n', 'E');
    expect(r != null && r.len == 3, isTrue, reason: 'should parse n+n');
  });

  test('LR-IndirectHidden-03-n+n+n', () {
    final r = parseForTree(indirectHiddenLR, 'n+n+n', 'E');
    expect(r != null && r.len == 5, isTrue, reason: 'should parse n+n+n');
  });

  test('LR-IndirectHidden-04-abcn+n', () {
    // With 'abc' prefix, right-recursive path
    final r = parseForTree(indirectHiddenLR, 'abcn+n', 'E');
    expect(r != null && r.len == 6, isTrue, reason: 'should parse abcn+n');
  });

  test('LR-IndirectHidden-05-ddn+n', () {
    // With 'dd' prefix, right-recursive path
    final r = parseForTree(indirectHiddenLR, 'ddn+n', 'E');
    expect(r != null && r.len == 5, isTrue, reason: 'should parse ddn+n');
  });

  // --- Multi-step Indirect LR: E <- F '+n' / 'n'; F <- "gh" / J; J <- 'k' / E 'l' ---
  // Three-step indirect cycle: E -> F -> J -> E
  const multiStepLR = '''
    E <- F "+n" / "n" ;
    F <- "gh" / J ;
    J <- "k" / E "l" ;
  ''';

  test('LR-MultiStep-01-n', () {
    final r = parseForTree(multiStepLR, 'n', 'E');
    expect(r != null && r.len == 1, isTrue, reason: 'should parse n');
  });

  test('LR-MultiStep-02-gh+n', () {
    // F matches "gh"
    final r = parseForTree(multiStepLR, 'gh+n', 'E');
    expect(r != null && r.len == 4, isTrue, reason: 'should parse gh+n');
  });

  test('LR-MultiStep-03-k+n', () {
    // F -> J -> 'k'
    final r = parseForTree(multiStepLR, 'k+n', 'E');
    expect(r != null && r.len == 3, isTrue, reason: 'should parse k+n');
  });

  test('LR-MultiStep-04-nl+n', () {
    // E <- F '+n' where F <- J where J <- E 'l'
    // So: E matches 'n', then 'l', giving 'nl' for J, for F
    // Then F '+n' gives 'nl+n'
    final r = parseForTree(multiStepLR, 'nl+n', 'E');
    expect(r != null && r.len == 4, isTrue, reason: 'should parse nl+n');
  });

  test('LR-MultiStep-05-nl+nl+n', () {
    // Nested multi-step LR
    final r = parseForTree(multiStepLR, 'nl+nl+n', 'E');
    expect(r != null && r.len == 7, isTrue, reason: 'should parse nl+nl+n');
  });

  // --- Direct + Indirect LR (Interwoven): L <- P '.x' / 'x'; P <- P '(n)' / L ---
  // Two interlocking cycles: L->P->L (indirect) and P->P (direct)
  const interwovenLR = '''
    L <- P ".x" / "x" ;
    P <- P "(n)" / L ;
  ''';

  test('LR-Interwoven-01-x', () {
    final r = parseForTree(interwovenLR, 'x', 'L');
    expect(r != null && r.len == 1, isTrue, reason: 'should parse x');
  });

  test('LR-Interwoven-02-x.x', () {
    final r = parseForTree(interwovenLR, 'x.x', 'L');
    expect(r != null && r.len == 3, isTrue, reason: 'should parse x.x');
  });

  test('LR-Interwoven-03-x(n).x', () {
    final r = parseForTree(interwovenLR, 'x(n).x', 'L');
    expect(r != null && r.len == 6, isTrue, reason: 'should parse x(n).x');
  });

  test('LR-Interwoven-04-x(n)(n).x', () {
    final r = parseForTree(interwovenLR, 'x(n)(n).x', 'L');
    expect(r != null && r.len == 9, isTrue, reason: 'should parse x(n)(n).x');
  });

  // --- Multiple Interlocking LR Cycles ---
  // E <- F 'n' / 'n'
  // F <- E '+' I* / G '-'
  // G <- H 'm' / E
  // H <- G 'l'
  // I <- '(' A+ ')'
  // A <- 'a'
  // Cycles: E->F->E, F->G->E, G->H->G
  const interlockingLR = '''
    E <- F "n" / "n" ;
    F <- E "+" I* / G "-" ;
    G <- H "m" / E ;
    H <- G "l" ;
    I <- "(" A+ ")" ;
    A <- "a" ;
  ''';

  test('LR-Interlocking-01-n', () {
    final r = parseForTree(interlockingLR, 'n', 'E');
    expect(r != null && r.len == 1, isTrue, reason: 'should parse n');
  });

  test('LR-Interlocking-02-n+n', () {
    // E <- F 'n' where F <- E '+'
    final r = parseForTree(interlockingLR, 'n+n', 'E');
    expect(r != null && r.len == 3, isTrue, reason: 'should parse n+n');
  });

  test('LR-Interlocking-03-n-n', () {
    // E <- F 'n' where F <- G '-' where G <- E
    final r = parseForTree(interlockingLR, 'n-n', 'E');
    expect(r != null && r.len == 3, isTrue, reason: 'should parse n-n');
  });

  test('LR-Interlocking-04-nlm-n', () {
    // G <- H 'm' where H <- G 'l', cycle G->H->G
    final r = parseForTree(interlockingLR, 'nlm-n', 'E');
    expect(r != null && r.len == 5, isTrue, reason: 'should parse nlm-n');
  });

  test('LR-Interlocking-05-n+(aaa)n', () {
    // E '+' I* where I <- '(' A+ ')'
    final r = parseForTree(interlockingLR, 'n+(aaa)n', 'E');
    expect(r != null && r.len == 8, isTrue, reason: 'should parse n+(aaa)n');
  });

  test('LR-Interlocking-06-nlm-n+(aaa)n', () {
    // Complex combination of all cycles
    final r = parseForTree(interlockingLR, 'nlm-n+(aaa)n', 'E');
    expect(r != null && r.len == 12, isTrue,
        reason: 'should parse nlm-n+(aaa)n');
  });

  // --- LR Precedence Grammar ---
  // E <- E '+' T / E '-' T / T
  // T <- T '*' F / T '/' F / F
  // F <- '(' E ')' / 'n'
  const precedenceGrammar = '''
    E <- E "+" T / E "-" T / T ;
    T <- T "*" F / T "/" F / F ;
    F <- "(" E ")" / "n" ;
  ''';

  test('LR-Precedence-01-n', () {
    final r = parseForTree(precedenceGrammar, 'n', 'E');
    expect(r != null && r.len == 1, isTrue, reason: 'should parse n');
  });

  test('LR-Precedence-02-n+n', () {
    final r = parseForTree(precedenceGrammar, 'n+n', 'E');
    expect(r != null && r.len == 3, isTrue, reason: 'should parse n+n');
  });

  test('LR-Precedence-03-n*n', () {
    final r = parseForTree(precedenceGrammar, 'n*n', 'E');
    expect(r != null && r.len == 3, isTrue, reason: 'should parse n*n');
  });

  test('LR-Precedence-04-n+n*n', () {
    // Precedence: n+(n*n) not (n+n)*n
    final r = parseForTree(precedenceGrammar, 'n+n*n', 'E');
    expect(r != null && r.len == 5, isTrue, reason: 'should parse n+n*n');
  });

  test('LR-Precedence-05-n+n*n+n/n', () {
    final r = parseForTree(precedenceGrammar, 'n+n*n+n/n', 'E');
    expect(r != null && r.len == 9, isTrue, reason: 'should parse n+n*n+n/n');
  });

  test('LR-Precedence-06-(n+n)*n', () {
    final r = parseForTree(precedenceGrammar, '(n+n)*n', 'E');
    expect(r != null && r.len == 7, isTrue, reason: 'should parse (n+n)*n');
  });

  // --- LR Error Recovery ---
  test('LR-Recovery-leading-error', () {
    // Input '+n+n+n+' starts with '+' which is invalid
    final (ok, err, _) = testParse(directLRSimple, '+n+n+n+', 'E');
    // Recovery should skip leading '+' and parse rest, or fail
    // The leading '+' can potentially be skipped as garbage
    if (ok) {
      expect(err, greaterThanOrEqualTo(1),
          reason: 'should have errors if succeeded');
    }
  });

  test('LR-Recovery-trailing-plus', () {
    // Input 'n+n+n+' has trailing '+' with no 'n' after
    final parseResult = squirrelParsePT(
      grammarSpec: directLRSimple,
      topRuleName: 'E',
      input: 'n+n+n+',
    );
    final result = parseResult.root;
    // Should parse 'n+n+n' and either fail on trailing '+' or recover
    if (!result.isMismatch) {
      // If it succeeded, it should have used recovery
      expect(result.len, greaterThanOrEqualTo(5),
          reason: 'should parse at least n+n+n');
    }
  });

  // --- Indirect Left Recursion (Fig7b): A <- B / 'x'; B <- (A 'y') / (A 'x') ---
  const fig7b = '''
    A <- B / "x" ;
    B <- A "y" / A "x" ;
  ''';

  test('M-ILR-01-x', () {
    final r = parseForTree(fig7b, 'x', 'A');
    expect(r != null && r.len == 1, isTrue, reason: 'should parse x');
  });

  test('M-ILR-02-xx', () {
    final r = parseForTree(fig7b, 'xx', 'A');
    expect(r != null && r.len == 2, isTrue, reason: 'should parse xx');
  });

  test('M-ILR-03-xy', () {
    final r = parseForTree(fig7b, 'xy', 'A');
    expect(r != null && r.len == 2, isTrue, reason: 'should parse xy');
  });

  test('M-ILR-04-xxy', () {
    final r = parseForTree(fig7b, 'xxy', 'A');
    expect(r != null && r.len == 3, isTrue, reason: 'should parse xxy');
  });

  test('M-ILR-05-xxyx', () {
    final r = parseForTree(fig7b, 'xxyx', 'A');
    expect(r != null && r.len == 4, isTrue, reason: 'should parse xxyx');
  });

  test('M-ILR-06-xyx', () {
    final r = parseForTree(fig7b, 'xyx', 'A');
    expect(r != null && r.len == 3, isTrue, reason: 'should parse xyx');
  });

  // --- Interwoven Left Recursion (Fig7f): L <- P '.x' / 'x'; P <- P '(n)' / L ---
  const fig7f = '''
    L <- P ".x" / "x" ;
    P <- P "(n)" / L ;
  ''';

  test('M-IW-01-x', () {
    final r = parseForTree(fig7f, 'x', 'L');
    expect(r != null && r.len == 1, isTrue, reason: 'should parse x');
  });

  test('M-IW-02-x.x', () {
    final r = parseForTree(fig7f, 'x.x', 'L');
    expect(r != null && r.len == 3, isTrue, reason: 'should parse x.x');
  });

  test('M-IW-03-x(n).x', () {
    final r = parseForTree(fig7f, 'x(n).x', 'L');
    expect(r != null && r.len == 6, isTrue, reason: 'should parse x(n).x');
  });

  test('M-IW-04-x(n)(n).x', () {
    final r = parseForTree(fig7f, 'x(n)(n).x', 'L');
    expect(r != null && r.len == 9, isTrue, reason: 'should parse x(n)(n).x');
  });

  test('M-IW-05-x.x(n)(n).x.x', () {
    final r = parseForTree(fig7f, 'x.x(n)(n).x.x', 'L');
    expect(r != null && r.len == 13, isTrue,
        reason: 'should parse x.x(n)(n).x.x');
  });

  // --- Optional-Dependent Left Recursion (Fig7d): A <- 'x'? (A 'y' / A / 'y') ---
  const fig7d = '''
    A <- "x"? (A "y" / A / "y") ;
  ''';

  test('M-OD-01-y', () {
    final r = parseForTree(fig7d, 'y', 'A');
    expect(r != null && r.len == 1, isTrue, reason: 'should parse y');
  });

  test('M-OD-02-xy', () {
    final r = parseForTree(fig7d, 'xy', 'A');
    expect(r != null && r.len == 2, isTrue, reason: 'should parse xy');
  });

  test('M-OD-03-xxyyy', () {
    final r = parseForTree(fig7d, 'xxyyy', 'A');
    expect(r != null && r.len == 5, isTrue, reason: 'should parse xxyyy');
  });

  // --- Input-Dependent Left Recursion (Fig7c): A <- B / 'z'; B <- ('x' A) / (A 'y') ---
  const fig7c = '''
    A <- B / "z" ;
    B <- "x" A / A "y" ;
  ''';

  test('M-ID-01-z', () {
    final r = parseForTree(fig7c, 'z', 'A');
    expect(r != null && r.len == 1, isTrue, reason: 'should parse z');
  });

  test('M-ID-02-xz', () {
    final r = parseForTree(fig7c, 'xz', 'A');
    expect(r != null && r.len == 2, isTrue, reason: 'should parse xz');
  });

  test('M-ID-03-zy', () {
    final r = parseForTree(fig7c, 'zy', 'A');
    expect(r != null && r.len == 2, isTrue, reason: 'should parse zy');
  });

  test('M-ID-04-xxzyyy', () {
    final r = parseForTree(fig7c, 'xxzyyy', 'A');
    expect(r != null && r.len == 6, isTrue, reason: 'should parse xxzyyy');
  });

  // --- Triple-nested indirect LR ---
  const tripleLR = '''
    A <- B / "a" ;
    B <- C / "b" ;
    C <- A "x" / "c" ;
  ''';

  test('M-TLR-01-a', () {
    final r = parseForTree(tripleLR, 'a', 'A');
    expect(r != null && r.len == 1, isTrue, reason: 'should parse a');
  });

  test('M-TLR-02-ax', () {
    final r = parseForTree(tripleLR, 'ax', 'A');
    expect(r != null && r.len == 2, isTrue, reason: 'should parse ax');
  });

  test('M-TLR-03-axx', () {
    final r = parseForTree(tripleLR, 'axx', 'A');
    expect(r != null && r.len == 3, isTrue, reason: 'should parse axx');
  });

  test('M-TLR-04-axxx', () {
    final r = parseForTree(tripleLR, 'axxx', 'A');
    expect(r != null && r.len == 4, isTrue, reason: 'should parse axxx');
  });
}
