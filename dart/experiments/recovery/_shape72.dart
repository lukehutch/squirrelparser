// _shape72.dart -- the official table reads m72 at 513/519 shape against m71's
// 517/519, so I29's recorded reason picks a different witness on at least four
// of the 519 mutants and picks a WORSE one. The shape column asks whether the
// recovered tree has the same shape as the PRISTINE document's parse tree, so
// this finds the mutants where m71 matches and m72 does not, and prints all
// three trees -- original, m71, m72 -- so the difference can be read rather
// than guessed.
import 'package:squirrel_parser/squirrel_parser.dart';

import 'final_table.dart' show jsonGrammar, treeShape;
import '_bat71.dart' show makeBattery;
import 'm71.dart' as e71;
import 'm72.dart' as e72;

void main() {
  final rules = MetaGrammar.parseGrammar(jsonGrammar);
  const base = '{"a":1,"bc":[2,33,true],"d":{"e":null},"f":"gh"}';
  final orig = treeShape(
      Parser(rules: rules, topRuleName: 'JSON', input: base).parse().root);
  final battery = makeBattery(rules);
  final a = e71.SuperDot3(rules: rules, topRuleName: 'JSON');
  final b = e72.SuperDot3(rules: rules, topRuleName: 'JSON');
  var s71 = 0, s72 = 0, shown = 0;
  final lost = <String>[], won = <String>[];
  for (final s in battery) {
    final ra = treeShape(a.recover(s).root) == orig;
    final rb = treeShape(b.recover(s).root) == orig;
    if (ra) s71++;
    if (rb) s72++;
    if (ra && !rb) lost.add(s);
    if (!ra && rb) won.add(s);
  }
  print('battery=${battery.length}  m71 shape=$s71  m72 shape=$s72');
  print('m71 matches & m72 does not: ${lost.length}');
  print('m72 matches & m71 does not: ${won.length}');
  for (final s in lost) {
    if (shown++ >= 4) break;
    print('\n--- LOST: "$s"');
    print('  orig ${orig.substring(0, orig.length.clamp(0, 200))}');
    print('  m71  ${treeShape(a.recover(s).root)}');
    print('  m72  ${treeShape(b.recover(s).root)}');
  }
}
