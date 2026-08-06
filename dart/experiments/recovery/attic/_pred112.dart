// _pred112.dart -- the zero-length fill was a free pass out of a failing
// predicate, and m112 refuses it. Before/after on the same cases.
//
// `_solveWitnesses` scores both predicates `(0, '')` (m105.dart:480-485): need
// 0, witness the EMPTY STRING rather than null. `_repair`'s fill block then sees
// `need == 0 <= budget` and `_witness(sub) != null`, so it fires unconditionally
// and offers
//
//     _Way(pos, /*cost*/ 0, 0, 0, true, site: 1, leaf: Filled(sub, pos, ''))
//
// `cost` is the FIRST key in `_better`, so that cost-0 way dominates every
// priced one and the sequence proceeds as though the guard had passed.
//
// The test is conformance, not taste. Cost 0 means "no repair was needed", so
// reporting cost 0 for a string the frozen PEG parser REJECTS is a false claim
// about the grammar, whatever tree comes with it.
//
// m112's rule is stated on the fill's LENGTH, not on the clause kind: a fill
// asserts characters, so a fill of none leaves the input and the position
// exactly as they were and the clause that just failed must fail again. A
// zero-length fill can never convert a failure into a success.
import 'package:squirrel_parser/squirrel_parser.dart';

import 'm105.dart' as before;
import 'm112.dart' as after;
import 'm78.dart' as incumbent;

const negGrammar = '''
Top <- Item+;
Item <- !Kw Word WS;
Kw <- "if";
Word <- [a-z]+;
~WS <- [ ]*;
''';

const posGrammar = '''
Top <- Item+;
Item <- &Kw Word WS;
Kw <- "if";
Word <- [a-z]+;
~WS <- [ ]*;
''';

/// Does the FROZEN parser accept [s] outright? That is the ground truth a
/// cost-0 recovery is claiming to agree with.
bool pegAccepts(Map<String, Clause> rules, String top, String s) {
  return !Parser(rules: rules, topRuleName: top, input: s)
      .parse()
      .hasSyntaxErrors;
}

void main() {
  var unsound = 0;
  for (final (name, text, cases) in <(String, String, List<String>)>[
    ('NEGATIVE  Item <- !Kw Word WS', negGrammar, ['ab', 'if', 'if ab']),
    ('POSITIVE  Item <- &Kw Word WS', posGrammar, ['if', 'ab', 'ab if']),
  ]) {
    final rules = MetaGrammar.parseGrammar(text);
    final b = before.SuperDot3(rules: rules, topRuleName: 'Top');
    final a = after.SuperDot3(rules: rules, topRuleName: 'Top');
    // m78 is the engine m105 has to beat, so it is held to the same bar. It is
    // skip-based and shares none of this code, which is the point of asking.
    final i = incumbent.SuperDot3(rules: rules, topRuleName: 'Top');
    print(name);
    print('  input      frozen PEG   m78 cost    m105 cost   m112 cost');
    for (final s in cases) {
      final peg = pegAccepts(rules, 'Top', s);
      // A rejected string must cost SOMETHING; an accepted one must cost
      // nothing. Both directions are conformance.
      String col(int c) {
        final bad = peg ? c != 0 : c == 0;
        return '$c${bad ? ' BAD' : ''}'.padRight(11);
      }

      final ci = col(i.recoverCost(s));
      final cb = col(b.recoverCost(s));
      final ca = col(a.recoverCost(s));
      if (ca.contains('BAD')) unsound++;
      print('  ${'"$s"'.padRight(9)}  ${peg ? 'accepts' : 'REJECTS'}      '
          '$ci $cb ${ca.trimRight()}');
    }
    print('');
  }
  print(unsound == 0
      ? 'm112: conformant on all 6'
      : 'm112: $unsound UNSOUND rows remain');
}
