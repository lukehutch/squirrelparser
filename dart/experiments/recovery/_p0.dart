import 'package:squirrel_parser/squirrel_parser.dart';
import 'astdiff.dart';
import 'm126.dart' as g;

void main() {
  final c = corpora.firstWhere((c) => c.name == 'json');
  final rules = MetaGrammar.parseGrammar(c.grammar);
  const cases = [
    '"a":1,"bc":[2,33,true],"d":{"e":null},"f":"gh"}',
    '"alpha":"beta gamma","delta":["epsilon","zeta"]}',
    '"{a":1,"bc":[2,33,true],"d":{"e":null},"f":"gh"}',
    '"{"a":1,"bc":[2,33,true],"d":{"e":null},"f":"gh"}',
    '{"a":1,"bc":[2,33,true],"d":{"e":null},"f":"gh"}',
  ];
  for (final s in cases) {
    final e = g.SuperDot3(rules: rules, topRuleName: c.top);
    final sw = Stopwatch()..start();
    final r = e.recover(s);
    sw.stop();
    print('${sw.elapsedMilliseconds.toString().padLeft(4)}ms  cost=${e.lastCost}'
        '  ${r == null ? "NULL" : "ok"}   $s');
  }
}
