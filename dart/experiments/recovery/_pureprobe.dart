// Scratch: what does the FROZEN parser do with Codex's #5 grammar on the clean
// prefix? PEG's First must take `(. 'b')` at 0 if it matches there, and which
// of r5 and the candidates agrees with it decides who is conformant.
import 'package:squirrel_parser/squirrel_parser.dart';

String show(MatchResult m) {
  final b = StringBuffer('${m.clause}@${m.pos}+${m.len}');
  if (m.subClauseMatches.isNotEmpty) {
    b.write('{');
    for (final k in m.subClauseMatches) {
      b.write('${show(k)} ');
    }
    b.write('}');
  }
  return b.toString();
}

void main() {
  final rules = MetaGrammar.parseGrammar("S <- ((. 'b') / [ab])*;");
  for (final s in ['ab', 'abc', 'a', 'abab']) {
    final r = Parser(rules: rules, topRuleName: 'S', input: s).parse();
    print('pure "$s"  errs=${r.hasSyntaxErrors}  ${show(r.root)}');
  }
}
