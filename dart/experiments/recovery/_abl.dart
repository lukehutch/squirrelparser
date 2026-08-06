// _abl.dart -- ablation timing. Same battery, same schedule; each variant has
// exactly one mechanism removed, so the difference IS that mechanism's cost.
import 'package:squirrel_parser/squirrel_parser.dart';

import 'final_table.dart' show jsonGrammar;
import 'm80.dart' as base;
import '_x1.dart' as noTree;
import '_x2.dart' as noFill;

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
  for (final (name, run) in [
    ('m80 (baseline)  ', (String s) => base.SuperDot3(rules: rules, topRuleName: 'JSON').recoverCost(s)),
    ('  - tree nodes  ', (String s) => noTree.SuperDot3(rules: rules, topRuleName: 'JSON').recoverCost(s)),
    ('  - FILL        ', (String s) => noFill.SuperDot3(rules: rules, topRuleName: 'JSON').recoverCost(s)),
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
