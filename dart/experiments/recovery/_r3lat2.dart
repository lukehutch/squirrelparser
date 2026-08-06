// _r3lat2.dart -- WHERE inside r3 does the time go, and could best-first help?
//
// Two questions, one run.
//
// (1) `_r3lat.dart` showed a case at cost 1 taking 11 ms with only 1493
//     expands -- 17x the median's time per expand. So the expand count is not
//     the unit of work. Count instead the things `_seq` does per chain: memo
//     LOOKUPS, COMBINATIONS materialized (`next.add`), elements handed to
//     `_prune`, and cells RECOMPUTED because the budget rose.
//
// (2) Iterative deepening pays for every round below the answer's cost. A
//     best-first search over an exact-cost priority queue would pay for none
//     of them -- so the most it can ever save is the share of time spent in
//     rounds 0..cost-1. Time each round separately and that ceiling is
//     measured, not argued.
import 'dart:math' show sqrt;

import 'package:squirrel_parser/squirrel_parser.dart';

import 'astdiff.dart';
import '_r3pe.dart' as pe;

class Row {
  Row(this.k, this.us, this.cost, this.expands, this.look, this.comb,
      this.pruneIn, this.recomp, this.maxCell, this.rounds);
  final Case k;
  final int us, cost, expands, look, comb, pruneIn, recomp, maxCell;
  final List<int> rounds; // microseconds per round, index == budget
  int get lastRound => rounds.isEmpty ? 0 : rounds.last;
  int get belowUs => us - lastRound;
}

String _pc(num a, num b) => b == 0 ? '   -' : (100 * a / b).toStringAsFixed(1);

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
  // Warm the JIT on the whole battery first. Without this the first cases pay
  // compilation and land in the slowest-20 list on that alone -- which is what
  // made `"a":1,...` look like a 11 ms outlier at cost 1 when warm it is 2.4.
  for (final k in cases) {
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
    rows.add(Row(k, sw.elapsedMicroseconds, e.lastCost, e.nExpand, e.nLook,
        e.nComb, e.nPruneIn, e.nRecomp, e.maxCell, List.of(e.roundUs)));
  }

  final total = rows.fold(0, (a, r) => a + r.us);
  print('${rows.length} distinct cases, ${(total / 1000).round()} ms total');

  // -- (1) what is the unit of work? ----------------------------------------
  print('\n== per-case work, by final cost ==');
  print('cost     n   mean us   expands    lookups     combos    pruneIn  '
      'recomp  maxCell   us/expand  us/combo');
  final byCost = <int, List<Row>>{};
  for (final r in rows) {
    (byCost[r.cost] ??= []).add(r);
  }
  for (final c in byCost.keys.toList()..sort()) {
    final g = byCost[c]!;
    double m(int Function(Row) f) => g.fold(0, (a, r) => a + f(r)) / g.length;
    print('${c.toString().padLeft(4)} ${g.length.toString().padLeft(5)} '
        '${m((r) => r.us).round().toString().padLeft(9)} '
        '${m((r) => r.expands).round().toString().padLeft(9)} '
        '${m((r) => r.look).round().toString().padLeft(10)} '
        '${m((r) => r.comb).round().toString().padLeft(10)} '
        '${m((r) => r.pruneIn).round().toString().padLeft(10)} '
        '${m((r) => r.recomp).round().toString().padLeft(7)} '
        '${m((r) => r.maxCell).toStringAsFixed(1).padLeft(8)} '
        '${(m((r) => r.us) / m((r) => r.expands)).toStringAsFixed(2).padLeft(11)} '
        '${(1000 * m((r) => r.us) / m((r) => r.comb)).toStringAsFixed(2).padLeft(9)}ns');
  }

  // Which counter tracks time best? Pearson r of each against microseconds.
  double corr(int Function(Row) f) {
    final n = rows.length;
    final mx = rows.fold(0, (a, r) => a + f(r)) / n;
    final my = total / n;
    var sxy = 0.0, sxx = 0.0, syy = 0.0;
    for (final r in rows) {
      final dx = f(r) - mx, dy = r.us - my;
      sxy += dx * dy;
      sxx += dx * dx;
      syy += dy * dy;
    }
    if (sxx == 0 || syy == 0) return 0;
    return sxy / sqrt(sxx * syy);
  }

  print('\ncorrelation with elapsed time (Pearson r, ${rows.length} cases):');
  for (final (name, f) in <(String, int Function(Row))>[
    ('expands', (r) => r.expands),
    ('lookups', (r) => r.look),
    ('combos', (r) => r.comb),
    ('pruneIn', (r) => r.pruneIn),
    ('recomp', (r) => r.recomp),
    ('maxCell', (r) => r.maxCell),
    ('len', (r) => r.k.mutant.length),
    ('cost', (r) => r.cost),
  ]) {
    print('  ${name.padRight(9)} ${corr(f).toStringAsFixed(3)}');
  }

  // -- (2) the best-first ceiling -------------------------------------------
  print('\n== how much time is spent BELOW the answer\'s cost? ==');
  print('(a best-first search pays none of it -- this is its whole upside)');
  final below = rows.fold(0, (a, r) => a + r.belowUs);
  print('total below-cost time: ${(below / 1000).round()} ms of '
      '${(total / 1000).round()} ms = ${_pc(below, total)}%');
  print('\ncost     n   mean us   final round   below   below%');
  for (final c in byCost.keys.toList()..sort()) {
    final g = byCost[c]!;
    final b = g.fold(0, (a, r) => a + r.belowUs);
    final s = g.fold(0, (a, r) => a + r.us);
    print('${c.toString().padLeft(4)} ${g.length.toString().padLeft(5)} '
        '${(s / g.length).round().toString().padLeft(9)} '
        '${((s - b) / g.length).round().toString().padLeft(13)} '
        '${(b / g.length).round().toString().padLeft(7)} '
        '${_pc(b, s).padLeft(7)}%');
  }

  // Per-round profile of the expensive cases: is round b cheap or dear?
  print('\n== round-by-round, the 12 slowest cases ==');
  rows.sort((a, b) => b.us - a.us);
  print('     us  cost  rounds (us per budget 0,1,2,...)          input');
  for (final r in rows.take(12)) {
    print('${r.us.toString().padLeft(7)} ${r.cost.toString().padLeft(5)}  '
        '${r.rounds.join(', ').padRight(38)}  `${r.k.mutant}`');
  }
}

