// _r3lat.dart -- what makes r3 slow?
//
// r3 deepens: round b admits ways costing at most b, and a cell computed at a
// lower budget is recomputed when the budget rises. So the work is roughly the
// sum of the chart size over rounds 0..cost, and the hypothesis to test is that
// FINAL COST dominates, with input length second.
import 'package:squirrel_parser/squirrel_parser.dart';

import 'astdiff.dart';
import '_r3pe.dart' as pe;

class Row {
  Row(this.k, this.us, this.cost, this.rounds, this.expands, this.ways,
      this.maxCell);
  final Case k;
  final int us, cost, rounds, expands, ways, maxCell;
}

void main() {
  final rulesOf = {
    for (final c in corpora) c.name: MetaGrammar.parseGrammar(c.grammar)
  };
  final seen = <String>{};
  final rows = <Row>[];
  final cases = <Case>[];
  for (final k in weighted(buildBattery())) {
    if (seen.add('${k.grammar}\x00${k.mutant}')) cases.add(k);
  }
  for (final k in cases) {
    // Warm the JIT first, or the earliest cases pay compilation and land in
    // the slowest-20 list on that alone.
    final c = corpora.firstWhere((x) => x.name == k.grammar);
    try {
      pe.Squirrel(rules: rulesOf[k.grammar]!, topRuleName: c.top)
          .recover(k.mutant);
    } catch (_) {}
  }
  for (final k in cases) {
    final c = corpora.firstWhere((x) => x.name == k.grammar);
    final e = pe.Squirrel(rules: rulesOf[k.grammar]!, topRuleName: c.top);
    final sw = Stopwatch()..start();
    try {
      e.recover(k.mutant);
    } catch (_) {
      continue;
    }
    sw.stop();
    rows.add(Row(k, sw.elapsedMicroseconds, e.lastCost, e.nRound, e.nExpand,
        e.nWay, e.maxCell));
  }

  final total = rows.fold(0, (a, r) => a + r.us);
  print('${rows.length} distinct cases, ${(total / 1000).round()} ms total\n');

  // -- by final cost ---------------------------------------------------------
  final byCost = <int, List<Row>>{};
  for (final r in rows) {
    (byCost[r.cost] ??= []).add(r);
  }
  print('cost   n    mean us   share of total   mean expands   mean len');
  final costs = byCost.keys.toList()..sort();
  for (final c in costs) {
    final g = byCost[c]!;
    final s = g.fold(0, (a, r) => a + r.us);
    print('${c.toString().padLeft(4)} ${g.length.toString().padLeft(5)} '
        '${(s / g.length).round().toString().padLeft(9)} '
        '${(100 * s / total).toStringAsFixed(1).padLeft(13)}% '
        '${(g.fold(0, (a, r) => a + r.expands) / g.length).round().toString().padLeft(14)} '
        '${(g.fold(0, (a, r) => a + r.k.mutant.length) / g.length).round().toString().padLeft(10)}');
  }

  // -- by category -----------------------------------------------------------
  final byCat = <String, List<Row>>{};
  for (final r in rows) {
    (byCat[r.k.category] ??= []).add(r);
  }
  print('\ncategory          n    mean us   share   mean cost');
  final cats = byCat.keys.toList()
    ..sort((a, b) => byCat[b]!.fold(0, (x, r) => x + r.us) -
        byCat[a]!.fold(0, (x, r) => x + r.us));
  for (final c in cats) {
    final g = byCat[c]!;
    final s = g.fold(0, (a, r) => a + r.us);
    print('${c.padRight(16)} ${g.length.toString().padLeft(4)} '
        '${(s / g.length).round().toString().padLeft(9)} '
        '${(100 * s / total).toStringAsFixed(1).padLeft(6)}% '
        '${(g.fold(0, (a, r) => a + r.cost) / g.length).toStringAsFixed(2).padLeft(10)}');
  }

  // -- by grammar ------------------------------------------------------------
  final byG = <String, List<Row>>{};
  for (final r in rows) {
    (byG[r.k.grammar] ??= []).add(r);
  }
  print('\ngrammar   n    mean us   share   mean cost   mean maxCell');
  for (final g in byG.keys) {
    final v = byG[g]!;
    final s = v.fold(0, (a, r) => a + r.us);
    print('${g.padRight(8)} ${v.length.toString().padLeft(4)} '
        '${(s / v.length).round().toString().padLeft(9)} '
        '${(100 * s / total).toStringAsFixed(1).padLeft(6)}% '
        '${(v.fold(0, (a, r) => a + r.cost) / v.length).toStringAsFixed(2).padLeft(10)} '
        '${(v.fold(0, (a, r) => a + r.maxCell) / v.length).toStringAsFixed(1).padLeft(13)}');
  }

  // -- the tail --------------------------------------------------------------
  rows.sort((a, b) => b.us - a.us);
  final tailShare = rows.take(20).fold(0, (a, r) => a + r.us) / total;
  print('\nslowest 20 are ${(100 * tailShare).toStringAsFixed(1)}% of all time:');
  print('     us  cost  rounds  expands   ways  maxCell  len  category  input');
  for (final r in rows.take(20)) {
    print('${r.us.toString().padLeft(7)} ${r.cost.toString().padLeft(5)} '
        '${r.rounds.toString().padLeft(7)} ${r.expands.toString().padLeft(8)} '
        '${r.ways.toString().padLeft(6)} ${r.maxCell.toString().padLeft(8)} '
        '${r.k.mutant.length.toString().padLeft(4)}  ${r.k.category.padRight(15)} '
        '`${r.k.mutant}`');
  }
  final med = rows[rows.length ~/ 2];
  print('\nmedian case: ${med.us} us, cost ${med.cost}, '
      '${med.expands} expands, len ${med.k.mutant.length}');
}
