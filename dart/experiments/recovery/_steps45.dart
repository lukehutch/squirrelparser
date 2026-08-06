// Scratch: where does m45's extra time at K>=2 go? `lastSteps` counts _compute
// calls, so it separates "more states" from "more work per state".
import 'dart:math';
import 'package:squirrel_parser/squirrel_parser.dart';
import 'm44.dart' as g44;
import 'm45.dart' as g45;
import '_k45.dart' show jsonGrammar, doc, damage;

void main() {
  final rules = MetaGrammar.parseGrammar(jsonGrammar);
  final d = doc(16);
  print('K   m44 steps   m45 steps   ratio');
  for (final k in [1, 2, 4, 8]) {
    final s = damage(d, k);
    final e43 = g44.SuperDot3(rules: rules, topRuleName: 'JSON')..recoverCost(s);
    final e44 = g45.SuperDot3(rules: rules, topRuleName: 'JSON')..recoverCost(s);
    print('$k   ${e43.lastSteps}   ${e44.lastSteps}   '
        '${(e44.lastSteps / max(1, e43.lastSteps)).toStringAsFixed(2)}');
  }
}
