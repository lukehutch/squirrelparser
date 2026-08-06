import 'package:squirrel_parser/squirrel_parser.dart';
import 'astdiff.dart';
import 'c2.dart' as c2;
import '_c1x.dart' as c1x;

void main() {
  final g = corpora.firstWhere((x) => x.name == 'json');
  final gr = MetaGrammar.parseGrammar(g.grammar);
  final e = c2.Squirrel(rules: gr, topRuleName: g.top);
  const doc0 = '{"n":[0,-7,1.5,2e3],zt":[true,false,null]}';
  final e1 = c1x.Squirrel(rules: gr, topRuleName: g.top);
  e1.recover(doc0);
  print('---');
  c2.Squirrel.spy = false;
  const doc = '{"n":[0,-7,1.5,2e3],zt":[true,false,null]}';
  final t = e.recover(doc);
  var cursor = 0;
  void walk(MatchResult k, String path) {
    if (k is SyntaxError) {
      if (k.len > 0) {
        if (k.pos != cursor) print('MISALIGN err@${k.pos} cursor=$cursor $path');
        cursor = k.pos + k.len;
      }
      return;
    }
    if (k.subClauseMatches.isEmpty) {
      if (k.len > 0) {
        if (k.pos != cursor) {
          print('MISALIGN ${k.clause} pos=${k.pos} len=${k.len} '
              'cursor=$cursor $path');
        }
        if (k.pos < 8) {
          print('leaf ${k.clause} pos=${k.pos} len=${k.len} $path');
        }
        cursor = k.pos + k.len;
      }
      return;
    }
    final name = k.clause is Ref ? (k.clause as Ref).ruleName : '.';
    for (final c in k.subClauseMatches) {
      walk(c, '$path/$name');
    }
  }
  walk(t, '');
  print('final cursor=$cursor of ${doc.length}');
}
