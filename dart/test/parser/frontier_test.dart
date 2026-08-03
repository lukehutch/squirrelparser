// ===========================================================================
// MISMATCH FRONTIER TESTS
// ===========================================================================
// A mismatch used to be one shared tombstone carrying len == -1 and no
// children, so the end of the validly-parsed input could only be approximated
// by scanning the memo table for the largest failing position. Each mismatch is
// now its own node: `pos + len` is the exact end of the input the subtree read
// and accepted, and the results it accumulated before failing are its children.
//
// These tests pin the three things that change: the length is now real, the
// children are now there, and nothing may compare a mismatch's length against a
// match's without asking `isMismatch` first.

import 'package:test/test.dart';

import 'package:squirrel_parser/squirrel_parser.dart';

/// Match [topRule] of [grammarSpec] against [input] with the pure parser.
MatchResult matchOf(String grammarSpec, String topRule, String input) {
  final parser = Parser(rules: MetaGrammar.parseGrammar(grammarSpec), topRuleName: topRule, input: input);
  return parser.matchRule(topRule, 0);
}

/// The deepest position any mismatch in [m] read up to.
int deepestFrontier(MatchResult m) {
  var best = -1;
  void walk(MatchResult k) {
    if (k is Mismatch && k.frontier > best) best = k.frontier;
    k.subClauseMatches.forEach(walk);
  }

  walk(m);
  return best;
}

void main() {
  group('Mismatch frontier', () {
    test('FRONT-01-seq-reports-the-slots-that-matched', () {
      // 'ab' matches, 'c' does not, so the sequence read exactly 2 characters.
      final m = matchOf("S <- 'a' 'b' 'c';", 'S', 'abX');
      expect(m.isMismatch, isTrue);
      expect(m, isA<Mismatch>());
      expect((m as Mismatch).frontier, 2);
      expect(m.len, 2);
      // The two matched slots plus the one that failed.
      expect(m.subClauseMatches.length, 3);
      expect(m.subClauseMatches[0].isMismatch, isFalse);
      expect(m.subClauseMatches[1].isMismatch, isFalse);
      expect(m.subClauseMatches[2].isMismatch, isTrue);
    });

    test('FRONT-02-str-reports-the-prefix-the-input-supplied', () {
      // `fun` of `function`: the error is three characters in, not at the start.
      final m = matchOf('S <- "function";', 'S', 'fun(');
      expect(m.isMismatch, isTrue);
      expect((m as Mismatch).frontier, 3);
    });

    test('FRONT-03-str-running-off-the-end-is-the-same-question', () {
      final m = matchOf('S <- "function";', 'S', 'fun');
      expect(m.isMismatch, isTrue);
      expect((m as Mismatch).frontier, 3);
    });

    test('FRONT-04-nested-seq-frontier-is-exact', () {
      // Everything up to the 8 is valid, so the frontier is at the 8.
      final g = "S <- '(' Digits ')'; Digits <- [0-9]+;";
      final m = matchOf(g, 'S', '(123');
      expect(m.isMismatch, isTrue);
      expect(deepestFrontier(m), 4);
    });

    test('FRONT-05-first-reports-the-arm-that-got-furthest', () {
      // Arm 1 reads 'ab' before failing; arm 2 fails immediately.
      final g = 'S <- "abc" / \'z\';';
      final m = matchOf(g, 'S', 'abX');
      expect(m.isMismatch, isTrue);
      expect((m as Mismatch).frontier, 2);
      // Every arm is kept, not just the furthest one.
      expect(m.subClauseMatches.length, 2);
    });

    test('FRONT-06-onetomore-carries-what-stopped-it', () {
      final m = matchOf("S <- [0-9]+;", 'S', 'xyz');
      expect(m.isMismatch, isTrue);
      expect((m as Mismatch).frontier, 0);
      expect(m.subClauseMatches.length, 1);
      expect(m.subClauseMatches.single.isMismatch, isTrue);
    });

    test('FRONT-07-predicates-are-zero-width-and-childless', () {
      // A predicate reads nothing, so its frontier is its own position, and a
      // repair placed under it would consume input the assertion does not.
      final notFollowed = matchOf("S <- !'a' 'b';", 'S', 'ab');
      expect(notFollowed.isMismatch, isTrue);
      expect(deepestFrontier(notFollowed), 0);

      final followed = matchOf("S <- &'a' 'a';", 'S', 'zz');
      expect(followed.isMismatch, isTrue);
      expect(deepestFrontier(followed), 0);
    });

    test('FRONT-08-a-long-mismatch-never-beats-a-short-match', () {
      // THE SENTINEL TEST. The memo fixed point used to read
      // `newResult.len <= result.len`, which was safe only because a mismatch
      // carried len == -1. Here a left recursive rule's failing attempt reads
      // far more input than its successful one; if length alone decided, the
      // mismatch would overwrite the match and the parse would collapse.
      final g = "E <- E '+' N / N; N <- [0-9]+;";
      final m = matchOf(g, 'E', '1+2+3');
      expect(m.isMismatch, isFalse);
      expect(m.len, 5);
    });

    test('FRONT-09-a-whole-parse-still-succeeds-unchanged', () {
      final m = matchOf("S <- 'a'+ 'b';", 'S', 'aaab');
      expect(m.isMismatch, isFalse);
      expect(m.len, 4);
    });

    test('FRONT-11-a-left-recursive-failure-keeps-its-evidence', () {
      // The left recursion fixed point seeds the cycle with a childless
      // zero-length mismatch, then breaks as soon as the next attempt also
      // fails -- and used to break while still holding the SEED, so every
      // left recursive rule reported a failure with no structure under it.
      // The two grammars here accept the same language and differ only in
      // which one is left recursive, so their failures must carry the same
      // evidence.
      final lr = matchOf("E <- E '+' N / N; N <- [0-9]+;", 'E', '+1');
      final notLr = matchOf("E <- N '+' E / N; N <- [0-9]+;", 'E', '+1');
      expect(lr.isMismatch, isTrue);
      expect(notLr.isMismatch, isTrue);
      // Both arms are reported, not a bare seed.
      expect(lr.subClauseMatches.length, notLr.subClauseMatches.length);
      expect(lr.subClauseMatches.length, 2);
    });

    test('FRONT-12-a-left-recursive-frontier-is-a-place-in-the-tree', () {
      // `(a` is the case the recovery experiments named: with the seed kept,
      // the whole grammar offered one site and nothing could be repaired.
      final m = matchOf("E <- E '+' T / T; T <- '(' E ')' / N; N <- [0-9]+;", 'E', '(a');
      expect(m.isMismatch, isTrue);
      // The '(' was read and accepted before anything failed.
      expect(deepestFrontier(m), 1);
      expect(m.subClauseMatches, isNotEmpty);
    });

    test('FRONT-10-mismatches-never-reach-the-AST', () {
      // The returned tree holds matches and SyntaxErrors; a mismatch is a
      // statement about why the parse stopped, not a construct in the input.
      final root = squirrelParseAST(grammarSpec: "S <- 'a' 'b' 'c';", topRuleName: 'S', input: 'abX');
      void walk(ASTNode n) {
        expect(n.label, isNot(equals('MISMATCH')));
        n.children.forEach(walk);
      }

      walk(root);
    });
  });
}
