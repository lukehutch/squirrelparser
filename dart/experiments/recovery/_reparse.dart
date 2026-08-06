// Scratch: how much does r1's re-parse discipline actually cost?
//
// `_round` installs each candidate repair, calls `_parse()`, and measures the
// resulting tree. `_parse()` opens with `_forget()`, which does `_memo.clear()`
// -- so every candidate trial re-derives the WHOLE table from scratch, not just
// the part the repair could have changed. This counts the multiplier.
import 'package:squirrel_parser/squirrel_parser.dart';

import '_r1e.dart' as r1e;
import 'astdiff.dart';

void main() {
  final rulesOf = {
    for (final c in corpora) c.name: MetaGrammar.parseGrammar(c.grammar)
  };
  final seen = <String>{};
  final cases = <Case>[];
  for (final k in weighted(buildBattery())) {
    if (seen.add('${k.grammar}\x00${k.category}\x00${k.mutant}')) cases.add(k);
  }

  final made = {
    for (final c in corpora)
      c.name: r1e.Squirrel(rules: rulesOf[c.name]!, topRuleName: c.top)
  };

  var parses = 0, evals = 0, damaged = 0, same = 0, diff = 0, fresh = 0;
  var maxParses = 0;
  var worst = '';
  // Baseline: one clean parse of the same string, to price a single pass.
  var clean = 0;
  for (final k in cases) {
    final e = made[k.grammar]!;
    final p0 = e.nParse, v0 = e.nEval;
    final s0 = e.nSame, d0 = e.nDiff, f0 = e.nNew;
    try {
      e.recover(k.mutant);
    } catch (_) {
      continue;
    }
    final dp = e.nParse - p0;
    parses += dp;
    evals += e.nEval - v0;
    same += e.nSame - s0;
    diff += e.nDiff - d0;
    fresh += e.nNew - f0;
    damaged++;
    if (dp > maxParses) {
      maxParses = dp;
      worst = '${k.grammar} ${k.mutant}';
    }
  }
  // Price one pass: parse each mutant once with a fresh engine and count evals.
  for (final k in cases) {
    final e =
        r1e.Squirrel(rules: rulesOf[k.grammar]!, topRuleName: byTop(k.grammar));
    try {
      e.recover(k.mutant);
    } catch (_) {
      continue;
    }
    clean += e.nEval ~/ (e.nParse == 0 ? 1 : e.nParse);
  }

  // Empirical scaling: does work grow like n^2, as the brief predicts?
  final byLen = <int, List<int>>{};
  for (final k in cases) {
    final e = made[k.grammar]!;
    final p0 = e.nParse, v0 = e.nEval;
    try {
      e.recover(k.mutant);
    } catch (_) {
      continue;
    }
    final bin = (k.mutant.length ~/ 10) * 10;
    (byLen[bin] ??= <int>[]).addAll([e.nParse - p0, e.nEval - v0]);
  }
  print('input len   cases   parses/case   evals/case   evals/n^2');
  final bins = byLen.keys.toList()..sort();
  for (final b in bins) {
    final v = byLen[b]!;
    final n = v.length ~/ 2;
    var tp = 0, te = 0;
    for (var i = 0; i < v.length; i += 2) {
      tp += v[i];
      te += v[i + 1];
    }
    final mid = (b + 5).toDouble();
    print('${'$b-${b + 9}'.padRight(12)}${'$n'.padLeft(5)}'
        '${(tp / n).toStringAsFixed(1).padLeft(14)}'
        '${(te / n).toStringAsFixed(0).padLeft(13)}'
        '${(te / n / (mid * mid)).toStringAsFixed(2).padLeft(12)}');
  }
  print('');
  print('cases                 $damaged');
  print('full parses           $parses   (${(parses / damaged).toStringAsFixed(1)} per case)');
  print('worst case            $maxParses parses in $worst');
  print('memo body evals       $evals');
  print('one-pass equivalent   $clean evals');
  print('re-derivation factor  ${(evals / clean).toStringAsFixed(1)}x');
  print('');
  print('Trial memo vs the memo it was applied on top of:');
  final tot = same + diff + fresh;
  print('  identical  ${same.toString().padLeft(9)}  ${(100 * same / tot).toStringAsFixed(1)}%  <- an incremental scheme need not re-derive these');
  print('  changed    ${diff.toString().padLeft(9)}  ${(100 * diff / tot).toStringAsFixed(1)}%');
  print('  new        ${fresh.toString().padLeft(9)}  ${(100 * fresh / tot).toStringAsFixed(1)}%');
}

String byTop(String grammar) =>
    corpora.firstWhere((c) => c.name == grammar).top;
