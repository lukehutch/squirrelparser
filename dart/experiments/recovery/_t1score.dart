// _t1score.dart -- t1 scorer.
// optional per-case dump (arg: "dump") in _res1's row format.
import 'package:squirrel_parser/squirrel_parser.dart';

import 't1.dart' as s0;
import 'astdiff.dart';

void main(List<String> argv) {
  final dump = argv.contains('dump');
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
  final made = <String, MatchResult? Function(String)>{};
  for (final c in corpora) {
    made[c.name] =
        s0.Squirrel(rules: rulesOf[c.name]!, topRuleName: c.top).recover;
  }
  final catScore = <String, double>{};
  final catN = <String, int>{};
  var crashed = 0, uncovered = 0, perfect = 0;
  double total = 0;
  final rows = <(double, String)>[];
  final sw = Stopwatch();
  for (var i = 0; i < cases.length; i++) {
    final k = cases[i];
    final c = byCorpus[k.grammar]!;
    MatchResult? produced;
    sw.start();
    try {
      produced = made[k.grammar]!(k.mutant);
    } catch (_) {
      produced = null;
    }
    sw.stop();
    final s = scoreCase(
      produced: produced,
      expected: expectedFor(k, original['${k.grammar} ${k.original}']!, c.named),
      inputLen: k.mutant.length,
      named: c.named,
    );
    if (s.crashed) crashed++;
    if (!s.covered) uncovered++;
    if (s.score == 1.0) perfect++;
    total += s.score;
    catScore[k.category] = (catScore[k.category] ?? 0) + s.score;
    catN[k.category] = (catN[k.category] ?? 0) + 1;
    if (dump && s.score < 1.0) {
      rows.add((
        s.score,
        '${s.score.toStringAsFixed(3)} ${k.grammar.padRight(4)} '
            '${k.category.padRight(14)} i=$i ${k.mutant.replaceAll('\n', r'\n')}'
      ));
    }
  }
  final cats = catN.keys.toList()
    ..sort((a, b) => categoryWeight[b]!.compareTo(categoryWeight[a]!));
  print([
    't1',
    (total / cases.length).toStringAsFixed(4),
    (perfect / cases.length * 100).toStringAsFixed(1),
    '$crashed',
    '$uncovered',
    '${sw.elapsedMilliseconds}',
    for (final k in cats) '$k=${(catScore[k]! / catN[k]!).toStringAsFixed(3)}',
  ].join(' '));
  if (dump) {
    rows.sort((x, y) => x.$1.compareTo(y.$1));
    for (final r in rows) {
      print(r.$2);
    }
  }
}
