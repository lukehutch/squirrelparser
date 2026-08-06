// _ab80.dart -- isolate ONE change: does asking the pure table first inside
// `_first` actually pay, and by how much? Same file, same budget schedule, the
// only difference is whether a non-chosen alternative is explored at the full
// budget before a later free one is found.
import 'package:squirrel_parser/squirrel_parser.dart';

import 'final_table.dart' show jsonGrammar;
import 'm80.dart' as pureFirst;
import '_m80f.dart' as fullScan;

const base = '{"a":1,"bc":[2,33,true],"d":{"e":null},"f":"gh"}';

List<String> battery(Map<String, Clause> rules) {
  bool parses(String s) => !Parser(rules: rules, topRuleName: 'JSON', input: s)
      .parse()
      .hasSyntaxErrors;
  final m = <String>[];
  for (var j = 0; j < base.length; j++) {
    m.add(base.substring(0, j) + base.substring(j + 1));
    if (j + 1 < base.length && base[j] != base[j + 1]) {
      m.add(base.substring(0, j) + base[j + 1] + base[j] + base.substring(j + 2));
    }
  }
  for (var j = 0; j <= base.length; j++) {
    for (final c in ['Q', 'z', '}', '"', ',', '5']) {
      m.add(base.substring(0, j) + c + base.substring(j));
      if (j < base.length && base[j] != c) {
        m.add(base.substring(0, j) + c + base.substring(j + 1));
      }
    }
  }
  return m.where((x) => !parses(x)).toList();
}

void main() {
  final rules = MetaGrammar.parseGrammar(jsonGrammar);
  final b = battery(rules);
  print('battery n=${b.length}');
  for (final (name, run) in [
    ('pure-first  (m80)', (String s) {
      final e = pureFirst.SuperDot3(rules: rules, topRuleName: 'JSON');
      e.recover(s);
      return e.lastCost;
    }),
    ('full-scan   (old)', (String s) {
      final e = fullScan.SuperDot3(rules: rules, topRuleName: 'JSON');
      e.recover(s);
      return e.lastCost;
    }),
  ]) {
    var costSum = 0;
    final sw = Stopwatch()..start();
    for (final s in b) {
      costSum += run(s);
    }
    sw.stop();
    print('$name  ${(sw.elapsedMilliseconds).toString().padLeft(6)} ms   '
        'cost sum $costSum');
  }
}
