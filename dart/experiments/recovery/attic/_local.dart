// _local.dart -- are CX2 and `[,2,` distinguishable by LOCAL facts?
//
// I54 is a local gate: at one position it sees only (need, minSkip, witness).
// If both cases present the SAME triple and want OPPOSITE answers, then no
// local gate can get both right, and the choice is necessarily global. That is
// the difference between "repair the prune" and "delete it", so it is worth
// measuring rather than arguing.
import 'package:squirrel_parser/squirrel_parser.dart';

import 'final_table.dart' show buildSetup;
import '_m113dbg.dart' as dbg;

const base = '{"a":1,"bc":[2,33,true],"d":{"e":null},"f":"gh"}';
const cx2 = "S <- A 'x' 'a';\nA <- [ab];\n";

void probe(String title, Map<String, Clause> rules, String top, String input,
    int want) {
  print('$title   input=$input   the contested site is pos=$want');
  final e = dbg.SuperDot3(rules: rules, topRuleName: top);
  dbg.probe = true;
  final seen = <String>[];
  dbg.sink = (line) {
    if (line.contains('pos=$want ')) seen.add(line);
  };
  e.recoverCost(input);
  dbg.probe = false;
  dbg.sink = null;
  for (final l in seen.toSet()) {
    print('  $l');
  }
  print('');
}

void main() {
  probe('CX2  (fill is RIGHT here)', MetaGrammar.parseGrammar(cx2), 'S', 'xa', 0);
  probe('BRIEF 2  (fill is WRONG here)', buildSetup().$1, 'JSON',
      base.replaceFirst('[2,33,true]', '[,2,33,true]'), 13);
}
