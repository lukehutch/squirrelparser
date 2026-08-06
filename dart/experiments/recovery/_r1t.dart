import 'package:squirrel_parser/squirrel_parser.dart';
import 'astdiff.dart';
import '_r1dbg.dart' as dbg;

void main(List<String> argv) {
  final g = argv[0], input = argv[1];
  final c = corpora.firstWhere((x) => x.name == g);
  dbg.trace = true;
  final e = dbg.Squirrel(rules: MetaGrammar.parseGrammar(c.grammar), topRuleName: c.top);
  final m = e.recover(input);
  print('RESULT cost=${e.lastCost} len=${m.len}/${input.length}');
  print(m.toPrettyString(input));
}
