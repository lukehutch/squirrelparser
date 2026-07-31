// _wit72.dart -- I29's claim is that the pointer chase rebuilds THE SAME
// witness, not merely the same price. `_subset72` compares `recoverCost`, and
// a cost can agree by accident: if the chase fails to find a tree, `_certified`
// returns false and I28 re-runs the tight pass, which may land on the same
// number. So compare what the caller actually receives -- the certificate, the
// error spans, the missing obligations, and the shape of the tree -- over the
// same 2387 brute-force-truth inputs.
import 'package:squirrel_parser/squirrel_parser.dart';
import 'package:squirrel_parser/src/recovery/skip_recovery.dart'
    show SkipResult;

import 'm71.dart' as e71;
import 'm72.dart' as e72;

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
  ("S <- A2 A2;\nA2 <- A1 A1;\nA1 <- B B;\nB <- 'a'? \"ab\";\n", 'S', 'ab'),
  ("S <- [a-z] / 'a' / '0';\n", 'S', 'a0'),
];

/// Clause identity is per-engine (each engine lowers its own copy), so compare
/// the clause's PRINTED form, which is what a caller would see.
void _shape(MatchResult m, StringBuffer out) {
  out.write(m is SyntaxError ? 'ERR' : m.clause.toString());
  out.write('@${m.pos}+${m.len}(');
  for (final s in m.subClauseMatches) {
    _shape(s, out);
    out.write(',');
  }
  out.write(')');
}

String _shapeOf(MatchResult m) {
  final b = StringBuffer();
  _shape(m, b);
  return b.toString();
}

String _full(SkipResult r) {
  final spans = r.errorSpans.map((e) => '${e.pos}+${e.len}').join('|');
  return 'forced=${r.forced} events=${r.recoveryEvents} clean=${r.clean} '
      'spans=[$spans] missing=${r.missing.length} '
      'skipped=${r.charsSkipped} tree=${_shapeOf(r.root)}';
}

void main() {
  var checked = 0, costDiff = 0, certDiff = 0, fullDiff = 0, shown = 0;
  var built71 = 0, built72 = 0;
  for (final (g, top, alpha) in grammars) {
    final r = MetaGrammar.parseGrammar(g);
    final a = e71.SuperDot3(rules: r, topRuleName: top);
    final b = e72.SuperDot3(rules: r, topRuleName: top);
    final strings = <String>[''];
    for (var len = 1; len <= 5; len++) {
      for (final p in strings.where((s) => s.length == len - 1).toList()) {
        for (final ch in alpha.split('')) {
          strings.add(p + ch);
        }
      }
    }
    final key = g.replaceAll('\n', ' ').trim();
    for (final s in strings) {
      checked++;
      final ca = a.recoverCost(s), cb = b.recoverCost(s);
      final va = a.lastVerified, vb = b.lastVerified;
      if (ca != cb) costDiff++;
      if (va != vb) certDiff++;
      if (va) built71++;
      if (vb) built72++;
      final fa = _full(a.recover(s)), fb = _full(b.recover(s));
      if (fa != fb) {
        fullDiff++;
        if (shown++ < 8) {
          print('FULL DIFF g=$key s="$s"');
          print('  m71 cost=$ca verified=$va $fa');
          print('  m72 cost=$cb verified=$vb $fb');
        }
      }
    }
  }
  print('');
  print('checked=$checked');
  print('  cost differences        = $costDiff');
  print('  certificate differences = $certDiff');
  print('  full-result differences = $fullDiff');
  print('  certified: m71=$built71  m72=$built72');
}
