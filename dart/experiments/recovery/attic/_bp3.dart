// _bp3.dart -- does packing (regret, why) into one int change any answer?
//
// `_m72p3` is m72 with the answer list at stride 3 instead of 4: the regret and
// the recorded reason share one int as `(reg << 21) | (why + 4)`. That is 25%
// less memory in every answer list, and the question is whether it is free.
// Before it can be timed it has to be shown ANSWER-IDENTICAL: the packing is
// lossy if either field ever exceeds its share, and under I30 the enumeration
// order IS the tie-break rule, so a difference in what lands in the list is a
// difference in the LANGUAGE. Compare the whole caller-visible result, not the
// cost, over the battery and the latency corpus.
import 'package:squirrel_parser/squirrel_parser.dart';
import 'package:squirrel_parser/src/recovery/skip_recovery.dart' show SkipResult;

import 'final_table.dart' show buildSetup;
import 'm72.dart' as a;
import '_m72p3.dart' as b;

void _shape(MatchResult m, StringBuffer out) {
  out.write(m is SyntaxError ? 'ERR' : m.clause.toString());
  out.write('@${m.pos}+${m.len}(');
  for (final s in m.subClauseMatches) {
    _shape(s, out);
    out.write(',');
  }
  out.write(')');
}

String _full(SkipResult r) {
  final sb = StringBuffer();
  _shape(r.root, sb);
  final spans = r.errorSpans.map((e) => '${e.pos}+${e.len}').join('|');
  return 'forced=${r.forced} events=${r.recoveryEvents} clean=${r.clean} '
      'spans=[$spans] missing=${r.missing.length} '
      'skipped=${r.charsSkipped} tree=$sb';
}

void main() {
  final (rules, battery, _, _, lat, _, _, _) = buildSetup();
  final inputs = <String>[...battery, ...lat];
  var checked = 0, costDiff = 0, fullDiff = 0, shown = 0;
  for (final s in inputs) {
    checked++;
    final ca = a.SuperDot3(rules: rules, topRuleName: 'JSON').recoverCost(s);
    final cb = b.SuperDot3(rules: rules, topRuleName: 'JSON').recoverCost(s);
    if (ca != cb) costDiff++;
    final fa = _full(a.SuperDot3(rules: rules, topRuleName: 'JSON').recover(s));
    final fb = _full(b.SuperDot3(rules: rules, topRuleName: 'JSON').recover(s));
    if (fa != fb) {
      fullDiff++;
      if (shown++ < 3) {
        print('DIFF on ${s.length} chars');
        print('  m72: $fa');
        print('  bs : $fb');
      }
    }
  }
  print('checked=$checked costDiff=$costDiff fullDiff=$fullDiff');
  print(costDiff == 0 && fullDiff == 0
      ? 'IDENTICAL -- the stride-3 packing is lossless; time it'
      : 'DIFFERS -- the packing loses information, do not time it');
}
