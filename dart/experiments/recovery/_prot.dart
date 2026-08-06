// _prot.dart -- the SAME battery under the two protocols, so the per-engine
// fixed cost is separated from the search. final_table's battery arm builds ONE
// engine and reuses it; _s80 built a fresh one per mutant.
import 'package:squirrel_parser/squirrel_parser.dart';

import 'final_table.dart' show jsonGrammar;
import 'm80.dart' as e80;

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

  e80.SuperDot3(rules: rules, topRuleName: 'JSON').recover(doc); // warm

  var sw = Stopwatch()..start();
  for (final m in b) {
    e80.SuperDot3(rules: rules, topRuleName: 'JSON').recoverCost(m);
  }
  sw.stop();
  print('fresh engine per mutant   ${sw.elapsedMilliseconds} ms');

  final one = e80.SuperDot3(rules: rules, topRuleName: 'JSON');
  sw = Stopwatch()..start();
  for (final m in b) {
    one.recoverCost(m);
  }
  sw.stop();
  print('ONE engine reused         ${sw.elapsedMilliseconds} ms   '
      '<- final_table protocol');
}
