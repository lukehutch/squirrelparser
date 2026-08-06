// _relax72.dart -- how often does the relaxed pass actually relax anything?
//
// `_certcost` prices I28's certificate at 33.7 ms of the 63.0 ms battery gap
// against m62, and `_confg` shows it is NOT removable: without it conformance
// falls 5/5 -> 3/5, and starting guarded instead costs 6.0% on the battery and
// 58.9% on latency. So the certificate has to stay -- but it does not have to
// be BOUGHT when there is nothing to doubt.
//
// The relaxed and guarded passes differ at exactly three sites, and at each one
// the difference is locally decidable: the loop stop inside the budget-zero
// window, the alternation's guards, and the spine self-loop's stop. If NONE of
// them computed anything different on a given input, the two passes are the
// same DP, so relaxedCost == tightCost and there is nothing for the certificate
// to catch. This counts, per input, how many times a site actually differed.
import 'dart:io';

import 'final_table.dart' show buildSetup;
import '_m72cnt.dart' as cnt;

void main() {
  final (rules, battery, _, validDocs, latCases, _, _, _) = buildSetup();
  final eng = cnt.SuperDot3(rules: rules, topRuleName: 'JSON');

  for (final (name, inputs) in [
    ('battery', battery),
    ('valid', validDocs),
    ('latency', latCases),
  ]) {
    var clean = 0, total = 0, sites = 0, cost0 = 0;
    for (final s in inputs) {
      final c = eng.recoverCost(s);
      total++;
      sites += eng.nRelax;
      if (eng.nRelax == 0) clean++;
      if (c <= 0) cost0++;
    }
    stdout.writeln('${name.padRight(8)} $total inputs: $clean relaxed nothing '
        '(${(100 * clean / total).toStringAsFixed(1)}%), '
        '$sites site-hits total, $cost0 already short-circuit at cost<=0');
  }
}
