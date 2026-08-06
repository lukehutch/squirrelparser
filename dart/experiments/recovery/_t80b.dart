// _t80b.dart -- m80 on DAMAGED input, timed per mutant, biggest first. The
// clean path is already known linear; this asks what repair costs.
import 'package:squirrel_parser/squirrel_parser.dart';

import 'final_table.dart' show jsonGrammar;
import 'm80.dart' as e80;

const base = '{"a":1,"bc":[2,33,true],"d":{"e":null},"f":"gh"}';

void main() {
  final rules = MetaGrammar.parseGrammar(jsonGrammar);
  final rows = <(int, int, String)>[];
  // Every single-character deletion: 47 mutants, all cost 1 or 2.
  for (var i = 0; i < base.length; i++) {
    final s = base.substring(0, i) + base.substring(i + 1);
    final e = e80.SuperDot3(rules: rules, topRuleName: 'JSON');
    final sw = Stopwatch()..start();
    e.recover(s);
    sw.stop();
    rows.add((sw.elapsedMicroseconds, e.lastCost, s));
  }
  rows.sort((a, b) => b.$1.compareTo(a.$1));
  var total = 0;
  for (final r in rows) {
    total += r.$1;
  }
  print('47 deletions, total ${total ~/ 1000} ms, worst first:');
  for (final r in rows.take(10)) {
    print('  ${(r.$1 / 1000).toStringAsFixed(1).padLeft(9)} ms  cost ${r.$2}  ${r.$3}');
  }
}
