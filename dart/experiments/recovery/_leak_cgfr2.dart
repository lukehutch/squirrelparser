// Inter-rule lookahead leak gate for cgfr2.
import 'package:squirrel_parser/squirrel_parser.dart';
import 'cgfr2.dart' as candidate;

void main() {
  final rules = MetaGrammar.parseGrammar('''
    S <- 'a' 'b';
  ''');
  final cand = candidate.SuperDot3(rules: rules, topRuleName: 'S');
  final res = cand.recover('ax');
  print('recovered cost for ax: ${cand.lastCost}');
  assert(cand.lastCost == 1);
  print('Leak gate passed!');
}
