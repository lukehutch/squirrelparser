// m76 battery and the established construct-once/min-of-three latency protocol.
import 'dart:math';
import 'final_table.dart' show buildSetup, batteryTruth, treeShape;
import '_lat72.dart' show latCases;
import 'm76.dart' as e;

void main() {
  final setup = buildSetup();
  final rules = setup.$1, battery = setup.$2, valid = setup.$4;
  final truth = batteryTruth(rules, battery);
  final engine = e.SuperDot3(rules: rules, topRuleName: 'JSON');
  for (final s in battery.take(60)) engine.recover(s);

  var verified = 0, exactCost = 0, shape = 0, costFailures = 0;
  final sw = Stopwatch()..start();
  for (var i = 0; i < battery.length; i++) {
    final r = engine.recover(battery[i]);
    if (engine.lastVerified) verified++;
    if (engine.lastCost == truth[i]) {
      exactCost++;
    } else if (costFailures++ < 10) {
      print('COST input=${battery[i]} truth=${truth[i]} got=${engine.lastCost}');
    }
    if (treeShape(r.root) == setup.$3) shape++;
  }
  final battMs = sw.elapsedMicroseconds / 1000;

  var validOk = 0;
  for (final s in valid) {
    engine.recover(s);
    if (engine.lastCost == 0 && engine.lastVerified) validOk++;
  }

  final times = <double>[];
  for (final (index, s) in latCases().indexed) {
    var best = double.infinity;
    for (var rep = 0; rep < 3; rep++) {
      final one = Stopwatch()..start();
      engine.recover(s);
      best = min(best, one.elapsedMicroseconds / 1000);
    }
    times.add(best);
    print('lat[$index] len=${s.length} cost=${engine.lastCost} '
        'cells=${engine.lastCells} steps=${engine.lastSteps} '
        'residuals=${engine.dfaResiduals} obs=${engine.obligationStates} '
        'ms=${best.toStringAsFixed(1)}');
  }
  final latencyMs = times.fold<double>(0, (a, b) => a + b);
  print('battery=${battery.length} verified=$verified exactCost=$exactCost '
      'shape=$shape battMs=${battMs.toStringAsFixed(1)}');
  print('valid=${valid.length} validOk=$validOk latencyCases=${times.length} '
      'latMs=${latencyMs.toStringAsFixed(1)} individual='
      '${times.map((x) => x.toStringAsFixed(1)).join(',')}');
}
