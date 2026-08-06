// _recon72.dart -- the step counter cannot see the witness build.
//
// _work72 says m71 and m72 take the same steps over the same cells, so the
// latency gap is not the search. But `_steps` counts only the search, and under
// I28 `recoverCost` also RECONSTRUCTS -- and m72's `_build` asks the oracle at
// every node it visits, through `_wholesale`, where m71's does not. This times
// the reconstruction alone, on both engines, over the latency corpus.
import 'package:squirrel_parser/squirrel_parser.dart';

import 'final_table.dart' show jsonGrammar;
import '_lat72.dart' show latCases;
import '_m71t.dart' as e71;
import '_m72t.dart' as e72;

void main() {
  final rules = MetaGrammar.parseGrammar(jsonGrammar);
  final cases = latCases();
  for (final s in cases) {
    e71.SuperDot3(rules: rules, topRuleName: 'JSON').recoverCost(s);
    e72.SuperDot3(rules: rules, topRuleName: 'JSON').recoverCost(s);
  }
  for (var rep = 0; rep < 3; rep++) {
    e71.SuperDot3.reconUs = 0;
    e72.SuperDot3.reconUs = 0;
    final t1 = Stopwatch()..start();
    for (final s in cases) {
      e71.SuperDot3(rules: rules, topRuleName: 'JSON').recoverCost(s);
    }
    t1.stop();
    final t2 = Stopwatch()..start();
    for (final s in cases) {
      e72.SuperDot3(rules: rules, topRuleName: 'JSON').recoverCost(s);
    }
    t2.stop();
    final r1 = e71.SuperDot3.reconUs / 1000, r2 = e72.SuperDot3.reconUs / 1000;
    final w1 = t1.elapsedMicroseconds / 1000, w2 = t2.elapsedMicroseconds / 1000;
    print('rep $rep');
    print('  m71  total ${w1.toStringAsFixed(1)} ms   rebuild ${r1.toStringAsFixed(1)} ms'
        '   search ${(w1 - r1).toStringAsFixed(1)} ms');
    print('  m72  total ${w2.toStringAsFixed(1)} ms   rebuild ${r2.toStringAsFixed(1)} ms'
        '   search ${(w2 - r2).toStringAsFixed(1)} ms');
    print('  rebuild m72/m71 = ${(r2 / r1).toStringAsFixed(2)}'
        '   search m72/m71 = ${((w2 - r2) / (w1 - r1)).toStringAsFixed(3)}');
  }
}
