// _guardeq.dart -- does the guarded pass alone give m72's answers?
//
// `_certcost` prices I28's certificate at 33.7 ms of the 63.0 ms battery gap
// against m62, while the tighten it guards fires zero times. If the GUARDED
// pass is sound on its own, I28 is overhead in both columns -- but only if it
// answers identically. This compares, over the battery and the brute-force
// truth set, shipped m72 against three diagnostics:
//
//   nocert     relaxed pass, certificate skipped   (expected to differ: unsound)
//   guard      guarded pass, certificate skipped   (the candidate)
//   guardcert  guarded pass, certificate demanded  (the candidate, still proved)
import 'dart:io';

import 'final_table.dart' show buildSetup;
import 'm72.dart' as e72;
import '_m72cnt.dart' as cnt;

void main() {
  final (rules, battery, _, validDocs, latCases, _, _, _) = buildSetup();
  final inputs = <String>[...battery, ...validDocs, ...latCases];

  final ship = e72.SuperDot3(rules: rules, topRuleName: 'JSON');
  final truth = [for (final s in inputs) ship.recoverCost(s)];

  for (final arm in ['nocert', 'guard', 'guardcert']) {
    cnt.SuperDot3.skipCert = arm == 'nocert' || arm == 'guard';
    cnt.SuperDot3.forceGuard = arm == 'guard' || arm == 'guardcert';
    final eng = cnt.SuperDot3(rules: rules, topRuleName: 'JSON');
    var diff = 0, worse = 0, better = 0;
    for (var i = 0; i < inputs.length; i++) {
      final got = eng.recoverCost(inputs[i]);
      if (got == truth[i]) continue;
      diff++;
      if (truth[i] < 0 || (got >= 0 && got > truth[i])) {
        worse++;
      } else {
        better++;
      }
    }
    stdout.writeln('$arm: ${inputs.length} inputs, $diff differ '
        '($worse over-priced/rejected, $better under-priced)');
  }
}
