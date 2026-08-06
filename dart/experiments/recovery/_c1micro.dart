import 'package:squirrel_parser/squirrel_parser.dart';

import 'c1.dart' as c1;
import 'astdiff.dart';

void main() {
  final g = corpora.firstWhere((x) => x.name == 'json');
  final gr = MetaGrammar.parseGrammar(g.grammar);
  final e = c1.Squirrel(rules: gr, topRuleName: g.top);
  const doc = '"a":1,"bc":[2,33,true],"d":{"e":null},"f":"gh"}';
  final sw = Stopwatch();
  final times = <int>[];
  for (var k = 0; k < 60; k++) {
    sw.reset();
    sw.start();
    e.recover(doc);
    sw.stop();
    times.add(sw.elapsedMicroseconds);
  }
  times.sort();
  print('median=${times[30]}us min=${times.first}us max=${times.last}us');
}
