// _witdepth71.dart -- the LRmax column measures a NUMBER, not an ANSWER.
//
// final_table's `depthLimit` calls `cost(s)`, i.e. `recoverCost`. m62 returns
// the number there WITHOUT ever reconstructing a witness, so its >=4096 is a
// ceiling for half an answer. Ask m62 for the whole answer -- `recover`, which
// is what a caller actually wants -- and its native `_build`/`_child`/`_row`
// descent runs at a depth linear in the input, exactly the recursion I26
// converts. This climbs BOTH entry points on BOTH ladder grammars so the
// comparison is like for like.
import 'package:squirrel_parser/squirrel_parser.dart';

import 'm62.dart' as e62;
import 'm70.dart' as e70;
import 'm71.dart' as e71;

final lr = MetaGrammar.parseGrammar(
    "E <- E '+' T / T;\nT <- T '*' F / F;\nF <- [0-9] / '(' E ')';\n");
final rr = MetaGrammar.parseGrammar(
    "E <- T '+' E / T;\nT <- F '*' T / F;\nF <- [0-9] / '(' E ')';\n");

String oneErr(int k) {
  final c = List.generate(k, (i) => '${i % 10}').join('+');
  return '${c.substring(0, c.length ~/ 2)}+${c.substring(c.length ~/ 2)}';
}

String climb(Map<String, Clause> g, void Function(Map<String, Clause>, String) f) {
  var last = '<256';
  for (final k in [256, 512, 1024, 2048]) {
    final s = oneErr(k);
    try {
      f(g, s);
      last = k == 2048 ? '>=${s.length}' : '${s.length}';
    } on StackOverflowError catch (_) {
      return last == '<256' ? '<${s.length}' : last;
    }
  }
  return last;
}

void main() {
  final rows = <(String, void Function(Map<String, Clause>, String))>[
    ('m62 recoverCost', (g, s) => e62.SuperDot3(rules: g, topRuleName: 'E').recoverCost(s)),
    ('m62 recover    ', (g, s) => e62.SuperDot3(rules: g, topRuleName: 'E').recover(s)),
    ('m70 recoverCost', (g, s) => e70.SuperDot3(rules: g, topRuleName: 'E').recoverCost(s)),
    ('m70 recover    ', (g, s) => e70.SuperDot3(rules: g, topRuleName: 'E').recover(s)),
    ('m71 recoverCost', (g, s) => e71.SuperDot3(rules: g, topRuleName: 'E').recoverCost(s)),
    ('m71 recover    ', (g, s) => e71.SuperDot3(rules: g, topRuleName: 'E').recover(s)),
  ];
  print('entry point         LRmax     RRmax');
  for (final (n, f) in rows) {
    print('$n  ${climb(lr, f).padLeft(7)}   ${climb(rr, f).padLeft(7)}');
  }
}
