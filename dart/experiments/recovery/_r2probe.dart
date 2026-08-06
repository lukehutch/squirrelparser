import 'package:squirrel_parser/squirrel_parser.dart';
import 'astdiff.dart';
import 'r1.dart' as r1;
import 'r2.dart' as r2;

const base = '{"a":1,"bc":[2,33,true],"d":{"e":null},"f":"gh"}';

final named = corpora.firstWhere((c) => c.name == 'json').named;

void dump(String label, MatchResult t, String s) {
  final errs = <String>[];
  void walk(MatchResult m) {
    if (m is SyntaxError) errs.add('${m.pos}..${m.pos + m.len}');
    m.subClauseMatches.forEach(walk);
  }
  walk(t);
  print('$label  len=${t.len}/${s.length}  errors=$errs');
  print('   skeleton=${skeleton(t, named).join(" ")}');
}

void main() {
  final rules = MetaGrammar.parseGrammar(jsonGrammar);
  for (final s in [
    base.replaceFirst('[2,33,true]', '[,2,33,true]'),
    base.replaceFirst('[2,33,true]', '[2,3,3true]'),
  ]) {
    print('input: $s');
    dump('  r1', r1.Squirrel(rules: rules, topRuleName: 'JSON').recover(s), s);
    dump('  r2', r2.Squirrel(rules: rules, topRuleName: 'JSON').recover(s), s);
    print('  want=${skeleton(r1.Squirrel(rules: rules, topRuleName: "JSON").recover(base), named).join(" ")}');
    print('');
  }
}
