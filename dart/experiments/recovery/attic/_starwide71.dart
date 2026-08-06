// _starwide71.dart -- the honest limit of I27, stated as a grammar.
//
// I27 discharges a star's stop by asking for the complement of the body's FIRST
// class, and `_oneCharClass` is null when the body is more than one character
// wide: the complement is then SUFFICIENT for failure but not NECESSARY, so the
// obligation is dropped and the stop stays free -- m62's behaviour.
//
// _subset71 already carries two multi-character star bodies -- ('a' 'b')* 'a' !.
// and ('a' / 'b' 'a')* "bb" -- and BOTH engines are exact on them, so they do not
// exhibit the hole. They cannot: their followers do not begin with the body.
//
// The exact multi-character analogue of the conformance case is ("ab")* "abc".
// The star is possessive, so wherever "abc" could match, the star has already
// eaten its "ab"; and the star never stops in front of an "ab". The language is
// therefore EMPTY, exactly as for 'a'* "ab", and the true cost is -1 on EVERY
// input. That is a truth no enumeration has to establish, which makes this the
// cheapest possible probe of the hole.
import 'package:squirrel_parser/squirrel_parser.dart';

import 'm62.dart' as e62;
import 'm70.dart' as e70;
import 'm71.dart' as e71;

bool inLang(Map<String, Clause> r, String t, String s) {
  final p = Parser(rules: r, topRuleName: t, input: s).parse();
  return !p.hasSyntaxErrors && p.root.len == s.length;
}

/// Sanity: no string up to `n` is in the language, so -1 is the truth.
int emptyCheck(Map<String, Clause> r, String t, String alpha, int n) {
  var hits = 0;
  var frontier = <String>[''];
  for (var len = 0; len <= n; len++) {
    for (final s in frontier) {
      if (inLang(r, t, s)) hits++;
    }
    frontier = [
      for (final s in frontier)
        for (final c in alpha.split('')) s + c
    ];
  }
  return hits;
}

final cases = <(String, String, List<String>)>[
  // The one-character original, which I27 fixes. Empty language.
  ("S <- 'a'* \"ab\";\n", 'a b', ['', 'b', 'aab', 'aaaab', 'ab']),
  // The multi-character analogue. Also empty, and this is the hole.
  ("S <- (\"ab\")* \"abc\";\n", 'a b c', ['', 'c', 'abc', 'ababc', 'abab']),
  // A body that is one character but spelled as a group -- does the shape or
  // the WIDTH decide? If this is fixed, `_oneCharClass` is looking through the
  // group and only true width matters.
  ("S <- ('a')* \"ab\";\n", 'a b', ['', 'b', 'aab']),
  // Two-character body, follower disjoint from it: language NON-empty, and both
  // engines must keep answering finite costs here.
  ("S <- (\"ab\")* \"cd\";\n", 'a b c d', ['', 'cd', 'abcd', 'ababq']),
];

void main() {
  for (final (g, alpha, inputs) in cases) {
    final r = MetaGrammar.parseGrammar(g);
    final hits = emptyCheck(r, 'S', alpha.replaceAll(' ', ''), 6);
    print('\n${g.trim()}   [strings of length <=6 in the language: $hits'
        '${hits == 0 ? "  => EMPTY, truth is -1 everywhere" : ""}]');
    print('  input        m62    m70    m71   m71verified');
    for (final s in inputs) {
      final c62 = e62.SuperDot3(rules: r, topRuleName: 'S').recoverCost(s);
      final c70 = e70.SuperDot3(rules: r, topRuleName: 'S').recoverCost(s);
      final e = e71.SuperDot3(rules: r, topRuleName: 'S');
      final c71 = e.recoverCost(s);
      final want = hits == 0 ? -1 : null;
      final mark = want == null
          ? ''
          : (c71 == want ? '   ok' : '   <-- m71 WRONG (truth $want)');
      // What a CALLER sees, not just what the cost path returns -- the whole
      // SkipResult, since `recoveryEvents` counts missing obligations as well as
      // skipped spans and `clean` is derived from it. m62 is shown alongside
      // because a hole it already had is not a regression m71 introduced.
      final res = e71.SuperDot3(rules: r, topRuleName: 'S').recover(s);
      final res62 = e62.SuperDot3(rules: r, topRuleName: 'S').recover(s);
      print('  ${'"$s"'.padRight(12)}'
          '${c62.toString().padLeft(4)}'
          '${c70.toString().padLeft(7)}'
          '${c71.toString().padLeft(7)}'
          '${e.lastVerified.toString().padLeft(14)}'
          '   m71.recover: forced=${res.forced} spans=${res.errorSpans.length}'
          ' missing=${res.missing.length} events=${res.recoveryEvents}'
          ' clean=${res.clean}'
          ' | m62.recover: forced=${res62.forced} events=${res62.recoveryEvents}'
          ' clean=${res62.clean}$mark');
    }
  }
}
