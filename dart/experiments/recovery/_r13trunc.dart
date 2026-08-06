// Scratch: r13 scores truncate 0.697 where r7 scores 0.843. Score the truncate
// cases one at a time and show where the gap actually is.
import 'package:squirrel_parser/squirrel_parser.dart';
import 'astdiff.dart';
import 'r13.dart' as r13;
import 'r7.dart' as r7;

void main() {
  final cases = weighted(buildBattery()).where((k) => k.category == 'truncate');
  final byCorpus = {for (final c in corpora) c.name: c};
  final rulesOf = {
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
  final e13 = {
    for (final c in corpora)
      c.name: r13.Squirrel(rules: rulesOf[c.name]!, topRuleName: c.top).recover
  };
  final e7 = {
    for (final c in corpora)
      c.name: r7.Squirrel(rules: rulesOf[c.name]!, topRuleName: c.top).recover
  };
  final rows = <(double, double, String, String)>[];
  for (final k in cases) {
    final c = byCorpus[k.grammar]!;
    final exp = expectedFor(k, original['${k.grammar} ${k.original}']!, c.named);
    double run(MatchResult? Function(String) e) {
      try {
        return scoreCase(
                produced: e(k.mutant),
                expected: exp,
                inputLen: k.mutant.length,
                named: c.named)
            .score;
      } catch (_) {
        return 0;
      }
    }

    rows.add((run(e13[k.grammar]!), run(e7[k.grammar]!), k.grammar, k.mutant));
  }
  rows.sort((a, b) => (b.$2 - b.$1).compareTo(a.$2 - a.$1));
  var s13 = 0.0, s7 = 0.0;
  for (final r in rows) {
    s13 += r.$1;
    s7 += r.$2;
  }
  print('truncate n=${rows.length}  r13=${(s13 / rows.length).toStringAsFixed(4)}'
      '  r7=${(s7 / rows.length).toStringAsFixed(4)}');
  print('worst 12 for r13 vs r7:');
  for (final r in rows.take(12)) {
    print('  r13=${r.$1.toStringAsFixed(3)} r7=${r.$2.toStringAsFixed(3)} '
        '${r.$3.padRight(6)} "${r.$4}"');
  }
  print('cases where r13 beats r7: ${rows.where((r) => r.$1 > r.$2).length}');
}
