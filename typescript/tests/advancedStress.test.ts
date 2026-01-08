/**
 * ADVANCED STRESS TESTS FOR SQUIRREL PARSER RECOVERY
 * These tests attempt to expose edge cases, subtle bugs, and potential
 * violations of the three invariants (Completeness, Isolation, Minimality).
 */

import { describe, expect, test } from '@jest/globals';
import type { Clause } from '../src';
import { CharRange, First, NotFollowedBy, OneOrMore, Optional, Ref, Seq, Str, ZeroOrMore } from '../src';
import { parse } from './testUtils';

describe('Phase Isolation Attacks', () => {
  test('ISO-01-probe-during-recovery-probe', () => {
    // Nested probe scenario: recovery calls probe, which may trigger
    // another bounded repetition that also calls probe.
    const grammar: Record<string, Clause> = {
      S: new Seq([new ZeroOrMore(new Ref('A')), new Ref('B')]),
      A: new Seq([new OneOrMore(new Str('a')), new Str('x')]),
      B: new Seq([new Str('b'), new Str('z')]),
    };
    // 'A' has inner OneOrMore which uses bound checking via probe
    // S's ZeroOrMore also uses probe for bounds
    const [ok, _err, _] = parse(grammar, 'aaXxbz');
    expect(ok).toBe(true); // nested probe should not poison cache
  });

  test('ISO-02-recovery-version-overflow', () => {
    // Many small errors to increment recoveryVersion many times
    // Tests that version counter doesn't wrap or cause issues
    const grammar: Record<string, Clause> = {
      S: new OneOrMore(new Str('ab')),
    };
    // FIX #10: With first-iteration recovery, input "aXaXaX...ab" skips all the way to first 'ab'
    // This counts as 1 error (entire skipped region). To test multiple errors, use "abXabXabX..."
    const input = 'ab' + Array.from({ length: 50 }, () => 'Xab').join('');
    const [ok, err, _] = parse(grammar, input);
    expect(ok).toBe(true); // many errors should not overflow version
    expect(err).toBe(50); // should count all 50 errors
  });

  test('ISO-03-alternating-probe-match', () => {
    // Alternate between probe and real match at same position
    const grammar: Record<string, Clause> = {
      S: new Seq([
        new ZeroOrMore(new Ref('A')),
        new ZeroOrMore(new Ref('B')),
        new Str('end'),
      ]),
      A: new Str('a'),
      B: new Str('a'), // Same as A - creates ambiguity
    };
    // Both ZeroOrMore will probe 'a' positions
    const [ok, _err, _] = parse(grammar, 'aaaXend');
    expect(ok).toBe(true); // ambiguous probes should resolve correctly
  });

  test('ISO-04-complete-result-reuse-after-lr', () => {
    // A complete result at position P, then LR expansion that touches P
    const grammar: Record<string, Clause> = {
      S: new Seq([new Ref('A'), new Ref('E')]),
      A: new Str('a'),
      E: new First([
        new Seq([new Ref('E'), new Str('+'), new Str('a')]),
        new Str('a'),
      ]),
    };
    // 'A' matches 'a' (complete). Then E starts LR at position 1.
    // E should not reuse A's result at position 0.
    const [ok, err, _] = parse(grammar, 'aa+a');
    expect(ok).toBe(true); // complete result should be isolated from LR
    expect(err).toBe(0); // clean parse
  });

  test('ISO-05-mismatch-cache-across-phases', () => {
    // Ensure mismatch in Phase 1 doesn't block recovery in Phase 2
    const grammar: Record<string, Clause> = {
      S: new First([
        new Seq([new Str('abc'), new Str('xyz')]),
        new Seq([new Str('ab'), new Str('z')]),
      ]),
    };
    // Phase 1: First alternative fails at 'Xz', second fails at 'X'
    // Phase 2: Should skip 'X' and match second alternative
    const [ok, _err, _] = parse(grammar, 'abXz');
    expect(ok).toBe(true); // Phase 1 mismatch should not block Phase 2
  });
});

