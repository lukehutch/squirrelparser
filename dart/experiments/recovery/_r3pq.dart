// _r3pq.dart -- would best-first search (a priority queue) beat r3's deepening?
//
// A best-first search over an exact-cost frontier never re-derives: it visits
// each state once, in cost order, and stops at the first complete parse. Its
// upside over iterative deepening is therefore exactly the RE-derivation that
// deepening pays, and nothing else.
//
// The ORACLE bounds that upside without building anything. Run r3 twice: once
// normally, to learn the answer's cost C; once with the deepening loop started
// AT C, so it pays for no round below the answer. Round C admits every way of
// cost <= C, so the answer is identical -- checked, not assumed. The oracle is
// strictly better than any real best-first search, because it also knows C in
// advance and so never explores a cost it did not need.
//
//   oracle time ~= total time  ->  deepening wastes nothing; a queue cannot help
//   oracle time <<  total time ->  the re-derivation is real and worth attacking
//
// Also settles the `"a":1,...` outlier from _r3lat.dart: 12.5 ms at cost 1,
// with 5.5 ms of it at BUDGET 0 -- before any repair is attempted. Budget 0 is
// the frozen parser, so either that clean parse is genuinely slow or the case
// was paying JIT warm-up. Re-timing it warm separates the two.
import 'package:squirrel_parser/squirrel_parser.dart';

import 'astdiff.dart';
import '_r3pe.dart' as pe;

int _cover(MatchResult m) => m.len;

void main() {
  final rulesOf = {
    for (final c in corpora) c.name: MetaGrammar.parseGrammar(c.grammar)
  };
  final cases = <Case>[];
  final seen = <String>{};
  for (final k in weighted(buildBattery())) {
    if (seen.add('${k.grammar}\x00${k.mutant}')) cases.add(k);
  }

  // Warm the JIT on the whole battery before timing anything.
  for (final k in cases) {
    final c = corpora.firstWhere((x) => x.name == k.grammar);
    try {
      pe.Squirrel(rules: rulesOf[k.grammar]!, topRuleName: c.top)
          .recover(k.mutant);
    } catch (_) {}
  }

  var deepUs = 0, oracleUs = 0, mismatch = 0, n = 0;
  final byCost = <int, List<int>>{}; // cost -> [deep us, oracle us, n]
  final rows = <(int, int, int, Case)>[]; // deep, oracle, cost, case
  for (final k in cases) {
    final c = corpora.firstWhere((x) => x.name == k.grammar);
    MatchResult a, b;
    int ta, tb, cost;

    final e1 = pe.Squirrel(rules: rulesOf[k.grammar]!, topRuleName: c.top);
    final s1 = Stopwatch()..start();
    try {
      a = e1.recover(k.mutant);
    } catch (_) {
      continue;
    }
    ta = s1.elapsedMicroseconds;
    cost = e1.lastCost;

    final e2 = pe.Squirrel(rules: rulesOf[k.grammar]!, topRuleName: c.top)
      ..floor = cost;
    final s2 = Stopwatch()..start();
    try {
      b = e2.recover(k.mutant);
    } catch (_) {
      continue;
    }
    tb = s2.elapsedMicroseconds;

    // The oracle must produce the same answer, or the bound is meaningless.
    if (e2.lastCost != cost || _cover(a) != _cover(b)) mismatch++;

    n++;
    deepUs += ta;
    oracleUs += tb;
    final g = byCost[cost] ??= [0, 0, 0];
    g[0] += ta;
    g[1] += tb;
    g[2] += 1;
    rows.add((ta, tb, cost, k));
  }

  print('$n cases  (answer mismatches: $mismatch -- must be 0)');
  print('deepening from 0 : ${(deepUs / 1000).round()} ms');
  print('oracle from cost : ${(oracleUs / 1000).round()} ms');
  print('best-first ceiling: '
      '${(100 * (deepUs - oracleUs) / deepUs).toStringAsFixed(1)}% saving, '
      'i.e. ${(deepUs / oracleUs).toStringAsFixed(2)}x faster AT BEST\n');

  print('cost     n   deepening   oracle   saving');
  for (final c in byCost.keys.toList()..sort()) {
    final g = byCost[c]!;
    print('${c.toString().padLeft(4)} ${g[2].toString().padLeft(5)} '
        '${(g[0] / g[2]).round().toString().padLeft(11)} '
        '${(g[1] / g[2]).round().toString().padLeft(8)} '
        '${(100 * (g[0] - g[1]) / g[0]).toStringAsFixed(1).padLeft(7)}%');
  }

  // Where would a queue actually pay off? Rank by absolute microseconds saved.
  rows.sort((x, y) => (y.$1 - y.$2) - (x.$1 - x.$2));
  print('\ncases a perfect best-first search would help most:');
  print('  deep   oracle  saved  cost  input');
  for (final (d, o, c, k) in rows.take(10)) {
    print('${d.toString().padLeft(6)} ${o.toString().padLeft(8)} '
        '${(d - o).toString().padLeft(6)} ${c.toString().padLeft(5)}  '
        '`${k.mutant}`');
  }

  // -- the outlier, timed warm and broken down by round ----------------------
  const odd = '"a":1,"bc":[2,33,true],"d":{"e":null},"f":"gh"}';
  final jc = corpora.firstWhere((x) => x.name == 'json');
  final e = pe.Squirrel(rules: rulesOf['json']!, topRuleName: jc.top);
  final sw = Stopwatch()..start();
  e.recover(odd);
  print('\noutlier `$odd`');
  print('  warm: ${sw.elapsedMicroseconds} us, cost ${e.lastCost}, '
      'rounds ${e.roundUs}, lookups ${e.nLook}, combos ${e.nComb}');
  // Budget 0 alone -- the frozen parser, no repair whatsoever.
  final e0 = pe.Squirrel(rules: rulesOf['json']!, topRuleName: jc.top);
  final sw0 = Stopwatch()..start();
  final p = Parser(rules: rulesOf['json']!, topRuleName: jc.top, input: odd)
      .parse();
  final frozenUs = sw0.elapsedMicroseconds;
  e0.floor = 0;
  print('  frozen parser alone: $frozenUs us '
      '(root len ${p.root.len} of ${odd.length})');
}
