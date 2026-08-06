// _wdrive2.dart -- is the top-down failure frontier a sound ANCHOR for the
// repair window? Measures |winning repair site - frontier| over the battery.
// If the winning repair sits far from the frontier, a window grown from the
// frontier is the wrong construction.
import 'package:squirrel_parser/squirrel_parser.dart';

import '_wprobe.dart';
import 'astdiff.dart';

String pct(List<num> xs, double q) {
  final s = List<num>.of(xs)..sort();
  return s[((s.length - 1) * q).round()].toStringAsFixed(1);
}

void main() {
  final rulesOf = {
    for (final c in corpora) c.name: MetaGrammar.parseGrammar(c.grammar)
  };
  final seen = <String>{};
  final dFirst = <num>[], dAll = <num>[], need = <num>[];
  for (final k in weighted(buildBattery())) {
    if (!seen.add('${k.grammar}\x00${k.category}\x00${k.mutant}')) continue;
    final p = SuperDot3(
        rules: rulesOf[k.grammar]!,
        topRuleName: corpora.firstWhere((c) => c.name == k.grammar).top);
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
    final f = p.probeReach;
    dFirst.add(sites.first - f);
    for (final s in sites) {
      dAll.add(s - f);
    }
    // half-width of a window centred on the frontier that contains every site
    need.add([
      (sites.first - f).abs(),
      (sites.last - f).abs()
    ].reduce((a, b) => a > b ? a : b));
  }
  print('${need.length} cases');
  print('                         p2    p10    p25    p50    p75    p90    p98');
  for (final (l, xs) in [
    ('|first site - front|', dFirst),
    ('|any site - frontier|', dAll),
    ('window half-width', need),
  ]) {
    print('${l.padRight(23)}${[0.02, 0.1, 0.25, 0.5, 0.75, 0.9, 0.98].map((q) => pct(xs, q).padLeft(7)).join()}');
  }
  print('');
  final before = dAll.where((x) => x < 0).length;
  final at = dAll.where((x) => x == 0).length;
  print('');
  print('  sites BEFORE the frontier: ${(100 * before / dAll.length).toStringAsFixed(1)}%'
      '   AT it: ${(100 * at / dAll.length).toStringAsFixed(1)}%'
      '   AFTER: ${(100 * (dAll.length - before - at) / dAll.length).toStringAsFixed(1)}%');
  for (final w in [0, 1, 2, 4, 8, 16, 32]) {
    final n = need.where((x) => x <= w).length;
    print('  half-width ${w.toString().padLeft(2)} contains ALL sites in '
        '${(100 * n / need.length).toStringAsFixed(1)}% of cases');
  }
}
