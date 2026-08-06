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
import 'm114.dart' as m114;
import 'm115.dart' as m115;
import 'm116.dart' as m116;
import 'm117.dart' as m117;
import 'm118.dart' as m118;
import 'm119.dart' as m119;
import 'm120.dart' as m120;
import 'm121.dart' as m121;
import 'm124.dart' as m124;
import 'm125.dart' as m125;
import 'm126.dart' as m126;
import 'm127.dart' as m127;
import 'm128.dart' as m128;
import 'm129.dart' as m129;
import 'm130.dart' as m130;
import 'm131.dart' as m131;
import 'm132.dart' as m132;
import 'm141.dart' as m141;
import 'm143.dart' as m143;
import 'm133.dart' as m133;
import 'm134.dart' as m134;
import 'm135.dart' as m135;
import 'm136.dart' as m136;
import 'm137.dart' as m137;
import 'm138.dart' as m138;
import 'm139.dart' as m139;
import 'm140.dart' as m140;
import 'm122.dart' as m122;
import 'm123.dart' as m123;
import 'r1.dart' as r1;
import 'r2.dart' as r2;
import 'r3.dart' as r3;
import '_u11.dart' as r4;

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
  ('m114', (r, t) => m114.SuperDot3(rules: r, topRuleName: t).recoverCost),
  ('m115', (r, t) => m115.SuperDot3(rules: r, topRuleName: t).recoverCost),
  ('m116', (r, t) => m116.SuperDot3(rules: r, topRuleName: t).recoverCost),
  ('m117', (r, t) => m117.SuperDot3(rules: r, topRuleName: t).recoverCost),
  ('m118', (r, t) => m118.SuperDot3(rules: r, topRuleName: t).recoverCost),
  ('m119', (r, t) => m119.SuperDot3(rules: r, topRuleName: t).recoverCost),
  ('m120', (r, t) => m120.SuperDot3(rules: r, topRuleName: t).recoverCost),
  ('m121', (r, t) => m121.SuperDot3(rules: r, topRuleName: t).recoverCost),
  ('m124', (r, t) => m124.SuperDot3(rules: r, topRuleName: t).recoverCost),
  ('m125', (r, t) => m125.SuperDot3(rules: r, topRuleName: t).recoverCost),
  ('m126', (r, t) => m126.SuperDot3(rules: r, topRuleName: t).recoverCost),
  ('m127', (r, t) => m127.SuperDot3(rules: r, topRuleName: t).recoverCost),
  ('m128', (r, t) => m128.SuperDot3(rules: r, topRuleName: t).recoverCost),
  ('m129', (r, t) => m129.SuperDot3(rules: r, topRuleName: t).recoverCost),
  ('m130', (r, t) => m130.SuperDot3(rules: r, topRuleName: t).recoverCost),
  ('m131', (r, t) => m131.SuperDot3(rules: r, topRuleName: t).recoverCost),
  ('m132', (r, t) => m132.SuperDot3(rules: r, topRuleName: t).recoverCost),
  ('m141', (r, t) => m141.SuperDot3(rules: r, topRuleName: t).recoverCost),
  ('m143', (r, t) => m143.SuperDot3(rules: r, topRuleName: t).recoverCost),
  ('m133', (r, t) => m133.SuperDot3(rules: r, topRuleName: t).recoverCost),
  ('m134', (r, t) => m134.SuperDot3(rules: r, topRuleName: t).recoverCost),
  ('m135', (r, t) => m135.SuperDot3(rules: r, topRuleName: t).recoverCost),
  ('m136', (r, t) => m136.SuperDot3(rules: r, topRuleName: t).recoverCost),
  ('m137', (r, t) => m137.SuperDot3(rules: r, topRuleName: t).recoverCost),
  ('m138', (r, t) => m138.SuperDot3(rules: r, topRuleName: t).recoverCost),
  ('m139', (r, t) => m139.SuperDot3(rules: r, topRuleName: t).recoverCost),
  ('m140', (r, t) => m140.SuperDot3(rules: r, topRuleName: t).recoverCost),
  ('m122', (r, t) => m122.SuperDot3(rules: r, topRuleName: t).recoverCost),
  ('m123', (r, t) => m123.SuperDot3(rules: r, topRuleName: t).recoverCost),
  ('r1', (r, t) => r1.Squirrel(rules: r, topRuleName: t).recoverCost),
  ('r2', (r, t) => r2.Squirrel(rules: r, topRuleName: t).recoverCost),
  ('r3', (r, t) => r3.Squirrel(rules: r, topRuleName: t).recoverCost),
  ('r4', (r, t) => r4.Squirrel(rules: r, topRuleName: t).recoverCost),
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
