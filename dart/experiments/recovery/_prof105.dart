// _prof105.dart -- where does m105's battery time structurally go?
//
// Latency is the one axis of the governing brief m105 does not meet: ~6.5 s of
// battery against m78's standing 2090 ms target. Two structural suspects are
// counted here in one run so that neither is argued about:
//
//   DEEPENING RE-DERIVATION. `_mc`/`_me` are cleared at the top of every budget
//   round, so a failed round is thrown away entirely. `wasted/total` is the
//   fraction of offered ways built in rounds that did not succeed -- the exact
//   ceiling on what an incremental-widening schedule could return.
//
//   `_put` PREFIX REBUILDING. A replacement `_cons`es a fresh copy of every way
//   ahead of the replaced one, so a cell holding k ways costs O(k) allocations
//   per replacement. consInPut/putCalls says whether that is a real cost or a
//   rounding error.
//
// The budget histogram says whether deepening is even reached, which decides
// whether the first suspect can matter at all.
import 'package:squirrel_parser/squirrel_parser.dart';

import 'astdiff.dart';
import '_m105prof.dart' as prof;

void main() {
  final cases = weighted(buildBattery());
  final rules = <String, Map<String, Clause>>{
    for (final c in corpora) c.name: MetaGrammar.parseGrammar(c.grammar)
  };
  final made = <String, MatchResult? Function(String)>{
    for (final c in corpora)
      c.name: prof.SuperDot3(rules: rules[c.name]!, topRuleName: c.top).recover
  };

  final sw = Stopwatch()..start();
  for (final k in cases) {
    try {
      made[k.grammar]!(k.mutant);
    } catch (_) {}
  }
  sw.stop();

  final total = prof.totalWork, wasted = prof.wastedWork;
  print('cases ${prof.casesRun}  rounds ${prof.roundsRun}  '
      'wall ${sw.elapsedMilliseconds} ms');
  print('');
  print('-- deepening --');
  print('rounds per case         ${(prof.roundsRun / prof.casesRun).toStringAsFixed(3)}');
  print('offered ways (total)    $total');
  print('offered ways (wasted)   $wasted'
      '  (${(wasted / total * 100).toStringAsFixed(1)}% of the search)');
  final names = <int, String>{0: 'b=0', 1: 'b=1', 2: 'b=2', 3: 'b=4', 4: 'b=8'};
  final hist = StringBuffer();
  for (var i = 0; i < 28; i++) {
    if (prof.budgetHist[i] == 0) continue;
    final label = i == 27 ? 'FAIL' : (names[i] ?? 'b=${1 << (i - 1)}');
    hist.write('  $label:${prof.budgetHist[i]}');
  }
  print('final budget           $hist');
  print('');
  print('-- _put --');
  print('calls                   ${prof.putCalls}');
  print('list steps scanned      ${prof.putScan}'
      '  (${(prof.putScan / prof.putCalls).toStringAsFixed(2)} per call)');
  print('replacements            ${prof.putReplace}'
      '  (${(prof.putReplace / prof.putCalls * 100).toStringAsFixed(1)}%)');
  print('_cons in prefix rebuild ${prof.consInPut}'
      '  (${(prof.consInPut / prof.putCalls).toStringAsFixed(2)} per call, '
      '${prof.putReplace == 0 ? 0 : (prof.consInPut / prof.putReplace).toStringAsFixed(2)} per replacement)');
  print('_extend calls           ${prof.extendCalls}');
  print('');
  print('-- top-rule way-set size at the moment of selection --');
  var shown = 0;
  for (var i = 0; i < 64 && shown < 12; i++) {
    if (prof.setSize[i] == 0) continue;
    shown++;
    print('  ${i.toString().padLeft(3)} ways: ${prof.setSize[i]}');
  }
}
