// =============================================================================
// ADVANCED STRESS TESTS FOR SQUIRREL PARSER RECOVERY
// =============================================================================
// These tests attempt to expose edge cases, subtle bugs, and potential
// violations of the three invariants (Completeness, Isolation, Minimality).

import 'package:test/test.dart';

import '../test_utils.dart';

void main() {
  // ===========================================================================
  // SECTION A: PHASE ISOLATION ATTACKS
  // ===========================================================================
  // Tests that attempt to violate Invariant II by creating cache pollution
  // scenarios between Phase 1, Phase 2, and probe() calls.

  group('Phase Isolation Attacks', () {
    test('ISO-01-probe-during-recovery-probe', () {
      // Nested probe scenario: recovery calls probe, which may trigger
      // another bounded repetition that also calls probe.
      const grammar = '''
        S <- A* B ;
        A <- "a"+ "x" ;
        B <- "b" "z" ;
      ''';
      // 'A' has inner OneOrMore which uses bound checking via probe
      // S's ZeroOrMore also uses probe for bounds
      final r = testParse(grammar, 'aaXxbz');
      expect(r.$1, isTrue, reason: 'nested probe should not poison cache');
    });

    test('ISO-02-recovery-version-overflow', () {
      // Many small errors to increment recoveryVersion many times
      // Tests that version counter doesn't wrap or cause issues
      const grammar = 'S <- "ab"+ ;';
      // FIX #10: With first-iteration recovery, input "aXaXaX...ab" skips all the way to first 'ab'
      // This counts as 1 error (entire skipped region). To test multiple errors, use "abXabXabX..."
      final input = 'ab${List.generate(50, (i) => 'Xab').join()}';
      final r = testParse(grammar, input);
      expect(r.$1, isTrue, reason: 'many errors should not overflow version');
      expect(r.$2, equals(50), reason: 'should count all 50 errors');
    });

    test('ISO-03-alternating-probe-match', () {
      // Alternate between probe and real match at same position
      const grammar = '''
        S <- A* B* "end" ;
        A <- "a" ;
        B <- "a" ;
      ''';
      // Both ZeroOrMore will probe 'a' positions
      final r = testParse(grammar, 'aaaXend');
      expect(r.$1, isTrue, reason: 'ambiguous probes should resolve correctly');
    });

    test('ISO-04-complete-result-reuse-after-lr', () {
      // A complete result at position P, then LR expansion that touches P
      const grammar = '''
        S <- A E ;
        A <- "a" ;
        E <- E "+" "a" / "a" ;
      ''';
      // 'A' matches 'a' (complete). Then E starts LR at position 1.
      // E should not reuse A's result at position 0.
      final r = testParse(grammar, 'aa+a');
      expect(r.$1, isTrue,
          reason: 'complete result should be isolated from LR');
      expect(r.$2, equals(0), reason: 'clean parse');
    });

    test('ISO-05-mismatch-cache-across-phases', () {
      // Ensure mismatch in Phase 1 doesn't block recovery in Phase 2
      const grammar = '''
        S <- "abc" "xyz" / "ab" "z" ;
      ''';
      // Phase 1: First alternative fails at 'Xz', second fails at 'X'
      // Phase 2: Should skip 'X' and match second alternative
      final r = testParse(grammar, 'abXz');
      expect(r.$1, isTrue, reason: 'Phase 1 mismatch should not block Phase 2');
    });
  });

  // ===========================================================================
  // SECTION B: LEFT RECURSION EDGE CASES
  // ===========================================================================

  group('Left Recursion Edge Cases', () {
    test('LR-EDGE-01-triple-nested-lr', () {
      // Three levels of left recursion
      const grammar = '''
        A <- A "+" B / B ;
        B <- B "*" C / C ;
        C <- C "-" "n" / "n" ;
      ''';
      // Error at deepest level
      final r = testParse(grammar, 'n+n*n-Xn', 'A');
      expect(r.$1, isTrue, reason: 'triple LR should recover');
    });

    test('LR-EDGE-02-lr-inside-repetition', () {
      // Left recursion inside a repetition
      const grammar = '''
        S <- E+ ;
        E <- E "+" "n" / "n" ;
      ''';
      // Two LR expressions separated by space
      final r = testParse(grammar, 'n+nXn+n');
      expect(r.$1, isTrue, reason: 'LR inside repetition should work');
    });

    test('LR-EDGE-03-lr-with-lookahead', () {
      // Left recursion with negative lookahead
      const grammar = '''
        E <- E "+" T / T ;
        T <- !"+" "n" ;
      ''';
      final r = testParse(grammar, 'n+Xn', 'E');
      expect(r.$1, isTrue, reason: 'LR with lookahead should recover');
    });

    test('LR-EDGE-04-mutual-lr', () {
      // Mutually recursive left recursion
      const grammar = '''
        A <- B "a" / "x" ;
        B <- A "b" / "y" ;
      ''';
      final r = testParse(grammar, 'ybaXba', 'A');
      expect(r.$1, isTrue, reason: 'mutual LR should recover');
    });

    test('LR-EDGE-05-lr-zero-length-between', () {
      // LR with zero-length elements between recursive call and terminal
      const grammar = '''
        E <- E " "? "+" "n" / "n" ;
      ''';
      final r = testParse(grammar, 'n +Xn', 'E');
      expect(r.$1, isTrue, reason: 'LR with optional should recover');
    });

    test('LR-EDGE-06-lr-empty-base', () {
      // LR where base case can be empty
      const grammar = '''
        E <- E "+" "n" / "n"? ;
      ''';
      // This is a pathological grammar - empty base allows infinite LR
      // Parser should handle gracefully
      testParse(grammar, '+n+n', 'E');
      // May fail or succeed with errors - just shouldn't infinite loop
      expect(true, isTrue, reason: 'should not infinite loop');
    });
  });

  // ===========================================================================
  // SECTION C: RECOVERY MINIMALITY ATTACKS
  // ===========================================================================

  group('Recovery Minimality Attacks', () {
    test('MIN-01-multiple-valid-recoveries', () {
      // Multiple ways to recover - should choose minimal
      const grammar = '''
        S <- "a" "b" "c" / "a" "c" ;
      ''';
      // 'aXc' can recover by: skip X (1 error) or delete b, skip X (2 errors)
      final r = testParse(grammar, 'aXc');
      expect(r.$1, isTrue, reason: 'should find recovery');
      expect(r.$2, equals(1), reason: 'should choose minimal recovery');
    });

    test('MIN-02-grammar-deletion-vs-input-skip', () {
      // Test that mid-parse grammar deletion is blocked (Fix #8)
      const grammar = 'S <- "a" "b" "c" "d" ;';
      // 'aXd' would need: skip X (inputSkip=1) + delete b,c (grammarSkip=2)
      // But grammarSkip > 0 at non-EOF position violates Visibility Constraint
      final r = testParse(grammar, 'aXd');
      expect(r.$1, isFalse,
          reason: 'should fail (requires mid-parse grammar deletion)');

      // Valid alternative: grammar deletion at EOF
      final r2 = testParse(grammar, 'abc');
      expect(r2.$1, isTrue, reason: 'should succeed with EOF grammar deletion');
      expect(r2.$2, equals(1), reason: 'delete "d" at EOF');
    });

    test('MIN-03-greedy-repetition-interaction', () {
      // Repetition might greedily consume too much, affecting minimality
      const grammar = 'S <- "a"+ "b" ;';
      // 'aaaaXb' - should skip X, not consume 'b' into repetition
      final r = testParse(grammar, 'aaaaXb');
      expect(r.$1, isTrue, reason: 'repetition should respect bounds');
      expect(r.$2, equals(1), reason: 'should skip only X');
    });

    test('MIN-04-nested-seq-recovery', () {
      // Test nested Seq recovery with input skipping (no grammar deletion mid-parse)
      const grammar = '''
        S <- "(" ("a" "b") ")" ;
      ''';
      // '(aXb)' - inner Seq can skip X without grammar deletion
      final r = testParse(grammar, '(aXb)');
      expect(r.$1, isTrue, reason: 'inner Seq should recover by skipping X');
      expect(r.$2, equals(1), reason: 'should skip only X');

      // '(aX)' would require deleting "b" mid-parse - should fail
      final r2 = testParse(grammar, '(aX)');
      expect(r2.$1, isFalse,
          reason: 'should fail (requires mid-parse grammar deletion)');
    });

    test('MIN-05-recovery-position-optimization', () {
      // Test structural integrity: cannot delete grammar elements mid-parse
      const grammar = 'S <- "aaa" "bbb" ;';
      // 'aaXbbb' - error breaks first element "aaa", cannot recover
      // Would require: skip "aaX" + delete "aaa" (grammarSkip=1 mid-parse)
      // This violates Visibility Constraint (Fix #8)
      final r = testParse(grammar, 'aaXbbb');
      expect(r.$1, isFalse,
          reason: 'should fail (requires mid-parse grammar deletion)');
    });
  });

  // ===========================================================================
  // SECTION D: COMPLETENESS ACCURACY ATTACKS
  // ===========================================================================

  group('Completeness Accuracy Attacks', () {
    test('COMP-01-nested-incomplete', () {
      // Deeply nested incomplete propagation
      const grammar = '''
        S <- A "z" ;
        A <- B "y" ;
        B <- C "x" ;
        C <- "a"* ;
      ''';
      // 'aaaQx...' - C matches 'aaa', then fails on Q
      // Incomplete must propagate through B -> A -> S
      final r = testParse(grammar, 'aaaQxyz');
      expect(r.$1, isTrue,
          reason: 'deeply nested incomplete should trigger recovery');
      expect(r.$2, equals(1), reason: 'should skip Q');
    });

    test('COMP-02-optional-inside-repetition', () {
      // Optional inside repetition - incomplete tracking
      const grammar = '''
        S <- ("a" "b"?)+ "z" ;
      ''';
      // 'aabXaz' - the Optional('b') failing on X should propagate
      final r = testParse(grammar, 'aabXaz');
      expect(r.$1, isTrue, reason: 'should recover');
    });

    test('COMP-03-first-alternative-incomplete', () {
      // First alternative returns incomplete, should try next
      const grammar = '''
        S <- "a"* "x" / "a"* "y" ;
      ''';
      // 'aaaQy' - first alt incomplete at Q, second should try
      final r = testParse(grammar, 'aaaQy');
      // In Phase 1, first returns incomplete. First should try second.
      // But PEG is ordered, so first failing means Seq fails.
      expect(r.$1, isTrue, reason: 'should recover');
    });

    test('COMP-04-complete-zero-length', () {
      // Zero-length match that is actually complete
      const grammar = 'S <- "x"* "a" ;';
      // ZeroOrMore matches empty at 'a' - this IS complete
      final r = testParse(grammar, 'a');
      expect(r.$1, isTrue, reason: 'zero-length complete should work');
      expect(r.$2, equals(0), reason: 'clean parse');
    });

    test('COMP-05-incomplete-at-eof', () {
      // Incomplete result exactly at EOF
      const grammar = 'S <- "a"+ "z" ;';
      // 'aaa' - OneOrMore matches, but 'z' expected at EOF
      final r = testParse(grammar, 'aaa');
      expect(r.$1, isTrue, reason: 'should delete missing z');
    });
  });

  // ===========================================================================
  // SECTION E: CACHE COHERENCE STRESS TESTS
  // ===========================================================================

  group('Cache Coherence Stress Tests', () {
    test('CACHE-01-same-clause-multiple-positions', () {
      // Same clause referenced at multiple positions
      const grammar = '''
        S <- X "+" X ;
        X <- "n" ;
      ''';
      // Input 'nQn' has "Q" instead of "+", requires grammar deletion
      // Would need: skip "Q" (inputSkip) + delete "+" (grammarSkip=1)
      // This violates Visibility Constraint - cannot delete "+" mid-parse
      final r = testParse(grammar, 'nQn');
      expect(r.$1, isFalse, reason: 'requires mid-parse grammar deletion');

      // Test that same clause works at different positions when input is valid
      final r2 = testParse(grammar, 'n+Xn');
      expect(r2.$1, isTrue, reason: 'same clause at different positions');
      expect(r2.$2, equals(1), reason: 'skip X between + and n');
    });

    test('CACHE-02-diamond-dependency', () {
      // Diamond: S -> A -> C, S -> B -> C
      const grammar = '''
        S <- A B ;
        A <- "a" C ;
        B <- "b" C ;
        C <- "c" ;
      ''';
      // C is referenced from both A and B
      final r = testParse(grammar, 'acXbc');
      expect(r.$1, isTrue, reason: 'diamond dependency should work');
    });

    test('CACHE-03-repeated-lr-at-same-pos', () {
      // Multiple LR rules starting at same position
      const grammar = '''
        S <- E ";" E ;
        E <- E "+" "n" / "n" ;
      ''';
      // Two separate E parses starting at different positions
      final r = testParse(grammar, 'n+n;n+Xn');
      expect(r.$1, isTrue, reason: 'repeated LR should work');
    });

    test('CACHE-04-interleaved-lr-and-non-lr', () {
      // Alternating between LR and non-LR clauses
      const grammar = '''
        S <- E "," F "," E ;
        E <- E "+" "n" / "n" ;
        F <- "xyz" ;
      ''';
      final r = testParse(grammar, 'n+n,xyz,n+Xn');
      expect(r.$1, isTrue, reason: 'interleaved LR/non-LR should work');
    });

    test('CACHE-05-rapid-phase-switching', () {
      // Simulate rapid switching between recovery enabled/disabled
      // This happens naturally during recovery with probes
      const grammar = '''
        S <- A* B* C* "end" ;
        A <- "a" ;
        B <- "b" ;
        C <- "c" ;
      ''';
      // Each ZeroOrMore uses probe, causing phase switches
      final r = testParse(grammar, 'aaaXbbbYcccZend');
      expect(r.$1, isTrue, reason: 'rapid phase switching should work');
    });
  });

  // ===========================================================================
  // SECTION F: PATHOLOGICAL GRAMMARS
  // ===========================================================================

  group('Pathological Grammars', () {
    test('PATH-01-deeply-nested-first', () {
      // Very deep First nesting - using grammar spec
      // Build a 20-deep First: "x" / ("x" / ("x" / ... / "target"))
      String buildDeepFirst(int depth) {
        if (depth == 0) return '"target"';
        return '"x" / (${buildDeepFirst(depth - 1)})';
      }

      final grammar = 'S <- ${buildDeepFirst(20)} ;';
      final r = testParse(grammar, 'target');
      expect(r.$1, isTrue, reason: 'deep First should work');
    });

    test('PATH-02-deeply-nested-seq', () {
      // Very deep Seq nesting - using grammar spec
      // Build: "a" ("a" ("a" ... "x"))
      String buildDeepSeq(int depth) {
        if (depth == 0) return '"x"';
        return '"a" (${buildDeepSeq(depth - 1)})';
      }

      final grammar = 'S <- (${buildDeepSeq(20)}) "end" ;';
      final input = 'a' * 20 + 'Qx' + 'end';
      final r = testParse(grammar, input);
      expect(r.$1, isTrue, reason: 'deep Seq should recover');
    });

    test('PATH-03-many-alternatives', () {
      // Many First alternatives
      final alts = List.generate(50, (i) => '"opt$i"').join(' / ');
      final grammar = 'S <- $alts / "target" ;';
      final r = testParse(grammar, 'target');
      expect(r.$1, isTrue, reason: 'many alternatives should work');
    });

    test('PATH-04-wide-seq', () {
      // Very wide Seq (many siblings)
      final elems = List.generate(
              30, (i) => '"${String.fromCharCode(97 + (i % 26))}"')
          .join(' ');
      final grammar = 'S <- $elems ;';
      // Insert error in middle
      final input =
          String.fromCharCodes(List.generate(30, (i) => 97 + (i % 26)));
      final errInput = '${input.substring(0, 15)}X${input.substring(15)}';
      final r = testParse(grammar, errInput);
      expect(r.$1, isTrue, reason: 'wide Seq should recover');
    });

    test('PATH-05-repetition-of-repetition', () {
      // Nested repetitions
      const grammar = 'S <- ("a"+)+ ;';
      final r = testParse(grammar, 'aaaXaaa');
      expect(r.$1, isTrue, reason: 'nested repetition should work');
    });
  });

  // ===========================================================================
  // SECTION G: REAL-WORLD GRAMMAR PATTERNS
  // ===========================================================================

  group('Real-World Grammar Patterns', () {
    test('REAL-01-json-like-array', () {
      const grammar = '''
        Array <- "[" Elements? "]" ;
        Elements <- Value ("," Value)* ;
        Value <- Array / "n" ;
      ''';
      // Missing comma
      final r = testParse(grammar, '[n n]', 'Array');
      expect(r.$1, isTrue, reason: 'should recover missing comma');
    });

    test('REAL-02-expression-with-parens', () {
      const grammar = '''
        E <- E "+" T / T ;
        T <- T "*" F / F ;
        F <- "(" E ")" / "n" ;
      ''';
      // Unclosed paren
      final r = testParse(grammar, '(n+n', 'E');
      expect(r.$1, isTrue, reason: 'should insert missing close paren');
    });

    test('REAL-03-statement-list', () {
      const grammar = '''
        Program <- Stmt+ ;
        Stmt <- Expr ";" ;
        Expr <- "if" "(" Expr ")" Stmt / "x" ;
      ''';
      // Missing semicolon
      final r = testParse(grammar, 'x x;', 'Program');
      expect(r.$1, isTrue, reason: 'should recover missing semicolon');
    });

    test('REAL-04-string-literal', () {
      const grammar = 'S <- "\\"" [a-z]* "\\"" ;';
      // Unclosed string
      final r = testParse(grammar, '"hello');
      expect(r.$1, isTrue, reason: 'should insert missing quote');
    });

    test('REAL-05-nested-blocks', () {
      const grammar = '''
        Block <- "{" Stmt* "}" ;
        Stmt <- Block / "x" ";" ;
      ''';
      // Deeply nested with error
      final r = testParse(grammar, '{x;{x;Xx;}}', 'Block');
      expect(r.$1, isTrue, reason: 'nested blocks should recover');
    });
  });

  // ===========================================================================
  // SECTION H: EMERGENT INTERACTION TESTS
  // ===========================================================================

  group('Emergent Interaction Tests', () {
    test('EMERG-01-lr-with-bounded-rep-recovery', () {
      // LR rule containing bounded repetition during recovery
      // FIX #9: Bound propagation now reaches nested Repetitions through context
      const grammar = '''
        S <- E "end" ;
        E <- E "+" "n"+ / "n" ;
      ''';
      // Error inside the repetition during LR expansion
      final r = testParse(grammar, 'n+nXn+nnend');
      expect(r.$1, isTrue, reason: 'LR with bounded rep should work');
    });

    test('EMERG-02-probe-triggers-lr', () {
      // A probe() call that triggers left recursion
      const grammar = '''
        S <- "a"* E ;
        E <- E "+" "n" / "n" ;
      ''';
      // ZeroOrMore probes E to check bounds, E is LR
      final r = testParse(grammar, 'aaXn+n');
      expect(r.$1, isTrue, reason: 'probe triggering LR should work');
    });

    test('EMERG-03-recovery-resets-lr-expansion', () {
      // After recovery, does LR expansion restart correctly?
      const grammar = '''
        S <- E ";" E ;
        E <- E "+" "n" / "n" ;
      ''';
      // First E has error, second E should expand fresh
      final r = testParse(grammar, 'n+Xn;n+n+n');
      expect(r.$1, isTrue, reason: 'second LR should expand independently');
      expect(r.$2, equals(1), reason: 'only first E has error');
    });

    test('EMERG-04-incomplete-propagation-through-lr', () {
      // Incomplete flag must propagate through LR expansion
      const grammar = '''
        E <- E "+" T / T ;
        T <- "n" "x"* ;
      ''';
      // T has ZeroOrMore that should mark incomplete
      final r = testParse(grammar, 'nxx+nxQx', 'E');
      expect(r.$1, isTrue, reason: 'incomplete should propagate through LR');
    });

    test('EMERG-05-cache-version-after-lr-recovery', () {
      // After LR expansion with recovery, is the cache version correct?
      const grammar = '''
        S <- E ";" E ;
        E <- E "+" "n" / "n" ;
      ''';
      // Both E's expand, with error in first
      // Version tracking must be correct for second E
      final r = testParse(grammar, 'n+Xn+n;n+n');
      expect(r.$1, isTrue,
          reason: 'version should be correct after LR recovery');
    });
  });
}
