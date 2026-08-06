// _cmp.dart -- per-case score diff between two engines, so a category that moves
// can be traced to the cases that moved it rather than guessed at.
//
// Usage: dart run _cmp.dart <engineA> <engineB> [category]
//
// Latency is NOT measured here: both engines run in one process precisely so
// they see identical expectations, which is the wrong setup for a clock.
import 'package:squirrel_parser/squirrel_parser.dart';

import '_score1.dart' show resolve;
import 'astdiff.dart';

void main(List<String> argv) {
  if (argv.length < 2) {
    print('usage: dart run _cmp.dart <engineA> <engineB> [category]');
    return;
  }
  final want = argv.length > 2 ? argv[2] : null;
  final builds = [resolve(argv[0]), resolve(argv[1])];
  for (var i = 0; i < 2; i++) {
    if (builds[i] == null) {
      print('${argv[i]} UNKNOWN');
      return;
    }
  }

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
  final made = [
    for (final b in builds)
      <String, MatchResult? Function(String)>{
        for (final c in corpora) c.name: b!(rulesOf[c.name]!, c.top)
      }
  ];

  // The battery repeats a case once per unit of weight; score each DISTINCT case
  // once and report its weight, or the same regression prints ten times.
  final seen = <String>{};
  var worse = 0, better = 0;
  final rows = <(double, String)>[];
  for (final k in cases) {
    final id = '${k.grammar}\x00${k.category}\x00${k.mutant}';
    if (!seen.add(id)) continue;
    if (want != null && k.category != want) continue;
    final c = byCorpus[k.grammar]!;
    final exp = expectedFor(k, original['${k.grammar} ${k.original}']!, c.named);
    final s = <double>[];
    for (var i = 0; i < 2; i++) {
      MatchResult? p;
      try {
        p = made[i][k.grammar]!(k.mutant);
      } catch (_) {
        p = null;
      }
      s.add(scoreCase(
        produced: p,
        expected: exp,
        inputLen: k.mutant.length,
        named: c.named,
      ).score);
    }
    final d = s[1] - s[0];
    if (d.abs() < 1e-9) continue;
    if (d < 0) {
      worse++;
    } else {
      better++;
    }
    rows.add((
      d,
      '${d >= 0 ? '+' : ''}${d.toStringAsFixed(3)}  '
          '${s[0].toStringAsFixed(3)}->${s[1].toStringAsFixed(3)}  '
          '${k.category.padRight(15)} ${k.grammar.padRight(6)} ${k.mutant}'
    ));
  }
  rows.sort((a, b) => a.$1.compareTo(b.$1));
  for (final r in rows) {
    print(r.$2);
  }
  print('\n${argv[1]} vs ${argv[0]}: $worse worse, $better better '
      '(distinct cases${want == null ? '' : ' in $want'})');
}
