import 'package:squirrel_parser/squirrel_parser.dart';
import 'astdiff.dart';
import 'r2.dart' as r2;

void main() {
  final rules = MetaGrammar.parseGrammar(jsonGrammar);
  final named = corpora.firstWhere((c) => c.name == 'json').named;
  for (final s in ['[1,[2,', '{"a":', '[2,33,true]']) {
    final e = r2.Squirrel(rules: rules, topRuleName: 'JSON');
    final t = e.recover(s);
    final errs = <String>[];
    void walk(MatchResult m) {
      if (m is SyntaxError) errs.add('${m.pos}..${m.pos + m.len}');
      m.subClauseMatches.forEach(walk);
    }
    walk(t);
    print('`$s` cost=${e.lastCost} len=${t.len}/${s.length} errors=$errs');
    print('   ${skeleton(t, named).join(" ")}');
  }
}
