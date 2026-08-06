// Scratch: what the engine SPENDS, counted rather than guessed. Totals over the
// whole battery, plus the same totals for the 24 slowest cases alone -- an
// optimization aimed at the mean is aimed at the wrong cases if the tail is
// where the time is.
import 'package:squirrel_parser/squirrel_parser.dart';

import 'astdiff.dart';
import '_r4up.dart' as p;

class Snap {
  Snap()
      : ways = p.nWays,
        hit = p.nHit,
        expand = p.nExpand,
        prune = p.nPrune,
        items = p.nPruneItems,
        skipK = p.nSkipK,
        movedK = p.nMovedK,
        movedStep = p.nMovedStep,
        seq = p.nSeq,
        first = p.nFirst,
        rep = p.nRep,
        term = p.nTerm,
        round = p.nRound;
  final int ways,
      hit,
      expand,
      prune,
      items,
      skipK,
      movedK,
      movedStep,
      seq,
      first,
      rep,
      term,
      round;

  Map<String, int> operator -(Snap o) => {
        'ways': ways - o.ways,
        'memoHit': hit - o.hit,
        'expand': expand - o.expand,
        'prune': prune - o.prune,
        'pruneItems': items - o.items,
        'skipK': skipK - o.skipK,
        'movedK': movedK - o.movedK,
        'movedStep': movedStep - o.movedStep,
        'seq': seq - o.seq,
        'first': first - o.first,
        'rep': rep - o.rep,
        'terminal': term - o.term,
        'rounds': round - o.round,
      };
}

void show(String label, Map<String, int> m, int n) {
  print('$label  ($n cases)');
  for (final e in m.entries) {
    print('  ${e.key.padRight(12)} ${e.value.toString().padLeft(12)}'
        '  ${(e.value / n).toStringAsFixed(1).padLeft(10)} /case');
  }
}

void main() {
  final cases = weighted(buildBattery());
  final rulesOf = <String, Map<String, Clause>>{
    for (final c in corpora) c.name: MetaGrammar.parseGrammar(c.grammar)
  };
  final made = <String, MatchResult Function(String)>{
    for (final c in corpora)
      c.name: p.Squirrel(rules: rulesOf[c.name]!, topRuleName: c.top).recover
  };

  final start = Snap();
  final per = <(int, Map<String, int>, String, String)>[];
  final sw = Stopwatch();
  for (final k in cases) {
    final a = Snap();
    sw.reset();
    sw.start();
    try {
      made[k.grammar]!(k.mutant);
    } catch (_) {}
    sw.stop();
    per.add((sw.elapsedMicroseconds, Snap() - a, k.grammar, k.mutant));
  }
  final all = Snap() - start;
  show('TOTAL', all, cases.length);

  per.sort((a, b) => b.$1 - a.$1);
  final tail = per.take(24).toList();
  final tailSum = <String, int>{};
  for (final t in tail) {
    t.$2.forEach((key, v) => tailSum[key] = (tailSum[key] ?? 0) + v);
  }
  var us = 0;
  for (final t in per) {
    us += t.$1;
  }
  var tailUs = 0;
  for (final t in tail) {
    tailUs += t.$1;
  }
  print('');
  print('total ${(us / 1000).toStringAsFixed(0)} ms; slowest 24 = '
      '${(tailUs / 1000).toStringAsFixed(0)} ms '
      '(${(tailUs / us * 100).toStringAsFixed(1)}%)');
  show('SLOWEST 24', tailSum, 24);
  print('');
  for (final t in tail.take(8)) {
    print('  ${(t.$1 / 1000).toStringAsFixed(1)}ms r${t.$2['rounds']} '
        'ways=${t.$2['ways']} skipK=${t.$2['skipK']} movedK=${t.$2['movedK']} '
        'pruneItems=${t.$2['pruneItems']}  ${t.$3} ${t.$4}');
  }
}
