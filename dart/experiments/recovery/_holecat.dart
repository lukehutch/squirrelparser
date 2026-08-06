// Scratch: which battery CATEGORY do an engine's Seq holes fall in?
//
// Claim under test: m143's 28 holes are truncation cases -- the input stops
// mid-production and m143 emits the production anyway with the required child
// dropped. If true, the one category where m143 beats m132 (truncate, 0.919 vs
// 0.890) is the one its unsound node-dropping applies to.
import 'package:squirrel_parser/squirrel_parser.dart';

import '_missing.dart' show shortSeqs;
import '_score1.dart' show resolve;
import 'astdiff.dart';

void main(List<String> argv) {
  final names = argv.isEmpty ? const ['m143'] : argv;
  final rulesOf = {
    for (final c in corpora) c.name: MetaGrammar.parseGrammar(c.grammar)
  };
  final seen = <String>{};
  final cases = <Case>[];
  for (final k in weighted(buildBattery())) {
    if (seen.add('${k.grammar}\x00${k.category}\x00${k.mutant}')) cases.add(k);
  }

  for (final e in names) {
    final b = resolve(e);
    if (b == null) {
      print('$e UNKNOWN');
      continue;
    }
    final made = {for (final c in corpora) c.name: b(rulesOf[c.name]!, c.top)};
    final byCat = <String, int>{};
    final byCatNodes = <String, int>{};
    final examples = <String, String>{};
    for (final k in cases) {
      int h;
      try {
        final t = made[k.grammar]!(k.mutant);
        if (t == null) continue;
        (h, _) = shortSeqs(t);
      } catch (_) {
        continue;
      }
      if (h == 0) continue;
      byCat[k.category] = (byCat[k.category] ?? 0) + 1;
      byCatNodes[k.category] = (byCatNodes[k.category] ?? 0) + h;
      examples[k.category] ??= '${k.grammar} ${k.mutant}';
    }
    final total = byCat.values.fold(0, (a, b) => a + b);
    print('$e: $total hole cases');
    final keys = byCat.keys.toList()..sort((a, b) => byCat[b]! - byCat[a]!);
    for (final c in keys) {
      print('  ${c.padRight(16)} ${'${byCat[c]}'.padLeft(4)} cases '
          '${'${byCatNodes[c]}'.padLeft(4)} nodes   e.g. ${examples[c]}');
    }
  }
}
