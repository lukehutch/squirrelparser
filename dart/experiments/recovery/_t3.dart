// _t1.dart -- show the repair two engines produce for the same inputs, marks and
// cost side by side. Usage: dart run _t1.dart <engA> <engB> [input ...]
import 'package:squirrel_parser/squirrel_parser.dart';

import 'astdiff.dart';
import 'm134.dart' as a;
import 'm135.dart' as b;

void marks(MatchResult m, String src, List<String> out) {
  if (m is a.Filled) {
    out.add('FILL@${m.pos} "${m.text}"');
  } else if (m is b.Filled) {
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

void main(List<String> argv) {
  final c = corpora.firstWhere((e) => e.name == 'json');
  final rules = MetaGrammar.parseGrammar(c.grammar);
  final cases = argv.isEmpty
      ? ['[1,[2,[3,[4', '[1,[2,[3,', '[1,[2,', '[{"x']
      : argv;
  for (final s in cases) {
    print('input  $s');
    for (final e in [
      ('m134', a.SuperDot3(rules: rules, topRuleName: c.top)),
      ('m135', b.SuperDot3(rules: rules, topRuleName: c.top)),
    ]) {
      final r = e.$2 is a.SuperDot3
          ? (e.$2 as a.SuperDot3).recover(s)
          : (e.$2 as b.SuperDot3).recover(s);
      final cost = e.$2 is a.SuperDot3
          ? (e.$2 as a.SuperDot3).lastCost
          : (e.$2 as b.SuperDot3).lastCost;
      final out = <String>[];
      if (r != null) marks(r, s, out);
      print('  ${e.$1} cost=$cost  ${out.join('  ')}');
    }
    print('');
  }
}
