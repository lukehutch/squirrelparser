// _prof.dart -- COUNT THE WORK, DON'T GUESS AT IT.
//
// Latency attribution across the I51-I54 chain says WHICH insight cost the
// time; it does not say which LOOP spends it. This runs the instrumented copy
// of m87 over the same 1824-case battery and reports the counters per
// category, so a prune can be aimed at the loop that actually dominates.
//
// Usage: dart run _prof.dart
import 'package:squirrel_parser/squirrel_parser.dart';

import 'astdiff.dart';
import '_p87.dart' as p;

void main() {
  final cases = weighted(buildBattery());
  final byCorpus = <String, Corpus>{for (final c in corpora) c.name: c};
  final rulesOf = <String, Map<String, Clause>>{
    for (final c in corpora) c.name: MetaGrammar.parseGrammar(c.grammar)
  };
  final made = <String, MatchResult? Function(String)>{
    for (final c in corpora)
      c.name: p.SuperDot3(rules: rulesOf[c.name]!, topRuleName: c.top).recover
  };

  final tot = <String, List<int>>{};
  final ms = <String, int>{};
  final n = <String, int>{};
  for (final k in cases) {
    p.pReset();
    final sw = Stopwatch()..start();
    try {
      made[byCorpus[k.grammar]!.name]!(k.mutant);
    } catch (_) {}
    sw.stop();
    final v = [
      p.pClause, p.pExpand, p.pPutCall, p.pCons, p.pPutNew, p.pPutRebuild,
      p.pExtend, p.pWrap, p.pNil, p.pSkipWay, p.pN, p.pTleaf, p.pTnode
    ];
    final acc = tot[k.category] ??= List.filled(13, 0);
    for (var i = 0; i < 13; i++) {
      acc[i] += v[i];
    }
    ms[k.category] = (ms[k.category] ?? 0) + sw.elapsedMicroseconds;
    n[k.category] = (n[k.category] ?? 0) + 1;
  }

  final cats = n.keys.toList()..sort((a, b) => ms[b]!.compareTo(ms[a]!));
  print('category            n      ms     clause     expand    putCall'
      '       cons     putNew  putRebuld     extend       wrap        nil'
      '    skipWay          _N     _Tleaf     _Tnode');
  final all = List.filled(13, 0);
  var allMs = 0, allN = 0;
  for (final c in cats) {
    final v = tot[c]!;
    for (var i = 0; i < 13; i++) {
      all[i] += v[i];
    }
    allMs += ms[c]!;
    allN += n[c]!;
    print('${c.padRight(16)}${n[c].toString().padLeft(4)}'
        '${(ms[c]! ~/ 1000).toString().padLeft(8)}'
        '${v.map((x) => x.toString().padLeft(11)).join()}');
  }
  print('${"TOTAL".padRight(16)}${allN.toString().padLeft(4)}'
      '${(allMs ~/ 1000).toString().padLeft(8)}'
      '${all.map((x) => x.toString().padLeft(11)).join()}');
  print('');
  final ways = all[3] + all[6] + all[7] + all[8] + all[9];
  final nodes = all[10] + all[11] + all[12];
  print('');
  print('_Way allocations   ' + ways.toString());
  print('  cons             ' + all[3].toString() +
      '   (of which _put rebuild ' + all[5].toString() + ')');
  print('  extend           ' + all[6].toString());
  print('  wrap             ' + all[7].toString());
  print('  nil              ' + all[8].toString());
  print('  skip             ' + all[9].toString());
  print('_N + _T allocations ' + nodes.toString());
  print('TOTAL objects      ' + (ways + nodes).toString());
  print('ns per object      ' +
      (allMs * 1000 / (ways + nodes)).toStringAsFixed(1));
}
