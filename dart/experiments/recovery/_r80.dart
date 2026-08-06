// _r80.dart -- where does m80's time actually go? Time every mutant and group
// by the cost it settled at, so the answer distinguishes "each round is
// expensive" from "there are too many rounds".
import 'package:squirrel_parser/squirrel_parser.dart';

import 'final_table.dart' show jsonGrammar;
import 'm80.dart' as e80;

const base = '{"a":1,"bc":[2,33,true],"d":{"e":null},"f":"gh"}';

List<String> buildBattery(Map<String, Clause> rules) {
  bool parses(String s) => !Parser(rules: rules, topRuleName: 'JSON', input: s)
      .parse()
      .hasSyntaxErrors;
  final mutants = <String>[];
  for (var j = 0; j < base.length; j++) {
    mutants.add(base.substring(0, j) + base.substring(j + 1));
    if (j + 1 < base.length && base[j] != base[j + 1]) {
      mutants.add(
          base.substring(0, j) + base[j + 1] + base[j] + base.substring(j + 2));
    }
  }
  for (var j = 0; j <= base.length; j++) {
    for (final c in ['Q', 'z', '}', '"', ',', '5']) {
      mutants.add(base.substring(0, j) + c + base.substring(j));
      if (j < base.length && base[j] != c) {
        mutants.add(base.substring(0, j) + c + base.substring(j + 1));
      }
    }
  }
  return mutants.where((m) => !parses(m)).toList();
}

void main() {
  final rules = MetaGrammar.parseGrammar(jsonGrammar);
  final battery = buildBattery(rules);
  final byCost = <int, List<int>>{};
  final rows = <(int, int, String)>[];
  for (final s in battery) {
    final e = e80.SuperDot3(rules: rules, topRuleName: 'JSON');
    final sw = Stopwatch()..start();
    e.recover(s);
    sw.stop();
    byCost.putIfAbsent(e.lastCost, () => []).add(sw.elapsedMicroseconds);
    rows.add((sw.elapsedMicroseconds, e.lastCost, s));
  }
  print('cost   n    total ms   mean ms    max ms');
  final costs = byCost.keys.toList()..sort();
  for (final c in costs) {
    final v = byCost[c]!;
    var tot = 0, mx = 0;
    for (final x in v) {
      tot += x;
      if (x > mx) mx = x;
    }
    print('${c.toString().padLeft(4)} ${v.length.toString().padLeft(4)} '
        '${(tot / 1000).toStringAsFixed(1).padLeft(11)} '
        '${(tot / v.length / 1000).toStringAsFixed(2).padLeft(9)} '
        '${(mx / 1000).toStringAsFixed(1).padLeft(9)}');
  }
  rows.sort((a, b) => b.$1.compareTo(a.$1));
  print('\nworst 8:');
  for (final r in rows.take(8)) {
    print('  ${(r.$1 / 1000).toStringAsFixed(1).padLeft(8)} ms  cost ${r.$2}  '
        '${r.$3}');
  }
}