describe('Left Recursion Edge Cases', () => {
  test('LR-EDGE-01-triple-nested-lr', () => {
    // Three levels of left recursion
    const grammar: Record<string, Clause> = {
      A: new First([
        new Seq([new Ref('A'), new Str('+'), new Ref('B')]),
        new Ref('B'),
      ]),
      B: new First([
        new Seq([new Ref('B'), new Str('*'), new Ref('C')]),
        new Ref('C'),
      ]),
      C: new First([
        new Seq([new Ref('C'), new Str('-'), new Str('n')]),
        new Str('n'),
      ]),
    };
    // Error at deepest level
    const [ok, _err, _] = parse(grammar, 'n+n*n-Xn', 'A');
    expect(ok).toBe(true); // triple LR should recover
  });

  test('LR-EDGE-02-lr-inside-repetition', () => {
    // Left recursion inside a repetition
    const grammar: Record<string, Clause> = {
      S: new OneOrMore(new Ref('E')),
      E: new First([
        new Seq([new Ref('E'), new Str('+'), new Str('n')]),
        new Str('n'),
      ]),
    };
    // Two LR expressions separated by space
    const [ok, _err, _] = parse(grammar, 'n+nXn+n');
    expect(ok).toBe(true); // LR inside repetition should work
  });

  test('LR-EDGE-03-lr-with-lookahead', () => {
    // Left recursion with negative lookahead
    const grammar: Record<string, Clause> = {
      E: new First([
        new Seq([new Ref('E'), new Str('+'), new Ref('T')]),
        new Ref('T'),
      ]),
      T: new Seq([new NotFollowedBy(new Str('+')), new Str('n')]),
    };
    const [ok, _err, _] = parse(grammar, 'n+Xn', 'E');
    expect(ok).toBe(true); // LR with lookahead should recover
  });

  test('LR-EDGE-04-mutual-lr', () => {
    // Mutually recursive left recursion
    const grammar: Record<string, Clause> = {
      A: new First([
        new Seq([new Ref('B'), new Str('a')]),
        new Str('x'),
      ]),
      B: new First([
        new Seq([new Ref('A'), new Str('b')]),
        new Str('y'),
      ]),
    };
    const [ok, _err, _] = parse(grammar, 'ybaXba', 'A');
    expect(ok).toBe(true); // mutual LR should recover
  });

  test('LR-EDGE-05-lr-zero-length-between', () => {
    // LR with zero-length elements between recursive call and terminal
    const grammar: Record<string, Clause> = {
      E: new First([
        new Seq([new Ref('E'), new Optional(new Str(' ')), new Str('+'), new Str('n')]),
        new Str('n'),
      ]),
    };
    const [ok, _err, _] = parse(grammar, 'n +Xn', 'E');
    expect(ok).toBe(true); // LR with optional should recover
  });

  test('LR-EDGE-06-lr-empty-base', () => {
    // LR where base case can be empty
    const grammar: Record<string, Clause> = {
      E: new First([
        new Seq([new Ref('E'), new Str('+'), new Str('n')]),
        new Optional(new Str('n')), // Can match empty!
      ]),
    };
    // This is a pathological grammar - empty base allows infinite LR
    // Parser should handle gracefully
    const [_ok, _err, _] = parse(grammar, '+n+n', 'E');
    // May fail or succeed with errors - just shouldn't infinite loop
    expect(true).toBe(true); // should not infinite loop
  });
});

