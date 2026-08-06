// _wdrive3.dart -- the TWO-SIDED window. The frontier bounds the repair on the
// right (measured: 100% of sites are at or before it) but overshoots by a
// median of 13. The left edge must come from the other direction: the smallest
// q from which the REST of the document parses at cost 0 is where the healthy
// suffix begins, and that is what a right-to-left sweep computes.
//
// Measures, per case: the suffix anchor R, and how tightly [R, frontier]
// brackets the winning repair sites.
import 'package:squirrel_parser/squirrel_parser.dart';

import '_wprobe.dart';
import 'astdiff.dart';

String pct(List<num> xs, double q) {
  if (xs.isEmpty) return '-';
  final s = List<num>.of(xs)..sort();
  return s[((s.length - 1) * q).round()].toStringAsFixed(1);
}

void main() {
  final rulesOf = {
    for (final c in corpora) c.name: MetaGrammar.parseGrammar(c.grammar)
  };
  final seen = <String>{};
  final width = <num>[], slack = <num>[], noSuffix = <String>[];
  var n = 0, contained = 0;
  for (final k in weighted(buildBattery())) {
    if (!seen.add('${k.grammar}\x00${k.category}\x00${k.mutant}')) continue;
    if (n++ % 3 != 0) continue;
    final c = corpora.firstWhere((x) => x.name == k.grammar);
    final p = SuperDot3(rules: rulesOf[k.grammar]!, topRuleName: c.top);
    MatchResult? r;
    try {
      r = p.recover(k.mutant);
    } catch (_) {
      continue;
    }
    if (r == null) continue;
    final sites = <int>[];
    void walk(MatchResult m) {
      if (m is Filled || m is SyntaxError) sites.add(m.pos);
      m.subClauseMatches.forEach(walk);
    }

    walk(r);
    if (sites.isEmpty) continue;
    sites.sort();
    final s = k.mutant;
    // R = smallest q from which the remainder is a complete cost-0 parse.
    var rAnchor = s.length;
    for (var q = 0; q <= s.length; q++) {
      final t = s.substring(q);
      if (t.isEmpty) continue;
      final res =
          Parser(rules: rulesOf[k.grammar]!, topRuleName: c.top, input: t)
              .parse();
      if (!res.hasSyntaxErrors && res.root.len == t.length) {
        rAnchor = q;
        break;
      }
    }
    if (rAnchor == s.length) {
      noSuffix.add(k.category);
      continue;
    }
    final f = p.probeReach;
    width.add((f - rAnchor).abs() + 1);
    if (sites.first >= rAnchor - 1 && sites.last <= f) contained++;
    slack.add(sites.first - rAnchor);
  }
  print('${width.length} cases with a healthy suffix; '
      '${noSuffix.length} without');
  print('                        p50    p75    p90    p95    p99');
  for (final (l, xs) in [
    ('window [R..frontier]', width),
    ('firstSite - R', slack),
  ]) {
    print('${l.padRight(22)}${[0.5, 0.75, 0.9, 0.95, 0.99].map((q) => pct(xs, q).padLeft(7)).join()}');
  }
  print('');
  print('  all sites inside [R-1, frontier]: '
      '${(100 * contained / width.length).toStringAsFixed(1)}%');
  final byCat = <String, int>{};
  for (final c in noSuffix) {
    byCat[c] = (byCat[c] ?? 0) + 1;
  }
  final t = byCat.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
  print('  cases with NO healthy suffix, by category: '
      '${t.take(5).map((e) => '${e.key} ${e.value}').join(', ')}');
}
