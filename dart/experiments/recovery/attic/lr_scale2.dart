// lr_scale.dart went to n=256 on ONE grammar shape (a left-leaning arithmetic
// spine). Two things were therefore unmeasured, and both were named as suspect:
// whether the left-recursion multiplier stays flat an order of magnitude further
// out, and whether a cycle spanning SEVERAL mutually recursive rules expands more
// per position than a single self-recursive rule does.
//
// Every call is guarded: at these depths StackOverflowError is a real outcome (see
// lr_depth2.dart), and one crashed cell must not hide the rest of the table.
import 'dart:math';
import 'package:squirrel_parser/squirrel_parser.dart';
import 'm26.dart' as g26;

// Direct left recursion, and the same language right-recursively.
const lr = "E <- E '+' T / T;\nT <- T '*' F / F;\nF <- [0-9] / '(' E ')';\n";
const rr = "E <- T '+' E / T;\nT <- F '*' T / F;\nF <- [0-9] / '(' E ')';\n";

// The cycle E -> A -> B -> E spans three rules, so one position's fixed point must
// expand a 3-rule cycle rather than a 1-rule self-loop.
const ind = "E <- A / F;\nA <- B '+' F;\nB <- E;\nF <- [0-9];\n";
// Same language, right-recursive, no cycle at all.
const indRR = "E <- F '+' E / F;\nF <- [0-9];\n";

/// (cost, best-of-3 ms) or (null, ms) if it could not complete.
(int?, double) probe(Map<String, Clause> rules, String s) {
  var t = double.infinity;
  int? cost;
  for (var i = 0; i < 3; i++) {
    final sw = Stopwatch()..start();
    try {
      cost = g26.SuperDot3(rules: rules, topRuleName: 'E').recoverCost(s);
    } on StackOverflowError {
      return (null, sw.elapsedMicroseconds / 1000);
    }
    t = min(t, sw.elapsedMicroseconds / 1000);
  }
  return (cost, t);
}

String fmt(int? c) => c == null ? 'STACK' : '$c';

void main() {
  final shapes = [
    ('direct (E <- E + T)', lr, rr),
    ('3-rule cycle (E->A->B->E)', ind, indRR),
  ];

  for (final (shape, gl, gr) in shapes) {
    final rl = MetaGrammar.parseGrammar(gl), rr_ = MetaGrammar.parseGrammar(gr);
    print('\n=== $shape ===');
    print('${'input'.padRight(14)}${'n'.padLeft(6)}${'LRcost'.padLeft(8)}'
        '${'LRms'.padLeft(10)}${'RRcost'.padLeft(8)}${'RRms'.padLeft(10)}'
        '${'LR/RR'.padLeft(9)}');
    for (final k in [128, 256, 512, 1024, 2048]) {
      final clean = List.generate(k, (i) => '${i % 10}').join('+');
      final mid = clean.length ~/ 2;
      for (final (label, s) in [
        ('clean-$k', clean),
        ('1err-$k', '${clean.substring(0, mid)}+${clean.substring(mid)}'),
      ]) {
        final (lc, lt) = probe(rl, s);
        final (rc, rt) = probe(rr_, s);
        // Same language, so a cost disagreement means the left-recursive path is
        // still under-approximating at this size. Only comparable if both ran.
        final flag = (lc != null && rc != null && lc != rc)
            ? '   COST DISAGREEMENT'
            : '';
        final ratio =
            (lc != null && rc != null) ? '${(lt / rt).toStringAsFixed(2)}x' : '-';
        print('${label.padRight(14)}${s.length.toString().padLeft(6)}'
            '${fmt(lc).padLeft(8)}${lt.toStringAsFixed(1).padLeft(10)}'
            '${fmt(rc).padLeft(8)}${rt.toStringAsFixed(1).padLeft(10)}'
            '${ratio.padLeft(9)}$flag');
      }
    }
  }
}
