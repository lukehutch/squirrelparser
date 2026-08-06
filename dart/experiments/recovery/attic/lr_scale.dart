// Does the left-recursion fixed point stay cheap at scale? Every correctness test
// for A5 used inputs of at most 8 characters, so the number of cycle expansions is
// argued (monotone ascending chain over a finite lattice) but unmeasured. A
// left-recursive grammar builds a left-leaning spine as deep as the input, which is
// the worst case for repeated expansion.
import 'dart:math';
import 'package:squirrel_parser/squirrel_parser.dart';
import 'm26.dart' as g26;

const lr = "E <- E '+' T / T;\nT <- T '*' F / F;\nF <- [0-9] / '(' E ')';\n";
const rr = "E <- T '+' E / T;\nT <- F '*' T / F;\nF <- [0-9] / '(' E ')';\n";

void main() {
  final left = g26.SuperDot3(rules: MetaGrammar.parseGrammar(lr), topRuleName: 'E');
  final right = g26.SuperDot3(rules: MetaGrammar.parseGrammar(rr), topRuleName: 'E');
  print('${'input'.padRight(22)}${'n'.padLeft(5)}${'LRcost'.padLeft(8)}'
      '${'LRms'.padLeft(8)}${'RRcost'.padLeft(8)}${'RRms'.padLeft(8)}'
      '${'LR/RR'.padLeft(8)}');
  for (final k in [8, 16, 32, 64, 128]) {
    // A clean left-leaning chain, then the same chain with one spurious operator
    // in the middle -- the case that forces the engine's own recursion (b >= 1).
    final clean = List.generate(k, (i) => '${i % 10}').join('+');
    final mid = clean.length ~/ 2;
    for (final (label, s) in [
      ('clean-$k', clean),
      ('1err-$k', '${clean.substring(0, mid)}+${clean.substring(mid)}'),
    ]) {
      double best(g26.SuperDot3 e) {
        var t = double.infinity;
        for (var i = 0; i < 3; i++) {
          final sw = Stopwatch()..start();
          e.recoverCost(s);
          t = min(t, sw.elapsedMicroseconds / 1000);
        }
        return t;
      }

      final lt = best(left), rt = best(right);
      final lc = left.recoverCost(s), rc = right.recoverCost(s);
      // Same language, so the two grammars must agree on cost. A disagreement
      // would mean the left-recursive path is still under-approximating.
      final flag = lc == rc ? '' : '   COST DISAGREEMENT';
      print('${label.padRight(22)}${s.length.toString().padLeft(5)}'
          '${lc.toString().padLeft(8)}${lt.toStringAsFixed(1).padLeft(8)}'
          '${rc.toString().padLeft(8)}${rt.toStringAsFixed(1).padLeft(8)}'
          '${(lt / rt).toStringAsFixed(2).padLeft(7)}x$flag');
    }
  }
}
