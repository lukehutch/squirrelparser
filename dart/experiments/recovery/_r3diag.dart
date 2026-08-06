// _r3diag.dart -- where does r2 lose to m143? Per case, not per category.
//
// Scratch diagnostic for the r3 design. Prints the cases with the largest
// (m143 score - r2 score) gap, so the design starts from what actually fails
// rather than from the category means.
import 'package:squirrel_parser/squirrel_parser.dart';

import 'astdiff.dart';
import 'm143.dart' as g143;
import 'r2.dart' as r2;

void main(List<String> argv) {
  final want = argv.isEmpty ? '' : argv[0];
  final show = argv.length > 1 ? int.parse(argv[1]) : 25;

  final cases = weighted(buildBattery());
  final byCorpus = <String, Corpus>{for (final c in corpora) c.name: c};
  final rulesOf = <String, Map<String, Clause>>{
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

  final rEng = <String, r2.Squirrel>{};
  final mEng = <String, dynamic>{};
  for (final c in corpora) {
    rEng[c.name] = r2.Squirrel(rules: rulesOf[c.name]!, topRuleName: c.top);
    mEng[c.name] = g143.SuperDot3(rules: rulesOf[c.name]!, topRuleName: c.top);
  }

  MatchResult? run(Object e, String s) {
    try {
      return e is r2.Squirrel ? e.recover(s) : (e as dynamic).recover(s);
    } catch (_) {
      return null;
    }
  }

  final rows = <(double, String, Case, double, double)>[];
  final seen = <String>{};
  for (final k in cases) {
    final key = '${k.grammar}\x00${k.category}\x00${k.mutant}';
    if (!seen.add(key)) continue;
    if (want.isNotEmpty && k.category != want) continue;
    final c = byCorpus[k.grammar]!;
    final exp = expectedFor(k, original['${k.grammar} ${k.original}']!, c.named);
    final sr = scoreCase(
        produced: run(rEng[k.grammar]!, k.mutant),
        expected: exp,
        inputLen: k.mutant.length,
        named: c.named);
    final sm = scoreCase(
        produced: run(mEng[k.grammar]!, k.mutant),
        expected: exp,
        inputLen: k.mutant.length,
        named: c.named);
    rows.add((sm.score - sr.score, k.category, k, sr.score, sm.score));
  }
  rows.sort((a, b) => b.$1.compareTo(a.$1));

  // Where the loss is concentrated, by grammar and category.
  final byPair = <String, double>{};
  final nPair = <String, int>{};
  for (final row in rows) {
    final key = '${row.$3.grammar}/${row.$2}';
    byPair[key] = (byPair[key] ?? 0) + row.$1;
    nPair[key] = (nPair[key] ?? 0) + 1;
  }
  final keys = byPair.keys.toList()
    ..sort((a, b) => byPair[b]!.compareTo(byPair[a]!));
  print('=== total r2 deficit by grammar/category (sum of per-case gap) ===');
  for (final key in keys.take(18)) {
    print('${key.padRight(26)} total=${byPair[key]!.toStringAsFixed(2)}'
        '  n=${nPair[key]}  mean=${(byPair[key]! / nPair[key]!).toStringAsFixed(3)}');
  }

  print('\n=== worst $show individual cases ===');
  for (final row in rows.take(show)) {
    final (gap, cat, k, sr, sm) = row;
    print('gap=${gap.toStringAsFixed(3)} r2=${sr.toStringAsFixed(3)} '
        'm143=${sm.toStringAsFixed(3)} [$cat/${k.grammar}]');
    print('   mutant: ${k.mutant.replaceAll('\n', '\\n')}');
    print('   orig  : ${k.original.replaceAll('\n', '\\n')}');
  }
}
