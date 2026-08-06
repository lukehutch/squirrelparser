// The tree r9 actually emits for the swallow, so the reading is read rather
// than guessed.
import 'package:squirrel_parser/squirrel_parser.dart';

import 'astdiff.dart';
import 'r9.dart' as r9;

void main(List<String> argv) {
  final name = argv.isEmpty ? 'stmt' : argv[0];
  final c = corpora.firstWhere((k) => k.name == name);
  final rules = MetaGrammar.parseGrammar(c.grammar);
  final eng = r9.Squirrel(rules: rules, topRuleName: c.top);
  for (final s in argv.length > 1
      ? argv.sublist(1)
      : ['x=1; "f (x) { y0=0; y1=1; }']) {
    final t = eng.recover(s);
    print('======== "$s"  (${s.length} chars)  cost ${eng.lastCost}');
    print(t.toPrettyString(s));
  }
}
