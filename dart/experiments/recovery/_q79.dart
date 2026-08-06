// _q79.dart -- localize the `[2,33true]` mis-recovery by asking each rule
// directly, so the failure is attributed to a rule and not to the whole engine.
import 'package:squirrel_parser/squirrel_parser.dart';

import 'final_table.dart' show jsonGrammar;
import 'm79.dart' as e79;
import '_p79.dart' show render;

void main() {
  final rules = MetaGrammar.parseGrammar(jsonGrammar);
  for (final (top, s) in [
    ('Array', '[2,33true]'),
    ('Value', '[2,33true]'),
    ('JSON', '[2,33true]'),
    ('String', '[2,33true]'),
    ('Array', '[,2,]'),
    ('JSON', '[,2,]'),
  ]) {
    final e = e79.SuperDot3(rules: rules, topRuleName: top);
    final r = e.recover(s);
    print('${top.padRight(7)} "$s"  cost ${e.lastCost.toString().padLeft(3)}  '
        '${render(r, s)}');
  }
}
