// Scratch probe: WHERE do the pre-m23 engines crash?
//
// The doc claims the project's largest bug -- the memo reentrancy guard caching
// the in-progress placeholder, so a left-recursive alternative contributes
// nothing -- is present "in every engine up to m22", and that the era-1
// 519-mutant JSON battery was structurally unable to see it because that
// grammar is not left-recursive. The era-2 battery HAS a left-recursive corpus
// (`expr`), so if the claim holds, the crashes must land there and nowhere
// else.
//
// Usage: dart _crashwho.dart <engine> [<engine> ...]
import 'package:squirrel_parser/squirrel_parser.dart';

import 'astdiff.dart';
import '_score1.dart' show resolve;

void main(List<String> argv) {
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

  for (final name in argv) {
    final build = resolve(name);
    if (build == null) {
      print('$name UNKNOWN');
      continue;
    }
    final made = <String, MatchResult? Function(String)>{
      for (final c in corpora) c.name: build(rulesOf[c.name]!, c.top)
    };
    final byGrammar = <String, int>{};
    final byCat = <String, int>{};
    final nOf = <String, int>{};
    // Mean score per grammar, and the same restricted to cases that did NOT
    // crash -- so a deficit that survives the crashes is visible on its own.
    final sumOf = <String, double>{};
    final sumLive = <String, double>{};
    final nLive = <String, int>{};
    String? sample;
    for (final k in cases) {
      nOf[k.grammar] = (nOf[k.grammar] ?? 0) + 1;
      MatchResult? produced;
      try {
        produced = made[k.grammar]!(k.mutant);
      } catch (_) {
        produced = null;
      }
      final s = scoreCase(
        produced: produced,
        expected: expectedFor(
            k, original['${k.grammar} ${k.original}']!, byCorpus[k.grammar]!.named),
        inputLen: k.mutant.length,
        named: byCorpus[k.grammar]!.named,
      );
      sumOf[k.grammar] = (sumOf[k.grammar] ?? 0) + s.score;
      if (s.crashed) {
        byGrammar[k.grammar] = (byGrammar[k.grammar] ?? 0) + 1;
        byCat[k.category] = (byCat[k.category] ?? 0) + 1;
        sample ??= '${k.grammar} | ${k.category} | ${k.mutant}';
      } else {
        sumLive[k.grammar] = (sumLive[k.grammar] ?? 0) + s.score;
        nLive[k.grammar] = (nLive[k.grammar] ?? 0) + 1;
      }
    }
    final total = byGrammar.values.fold(0, (a, b) => a + b);
    print('$name: $total crashes of ${cases.length} weighted cases');
    print('   crashes by grammar : ${byGrammar.isEmpty ? "(none)" : byGrammar}'
        '   [cases per grammar: $nOf]');
    print('   crashes by category: ${byCat.isEmpty ? "(none)" : byCat}');
    if (sample != null) print('   first crashing case: $sample');
    final all = [
      for (final g in nOf.keys)
        '$g=${(sumOf[g]! / nOf[g]!).toStringAsFixed(4)}'
    ].join(' ');
    final live = [
      for (final g in nOf.keys)
        '$g=${nLive[g] == null ? "n/a" : (sumLive[g]! / nLive[g]!).toStringAsFixed(4)}'
    ].join(' ');
    print('   mean score / grammar, all cases      : $all');
    print('   mean score / grammar, NON-CRASHED only: $live');
  }
}
