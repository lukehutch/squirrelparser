// _p80.dart -- separate m80's FIXED per-instance cost (solving the witness
// fixed point, which every new engine does once) from its SEARCH cost. The
// battery builds a fresh engine per mutant, so a large fixed cost is paid 519
// times and would be invisible in the totals.
import 'package:squirrel_parser/squirrel_parser.dart';

import 'final_table.dart' show jsonGrammar;
import 'm80.dart' as e80;

double ms(int us) => us / 1000;

void main() {
  final rules = MetaGrammar.parseGrammar(jsonGrammar);

  // Warm the JIT on both paths first.
  for (var i = 0; i < 50; i++) {
    e80.SuperDot3(rules: rules, topRuleName: 'JSON').recover('1');
  }

  // Fixed cost: construct + recover the smallest possible valid document.
  var sw = Stopwatch()..start();
  for (var i = 0; i < 519; i++) {
    e80.SuperDot3(rules: rules, topRuleName: 'JSON').recover('1');
  }
  sw.stop();
  print('519 x (construct + parse "1")      ${ms(sw.elapsedMicroseconds)} ms'
      '   -> ${ms(sw.elapsedMicroseconds ~/ 519)} ms fixed per engine');

  // Same engine reused, so witnesses are solved once.
  final one = e80.SuperDot3(rules: rules, topRuleName: 'JSON');
  sw = Stopwatch()..start();
  for (var i = 0; i < 519; i++) {
    one.recover('1');
  }
  sw.stop();
  print('519 x parse "1" on ONE engine      ${ms(sw.elapsedMicroseconds)} ms');

  const base = '{"a":1,"bc":[2,33,true],"d":{"e":null},"f":"gh"}';
  sw = Stopwatch()..start();
  for (var i = 0; i < 100; i++) {
    e80.SuperDot3(rules: rules, topRuleName: 'JSON').recover(base);
  }
  sw.stop();
  print('100 x clean 47-char document       ${ms(sw.elapsedMicroseconds)} ms'
      '   -> ${ms(sw.elapsedMicroseconds ~/ 100)} ms each');

  for (final s in [
    '{"a":1,"bc":[2,33true],"d":{"e":null},"f":"gh"}',
    '[1,2,3',
    '[1,2',
    '[1',
  ]) {
    final sw2 = Stopwatch()..start();
    for (var i = 0; i < 20; i++) {
      e80.SuperDot3(rules: rules, topRuleName: 'JSON').recover(s);
    }
    sw2.stop();
    print('20 x "$s"'.padRight(35) +
        '${ms(sw2.elapsedMicroseconds)} ms   -> '
            '${ms(sw2.elapsedMicroseconds ~/ 20)} ms each');
  }
}
