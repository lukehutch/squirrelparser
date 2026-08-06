import 'package:squirrel_parser/squirrel_parser.dart';

import 'astdiff.dart';
import '_codexr4_profile_fast_engine.dart' as prof;

void add(Map<String, int> out, String key, int value) {
  out[key] = (out[key] ?? 0) + value;
}

void printMap(String title, Map<String, int> values, int total) {
  final rows = values.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  print('\n$title');
  for (final row in rows) {
    print('${row.key.padRight(22)} ${row.value.toString().padLeft(10)} '
        '${(row.value * 100 / total).toStringAsFixed(1).padLeft(6)}%');
  }
}

void main() {
  final cases = weighted(buildBattery());
  final rules = <String, Map<String, Clause>>{
    for (final c in corpora) c.name: MetaGrammar.parseGrammar(c.grammar)
  };
  final engines = <String, prof.Squirrel>{
    for (final c in corpora)
      c.name: prof.Squirrel(rules: rules[c.name]!, topRuleName: c.top)
  };
  final byGrammar = <String, int>{};
  final byCategory = <String, int>{};
  final byCost = <String, int>{};
  final caseCountByCost = <String, int>{};
  for (final c in cases) {
    final engine = engines[c.grammar]!;
    final before = engine.lookups;
    engine.recover(c.mutant);
    final used = engine.lookups - before;
    add(byGrammar, c.grammar, used);
    add(byCategory, c.category, used);
    add(byCost, '${engine.lastCost}', used);
    add(caseCountByCost, '${engine.lastCost}', 1);
  }

  var total = 0, expansions = 0, hits = 0, path = 0;
  final bySite = <String, int>{};
  final byClause = <String, int>{};
  final byBudget = <String, int>{};
  for (final engine in engines.values) {
    total += engine.lookups;
    expansions += engine.expansions;
    hits += engine.memoHits;
    path += engine.pathHits;
    for (final e in engine.lookupsBySite.entries) add(bySite, e.key, e.value);
    for (final e in engine.lookupsByClause.entries) add(byClause, e.key, e.value);
    for (final e in engine.lookupsByBudget.entries) {
      add(byBudget, '${e.key}', e.value);
    }
  }
  print('cases=${cases.length} lookups=$total expansions=$expansions '
      'memoHits=$hits pathHits=$path lookups/expansion='
      '${(total / expansions).toStringAsFixed(2)}');
  final siteTotal = bySite.values.fold(0, (a, b) => a + b);
  printMap('call site (all _ways calls)', bySite, siteTotal);
  printMap('clause kind', byClause, total);
  printMap('grammar', byGrammar, total);
  printMap('damage category', byCategory, total);
  printMap('residual budget', byBudget, total);
  printMap('answer cost (lookup share)', byCost, total);
  print('\nanswer cost (case count): $caseCountByCost');
}
