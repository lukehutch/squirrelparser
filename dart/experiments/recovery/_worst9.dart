// Scratch: where r9's remaining battery loss actually is -- the worst-scoring
// cases, and how much of the loss sits in SHORT inputs, so the "extreme
// truncation reads as one long string" gap can be sized rather than guessed.
//
// Scoring is the official path: `scoreCase` against `expectedFor`, exactly as
// _score1.dart does it, so these numbers compose back to the published ones.
//
//   dart run _worst9.dart [category|''] [howMany]

import 'package:squirrel_parser/squirrel_parser.dart';
import 'astdiff.dart';
import 'r9.dart' as b;

void main(List<String> argv) {
  final only = argv.isNotEmpty ? argv[0] : '';
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
  final made = <String, MatchResult? Function(String)>{
    for (final c in corpora)
      c.name: b.Squirrel(rules: rulesOf[c.name]!, topRuleName: c.top).recover
  };

  final rows = <(double, String, String, String, String, int)>[];
  var lost = 0.0;
  for (final k in cases) {
    if (only.isNotEmpty && k.category != only) continue;
    final c = byCorpus[k.grammar]!;
    MatchResult? produced;
    try {
      produced = made[k.grammar]!(k.mutant);
    } catch (_) {
      produced = null;
    }
    final s = scoreCase(
      produced: produced,
      expected: expectedFor(k, original['${k.grammar} ${k.original}']!, c.named),
      inputLen: k.mutant.length,
      named: c.named,
    );
    lost += 1.0 - s.score;
    rows.add((
      s.score,
      k.category,
      k.grammar,
      k.mutant,
      produced == null ? '<null>' : skeleton(produced, c.named).join(' '),
      k.mutant.length,
    ));
  }
  rows.sort((x, y) => x.$1.compareTo(y.$1));
  print('${rows.length} cases, total loss ${lost.toStringAsFixed(2)}\n');

  for (final n in [4, 6, 8, 12, 20]) {
    var l = 0.0, cnt = 0;
    for (final r in rows) {
      if (r.$6 <= n) {
        l += 1.0 - r.$1;
        cnt++;
      }
    }
    print('inputs <= ${n.toString().padLeft(2)} chars: '
        '${cnt.toString().padLeft(4)} cases, '
        '${l.toStringAsFixed(2).padLeft(7)} of the loss '
        '(${(l / lost * 100).toStringAsFixed(1)}%)');
  }
  print('');
  for (final r in rows.take(show)) {
    print('${r.$1.toStringAsFixed(3)}  ${r.$2.padRight(15)}'
        '${r.$3.padRight(7)}${r.$6.toString().padLeft(3)}c  '
        '${r.$4.replaceAll('\n', ' ')}   ->   ${r.$5}');
  }
}
