// Scratch: sweep the battery under asymmetric repair pricing --
// one deleted input character costs delWeight charge points instead of
// 1 -- measuring whether preferring insertion over destruction moves
// judgment toward the yardstick. Symmetric pricing (weight 1) is the
// standing baseline.
import 'package:squirrel_parser/squirrel_parser.dart';

import 'astdiff.dart';
import '../../experiments/recovery/_c14b.dart' as eng;

void main(List<String> argv) {
  final weights = argv.isEmpty ? [1, 2, 3] : [int.parse(argv[0])];
  final cases = weighted(buildBattery());
  final byCorpus = <String, Corpus>{for (final c in corpora) c.name: c};
  final rulesOf = <String, Map<String, Clause>>{
    for (final c in corpora) c.name: MetaGrammar.parseGrammar(c.grammar)
  };
  final original = <String, MatchResult>{};
  for (final c in corpora) {
    for (final doc in c.documents) {
      original['${c.name} $doc'] = Parser(
              rules: rulesOf[c.name]!, topRuleName: c.top, input: doc)
          .parse()
          .root;
    }
  }

  for (final w in weights) {
    eng.Squirrel.delWeight = w;
    eng.Squirrel.retainTies = false;
    var sum = 0.0, perfect = 0, crashes = 0;
    final byCat = <String, double>{};
    final nByCat = <String, int>{};
    for (final k in cases) {
      final c = byCorpus[k.grammar]!;
      MatchResult? produced;
      try {
        produced =
            eng.Squirrel(rules: rulesOf[k.grammar]!, topRuleName: c.top)
                .recover(k.mutant);
      } catch (_) {
        crashes++;
      }
      final exp = expectedFor(
          k, original['${k.grammar} ${k.original}']!, c.named);
      final s = scoreCase(
              produced: produced,
              expected: exp,
              inputLen: k.mutant.length,
              named: c.named)
          .score;
      sum += s;
      if (s >= 1.0) perfect++;
      byCat[k.category] = (byCat[k.category] ?? 0) + s;
      nByCat[k.category] = (nByCat[k.category] ?? 0) + 1;
    }
    final cats = byCat.keys.toList()..sort();
    final catStr = cats
        .map((g) =>
            '$g=${(byCat[g]! / nByCat[g]!).toStringAsFixed(3)}')
        .join(' ');
    print('delWeight=$w score=${(sum / cases.length).toStringAsFixed(4)} '
        'perfect%=${(100 * perfect / cases.length).toStringAsFixed(1)} '
        'crashes=$crashes');
    print('  $catStr');
  }
}
