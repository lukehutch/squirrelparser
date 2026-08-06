// per-case latency profile for c1: ms, winning round, clean boundary, length
import 'package:squirrel_parser/squirrel_parser.dart';

import 'c1.dart' as c1;
import 'astdiff.dart';

void main() {
  final cases = weighted(buildBattery());
  final rulesOf = <String, Map<String, Clause>>{
    for (final c in corpora) c.name: MetaGrammar.parseGrammar(c.grammar)
  };
  final made = <String, c1.Squirrel>{};
  for (final c in corpora) {
    made[c.name] = c1.Squirrel(rules: rulesOf[c.name]!, topRuleName: c.top);
  }
  final rows = <(int, String)>[];
  final byRound = <int, int>{};
  final byCorpus = <String, int>{};
  var sameTot = 0, compTot = 0;
  final sw = Stopwatch();
  for (var i = 0; i < cases.length; i++) {
    final k = cases[i];
    final e = made[k.grammar]!;
    sw.reset();
    sw.start();
    try {
      e.recover(k.mutant);
    } catch (_) {}
    sw.stop();
    final ms = sw.elapsedMicroseconds;
    byRound[e.lastRound] = (byRound[e.lastRound] ?? 0) + ms;
    byCorpus[k.grammar] = (byCorpus[k.grammar] ?? 0) + ms;
    sameTot += e.cellsSame;
    compTot += e.cellsComputed;
    rows.add((
      ms,
      '${(ms / 1000).toStringAsFixed(1)}ms r=${e.lastRound} '
          '${k.grammar.padRight(4)} ${k.category.padRight(14)} '
          'len=${k.mutant.length} cells=${e.cellsComputed} '
          'same=${e.cellsSame} ${k.mutant.replaceAll('\n', r'\n').substring(0, k.mutant.length > 48 ? 48 : k.mutant.length)}'
    ));
  }
  rows.sort((a, b) => b.$1 - a.$1);
  final tot = rows.fold(0, (a, r) => a + r.$1);
  print('total=${tot ~/ 1000}ms cells=$compTot identical=$sameTot '
      '(${(sameTot * 100 / compTot).toStringAsFixed(1)}%)');
  print('by round (ms): ' +
      (byRound.entries.toList()..sort((a, b) => a.key - b.key))
          .map((e) => '${e.key}:${e.value ~/ 1000}')
          .join(' '));
  print('by corpus (ms): ' +
      byCorpus.entries.map((e) => '${e.key}:${e.value ~/ 1000}').join(' '));
  var cum = 0;
  for (var i = 0; i < 25; i++) {
    cum += rows[i].$1;
    print('${(cum * 100 / tot).toStringAsFixed(0).padLeft(3)}% ${rows[i].$2}');
  }
}
