import 'package:squirrel_parser/squirrel_parser.dart';
import 'm57.dart' as e;
import 'm53.dart' as r;

String shape(MatchResult m) {
  final kids = m.subClauseMatches;
  final label = m is SyntaxError ? 'ERR' : '${m.clause}';
  return kids.isEmpty
      ? '$label@${m.pos}+${m.len}'
      : '$label@${m.pos}+${m.len}(${kids.map(shape).join(',')})';
}

void one(String g, String top, String input) {
  final a = e.SuperDot3(rules: MetaGrammar.parseGrammar(g), topRuleName: top);
  final b = r.SuperDot3(rules: MetaGrammar.parseGrammar(g), topRuleName: top);
  final ra = a.recover(input);
  final rb = b.recover(input);
  print('=== "$input" m57 cost=${a.lastCost} ver=${a.lastVerified} | m53 cost=${b.lastCost} ver=${b.lastVerified}');
  final sa = shape(ra.root), sb = shape(rb.root);
  if (sa == sb) { print('  same'); return; }
  // print the first divergence region
  var i = 0;
  while (i < sa.length && i < sb.length && sa[i] == sb[i]) { i++; }
  final from = (i - 40).clamp(0, i);
  print('  m57: ...${sa.substring(from, (i + 80).clamp(0, sa.length))}');
  print('  m53: ...${sb.substring(from, (i + 80).clamp(0, sb.length))}');
}

void main() {
  const expr = "E <- E '+' T / T;\nT <- T '*' F / F;\nF <- [0-9] / '(' E ')';\n";
  one(expr, 'E', '1+2++3');
  one(expr, 'E', '((1');
  const g1 = "S <- (&[a-z] !'q' .)*;";
  one(g1, 'S', 'q');
}
