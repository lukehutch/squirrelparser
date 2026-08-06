// _r3why.dart -- print the actual repair r3 chose, mark by mark.
import 'package:squirrel_parser/squirrel_parser.dart';

import 'astdiff.dart';
import 'm143.dart' as g143;
import 'r3.dart' as r3;

void marks(MatchResult m, String s, List<String> out) {
  if (m is SyntaxError) {
    out.add(m.len == 0
        ? 'unmet@${m.pos}'
        : 'del@${m.pos}:${s.substring(m.pos, m.pos + m.len)}');
  }
  for (final k in m.subClauseMatches) {
    marks(k, s, out);
  }
}

void main(List<String> argv) {
  const probes = [
    ('stmt', '{ p="q"; { r="st"; } if () v="w"; }'),
    ('stmt', 'if (a) { ="hi"; } c="jk"; d=1;'),
    ('stmt', 'if (a) { if (b) { c=; } }'),
    ('json', '{"n":[0,-7,1.5,2e3],"t":[true,false,nll]}'),
    ('json', '{"a":1,"bc":[2,33,rue],"d":{"e":null},"f":"gh"}'),
  ];
  for (final (g, s) in probes) {
    final c = corpora.firstWhere((x) => x.name == g);
    final rules = MetaGrammar.parseGrammar(c.grammar);
    final e = r3.Squirrel(rules: rules, topRuleName: c.top);
    final t = e.recover(s);
    final out = <String>[];
    marks(t, s, out);
    print('`$s`');
    print('  r3   cost=${e.lastCost} cover=${t.len}/${s.length}  ${out.join(' ')}');
    final t2 = g143.SuperDot3(rules: rules, topRuleName: c.top).recover(s);
    final out2 = <String>[];
    marks(t2, s, out2);
    print('  m143 cover=${t2.len}/${s.length}  ${out2.join(' ')}');
  }
}
