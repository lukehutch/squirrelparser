// _starwide75.dart -- Codex's counterexample, checked against m74.
//
// I reported the possessive star stop as EXACT on the strength of _holes75's
// three star grammars (0 wrong of 491). Codex measured `("ab")* "abc"` and found
// it wrong on every input. The two claims are compatible: none of my three
// grammars can exhibit the hole, because in each one the star's FOLLOWER does
// not begin with the star's BODY, so the stop never has to be proved.
//
//   ("ab")* 'a' 'c'  -- follower "ac", star stops before it, LANGUAGE NON-EMPTY
//   ('a' 'b')* !.    -- follower is EOF, LANGUAGE NON-EMPTY
//   'a'* "ab"        -- one-character body, so `_oneCharClass` is NOT null and
//                       the obligation is actually carried
//
// `("ab")* "abc"` is the multi-character analogue of the third. PROVEN empty,
// not merely checked: the star is possessive, so where it stops the input does
// not begin with "ab"; but the follower "abc" does begin with "ab". No input can
// match, and the true cost is -1 EVERYWHERE. Any finite answer is m74 claiming a
// repair that does not exist.
import 'dart:io';

import 'package:squirrel_parser/squirrel_parser.dart';

import 'm74.dart' as e74;

bool inLang(Map<String, Clause> r, String t, String s) {
  final p = Parser(rules: r, topRuleName: t, input: s).parse();
  return !p.hasSyntaxErrors && p.root.len == s.length;
}

/// Every string over `alpha` up to length `n` that the grammar accepts.
List<String> members(Map<String, Clause> r, String t, String alpha, int n) {
  final hits = <String>[];
  var frontier = <String>[''];
  for (var len = 0; len <= n; len++) {
    for (final s in frontier) {
      if (inLang(r, t, s)) hits.add(s);
    }
    frontier = [
      for (final s in frontier)
        for (final c in alpha.split('')) s + c
    ];
  }
  return hits;
}

final cases = <(String, String, List<String>, String)>[
  ("S <- 'a'* \"ab\";\n", 'ab', ['', 'b', 'aab', 'aaaab', 'ab'],
      'ONE-char body: obligation is carried'),
  ("S <- (\"ab\")* \"abc\";\n", 'abc', ['', 'c', 'abc', 'ababc', 'abab'],
      "CODEX'S CASE: two-char body, follower starts with body"),
  ("S <- (\"ab\")* 'a' 'c';\n", 'abc', ['', 'ac', 'abac', 'ab'],
      'my _holes75 probe: follower disjoint at char 2'),
  ("S <- ('a' 'b')* !.;\n", 'ab', ['', 'ab', 'abab', 'aba'],
      'my _holes75 probe: follower is EOF'),
  ("S <- (\"ab\")* \"cd\";\n", 'abcd', ['', 'cd', 'abcd', 'ababq'],
      'control: two-char body, disjoint follower'),
];

void main() {
  var wrong = 0, checked = 0;
  for (final (g, alpha, inputs, what) in cases) {
    final r = MetaGrammar.parseGrammar(g);
    final hits = members(r, 'S', alpha, 6);
    final empty = hits.isEmpty;
    stdout.writeln('\n${g.trim()}');
    stdout.writeln('  $what');
    stdout.writeln('  members up to length 6: ${hits.length}'
        '${empty ? "  => LANGUAGE EMPTY, truth is -1 on every input" : "  "
            "e.g. ${hits.take(4).map((s) => '"$s"').join(" ")}"}');
    for (final s in inputs) {
      final c74 = e74.SuperDot3(rules: r, topRuleName: 'S').recoverCost(s);
      final e = e74.SuperDot3(rules: r, topRuleName: 'S');
      final res = e.recover(s);
      checked++;
      final mark = empty
          ? (c74 == -1 ? 'ok' : '<-- m74 WRONG (truth -1, said $c74)')
          : '';
      if (empty && c74 != -1) wrong++;
      stdout.writeln('  ${'"$s"'.padRight(10)} m74 cost ${c74.toString().padLeft(3)}'
          '  verified=${e.lastVerified}'
          '  forced=${res.forced} clean=${res.clean}  $mark');
    }
  }
  stdout.writeln('\nm74 wrong on $wrong of $checked '
      '(only empty-language rows can be scored here)');
}
