// _nv72.dart -- _subset72's 2387 brute-force truths, asking one question:
// can I5's re-parse come off the COST path?
// The router's load-bearing claim, attacked: c62 <= trueCost on every input
// (the floor half of the squeeze), and m66 == trueCost exactly. Adversarial
// grammars chosen where the relaxation, the I3 veto, and lookaheads
// interact: possessive stars, committed choices, lookaheads that peek from
// an unedited span into an edited region. Truth by brute-force enumeration
// with pure-parse membership, cap 3.
import 'package:squirrel_parser/squirrel_parser.dart';
import 'm72.dart' as ship;
import '_m72cnt.dart' as cnt;

bool inLang(Map<String, Clause> r, String t, String s) {
  final p = Parser(rules: r, topRuleName: t, input: s).parse();
  return !p.hasSyntaxErrors && p.root.len == s.length;
}

int? trueDist(Map<String, Clause> r, String t, String s, String alpha, int maxK) {
  var frontier = {s};
  final seen = {s};
  for (var k = 0; k <= maxK; k++) {
    for (final c in frontier) {
      if (inLang(r, t, c)) return k;
    }
    final next = <String>{};
    for (final c in frontier) {
      for (var i = 0; i < c.length; i++) {
        final del = c.substring(0, i) + c.substring(i + 1);
        if (seen.add(del)) next.add(del);
      }
      for (var i = 0; i <= c.length; i++) {
        for (final ch in alpha.split('')) {
          final ins = c.substring(0, i) + ch + c.substring(i);
          if (seen.add(ins)) next.add(ins);
          if (i < c.length) {
            final sub = c.substring(0, i) + ch + c.substring(i + 1);
            if (seen.add(sub)) next.add(sub);
          }
        }
      }
    }
    frontier = next;
  }
  return null;
}

final grammars = <(String, String, String)>[
  ("S <- 'a'* \"ab\";\n", 'S', 'ab'),
  ("S <- ('a' / \"ab\") 'b';\n", 'S', 'ab'),
  ("S <- A 'c';\nA <- 'a' / \"ab\";\n", 'S', 'abc'),
  ("S <- 'a'? \"ab\";\n", 'S', 'ab'),
  ("S <- (A / B) T;\nA <- 'a' &'x';\nB <- 'a';\nT <- 'x' / 'y';\n", 'S', 'axy'),
  ("S <- (A / 'a') 'b' 'x';\nA <- 'a' &('b' 'x');\n", 'S', 'abx'),
  ("S <- !'x' ('a' / 'x') 'b';\n", 'S', 'abx'),
  ("S <- ('a' &'b' / 'a' / 'b')* !.;\n", 'S', 'ab'),
  ("S <- A B;\nA <- 'a' 'a' / 'a';\nB <- 'a' 'b' / 'b';\n", 'S', 'ab'),
  ("S <- ('a' 'b')* 'a' !.;\n", 'S', 'ab'),
  ("S <- &(A 'b') A 'b' 'x';\nA <- 'a'*;\n", 'S', 'abx'),
  ("S <- ('a' / 'b' 'a')* \"bb\";\n", 'S', 'ab'),
  // Codex round four's executed counterexamples, now permanent:
  // reference duplication amplifies the optional-stealing gap (mass fix),
  ("S <- A2 A2;\nA2 <- A1 A1;\nA1 <- B B;\nB <- 'a'? \"ab\";\n", 'S', 'ab'),
  // and the in-envelope regret tie (cost must stay exact; tie residue known).
  ("S <- [a-z] / 'a' / '0';\n", 'S', 'a0'),
];


void main() {
  // `_confg` says dropping `_verify` still scores 5/5 conformance, because
  // `_build`'s own failure is what catches the possessive-star cases. That is
  // not enough to move it: `_verify` is I5, and I5 is the SOUNDNESS check --
  // the residual 98 are all over-priced or rejected and NONE under-priced, and
  // an unverified witness is exactly how under-pricing would get in. So this
  // re-runs the 2387 brute-force truths and classifies every disagreement by
  // direction, because only one direction disqualifies.
  var checked = 0, agree = 0, shipW = 0, nvW = 0, newUnder = 0, moved = 0;
  for (final (g, top, alpha) in grammars) {
    final r = MetaGrammar.parseGrammar(g);
    final a = ship.SuperDot3(rules: r, topRuleName: top);
    cnt.SuperDot3.skipCert = false;
    cnt.SuperDot3.forceGuard = false;
    cnt.SuperDot3.skipVerify = true;
    final b = cnt.SuperDot3(rules: r, topRuleName: top);
    final strings = <String>[''];
    for (var len = 1; len <= 5; len++) {
      for (final p in strings.where((s) => s.length == len - 1).toList()) {
        for (final ch in alpha.split('')) {
          strings.add(p + ch);
        }
      }
    }
    for (final s in strings) {
      final truth = trueDist(r, top, s, alpha, 3);
      bool ok(int c) => truth == null ? (c > 3 || c == -1) : c == truth;
      // under-pricing: claims a repair cheaper than one that exists, or any
      // finite claim where brute force found none within reach.
      bool under(int c) =>
          truth == null ? (c >= 0 && c <= 3) : (c >= 0 && c < truth);
      final ca = a.recoverCost(s), cb = b.recoverCost(s);
      checked++;
      if (ca == cb) agree++;
      if (!ok(ca)) shipW++;
      if (!ok(cb)) nvW++;
      if (ca != cb) {
        moved++;
        if (under(cb) && !under(ca)) {
          newUnder++;
          print('  NEW UNDER: ${g.replaceAll("\n", " ")} '
              '"${s.isEmpty ? "<empty>" : s}" truth=$truth ship=$ca nv=$cb');
        }
      }
    }
  }
  print('checked=$checked agree=$agree moved=$moved');
  print('wrong: ship=$shipW nverify=$nvW');
  print('NEW UNDER-PRICING introduced by dropping _verify: $newUnder');
}
