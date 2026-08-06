// Score _r1b.dart on the official battery, with _score1.dart's protocol copied
// verbatim rather than modified: the tracked gate is being read by an audit run,
// so registering a scratch engine in it would move it under the auditor.
import 'package:squirrel_parser/squirrel_parser.dart';

import '_r1b.dart' as r1b;
import 'astdiff.dart';

void main() {
  final cases = weighted(buildBattery());
  final byCorpus = {for (final c in corpora) c.name: c};
  final rulesOf = {
    for (final c in corpora) c.name: MetaGrammar.parseGrammar(c.grammar)
  };

  final original = <String, MatchResult>{};
  for (final c in corpora) {
    for (final doc in c.documents) {
      final r = Parser(rules: rulesOf[c.name]!, topRuleName: c.top, input: doc)
          .parse();
      if (r.hasSyntaxErrors) {
        throw StateError('corpus ${c.name}: document does not parse: $doc');
      }
      original['${c.name} $doc'] = r.root;
    }
  }

  final made = <String, MatchResult? Function(String)>{};
  for (final c in corpora) {
    made[c.name] =
        r1b.Squirrel(rules: rulesOf[c.name]!, topRuleName: c.top).recover;
  }

  final catScore = <String, double>{};
  final catN = <String, int>{};
  var crashed = 0, uncovered = 0, perfect = 0;
  double total = 0;
  final sw = Stopwatch();
  for (final k in cases) {
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
  }
  final cats = catN.keys.toList()
    ..sort((a, b) => categoryWeight[b]!.compareTo(categoryWeight[a]!));
  print([
    'r1b',
    (total / cases.length).toStringAsFixed(4),
    (perfect / cases.length * 100).toStringAsFixed(1),
    '$crashed',
    '$uncovered',
    '${sw.elapsedMilliseconds}',
    for (final k in cats) '$k=${(catScore[k]! / catN[k]!).toStringAsFixed(3)}',
  ].join(' '));
}
