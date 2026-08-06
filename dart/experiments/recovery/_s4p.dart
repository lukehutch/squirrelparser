import 'package:squirrel_parser/squirrel_parser.dart';
import 'astdiff.dart';
import 's4.dart' as s4;

void main() {
  final sw = Stopwatch()..start();
  final toy = MetaGrammar.parseGrammar("S <- Item+;\nItem <- 'a' 'b';\n");
  for (final s in ['abab', 'abXab', 'ab', 'XXab']) {
    final e = s4.Squirrel(rules: toy, topRuleName: 'S');
    final t = e.recover(s);
    print('"$s" cost=${e.lastCost} covered=${covers(t, s.length)} ${sw.elapsedMilliseconds}ms');
  }
  final j = corpora.firstWhere((x) => x.name == 'json');
  final jr = MetaGrammar.parseGrammar(j.grammar);
  for (final s in ['[1,2]', '[1,2', '[2,33true]', '{"a":1,"bc":[2,33,true],"d":{"e":null},"f":"gh"}']) {
    sw.reset();
    final e = s4.Squirrel(rules: jr, topRuleName: j.top);
    final t = e.recover(s.substring(0, s.length - (s == '[1,2]' ? 0 : 1)) + s[s.length-1]);
    print('"$s" cost=${e.lastCost} covered=${covers(t, s.length)} ${sw.elapsedMilliseconds}ms');
  }
  // one damaged real case
  sw.reset();
  final e = s4.Squirrel(rules: jr, topRuleName: j.top);
  e.recover('{"a":1,"bc"[2,33,true],"d":{"e":null},"f":"gh"}');
  print('delim-del case cost=${e.lastCost} ${sw.elapsedMilliseconds}ms');
}
