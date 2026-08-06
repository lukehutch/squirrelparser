// Copy of _subset72.dart with the m72 arm switched to m74: I29+I30+I31
// must not move a single answer against m71/m72 either.
// The router's load-bearing claim, attacked: c62 <= trueCost on every input
// (the floor half of the squeeze), and m66 == trueCost exactly. Adversarial
// grammars chosen where the relaxation, the I3 veto, and lookaheads
// interact: possessive stars, committed choices, lookaheads that peek from
// an unedited span into an edited region. Truth by brute-force enumeration
// with pure-parse membership, cap 3.
import 'package:squirrel_parser/squirrel_parser.dart';
import 'm62.dart' as fast;
import 'm71.dart' as router;
import 'm70.dart' as tape70;
import 'm74.dart' as chase;

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
  // Is m71's residual a SUBSET of m62's? A regression is any (grammar,string)
  // where m62 was exact and m71 is not. Everything else is progress or a
  // pre-existing hole.
  var checked = 0, fixed = 0, regressed = 0, bothWrong = 0, m62w = 0, m71w = 0;
  var m70w = 0, m74w = 0, diff = 0;
  final byG = <String, List<int>>{};
  for (final (g, top, alpha) in grammars) {
    final r = MetaGrammar.parseGrammar(g);
    final e62 = fast.SuperDot3(rules: r, topRuleName: top);
    final e71 = router.SuperDot3(rules: r, topRuleName: top);
    final e70 = tape70.SuperDot3(rules: r, topRuleName: top);
    final e72 = chase.SuperDot3(rules: r, topRuleName: top);
    final strings = <String>[''];
    for (var len = 1; len <= 5; len++) {
      for (final p in strings.where((s) => s.length == len - 1).toList()) {
        for (final ch in alpha.split('')) {
          strings.add(p + ch);
        }
      }
    }
    final key = g.replaceAll('\n', ' ').trim();
    byG[key] = [0, 0, 0];
    for (final s in strings) {
      final truth = trueDist(r, top, s, alpha, 3);
      bool ok(int c) => truth == null ? (c > 3 || c == -1) : c == truth;
      final a = ok(e62.recoverCost(s)), b = ok(e71.recoverCost(s));
      // m70 counted too, so the three-way headline is one run rather than one
      // measurement plus two quotations from earlier occasions.
      if (!ok(e70.recoverCost(s))) m70w++;
      final c72 = e72.recoverCost(s);
      if (!ok(c72)) m74w++;
      // I29's claim is IDENTITY with m71, not merely a similar score.
      final c71 = e71.recoverCost(s);
      if (c72 != c71) {
        diff++;
        if (diff <= 12) {
          print('DIFF g=$key s="$s" true=${truth ?? ">3"} m71=$c71 m72=$c72');
        }
      }
      checked++;
      if (!a) m62w++;
      if (!b) m71w++;
      if (!a && b) {
        fixed++;
        byG[key]![0]++;
      }
      if (a && !b) {
        regressed++;
        byG[key]![1]++;
        print('REGRESSION g=$key s="$s" true=${truth ?? ">3"} '
            'm62=${e62.recoverCost(s)} m71=${e71.recoverCost(s)}');
      }
      if (!a && !b) {
        bothWrong++;
        byG[key]![2]++;
      }
    }
  }
  print('');
  print('checked=$checked  m62wrong=$m62w  m70wrong=$m70w  m71wrong=$m71w  '
      'm74wrong=$m74w');
  print('m71 vs m74 cost DIFFERENCES = $diff   (I29 must give 0)');
  print('  fixed by I27 = $fixed   REGRESSED = $regressed   '
      'still wrong in both = $bothWrong');
  print('');
  print('per grammar: fixed / regressed / bothWrong');
  byG.forEach((k, v) {
    if (v[0] + v[1] + v[2] > 0) print('  ${v[0]}/${v[1]}/${v[2]}  $k');
  });
}