describe('Recovery Minimality Attacks', () => {
  test('MIN-01-multiple-valid-recoveries', () => {
    // Multiple ways to recover - should choose minimal
    const grammar: Record<string, Clause> = {
      S: new First([
        new Seq([new Str('a'), new Str('b'), new Str('c')]),
        new Seq([new Str('a'), new Str('c')]),
      ]),
    };
    // 'aXc' can recover by: skip X (1 error) or delete b, skip X (2 errors)
    const [ok, err, _] = parse(grammar, 'aXc');
    expect(ok).toBe(true); // should find recovery
    expect(err).toBe(1); // should choose minimal recovery
  });

  test('MIN-02-grammar-deletion-vs-input-skip', () => {
    // Test that mid-parse grammar deletion is blocked (Fix #8)
    const grammar: Record<string, Clause> = {
      S: new Seq([new Str('a'), new Str('b'), new Str('c'), new Str('d')]),
    };
    // 'aXd' would need: skip X (inputSkip=1) + delete b,c (grammarSkip=2)
    // But grammarSkip > 0 at non-EOF position violates Visibility Constraint
    const [ok, _err, _] = parse(grammar, 'aXd');
    expect(ok).toBe(false); // should fail (requires mid-parse grammar deletion)

    // Valid alternative: grammar deletion at EOF
    const [ok2, err2, _2] = parse(grammar, 'abc');
    expect(ok2).toBe(true); // should succeed with EOF grammar deletion
    expect(err2).toBe(1); // delete "d" at EOF
  });

  test('MIN-03-greedy-repetition-interaction', () => {
    // Repetition might greedily consume too much, affecting minimality
    const grammar: Record<string, Clause> = {
      S: new Seq([new OneOrMore(new Str('a')), new Str('b')]),
    };
    // 'aaaaXb' - should skip X, not consume 'b' into repetition
    const [ok, err, _] = parse(grammar, 'aaaaXb');
    expect(ok).toBe(true); // repetition should respect bounds
    expect(err).toBe(1); // should skip only X
  });

  test('MIN-04-nested-seq-recovery', () => {
    // Test nested Seq recovery with input skipping (no grammar deletion mid-parse)
    const grammar: Record<string, Clause> = {
      S: new Seq([
        new Str('('),
        new Seq([new Str('a'), new Str('b')]),
        new Str(')'),
      ]),
    };
    // '(aXb)' - inner Seq can skip X without grammar deletion
    const [ok, err, _] = parse(grammar, '(aXb)');
    expect(ok).toBe(true); // inner Seq should recover by skipping X
    expect(err).toBe(1); // should skip only X

    // '(aX)' would require deleting "b" mid-parse - should fail
    const [ok2, _err2, _2] = parse(grammar, '(aX)');
    expect(ok2).toBe(false); // should fail (requires mid-parse grammar deletion)
  });

  test('MIN-05-recovery-position-optimization', () => {
    // Test structural integrity: cannot delete grammar elements mid-parse
    const grammar: Record<string, Clause> = {
      S: new Seq([new Str('aaa'), new Str('bbb')]),
    };
    // 'aaXbbb' - error breaks first element "aaa", cannot recover
    // Would require: skip "aaX" + delete "aaa" (grammarSkip=1 mid-parse)
    // This violates Visibility Constraint (Fix #8)
    const [ok, _err, _] = parse(grammar, 'aaXbbb');
    expect(ok).toBe(false); // should fail (requires mid-parse grammar deletion)
  });
});

describe('Completeness Accuracy Attacks', () => {
  test('COMP-01-nested-incomplete', () => {
    // Deeply nested incomplete propagation
    const grammar: Record<string, Clause> = {
      S: new Seq([new Ref('A'), new Str('z')]),
      A: new Seq([new Ref('B'), new Str('y')]),
      B: new Seq([new Ref('C'), new Str('x')]),
      C: new ZeroOrMore(new Str('a')),
    };
    // 'aaaQx...' - C matches 'aaa', then fails on Q
    // Incomplete must propagate through B -> A -> S
    const [ok, err, _] = parse(grammar, 'aaaQxyz');
    expect(ok).toBe(true); // deeply nested incomplete should trigger recovery
    expect(err).toBe(1); // should skip Q
  });

  test('COMP-02-optional-inside-repetition', () => {
    // Optional inside repetition - incomplete tracking
    const grammar: Record<string, Clause> = {
      S: new Seq([
        new OneOrMore(new Seq([new Str('a'), new Optional(new Str('b'))])),
        new Str('z'),
      ]),
    };
    // 'aabXaz' - the Optional('b') failing on X should propagate
    const [ok, _err, _] = parse(grammar, 'aabXaz');
    expect(ok).toBe(true); // should recover
  });

  test('COMP-03-first-alternative-incomplete', () => {
    // First alternative returns incomplete, should try next
    const grammar: Record<string, Clause> = {
      S: new First([
        new Seq([new ZeroOrMore(new Str('a')), new Str('x')]),
        new Seq([new ZeroOrMore(new Str('a')), new Str('y')]),
      ]),
    };
    // 'aaaQy' - first alt incomplete at Q, second should try
    const [ok, _err, _] = parse(grammar, 'aaaQy');
    // In Phase 1, first returns incomplete. First should try second.
    // But PEG is ordered, so first failing means Seq fails.
    expect(ok).toBe(true); // should recover
  });

  test('COMP-04-complete-zero-length', () => {
    // Zero-length match that is actually complete
    const grammar: Record<string, Clause> = {
      S: new Seq([new ZeroOrMore(new Str('x')), new Str('a')]),
    };
    // ZeroOrMore matches empty at 'a' - this IS complete
    const [ok, err, _] = parse(grammar, 'a');
    expect(ok).toBe(true); // zero-length complete should work
    expect(err).toBe(0); // clean parse
  });

  test('COMP-05-incomplete-at-eof', () => {
    // Incomplete result exactly at EOF
    const grammar: Record<string, Clause> = {
      S: new Seq([new OneOrMore(new Str('a')), new Str('z')]),
    };
    // 'aaa' - OneOrMore matches, but 'z' expected at EOF
    const [ok, _err, _] = parse(grammar, 'aaa');
    expect(ok).toBe(true); // should delete missing z
  });
});

