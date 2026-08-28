// Scratch: sweep the whole battery with exact-tie RETENTION on
// (_c14b.retainTies), then judge every collected complete root admission
// OFFLINE against the expectation. Measures the judgment headroom hiding
// in arrival-order tie resolution:
//   - how many imperfect cases have a better-scoring candidate in hand?
//   - how many have a PERFECT one?
//   - what did retaining ties cost in candidate volume?
import 'package:squirrel_parser/squirrel_parser.dart';

import 'astdiff.dart';
import '../../experiments/recovery/_c14b.dart' as eng;

void main(List<String> argv) {
  eng.Squirrel.retainTies = true;
  if (argv.isNotEmpty) eng.Squirrel.tieCap = int.parse(argv[0]);
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

  var imperfect = 0, headroom = 0, perfectInSet = 0;
  var chosenSum = 0.0, bestSum = 0.0;
  var maxCands = 0, totalCands = 0, damagedCases = 0;
  final examples = <String>[];
  for (var i = 0; i < cases.length; i++) {
    final k = cases[i];
    final c = byCorpus[k.grammar]!;
    final e = eng.Squirrel(rules: rulesOf[k.grammar]!, topRuleName: c.top);
    MatchResult? produced;
    try {
      produced = e.recover(k.mutant);
    } catch (_) {}
    final exp =
        expectedFor(k, original['${k.grammar} ${k.original}']!, c.named);
    double sc(MatchResult? t) =>
        scoreCase(
                produced: t,
                expected: exp,
                inputLen: k.mutant.length,
                named: c.named)
            .score;
    final chosen = sc(produced);
    // Offline-judge every collected candidate.
    double bestCand = chosen;
    var n = 0;
    for (final r in e.rootCands) {
      final s2 = sc(e.candidateTree(r));
      if (s2 > bestCand) bestCand = s2;
      n++;
    }
    totalCands += n;
    if (n > maxCands) maxCands = n;
    if (n > 0) damagedCases++;
    chosenSum += chosen;
    bestSum += chosen > bestCand ? chosen : bestCand;
    if (chosen < 1.0) {
      imperfect++;
      if (bestCand > chosen) {
        headroom++;
        if (bestCand >= 1.0 && examples.length < 12) {
          perfectInSet++;
          examples.add('i=$i ${k.grammar} ${k.category}');
        }
      }
    }
  }
  print('tieCap=${eng.Squirrel.tieCap}');
  print('cases=${cases.length} imperfect=$imperfect');
  print('candidates: mean over damaged=${(totalCands / (damagedCases == 0 ? 1 : damagedCases)).toStringAsFixed(2)} max=$maxCands');
  print('imperfect cases with a BETTER candidate in the set: $headroom');
  print('  ... of which PERFECT candidate exists: $perfectInSet');
  for (final x in examples) {
    print('    $x');
  }
  print('mean score: chosen=${(chosenSum / cases.length).toStringAsFixed(4)} '
      'oracle-over-set=${(bestSum / cases.length).toStringAsFixed(4)}');
}
