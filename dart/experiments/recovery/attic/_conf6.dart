// _conf1's sixth probe is the only one the two engine lines answer differently:
// `Top <- Item+; Item <- &Kw Word WS; Kw <- "if"; Word <- [a-z]+` on `ab if`.
// m112-m143 report cost 2; r1-r9 report 3. This asks the frozen parser which
// repaired strings are actually in the language, so the disagreement can be
// attributed rather than guessed at.
import 'package:squirrel_parser/squirrel_parser.dart';

const posGrammar = '''
Top <- Item+;
Item <- &Kw Word WS;
Kw <- "if";
Word <- [a-z]+;
~WS <- [ ]*;
''';

bool accepts(Map<String, Clause> rules, String s) {
  final r = Parser(rules: rules, topRuleName: 'Top', input: s).parse();
  return !r.hasSyntaxErrors;
}

void main() {
  final rules = MetaGrammar.parseGrammar(posGrammar);
  // (candidate, edits from `ab if`, what kind of edit)
  const cands = [
    ('ab if', 0, 'the input itself'),
    ('ifab if', 2, 'INSERT "if" at 0 -- invents two characters'),
    ('if if', 2, 'SUBSTITUTE ab -> if -- invents two characters'),
    ('if', 3, 'DELETE "ab " -- invents nothing'),
    ('abif', 2, 'INSERT/move -- no leading if'),
    ('if ab', 0, 'the other order, for reference'),
  ];
  for (final (s, n, how) in cands) {
    print('${accepts(rules, s) ? 'ACCEPT' : 'reject'}  cost $n  '
        '${'"$s"'.padRight(10)} $how');
  }
}
