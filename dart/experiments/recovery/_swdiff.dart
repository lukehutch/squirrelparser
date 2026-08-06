// Which cases the absorption price actually MOVED, and which way. Baseline is
// the committed r9 (`_r9base.dart`, a copy of HEAD); the candidate is the
// working tree. Scored case by case with the battery's own scorer, so a row
// here is a real score delta and not a tree that merely differs.
//
// Usage: dart run _swdiff.dart [category] [limit]
import 'package:squirrel_parser/squirrel_parser.dart';

import '_r9base.dart' as base;
import '_score1.dart' show scoreCase, expectedFor;
import 'astdiff.dart';
import 'r9.dart' as cand;

void main(List<String> argv) {
  final only = argv.isEmpty ? null : argv[0];
  final lim = argv.length > 1 ? int.parse(argv[1]) : 12;
  final cases = weighted(buildBattery());
  final byCorpus = {for (final c in corpora) c.name: c};
  final rulesOf = {
    for (final c in corpora) c.name: MetaGrammar.parseGrammar(c.grammar)
  };
  final original = <String, MatchResult>{};
  for (final c in corpora) {
    for (final doc in c.documents) {
      original['${c.name} $doc'] =
          Parser(rules: rulesOf[c.name]!, topRuleName: c.top, input: doc)
              .parse()
              .root;
    }
  }
  final eb = {
    for (final c in corpora)
      c.name: base.Squirrel(rules: rulesOf[c.name]!, topRuleName: c.top)
  };
  final ec = {
    for (final c in corpora)
      c.name: cand.Squirrel(rules: rulesOf[c.name]!, topRuleName: c.top)
  };

  final rows = <(double, Case, double, double, int, int)>[];
  var up = 0, down = 0;
  for (final k in cases) {
    if (only != null && k.category != only) continue;
    final c = byCorpus[k.grammar]!;
    final exp = expectedFor(k, original['${k.grammar} ${k.original}']!, c.named);
    MatchResult? a, b;
    try {
      a = eb[k.grammar]!.recover(k.mutant);
    } catch (_) {}
    try {
      b = ec[k.grammar]!.recover(k.mutant);
    } catch (_) {}
    final sa = scoreCase(
        produced: a, expected: exp, inputLen: k.mutant.length, named: c.named);
    final sb = scoreCase(
        produced: b, expected: exp, inputLen: k.mutant.length, named: c.named);
    if ((sb.score - sa.score).abs() < 1e-9) continue;
    if (sb.score > sa.score) up++;
    if (sb.score < sa.score) down++;
    rows.add((sb.score - sa.score, k, sa.score, sb.score,
        eb[k.grammar]!.lastCost, ec[k.grammar]!.lastCost));
  }
  rows.sort((x, y) => x.$1.compareTo(y.$1));
  for (final r in rows.take(lim)) {
    print('${r.$1.toStringAsFixed(3).padLeft(7)}  ${r.$2.grammar} '
        '${r.$2.category.padRight(14)} ${r.$3.toStringAsFixed(3)} -> '
        '${r.$4.toStringAsFixed(3)}  cost ${r.$5} -> ${r.$6}');
    print('     mutant "${r.$2.mutant}"');
  }
  print('moved ${rows.length}: $down worse, $up better'
      '${only == null ? '' : '  (category $only)'}');
}
