import 'package:squirrel_parser/squirrel_parser.dart';
import '_m68dbg.dart' as d;
void main() {
  final cases = <(String, String)>[
    ('S <- &[a-z] [a-z];\n', 'Q'),
    ('S <- &[a-z] [0-9m-q];\n', ''),
    ('S <- ![a-l] [a-z];\n', ''),
    ('S <- &[a-c] [x-z];\n', ''),
  ];
  for (final (g, x) in cases) {
    final r = MetaGrammar.parseGrammar(g);
    final e = d.SuperDot3(rules: r, topRuleName: 'S');
    final relaxed = e.dbgRelaxedCost(x);
    final res = e.recover(x);
    print('${g.trim().padRight(24)} "$x"');
    print('   wide=${e.dbgWide} mass=${e.dbgMass} relaxedCost=$relaxed');
    print('   final=${e.lastCost} fellBack=${e.lastFellBack} '
        'verified=${e.lastVerified} horizon=${e.lastHorizon}');
    print('   spans=${res.errorSpans.length} '
        'missing=${res.missing.map((m) => "${e.dbgSpell(m.clause)}@${m.pos}").toList()}');
  }
}
