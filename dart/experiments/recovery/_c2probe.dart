import 'package:squirrel_parser/squirrel_parser.dart';
import 'astdiff.dart';
import 'c2.dart' as c2;

void main() {
  final g = corpora.firstWhere((x) => x.name == 'json');
  final gr = MetaGrammar.parseGrammar(g.grammar);
  final e = c2.Squirrel(rules: gr, topRuleName: g.top);
  final sw = Stopwatch()..start();
  final p = Parser(rules: e.rules, topRuleName: 'T', input: '[1,2,3]');
  final r = p.parse();
  print('pure clean: ${sw.elapsedMicroseconds}us errors=${r.hasSyntaxErrors}');
  sw.reset();
  final t = e.recover('[1,2,3]');
  print('clean recover: ${sw.elapsedMicroseconds}us ${skeleton(t, g.named).join(' ').substring(0, 40)}');
  sw.reset();
  c2.Squirrel.nExpand = 0;
  c2.Squirrel.nGrow = 0;
  c2.Squirrel.nWays = 0;
  final t2 = e.recover('[1,2 3]');
  print('damaged: ${sw.elapsedMicroseconds}us cost=${e.lastCost} ${skeleton(t2, g.named).join(' ')}');
  print('expands=${c2.Squirrel.nExpand} grows=${c2.Squirrel.nGrow} ways=${c2.Squirrel.nWays}');
  sw.reset();
  e.recover('[1,2 3]');
  print('damaged again: ${sw.elapsedMicroseconds}us');
  sw.reset();
  final f = e.fillOf();
  print('minFill alone: ${sw.elapsedMicroseconds}us fill=$f');
}
