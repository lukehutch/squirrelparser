// _work72.dart -- is m72's latency gap MORE work, or the same work done slower?
//
// Timing ratios for m72/m71 came out anywhere from 1.05 to 1.13 depending on
// which harness ran them, so the clock cannot settle a 5% question here. Steps
// and cells can: they are exact counts of the search's own work, identical run
// to run. If m72 takes the same steps over the same cells, the gap is per-step
// cost -- layout, not algorithm.
import 'package:squirrel_parser/squirrel_parser.dart';

import 'final_table.dart' show jsonGrammar;
import '_lat72.dart' show latCases;
import 'm71.dart' as e71;
import 'm72.dart' as e72;

void main() {
  final rules = MetaGrammar.parseGrammar(jsonGrammar);
  final cases = latCases();
  print('case  len       steps71       steps72   ratio    cells71   cells72');
  var s1 = 0, s2 = 0, c1 = 0, c2 = 0;
  for (var i = 0; i < cases.length; i++) {
    final a = e71.SuperDot3(rules: rules, topRuleName: 'JSON');
    final b = e72.SuperDot3(rules: rules, topRuleName: 'JSON');
    a.recoverCost(cases[i]);
    b.recoverCost(cases[i]);
    s1 += a.lastSteps;
    s2 += b.lastSteps;
    c1 += a.lastCells;
    c2 += b.lastCells;
    print('${i.toString().padLeft(4)} ${cases[i].length.toString().padLeft(4)} '
        '${a.lastSteps.toString().padLeft(13)} '
        '${b.lastSteps.toString().padLeft(13)} '
        '${(b.lastSteps / (a.lastSteps == 0 ? 1 : a.lastSteps)).toStringAsFixed(3).padLeft(7)} '
        '${a.lastCells.toString().padLeft(10)} ${b.lastCells.toString().padLeft(9)}');
  }
  print('');
  print('TOTAL steps m71=$s1  m72=$s2   ratio=${(s2 / s1).toStringAsFixed(4)}');
  print('TOTAL cells m71=$c1  m72=$c2   ratio=${(c2 / c1).toStringAsFixed(4)}');
}
