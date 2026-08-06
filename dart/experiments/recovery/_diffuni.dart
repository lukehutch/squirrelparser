// Scratch: exactly which battery cases separate r9 from a variant, and by how
// much. Scoring is the official path so the deltas compose back to the
// published aggregate.
//
//   dart run _diffuni.dart <variant> [howMany]

import 'package:squirrel_parser/squirrel_parser.dart';
import 'astdiff.dart';
import '_xscore.dart' show resolve;

void main(List<String> argv) {
  final other = argv.isNotEmpty ? argv[0] : 'uni';
  final show = argv.length > 1 ? int.parse(argv[1]) : 20;

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
  final ba = resolve('r9')!, bb = resolve(other)!;
  final ea = {for (final c in corpora) c.name: ba(rulesOf[c.name]!, c.top)};
  final eb = {for (final c in corpora) c.name: bb(rulesOf[c.name]!, c.top)};

  MatchResult? run(Map<String, MatchResult? Function(String)> e, Case k) {
    try {
      return e[k.grammar]!(k.mutant);
    } catch (_) {
      return null;
    }
  }

  final rows = <(double, Case, String, String)>[];
  var up = 0.0, down = 0.0;
  for (final k in cases) {
    final c = byCorpus[k.grammar]!;
    final exp = expectedFor(k, original['${k.grammar} ${k.original}']!, c.named);
    final pa = run(ea, k), pb = run(eb, k);
    final sa = scoreCase(
        produced: pa, expected: exp, inputLen: k.mutant.length, named: c.named);
    final sb = scoreCase(
        produced: pb, expected: exp, inputLen: k.mutant.length, named: c.named);
    final d = sb.score - sa.score;
    if (d.abs() < 1e-9) continue;
    if (d > 0) {
      up += d;
    } else {
      down += -d;
    }
    rows.add((
      d,
      k,
      pa == null ? '<null>' : skeleton(pa, c.named).join(' '),
      pb == null ? '<null>' : skeleton(pb, c.named).join(' ')
    ));
  }
  rows.sort((x, y) => x.$1.compareTo(y.$1));
  print('$other vs r9: ${rows.length} cases differ; '
      '$other gains ${up.toStringAsFixed(3)}, loses ${down.toStringAsFixed(3)}, '
      'net ${(up - down).toStringAsFixed(3)} over ${cases.length} cases\n');
  void dump(Iterable<(double, Case, String, String)> rs) {
    for (final r in rs) {
      print('${r.$1.toStringAsFixed(3).padLeft(7)}  '
          '${r.$2.category.padRight(15)}${r.$2.grammar.padRight(7)}'
          '${r.$2.mutant.length.toString().padLeft(3)}c  '
          '${r.$2.mutant.replaceAll('\n', ' ')}');
      print('           r9 : ${r.$3}');
      print('           $other: ${r.$4}');
    }
  }

  print('=== worst for $other');
  dump(rows.take(show));
  print('\n=== best for $other');
  dump(rows.reversed.take(show ~/ 2));
}
