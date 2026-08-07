// _conf1.dart -- which engines hand a failing predicate a free pass?
//
// Cost 0 means "no repair was needed". Reporting 0 for a string the FROZEN
// parser rejects is a false claim about the grammar, whatever tree comes with
// it, so this is conformance rather than taste.
//
// The hole is in the witness/fill family: `_solveWitnesses` scores `&e` and `!e`
// as (0, ''), need 0 with a non-null witness, and `_repair`'s fill gate reads
// that as "fillable for nothing". `cost` is the first key in `_better`, so the
// free way dominates every honest one. m112 refuses it by requiring the fill to
// assert at least one character.
//
// `Name <- !Keyword [a-z]+` is the `stmt` corpus's own guard (astdiff.dart:250),
// so this is a live path on the battery, not a constructed one.
import 'package:squirrel_parser/squirrel_parser.dart';

import '_convert.dart';

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

typedef Cost = int Function(String) Function(Map<String, Clause>, String);

final engines = <(String, Cost)>[
  ('c8', (r, t) => convertC8(r, t).recoverCost),
];

bool pegAccepts(Map<String, Clause> rules, String top, String s) =>
    !Parser(rules: rules, topRuleName: top, input: s).parse().hasSyntaxErrors;

void main() {
  // Ground truth first, from the frozen parser: which of these does the grammar
  // actually accept?
  final probes = <(String, String, String)>[
    ('neg', negGrammar, 'ab'),
    ('neg', negGrammar, 'if'),
    ('neg', negGrammar, 'if ab'),
    ('pos', posGrammar, 'if'),
    ('pos', posGrammar, 'ab'),
    ('pos', posGrammar, 'ab if'),
  ];
  final rules = <String, Map<String, Clause>>{
    'neg': MetaGrammar.parseGrammar(negGrammar),
    'pos': MetaGrammar.parseGrammar(posGrammar),
  };
  final accepts = [
    for (final (g, _, s) in probes) pegAccepts(rules[g]!, 'Top', s)
  ];
  print('engine  free-passes  costs');
  for (final (name, build) in engines) {
    final costs = <String>[];
    var free = 0;
    for (var i = 0; i < probes.length; i++) {
      final (g, _, s) = probes[i];
      int c;
      try {
        c = build(rules[g]!, 'Top')(s);
      } catch (_) {
        costs.add('ERR');
        continue;
      }
      // Only the REJECTS rows can show a free pass; an accepted string costing 0
      // is correct.
      if (!accepts[i] && c == 0) free++;
      costs.add('$c');
    }
    print('${name.padRight(7)} ${free == 0 ? '   .   ' : '  $free/4  '}'
        '    ${costs.join(' ')}');
  }
  print('');
  print('probes: ${[for (var i = 0; i < probes.length; i++) '${probes[i].$3}'
      '=${accepts[i] ? 'ok' : 'REJ'}'].join('  ')}');
}
