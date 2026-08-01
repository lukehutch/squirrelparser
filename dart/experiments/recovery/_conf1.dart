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

import 'm78.dart' as m78;
import 'm79.dart' as m79;
import 'm80.dart' as m80;
import 'm81.dart' as m81;
import 'm82.dart' as m82;
import 'm83.dart' as m83;
import 'm84.dart' as m84;
import 'm85.dart' as m85;
import 'm86.dart' as m86;
import 'm87.dart' as m87;
import 'm88.dart' as m88;
import 'm89.dart' as m89;
import 'm90.dart' as m90;
import 'm91.dart' as m91;
import 'm92.dart' as m92;
import 'm93.dart' as m93;
import 'm94.dart' as m94;
import 'm95.dart' as m95;
import 'm96.dart' as m96;
import 'm97.dart' as m97;
import 'm98.dart' as m98;
import 'm99.dart' as m99;
import 'm100.dart' as m100;
import 'm101.dart' as m101;
import 'm102.dart' as m102;
import 'm103.dart' as m103;
import 'm105.dart' as m105;
import 'm106.dart' as m106;
import 'm108.dart' as m108;
import 'm109.dart' as m109;
import 'm110.dart' as m110;
import 'm111.dart' as m111;
import 'm112.dart' as m112;
import 'm113.dart' as m113;

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
  ('m78', (r, t) => m78.SuperDot3(rules: r, topRuleName: t).recoverCost),
  ('m79', (r, t) => m79.SuperDot3(rules: r, topRuleName: t).recoverCost),
  ('m80', (r, t) => m80.SuperDot3(rules: r, topRuleName: t).recoverCost),
  ('m81', (r, t) => m81.SuperDot3(rules: r, topRuleName: t).recoverCost),
  ('m82', (r, t) => m82.SuperDot3(rules: r, topRuleName: t).recoverCost),
  ('m83', (r, t) => m83.SuperDot3(rules: r, topRuleName: t).recoverCost),
  ('m84', (r, t) => m84.SuperDot3(rules: r, topRuleName: t).recoverCost),
  ('m85', (r, t) => m85.SuperDot3(rules: r, topRuleName: t).recoverCost),
  ('m86', (r, t) => m86.SuperDot3(rules: r, topRuleName: t).recoverCost),
  ('m87', (r, t) => m87.SuperDot3(rules: r, topRuleName: t).recoverCost),
  ('m88', (r, t) => m88.SuperDot3(rules: r, topRuleName: t).recoverCost),
  ('m89', (r, t) => m89.SuperDot3(rules: r, topRuleName: t).recoverCost),
  ('m90', (r, t) => m90.SuperDot3(rules: r, topRuleName: t).recoverCost),
  ('m91', (r, t) => m91.SuperDot3(rules: r, topRuleName: t).recoverCost),
  ('m92', (r, t) => m92.SuperDot3(rules: r, topRuleName: t).recoverCost),
  ('m93', (r, t) => m93.SuperDot3(rules: r, topRuleName: t).recoverCost),
  ('m94', (r, t) => m94.SuperDot3(rules: r, topRuleName: t).recoverCost),
  ('m95', (r, t) => m95.SuperDot3(rules: r, topRuleName: t).recoverCost),
  ('m96', (r, t) => m96.SuperDot3(rules: r, topRuleName: t).recoverCost),
  ('m97', (r, t) => m97.SuperDot3(rules: r, topRuleName: t).recoverCost),
  ('m98', (r, t) => m98.SuperDot3(rules: r, topRuleName: t).recoverCost),
  ('m99', (r, t) => m99.SuperDot3(rules: r, topRuleName: t).recoverCost),
  ('m100', (r, t) => m100.SuperDot3(rules: r, topRuleName: t).recoverCost),
  ('m101', (r, t) => m101.SuperDot3(rules: r, topRuleName: t).recoverCost),
  ('m102', (r, t) => m102.SuperDot3(rules: r, topRuleName: t).recoverCost),
  ('m103', (r, t) => m103.SuperDot3(rules: r, topRuleName: t).recoverCost),
  ('m105', (r, t) => m105.SuperDot3(rules: r, topRuleName: t).recoverCost),
  ('m106', (r, t) => m106.SuperDot3(rules: r, topRuleName: t).recoverCost),
  ('m108', (r, t) => m108.SuperDot3(rules: r, topRuleName: t).recoverCost),
  ('m109', (r, t) => m109.SuperDot3(rules: r, topRuleName: t).recoverCost),
  ('m110', (r, t) => m110.SuperDot3(rules: r, topRuleName: t).recoverCost),
  ('m111', (r, t) => m111.SuperDot3(rules: r, topRuleName: t).recoverCost),
  ('m112', (r, t) => m112.SuperDot3(rules: r, topRuleName: t).recoverCost),
  ('m113', (r, t) => m113.SuperDot3(rules: r, topRuleName: t).recoverCost),
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
