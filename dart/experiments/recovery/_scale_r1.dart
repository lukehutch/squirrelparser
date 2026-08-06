// Scratch: controlled scaling test for r1's recovery.
//
// The brief predicts O(|G|n^2) for recovery. The battery cannot check that --
// it mixes grammars, damage kinds and lengths, so its bins are confounded. This
// holds everything fixed but n: one grammar, one damage, the SAME damage at the
// same relative position, inputs grown by repeating a statement.
//
// Reported: memo body evaluations and full parses against n, plus the observed
// exponent between consecutive sizes, log(w2/w1)/log(n2/n1).
import 'dart:math' as math;

import 'package:squirrel_parser/squirrel_parser.dart';

import '_r1e.dart' as r1e;
import 'astdiff.dart';

void main() {
  final stmt = corpora.firstWhere((c) => c.name == 'stmt');
  final rules = MetaGrammar.parseGrammar(stmt.grammar);

  print('${'n'.padLeft(5)}${'parses'.padLeft(9)}${'evals'.padLeft(11)}'
      '${'ms'.padLeft(7)}${'exponent'.padLeft(10)}');
  var prevN = 0, prevE = 0;
  for (final reps in [2, 4, 8, 16, 32, 64, 128]) {
    // A valid program: `a=1; a=1; ...`. Damage it once, in the middle, by
    // deleting the `;` of the middle statement -- the same relative damage at
    // every size.
    final good = List.filled(reps, 'a=1; ').join();
    final mid = (reps ~/ 2) * 5 + 3; // index of the middle statement's ';'
    final bad = good.substring(0, mid) + good.substring(mid + 1);

    final e = r1e.Squirrel(rules: rules, topRuleName: stmt.top);
    final sw = Stopwatch()..start();
    try {
      e.recover(bad);
    } catch (err) {
      print('${bad.length.toString().padLeft(5)}   THREW ${err.runtimeType}');
      continue;
    }
    sw.stop();
    final n = bad.length;
    final exp = prevN == 0
        ? ''
        : (math.log(e.nEval / prevE) / math.log(n / prevN)).toStringAsFixed(2);
    print('${n.toString().padLeft(5)}${e.nParse.toString().padLeft(9)}'
        '${e.nEval.toString().padLeft(11)}'
        '${sw.elapsedMilliseconds.toString().padLeft(7)}'
        '${exp.padLeft(10)}');
    prevN = n;
    prevE = e.nEval;
  }

  // Second experiment: hold n fixed and vary the NUMBER of damage sites. Each
  // site needs its own round, and each round costs O(n) trial parses, so if the
  // rounds compose the way the structure suggests this should grow like k*n.
  print('');
  print('n fixed at 320; k damage sites');
  print('${'k'.padLeft(5)}${'parses'.padLeft(9)}${'evals'.padLeft(11)}'
      '${'ms'.padLeft(7)}${'evals/k'.padLeft(10)}');
  const reps = 64;
  final good = List.filled(reps, 'a=1; ').join();
  for (final k in [1, 2, 4, 8, 16]) {
    // Delete the ';' of k statements, spread evenly.
    final drop = <int>{};
    for (var i = 0; i < k; i++) {
      drop.add((i * reps ~/ k) * 5 + 3);
    }
    final sb = StringBuffer();
    for (var i = 0; i < good.length; i++) {
      if (!drop.contains(i)) sb.write(good[i]);
    }
    final bad = sb.toString();
    final e = r1e.Squirrel(rules: rules, topRuleName: stmt.top);
    final sw = Stopwatch()..start();
    try {
      e.recover(bad);
    } catch (err) {
      print('${k.toString().padLeft(5)}   THREW ${err.runtimeType}');
      continue;
    }
    sw.stop();
    print('${k.toString().padLeft(5)}${e.nParse.toString().padLeft(9)}'
        '${e.nEval.toString().padLeft(11)}'
        '${sw.elapsedMilliseconds.toString().padLeft(7)}'
        '${(e.nEval / k).toStringAsFixed(0).padLeft(10)}');
  }
}