describe('Cache Coherence Stress Tests', () => {
  test('CACHE-01-same-clause-multiple-positions', () => {
    // Same clause referenced at multiple positions
    const grammar: Record<string, Clause> = {
      S: new Seq([new Ref('X'), new Str('+'), new Ref('X')]),
      X: new Str('n'),
    };
    // Input 'nQn' has "Q" instead of "+", requires grammar deletion
    // Would need: skip "Q" (inputSkip) + delete "+" (grammarSkip=1)
    // This violates Visibility Constraint - cannot delete "+" mid-parse
    const [ok, _err, _] = parse(grammar, 'nQn');
    expect(ok).toBe(false); // requires mid-parse grammar deletion

    // Test that same clause works at different positions when input is valid
    const [ok2, err2, _2] = parse(grammar, 'n+Xn');
    expect(ok2).toBe(true); // same clause at different positions
    expect(err2).toBe(1); // skip X between + and n
  });

  test('CACHE-02-diamond-dependency', () => {
    // Diamond: S -> A -> C, S -> B -> C
    const grammar: Record<string, Clause> = {
      S: new Seq([new Ref('A'), new Ref('B')]),
      A: new Seq([new Str('a'), new Ref('C')]),
      B: new Seq([new Str('b'), new Ref('C')]),
      C: new Str('c'),
    };
    // C is referenced from both A and B
    const [ok, _err, _] = parse(grammar, 'acXbc');
    expect(ok).toBe(true); // diamond dependency should work
  });

  test('CACHE-03-repeated-lr-at-same-pos', () => {
    // Multiple LR rules starting at same position
    const grammar: Record<string, Clause> = {
      S: new Seq([new Ref('E'), new Str(';'), new Ref('E')]),
      E: new First([
        new Seq([new Ref('E'), new Str('+'), new Str('n')]),
        new Str('n'),
      ]),
    };
    // Two separate E parses starting at different positions
    const [ok, _err, _] = parse(grammar, 'n+n;n+Xn');
    expect(ok).toBe(true); // repeated LR should work
  });

  test('CACHE-04-interleaved-lr-and-non-lr', () => {
    // Alternating between LR and non-LR clauses
    const grammar: Record<string, Clause> = {
      S: new Seq([new Ref('E'), new Str(','), new Ref('F'), new Str(','), new Ref('E')]),
      E: new First([
        new Seq([new Ref('E'), new Str('+'), new Str('n')]),
        new Str('n'),
      ]),
      F: new Str('xyz'),
    };
    const [ok, _err, _] = parse(grammar, 'n+n,xyz,n+Xn');
    expect(ok).toBe(true); // interleaved LR/non-LR should work
  });

  test('CACHE-05-rapid-phase-switching', () => {
    // Simulate rapid switching between recovery enabled/disabled
    // This happens naturally during recovery with probes
    const grammar: Record<string, Clause> = {
      S: new Seq([
        new ZeroOrMore(new Ref('A')),
        new ZeroOrMore(new Ref('B')),
        new ZeroOrMore(new Ref('C')),
        new Str('end'),
      ]),
      A: new Str('a'),
      B: new Str('b'),
      C: new Str('c'),
    };
    // Each ZeroOrMore uses probe, causing phase switches
    const [ok, _err, _] = parse(grammar, 'aaaXbbbYcccZend');
    expect(ok).toBe(true); // rapid phase switching should work
  });
});

