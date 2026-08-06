import 'package:squirrel_parser/squirrel_parser.dart';
import '_dbg57.dart' as e;
import 'm53.dart' as r;

void one(String g, String top, String input) {
  final a = e.SuperDot3(rules: MetaGrammar.parseGrammar(g), topRuleName: top);
  final b = r.SuperDot3(rules: MetaGrammar.parseGrammar(g), topRuleName: top);
  a.dbgTrace = true;
  final ca = a.recoverCost(input);
  final cb = b.recoverCost(input);
  print('"$input"  m57=$ca m53=$cb  steps=${a.lastSteps}/${b.lastSteps} '
      'cells=${a.lastCells}/${b.lastCells} regress=${a.dbgRegress} below=${a.dbgBelow}');
}

void main() {
  const g1 = "S <- !'x' A; A <- 'x' / \"yy\";";
  for (final s in ['xyy', 'q', 'yy', '']) { one(g1, 'S', s); }
  const g2 = "S <- Kw; Kw <- \"if\" !Alpha; Alpha <- [a-z];";
  for (final s in ['ifa', 'if', 'i', 'ifq']) { one(g2, 'S', s); }
  const g3 = "S <- &'x' !'x' 'y';";
  for (final s in ['y', 'x', '']) { one(g3, 'S', s); }
}
