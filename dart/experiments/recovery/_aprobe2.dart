// _aprobe2.dart -- a few cases per (corpus, category), printed as they finish.
import 'dart:io';

import 'package:squirrel_parser/squirrel_parser.dart';

import 'astdiff.dart';
import 'm80.dart' as e80;

void main() {
  final cases = weighted(buildBattery());
  final byCorpus = <String, Corpus>{for (final c in corpora) c.name: c};
  final rulesOf = <String, Map<String, Clause>>{
    for (final c in corpora) c.name: MetaGrammar.parseGrammar(c.grammar)
  };
  final seen = <String, int>{};
  final tot = <String, int>{}, cnt = <String, int>{};
  for (final k in cases) {
    final key = '${k.grammar}/${k.category}';
    if ((seen[key] ?? 0) >= 4) continue;
    seen[key] = (seen[key] ?? 0) + 1;
    final c = byCorpus[k.grammar]!;
    final eng = e80.SuperDot3(rules: rulesOf[k.grammar]!, topRuleName: c.top);
    final sw = Stopwatch()..start();
    var cost = -99;
    try {
      eng.recover(k.mutant);
      cost = eng.lastCost;
    } catch (e) {
      stdout.writeln('THREW $key: ${k.mutant}');
    }
    sw.stop();
    tot[key] = (tot[key] ?? 0) + sw.elapsedMicroseconds;
    cnt[key] = (cnt[key] ?? 0) + 1;
    stdout.writeln('${(sw.elapsedMicroseconds / 1000).toStringAsFixed(1).padLeft(9)} ms '
        'cost ${cost.toString().padLeft(3)}  ${key.padRight(22)} ${k.mutant}');
  }
  stdout.writeln('\n--- mean ms per (corpus,category) ---');
  final keys = tot.keys.toList()..sort();
  for (final k in keys) {
    stdout.writeln('${k.padRight(24)}${(tot[k]! / cnt[k]! / 1000).toStringAsFixed(1).padLeft(10)} ms');
  }
}