describe('Pathological Grammars', () => {
  test('PATH-01-deeply-nested-first', () => {
    // Very deep First nesting
    function buildDeepFirst(depth: number, terminal: string): Clause {
      if (depth === 0) return new Str(terminal);
      return new First([new Str('x'), buildDeepFirst(depth - 1, terminal)]);
    }

    const grammar: Record<string, Clause> = {
      S: buildDeepFirst(20, 'target'),
    };
    const [ok, _err, _] = parse(grammar, 'target');
    expect(ok).toBe(true); // deep First should work
  });

  test('PATH-02-deeply-nested-seq', () => {
    // Very deep Seq nesting
    function buildDeepSeq(depth: number): Clause {
      if (depth === 0) return new Str('x');
      return new Seq([new Str('a'), buildDeepSeq(depth - 1)]);
    }

    const grammar: Record<string, Clause> = {
      S: new Seq([buildDeepSeq(20), new Str('end')]),
    };
    const input = 'a'.repeat(20) + 'Qx' + 'end';
    const [ok, _err, _] = parse(grammar, input);
    expect(ok).toBe(true); // deep Seq should recover
  });

  test('PATH-03-many-alternatives', () => {
    // Many First alternatives
    const alts = Array.from({ length: 50 }, (_, i) => new Str(`opt${i}`));
    const grammar: Record<string, Clause> = {
      S: new First([...alts, new Str('target')]),
    };
    const [ok, _err, _] = parse(grammar, 'target');
    expect(ok).toBe(true); // many alternatives should work
  });

  test('PATH-04-wide-seq', () => {
    // Very wide Seq (many siblings)
    const elems = Array.from({ length: 30 }, (_, i) => new Str(String.fromCharCode(97 + (i % 26))));
    const grammar: Record<string, Clause> = {
      S: new Seq(elems),
    };
    // Insert error in middle
    const input = String.fromCharCode(...Array.from({ length: 30 }, (_, i) => 97 + (i % 26)));
    const errInput = input.substring(0, 15) + 'X' + input.substring(15);
    const [ok, _err, _] = parse(grammar, errInput);
    expect(ok).toBe(true); // wide Seq should recover
  });

  test('PATH-05-repetition-of-repetition', () => {
    // Nested repetitions
    const grammar: Record<string, Clause> = {
      S: new OneOrMore(new OneOrMore(new Str('a'))),
    };
    const [ok, _err, _] = parse(grammar, 'aaaXaaa');
    expect(ok).toBe(true); // nested repetition should work
  });
});

describe('Real-World Grammar Patterns', () => {
  test('REAL-01-json-like-array', () => {
    const grammar: Record<string, Clause> = {
      Array: new Seq([new Str('['), new Optional(new Ref('Elements')), new Str(']')]),
      Elements: new Seq([
        new Ref('Value'),
        new ZeroOrMore(new Seq([new Str(','), new Ref('Value')])),
      ]),
      Value: new First([new Ref('Array'), new Str('n')]),
    };
    // Missing comma
    const [ok, _err, _] = parse(grammar, '[n n]', 'Array');
    expect(ok).toBe(true); // should recover missing comma
  });

  test('REAL-02-expression-with-parens', () => {
    const grammar: Record<string, Clause> = {
      E: new First([
        new Seq([new Ref('E'), new Str('+'), new Ref('T')]),
        new Ref('T'),
      ]),
      T: new First([
        new Seq([new Ref('T'), new Str('*'), new Ref('F')]),
        new Ref('F'),
      ]),
      F: new First([
        new Seq([new Str('('), new Ref('E'), new Str(')')]),
        new Str('n'),
      ]),
    };
    // Unclosed paren
    const [ok, _err, _] = parse(grammar, '(n+n', 'E');
    expect(ok).toBe(true); // should insert missing close paren
  });

  test('REAL-03-statement-list', () => {
    const grammar: Record<string, Clause> = {
      Program: new OneOrMore(new Ref('Stmt')),
      Stmt: new Seq([new Ref('Expr'), new Str(';')]),
      Expr: new First([
        new Seq([new Str('if'), new Str('('), new Ref('Expr'), new Str(')'), new Ref('Stmt')]),
        new Str('x'),
      ]),
    };
    // Missing semicolon
    const [ok, _err, _] = parse(grammar, 'x x;', 'Program');
    expect(ok).toBe(true); // should recover missing semicolon
  });

  test('REAL-04-string-literal', () => {
    const grammar: Record<string, Clause> = {
      S: new Seq([new Str('"'), new ZeroOrMore(new CharRange('a', 'z')), new Str('"')]),
    };
    // Unclosed string
    const [ok, _err, _] = parse(grammar, '"hello');
    expect(ok).toBe(true); // should insert missing quote
  });

  test('REAL-05-nested-blocks', () => {
    const grammar: Record<string, Clause> = {
      Block: new Seq([new Str('{'), new ZeroOrMore(new Ref('Stmt')), new Str('}')]),
      Stmt: new First([new Ref('Block'), new Seq([new Str('x'), new Str(';')])]),
    };
    // Deeply nested with error
    const [ok, _err, _] = parse(grammar, '{x;{x;Xx;}}', 'Block');
    expect(ok).toBe(true); // nested blocks should recover
  });
});

