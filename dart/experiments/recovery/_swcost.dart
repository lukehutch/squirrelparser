// What the swallow costs, and what the honest reading of the same input costs.
// `%` is junk no rule can start with, so the second line is the same document
// with the String reading unavailable -- if it lands at the same price, the
// swallow did not win on cost, it won on rank.
import 'package:squirrel_parser/squirrel_parser.dart';

import 'astdiff.dart';
import 'r9.dart' as r9;

void main() {
  final c = corpora.firstWhere((k) => k.name == 'stmt');
  final rules = MetaGrammar.parseGrammar(c.grammar);
  for (final s in [
    'x=1; "f (x) { y0=0; y1=1; }',
    'x=1; %f (x) { y0=0; y1=1; }',
    'x=1; f (x) { y0=0; y1=1; }',
    'x=1; if (x) { y0=0; y1=1; }',
  ]) {
    final eng = r9.Squirrel(rules: rules, topRuleName: c.top);
    final t = eng.recover(s);
    final one = t.toPrettyString(s).split('\n');
    print('cost ${eng.lastCost}  "$s"');
    print('   ${one.where((l) => l.contains('SyntaxError') || l.contains('Str') || l.contains('If') || l.contains('Block')).map((l) => l.trim()).join('\n   ')}');
  }
}
