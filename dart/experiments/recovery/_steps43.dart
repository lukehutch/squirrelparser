// Scratch: where does m43's extra time at K>=2 go? `lastSteps` counts _compute
// calls, so it separates "more states" from "more work per state".
import 'dart:math';
import 'package:squirrel_parser/squirrel_parser.dart';
import 'm42.dart' as g42;
import 'm43.dart' as g43;
import '_k43.dart' show jsonGrammar, doc, damage;

void main() {
  final rules = MetaGrammar.parseGrammar(jsonGrammar);
  final d = doc(16);
  print('K   m42 steps   m43 steps   ratio');
  for (final k in [1, 2, 4, 8]) {
    final s = damage(d, k);
    final e42 = g42.SuperDot3(rules: rules, topRuleName: 'JSON')..recoverCost(s);
    final e43 = g43.SuperDot3(rules: rules, topRuleName: 'JSON')..recoverCost(s);
    print('$k   ${e42.lastSteps}   ${e43.lastSteps}   '
        '${(e43.lastSteps / max(1, e42.lastSteps)).toStringAsFixed(2)}');
  }
}
