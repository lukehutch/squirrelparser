// _wdrive5.dart -- the true total work of m132, against what a LEFT-GROWING
// window over a right-to-left chart would cost.
//
// The eager chart lost on latency because it filled every position (11x in
// dart/lib's semiring_recovery, 14x for m51's bottom-up agenda). The windowed
// hybrid only fills positions between the failure frontier and a left edge that
// GROWS until the bridge closes -- median 13 positions, measured, versus the
// ~35 an input is long.
//
// So the comparison that decides it is:
//     m132 total memo-cell bodies      vs      |window| x |grammar|
// where |grammar| is the number of distinct clause nodes, because a chart fills
// every clause at every position it touches whereas top-down descent only
// reaches the clauses some parent demands.
import 'package:squirrel_parser/squirrel_parser.dart';

import '_wprobe.dart';
import 'astdiff.dart';

String pct(List<num> xs, double q) {
  final s = List<num>.of(xs)..sort();
  return s[((s.length - 1) * q).round()].toStringAsFixed(1);
}

/// Distinct clause nodes reachable from a rule set -- the height of a chart
/// column.
int grammarSize(Map<String, Clause> rules) {
  final seen = <Clause>{};
  void walk(Clause c) {
    if (!seen.add(c)) return;
    if (c is HasMultipleSubClauses) c.subClauses.forEach(walk);
    if (c is HasOneSubClause) walk(c.subClause);
    if (c is Ref) {
      final t = rules[c.ruleName];
      if (t != null) walk(t);
    }
  }

  rules.values.forEach(walk);
  return seen.length;
}

void main() {
  final rulesOf = {
    for (final c in corpora) c.name: MetaGrammar.parseGrammar(c.grammar)
  };
  final gsize = {for (final e in rulesOf.entries) e.key: grammarSize(e.value)};
  for (final e in gsize.entries) {
    print('  grammar ${e.key.padRight(10)} ${e.value} distinct clause nodes');
  }
  print('');

  final seen = <String>{};
  final body = <num>[], cellsAll = <num>[], lens = <num>[], relax = <num>[];
  final colEq = <num>[]; // m132 cells expressed as chart COLUMNS of |G|
  for (final k in weighted(buildBattery())) {
    if (!seen.add('${k.grammar}\x00${k.category}\x00${k.mutant}')) continue;
    final p = SuperDot3(
        rules: rulesOf[k.grammar]!,
        topRuleName: corpora.firstWhere((c) => c.name == k.grammar).top);
    try {
      p.recover(k.mutant);
    } catch (_) {
      continue;
    }
    if (p.probeAll.isEmpty) continue;
    body.add(p.probeBody);
    cellsAll.add(p.probeAll.length);
    relax.add(p.probeBody / p.probeAll.length);
    lens.add(k.mutant.length);
    colEq.add(p.probeBody / gsize[k.grammar]!);
  }

  print('${body.length} distinct cases');
  print('                          p50    p75    p90    p95    p99    max');
  for (final (l, xs) in [
    ('input length', lens),
    ('TOTAL cell bodies', body),
    ('distinct cells', cellsAll),
    ('relaxations/cell', relax),
    ('= chart columns of |G|', colEq),
  ]) {
    print('${l.padRight(24)}'
        '${[0.5, 0.75, 0.9, 0.95, 0.99, 1.0].map((q) => pct(xs, q).padLeft(7)).join()}');
  }
  print('');
  print('  A right-to-left chart pays |G| cells per column it fills.');
  print('  m132 already costs the equivalent of ${pct(colEq, 0.5)} full columns '
      '(p50), ${pct(colEq, 0.9)} (p90).');
  print('  A window has to close the bridge inside that many columns to win.');
}
