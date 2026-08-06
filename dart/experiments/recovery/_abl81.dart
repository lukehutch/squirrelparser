// _abl.dart -- ablation timing. Same battery, same schedule; each variant has
// exactly one mechanism removed, so the difference IS that mechanism's cost.
import 'package:squirrel_parser/squirrel_parser.dart';

import 'final_table.dart' show jsonGrammar;
import 'm81.dart' as base;
import '_x1.dart' as noTree;
import '_x2.dart' as noFill;
import '_x3.dart' as noDeepen;

const doc = '{"a":1,"bc":[2,33,true],"d":{"e":null},"f":"gh"}';

List<String> battery(Map<String, Clause> rules) {
  bool parses(String s) => !Parser(rules: rules, topRuleName: 'JSON', input: s)
      .parse()
      .hasSyntaxErrors;
  final m = <String>[];
  for (var j = 0; j < doc.length; j++) {
    m.add(doc.substring(0, j) + doc.substring(j + 1));
    if (j + 1 < doc.length && doc[j] != doc[j + 1]) {
      m.add(doc.substring(0, j) + doc[j + 1] + doc[j] + doc.substring(j + 2));
    }
  }
  for (var j = 0; j <= doc.length; j++) {
    for (final c in ['Q', 'z', '}', '"', ',', '5']) {
      m.add(doc.substring(0, j) + c + doc.substring(j));
      if (j < doc.length && doc[j] != c) {
        m.add(doc.substring(0, j) + c + doc.substring(j + 1));
      }
    }
  }
  return m.where((x) => !parses(x)).toList();
}

void main() {
  final rules = MetaGrammar.parseGrammar(jsonGrammar);
  final b = battery(rules);
  print('battery n=${b.length}');
  // The oracle for the no-deepening ablation: the cost each mutant actually
  // settles at, found by a normal run first, so the ablated run starts at the
  // round that succeeds and every earlier round is skipped.
  final oracle = {
    for (final m in b)
      m: base.SuperDot3(rules: rules, topRuleName: 'JSON').recoverCost(m)
  };
  for (final (name, run) in [
    ('m81 (baseline)  ', (String s) => base.SuperDot3(rules: rules, topRuleName: 'JSON').recoverCost(s)),
    ('  - tree nodes  ', (String s) => noTree.SuperDot3(rules: rules, topRuleName: 'JSON').recoverCost(s)),
    ('  - FILL        ', (String s) => noFill.SuperDot3(rules: rules, topRuleName: 'JSON').recoverCost(s)),
    ('  - deepening   ', (String s) {
      noDeepen.startBudget = oracle[s] ?? 0;
      final r = noDeepen.SuperDot3(rules: rules, topRuleName: 'JSON').recoverCost(s);
      noDeepen.startBudget = 0;
      return r;
    }),
  ]) {
    run(doc); // warm
    var sum = 0;
    final sw = Stopwatch()..start();
    for (final m in b) {
      sum += run(m);
    }
    sw.stop();
    print('$name  ${sw.elapsedMilliseconds} ms   cost sum $sum');
  }
}