describe('Emergent Interaction Tests', () => {
  test('EMERG-01-lr-with-bounded-rep-recovery', () => {
    // LR rule containing bounded repetition during recovery
    // FIX #9: Bound propagation now reaches nested Repetitions through context
    const grammar: Record<string, Clause> = {
      S: new Seq([new Ref('E'), new Str('end')]),
      E: new First([
        new Seq([new Ref('E'), new Str('+'), new OneOrMore(new Str('n'))]),
        new Str('n'),
      ]),
    };
    // Error inside the repetition during LR expansion
    const [ok, _err, _] = parse(grammar, 'n+nXn+nnend');
    expect(ok).toBe(true); // LR with bounded rep should work
  });

  test('EMERG-02-probe-triggers-lr', () => {
    // A probe() call that triggers left recursion
    const grammar: Record<string, Clause> = {
      S: new Seq([new ZeroOrMore(new Str('a')), new Ref('E')]),
      E: new First([
        new Seq([new Ref('E'), new Str('+'), new Str('n')]),
        new Str('n'),
      ]),
    };
    // ZeroOrMore probes E to check bounds, E is LR
    const [ok, _err, _] = parse(grammar, 'aaXn+n');
    expect(ok).toBe(true); // probe triggering LR should work
  });

  test('EMERG-03-recovery-resets-lr-expansion', () => {
    // After recovery, does LR expansion restart correctly?
    const grammar: Record<string, Clause> = {
      S: new Seq([new Ref('E'), new Str(';'), new Ref('E')]),
      E: new First([
        new Seq([new Ref('E'), new Str('+'), new Str('n')]),
        new Str('n'),
      ]),
    };
    // First E has error, second E should expand fresh
    const [ok, err, _] = parse(grammar, 'n+Xn;n+n+n');
    expect(ok).toBe(true); // second LR should expand independently
    expect(err).toBe(1); // only first E has error
  });

  test('EMERG-04-incomplete-propagation-through-lr', () => {
    // Incomplete flag must propagate through LR expansion
    const grammar: Record<string, Clause> = {
      E: new First([
        new Seq([new Ref('E'), new Str('+'), new Ref('T')]),
        new Ref('T'),
      ]),
      T: new Seq([new Str('n'), new ZeroOrMore(new Str('x'))]),
    };
    // T has ZeroOrMore that should mark incomplete
    const [ok, _err, _] = parse(grammar, 'nxx+nxQx', 'E');
    expect(ok).toBe(true); // incomplete should propagate through LR
  });

  test('EMERG-05-cache-version-after-lr-recovery', () => {
    // After LR expansion with recovery, is the cache version correct?
    const grammar: Record<string, Clause> = {
      S: new Seq([new Ref('E'), new Str(';'), new Ref('E')]),
      E: new First([
        new Seq([new Ref('E'), new Str('+'), new Str('n')]),
        new Str('n'),
      ]),
    };
    // Both E's expand, with error in first
    // Version tracking must be correct for second E
    const [ok, _err, _] = parse(grammar, 'n+Xn+n;n+n');
    expect(ok).toBe(true); // version should be correct after LR recovery
  });
});
