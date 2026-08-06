// Scratch: the lowest-scoring cases of one category for r8.
//   dart run _worst8.dart <category> [n]
import 'package:squirrel_parser/squirrel_parser.dart';
import 'astdiff.dart';
import 'r8.dart' as e;

void main(List<String> argv) {
  final cat = argv.isEmpty ? 'truncate' : argv[0];
  final n = argv.length > 1 ? int.parse(argv[1]) : 5;
  final cases = weighted(buildBattery());
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
  final eng = {
    for (final c in corpora)
      c.name: e.Squirrel(rules: rulesOf[c.name]!, topRuleName: c.top).recover
  };
  final rows = <(double, Case, List<String>, List<String>)>[];
  final seen = <String>{};
  for (final k in cases) {
    if (k.category != cat) continue;
    if (!seen.add('${k.grammar}|${k.mutant}')) continue;
    final c = byCorpus[k.grammar]!;
    final exp = expectedFor(k, original['${k.grammar} ${k.original}']!, c.named);
    MatchResult? got;
    try {
      got = eng[k.grammar]!(k.mutant);
    } catch (_) {}
    final s = scoreCase(
        produced: got, expected: exp, inputLen: k.mutant.length, named: c.named);
    rows.add((s.score, k, exp, got == null ? ['<crash>'] : skeleton(got, c.named)));
  }
  rows.sort((a, b) => a.$1.compareTo(b.$1));
  print('$cat: ${rows.length} distinct cases, mean '
      '${(rows.map((r) => r.$1).reduce((a, b) => a + b) / rows.length).toStringAsFixed(4)}\n');
  for (final r in rows.take(n)) {
    print('score ${r.$1.toStringAsFixed(3)}  ${r.$2.grammar}');
    print('  orig  ${r.$2.original}');
    print('  input ${r.$2.mutant}');
    print('  want  ${r.$3.join(" ")}');
    print('  got   ${r.$4.join(" ")}\n');
  }
}
