// _nr74.dart -- is the regret objective still doing work under I30?
//
// `_keepBest` compares (cost, regret) and refuses an equal entry, so with
// regret identically 0 the comparison degenerates to cost alone and the
// FIRST writer of a key wins outright -- which is exactly what I30 says the
// tie-break should be. If shape, cover and cost all hold, the whole regret
// apparatus (`_regretPrefix`, `_skipRegret`, `_width`, `_widthOf`,
// `_cleanRegret`, `_cleanRegrets`, `_widestClass`) is dead weight.
import 'dart:io';

import 'package:squirrel_parser/src/recovery/skip_recovery.dart'
    show SkipResult;

import 'final_table.dart' show buildSetup, treeShape, covers;
import 'm74.dart' as e74;
import '_m74nr.dart' as enr;

typedef Rec = (
  SkipResult Function(String),
  int Function(),
  bool Function(),
  int Function(String)
);

void main() {
  final (rules, battery, origShape, _, latCases, _, _, _) = buildSetup();
  final made = <String, Rec>{
    'm74': () {
      final e = e74.SuperDot3(rules: rules, topRuleName: 'JSON');
      return (e.recover, () => e.lastCost, () => e.lastVerified, e.recoverCost);
    }(),
    'nr ': () {
      final e = enr.SuperDot3(rules: rules, topRuleName: 'JSON');
      return (e.recover, () => e.lastCost, () => e.lastVerified, e.recoverCost);
    }(),
  };
  made.forEach((name, r) {
    final (rec, cost, ok, costOf) = r;
    var shape = 0, cov = 0, cert = 0, sum = 0;
    for (final s in battery) {
      final t = rec(s);
      sum += cost();
      if (ok()) cert++;
      if (covers(t.root, s.length)) cov++;
      if (treeShape(t.root) == origShape) shape++;
    }
    for (final s in latCases) {
      sum += costOf(s);
    }
    stdout.writeln('$name shape $shape/${battery.length}  '
        'cover $cov/${battery.length}  certified $cert  costsum $sum');
  });
}
