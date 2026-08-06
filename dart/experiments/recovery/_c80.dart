// _c80.dart -- WHERE does a budget-1 round go? Count derivation steps per round
// instead of guessing from wall time.
import 'package:squirrel_parser/squirrel_parser.dart';

import 'final_table.dart' show jsonGrammar;
import '_m80i.dart' as e;

const base = '{"a":1,"bc":[2,33,true],"d":{"e":null},"f":"gh"}';

void main() {
  final rules = MetaGrammar.parseGrammar(jsonGrammar);
  for (final s in [
    base,
    '{"a":1,"bc":[2,33true],"d":{"e":null},"f":"gh"}',
    '[1,2,3]',
    '[1,2,3',
  ]) {
    final eng = e.SuperDot3(rules: rules, topRuleName: 'JSON');
    e.resetCounters();
    final sw = Stopwatch()..start();
    eng.recover(s);
    sw.stop();
    print('cost ${eng.lastCost.toString().padLeft(2)}  '
        '${(sw.elapsedMicroseconds / 1000).toStringAsFixed(2).padLeft(7)} ms  '
        'expand ${e.cExpand.toString().padLeft(7)}  '
        'put ${e.cPut.toString().padLeft(8)}   $s');
    final keys = e.cFam.keys.toList()..sort();
    for (final k in keys) {
      print('      $k  expands ${e.cFam[k].toString().padLeft(6)}  '
          'distinct cells ${e.cCells[k]!.length.toString().padLeft(6)}');
    }
  }
}
