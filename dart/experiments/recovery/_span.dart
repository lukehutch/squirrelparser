// _span.dart -- how far apart are the edit sites of a winning repair?
//
// The hybrid design confines the repair search to a WINDOW grown from the
// top-down failure point. That is only worth building if real repairs are
// local: if the sites of the winning repair span most of the document, the
// window is the whole input and the hybrid buys nothing.
//
// Reports, over every distinct battery case: how many repair marks the winning
// tree carries, how wide a window would have had to be to contain them all
// (last site - first site + 1), and that width as a fraction of the input.
//
// Usage: dart run _span.dart [engine]
import 'package:squirrel_parser/squirrel_parser.dart';

import '_score1.dart' show resolve;
import 'astdiff.dart';
import 'm132.dart' as m132;

/// Positions carrying a repair mark, in input coordinates.
List<int> sites(MatchResult m) {
  final out = <int>[];
  void walk(MatchResult k) {
    if (k is m132.Filled || k is SyntaxError) out.add(k.pos);
    k.subClauseMatches.forEach(walk);
  }

  walk(m);
  return out;
}

String pct(List<num> xs, double q) {
  if (xs.isEmpty) return '-';
  final s = List<num>.of(xs)..sort();
  return s[((s.length - 1) * q).round()].toStringAsFixed(1);
}

void main(List<String> argv) {
  final name = argv.isEmpty ? 'm132' : argv[0];
  final b = resolve(name)!;
  final rulesOf = {
    for (final c in corpora) c.name: MetaGrammar.parseGrammar(c.grammar)
  };
  final made = {for (final c in corpora) c.name: b(rulesOf[c.name]!, c.top)};

  final seen = <String>{};
  final widths = <int>[], counts = <int>[], fracs = <double>[], lens = <int>[];
  var none = 0;
  for (final k in weighted(buildBattery())) {
    if (!seen.add('${k.grammar}\x00${k.category}\x00${k.mutant}')) continue;
    MatchResult? p;
    try {
      p = made[k.grammar]!(k.mutant);
    } catch (_) {
      continue;
    }
    if (p == null) continue;
    final s = sites(p);
    if (s.isEmpty) {
      none++;
      continue;
    }
    s.sort();
    final w = s.last - s.first + 1;
    widths.add(w);
    counts.add(s.length);
    lens.add(k.mutant.length);
    fracs.add(k.mutant.isEmpty ? 0 : w / k.mutant.length);
  }

  print('$name over ${widths.length} repaired cases ($none with no marks)');
  print('');
  print('               p50    p75    p90    p95    p99    max');
  for (final (label, xs) in [
    ('input length', lens.map((e) => e as num).toList()),
    ('repair marks', counts.map((e) => e as num).toList()),
    ('window width', widths.map((e) => e as num).toList()),
    ('width/length', fracs.map((e) => e as num).toList()),
  ]) {
    print('${label.padRight(14)}${[0.5, 0.75, 0.9, 0.95, 0.99, 1.0].map((q) => pct(xs, q).padLeft(7)).join()}');
  }

  print('');
  for (final w in [1, 2, 4, 8, 16, 32, 64]) {
    final n = widths.where((x) => x <= w).length;
    print('  window <= ${w.toString().padLeft(2)} chars covers '
        '${(100 * n / widths.length).toStringAsFixed(1)}% of repairs');
  }
}
