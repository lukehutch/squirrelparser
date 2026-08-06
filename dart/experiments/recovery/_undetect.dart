// _undetect.dart -- HOW MANY DAMAGED DOCUMENTS ARE STILL VALID DOCUMENTS?
//
// Deleting the comma from `[1,2]` gives `[12]`, which is a perfectly good JSON
// array of one number. There is no error to detect and nothing to recover; a
// human reading `[12]` reports no problem. But the battery scores it against the
// UNDAMAGED skeleton, which has two Numbers, so every engine is charged for
// failing to undo an edit that left no evidence behind.
//
// This counts those cases and prices the charge.
import 'package:squirrel_parser/squirrel_parser.dart';

import 'astdiff.dart';

void main() {
  final cases = weighted(buildBattery());
  final byCorpus = <String, Corpus>{for (final c in corpora) c.name: c};
  final rulesOf = <String, Map<String, Clause>>{
    for (final c in corpora) c.name: MetaGrammar.parseGrammar(c.grammar)
  };
  final expected = <String, List<String>>{};
  for (final c in corpora) {
    for (final doc in c.documents) {
      final r = Parser(rules: rulesOf[c.name]!, topRuleName: c.top, input: doc)
          .parse();
      expected['${c.name} $doc'] = skeleton(r.root, c.named);
    }
  }

  final n = <String, int>{}, clean = <String, int>{};
  final capSum = <String, double>{};
  final shown = <String>[];
  for (final k in cases) {
    final c = byCorpus[k.grammar]!;
    n[k.category] = (n[k.category] ?? 0) + 1;
    final r =
        Parser(rules: rulesOf[c.name]!, topRuleName: c.top, input: k.mutant)
            .parse();
    if (r.hasSyntaxErrors) continue;
    clean[k.category] = (clean[k.category] ?? 0) + 1;
    // The best any engine can do on a clean document is return its own parse.
    final s = scoreCase(
        produced: r.root,
        expected: expected['${k.grammar} ${k.original}']!,
        inputLen: k.mutant.length,
        named: c.named);
    capSum[k.category] = (capSum[k.category] ?? 0) + s.score;
    if (s.score < 1.0 && shown.length < 10) {
      shown.add('  ${k.grammar}/${k.category} '
          '${k.original} -> ${k.mutant}  cap ${s.score.toStringAsFixed(3)}');
    }
  }

  print('category        n   clean  clean%  mean cap on clean');
  final ks = n.keys.toList()
    ..sort((a, b) => (clean[b] ?? 0).compareTo(clean[a] ?? 0));
  var tot = 0, totClean = 0;
  double lost = 0;
  for (final k in ks) {
    final cl = clean[k] ?? 0;
    tot += n[k]!;
    totClean += cl;
    if (cl > 0) lost += cl - capSum[k]!;
    print('${k.padRight(15)} ${n[k]}  $cl  '
        '${(cl / n[k]! * 100).toStringAsFixed(1)}%  '
        '${cl == 0 ? "-" : (capSum[k]! / cl).toStringAsFixed(3)}');
  }
  print('');
  print('total $totClean of $tot cases (${(totClean / tot * 100).toStringAsFixed(1)}%) '
      'are still valid documents');
  print('aggregate points lost to undetectable damage: '
      '${(lost / tot).toStringAsFixed(4)}');
  print('');
  shown.forEach(print);
}
