// _resid71.dart -- of the 98 inputs m71 still gets wrong, how many does it
// UNDER-price (a lower bound the ladder could in principle climb past) and how
// many does it OVER-price or reject outright (only a repaired-input lookahead
// verdict can reach those)? The answer decides whether any cheap third rung
// exists, or whether the residual needs m70's tape.
// The router's load-bearing claim, attacked: c62 <= trueCost on every input
// (the floor half of the squeeze), and m66 == trueCost exactly. Adversarial
// grammars chosen where the relaxation, the I3 veto, and lookaheads
// interact: possessive stars, committed choices, lookaheads that peek from
// an unedited span into an edited region. Truth by brute-force enumeration
// with pure-parse membership, cap 3.
import 'package:squirrel_parser/squirrel_parser.dart';
import 'm62.dart' as fast;
import 'm71.dart' as router;
import 'm65.dart' as tapeeng;

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
  var checked = 0, floorViolations = 0, routerWrong = 0;
  var under = 0, over = 0;
  for (final (g, top, alpha) in grammars) {
    final r = MetaGrammar.parseGrammar(g);
    final e62 = fast.SuperDot3(rules: r, topRuleName: top);
    final e66 = router.SuperDot3(rules: r, topRuleName: top);
    final e65 = tapeeng.SuperDot3(rules: r, topRuleName: top);
    final strings = <String>[''];
    for (var len = 1; len <= 5; len++) {
      final prev = strings.where((s) => s.length == len - 1).toList();
      for (final p in prev) {
        for (final ch in alpha.split('')) {
          strings.add(p + ch);
        }
      }
    }
    for (final s in strings) {
      final truth = trueDist(r, top, s, alpha, 3);
      final c62 = e62.recoverCost(s);
      final c66 = e66.recoverCost(s);
      checked++;
      if (truth != null && c62 >= 0 && c62 > truth) {
        floorViolations++;

      }
      final ok = truth == null ? (c66 > 3 || c66 == -1) : c66 == truth;
      if (!ok) {
        if (truth == null) {
          over++; // engine claims a repair where brute force finds none <=3
        } else if (c66 < 0 || c66 > truth) {
          over++;
        } else {
          under++;
        }
      }
      if (!ok) {
        routerWrong++;
        final c65 = e65.recoverCost(s);

      }
    }
  }
  print('checked=$checked  floorViolations=$floorViolations  '
      'routerWrong=$routerWrong');
  print('  under-priced (cost < truth) = $under');
  print('  over-priced or rejected      = $over');
}
