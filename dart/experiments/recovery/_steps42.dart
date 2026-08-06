// Scratch: where does m42's extra time at K>=2 go? `lastSteps` counts _compute
// calls, so it separates "more states" from "more work per state".
import 'dart:math';
import 'package:squirrel_parser/squirrel_parser.dart';
import 'm41.dart' as g41;
import 'm42.dart' as g42;
import '_k42.dart' show jsonGrammar, doc, damage;

void main() {
  final rules = MetaGrammar.parseGrammar(jsonGrammar);
  final d = doc(16);
  print('K   m41 steps   m42 steps   ratio');
  for (final k in [1, 2, 4, 8]) {
    final s = damage(d, k);
    final e41 = g41.SuperDot3(rules: rules, topRuleName: 'JSON')..recoverCost(s);
    final e42 = g42.SuperDot3(rules: rules, topRuleName: 'JSON')..recoverCost(s);
    print('$k   ${e41.lastSteps}   ${e42.lastSteps}   '
        '${(e42.lastSteps / max(1, e41.lastSteps)).toStringAsFixed(2)}');
  }
}
