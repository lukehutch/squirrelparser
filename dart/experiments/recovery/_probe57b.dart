import 'package:squirrel_parser/squirrel_parser.dart';
import '_dbg57.dart' as e;

void main() {
  const g2 = "S <- Kw; Kw <- \"if\" !Alpha; Alpha <- [a-z];";
  final a = e.SuperDot3(rules: MetaGrammar.parseGrammar(g2), topRuleName: 'S');
  a.dbgTrace = true;
  print('cost=${a.recoverCost("i")}');
}
