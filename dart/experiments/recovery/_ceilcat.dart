// _ceilcat.dart -- WHERE DOES ONE CATEGORY ACTUALLY LOSE ITS POINTS?
//
// The aggregate says an engine is at 0.905. It does not say which cases are
// wrong or what they got instead. This scores a single category, sorts the
// misses by how much they cost, and prints the expected and produced skeletons
// side by side so the failure is readable rather than inferred.
//
// It was written to test a specific claim: that the truncate category was
// capped far below 1.0 by the evaluator rather than by the engines. It was --
// the cap was 0.566 -- and [expectedFor] now fixes that at the source, so this
// file no longer computes a ceiling of its own. Keeping one definition of the
// expectation is the point: two would drift.
//
// Usage: dart run _ceilcat.dart [category] [howManyToPrint]
import 'package:squirrel_parser/squirrel_parser.dart';

import 'astdiff.dart';
import 'm92.dart' as g92;

void main(List<String> argv) {
  final want = argv.isEmpty ? 'truncate' : argv[0];
  final show = argv.length > 1 ? int.parse(argv[1]) : 8;

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
      c.name: g92.SuperDot3(rules: rulesOf[c.name]!, topRuleName: c.top).recover
  };

  var n = 0, perfect = 0;
  double sum = 0;
  final miss = <(double, Case, List<String>, List<String>)>[];
  for (final k in cases) {
    if (k.category != want) continue;
    final c = byCorpus[k.grammar]!;
    final exp = expectedFor(k, original['${k.grammar} ${k.original}']!, c.named);

    MatchResult? produced;
    try {
      produced = made[k.grammar]!(k.mutant);
    } catch (_) {}
    final s = scoreCase(
        produced: produced,
        expected: exp,
        inputLen: k.mutant.length,
        named: c.named);

    n++;
    sum += s.score;
    if (s.score == 1.0) {
      perfect++;
    } else {
      miss.add((
        1 - s.score,
        k,
        exp,
        produced == null ? ['<null>'] : skeleton(produced, c.named)
      ));
    }
  }

  print('category   $want');
  print('cases      $n');
  print('mean       ${(sum / n).toStringAsFixed(4)}');
  print('perfect    $perfect  (${(perfect / n * 100).toStringAsFixed(1)}%)');
  print('');
  miss.sort((a, b) => b.$1.compareTo(a.$1));
  for (final e in miss.take(show)) {
    print('--- lost ${e.$1.toStringAsFixed(3)}  ${e.$2.grammar}');
    print('    mutant   ${e.$2.mutant}');
    print('    expected ${e.$3.join(' ')}');
    print('    got      ${e.$4.join(' ')}');
  }
}
