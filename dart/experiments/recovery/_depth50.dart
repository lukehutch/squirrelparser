// How many NESTINGS of `_compute` per input position does the descent spend, and
// how does that scale? m49's right-recursive ceiling bisects to k~537 elements
// (input len ~1074), and the question m50 has to answer is whether that ceiling
// can be lifted by shortening the frame chain per nesting (`_ends` ->
// `_Entry.ends` -> `_compute` -> `_chain`, four frames) or whether the native
// recursion has to go entirely.
//
// Right recursion is the deep case; left recursion is included as the control,
// since the parser's own asymmetry is the thing recovery is said to inherit.
import 'package:squirrel_parser/squirrel_parser.dart';
import 'm49.dart' as g49;

const rr = "E <- T '+' E / T;\nT <- F '*' T / F;\nF <- [0-9] / '(' E ')';\n";
const lr = "E <- E '+' T / T;\nT <- T '*' F / F;\nF <- [0-9] / '(' E ')';\n";

String oneErr(int k) {
  final c = List.generate(k, (i) => '${i % 10}').join('+');
  final mid = c.length ~/ 2;
  return '${c.substring(0, mid)}+${c.substring(mid)}';
}

void main() {
  print('${'shape'.padRight(6)}${'k'.padLeft(6)}${'n'.padLeft(7)}'
      '${'maxDepth'.padLeft(10)}${'depth/n'.padLeft(9)}${'cost'.padLeft(6)}');
  for (final (label, g) in [('RR', rr), ('LR', lr)]) {
    final rules = MetaGrammar.parseGrammar(g);
    final eng = g49.SuperDot3(rules: rules, topRuleName: 'E');
    for (final k in [8, 16, 32, 64, 128, 256]) {
      final s = oneErr(k);
      final cost = eng.recoverCost(s);
      print('${label.padRight(6)}${k.toString().padLeft(6)}'
          '${s.length.toString().padLeft(7)}${eng.lastMaxDepth.toString().padLeft(10)}'
          '${(eng.lastMaxDepth / s.length).toStringAsFixed(2).padLeft(9)}'
          '${cost.toString().padLeft(6)}');
    }
  }
}
