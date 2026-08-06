import 'package:squirrel_parser/squirrel_parser.dart';
import 'astdiff.dart';
import 'm126.dart' as g;

void marks(MatchResult m, String src, List<String> out) {
  if (m is g.Filled) {
    out.add('FILL@${m.pos} "${m.text}"');
  } else if (m is SyntaxError) {
    out.add('SKIP@${m.pos}+${m.len} '
        '"${src.substring(m.pos, (m.pos + m.len).clamp(0, src.length))}"');
  }
  if (m is Match) {
    for (final k in m.subClauseMatches) {
      marks(k, src, out);
    }
  }
}

void main() {
  final c = corpora.firstWhere((c) => c.name == 'json');
  final rules = MetaGrammar.parseGrammar(c.grammar);
  const cases = [
    '"a":1,"bc":[2,33,true],"d":{"e":null},"f":"gh"}',
    '"alpha":"beta gamma","delta":["epsilon","zeta"]}',
  ];
  for (final s in cases) {
    final e = g.SuperDot3(rules: rules, topRuleName: c.top);
    final r = e.recover(s);
    final out = <String>[];
    if (r != null) marks(r, s, out);
    print('input  $s');
    print('cost   ${e.lastCost}');
    for (final o in out) {
      print('       $o');
    }
    print('');
  }
}
