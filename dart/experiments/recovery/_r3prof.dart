import 'package:squirrel_parser/squirrel_parser.dart';
import 'astdiff.dart';
import '_r3prof_engine.dart' as r3;

void main() {
  for (final name in ['json', 'stmt']) {
    final c = corpora.firstWhere((x) => x.name == name);
    final rules = MetaGrammar.parseGrammar(c.grammar);
    final doc = c.documents.reduce((a, b) => a.length > b.length ? a : b);
    final e = r3.Squirrel(rules: rules, topRuleName: c.top);
    final sw = Stopwatch()..start();
    e.recover(doc);
    sw.stop();
    print('$name len=${doc.length} ${sw.elapsedMilliseconds}ms '
        'expands=${e.nExpand} ways=${e.nWay} maxWaysInCell=${e.maxWays}');
    // way-count histogram over cells
    final hist = <int, int>{};
    e.cellSizes().forEach((n) => hist[n] = (hist[n] ?? 0) + 1);
    final ks = hist.keys.toList()..sort();
    print('  cells by way-count: ${[for (final k in ks) '$k:${hist[k]}'].join(' ')}');
  }
}
