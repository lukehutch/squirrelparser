// _wdrive6.dart -- the floor. What does the FROZEN parser cost on exactly the
// battery m132 is timed on?
//
// Every recovery engine must at minimum parse the input at cost 0, and a
// bottom-up chart must do that too -- eagerly, so strictly more of it. So the
// plain-parse time is a hard lower bound on any design, and the gap between it
// and m132 is the entire budget available to ANY scheduling change.
import 'package:squirrel_parser/squirrel_parser.dart';

import 'astdiff.dart';
import 'm132.dart' as m132;

void main() {
  final rulesOf = {
    for (final c in corpora) c.name: MetaGrammar.parseGrammar(c.grammar)
  };
  final topOf = {for (final c in corpora) c.name: c.top};

  final seen = <String>{};
  final cases = <Case>[];
  for (final k in weighted(buildBattery())) {
    if (seen.add('${k.grammar}\x00${k.category}\x00${k.mutant}')) cases.add(k);
  }

  // Warm both paths before timing either.
  for (var round = 0; round < 2; round++) {
    final t0 = DateTime.now();
    for (final k in cases) {
      Parser(
              rules: rulesOf[k.grammar]!,
              topRuleName: topOf[k.grammar]!,
              input: k.mutant)
          .parse();
    }
    final t1 = DateTime.now();
    final made = {
      for (final c in corpora)
        c.name: m132.SuperDot3(rules: rulesOf[c.name]!, topRuleName: c.top)
    };
    for (final k in cases) {
      try {
        made[k.grammar]!.recover(k.mutant);
      } catch (_) {}
    }
    final t2 = DateTime.now();
    final plain = t1.difference(t0).inMilliseconds;
    final rec = t2.difference(t1).inMilliseconds;
    print('round $round  ${cases.length} cases: '
        'frozen parse ${plain} ms, m132 recover ${rec} ms '
        '= ${(rec / plain).toStringAsFixed(1)}x');
  }
}
