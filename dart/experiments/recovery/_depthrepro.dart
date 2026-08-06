// _depthrepro.dart -- the table says m70 RRmax=2048; two standalone probes say
// len=4096 completes. One of them is wrong about what it is measuring.
//
// `_rr70` spawns one isolate per rung and `_seq70` runs the whole LR-then-RR
// ladder in one isolate; both give m70 RR len=4096 OK. The table gives 2048,
// with the overflow inside `_verify`. The probes are therefore not reproducing
// the table's conditions, and the only structural difference left is that the
// table's depth isolate calls `buildSetup()` FIRST -- building the JSON grammar,
// the 519-mutant battery and the latency corpus -- before the ladder runs.
//
// This calls the table's OWN `measureOne(name, 'depth')` in a spawned isolate,
// so there is nothing left to differ, and then re-runs the same ladder with the
// setup allocation removed. If the first overflows and the second does not, the
// RRmax column is reporting heap state, not the engine.
import 'dart:async';
import 'dart:isolate';

import 'package:squirrel_parser/squirrel_parser.dart';

import 'final_table.dart' as ft;
import 'm69.dart' as e69;
import 'm70.dart' as e70;

String oneErr(int k) {
  final c = List.generate(k, (i) => '${i % 10}').join('+');
  return '${c.substring(0, c.length ~/ 2)}+${c.substring(c.length ~/ 2)}';
}

const gLRsrc = "E <- E '+' T / T;\nT <- T '*' F / F;\nF <- [0-9] / '(' E ')';\n";
const gRRsrc = "E <- T '+' E / T;\nT <- F '*' T / F;\nF <- [0-9] / '(' E ')';\n";

/// Exactly the table's depth part.
void tableJob(List<Object> msg) {
  final port = msg[0] as SendPort;
  final name = msg[1] as String;
  try {
    final out = ft.measureOne(name, 'depth');
    port.send(<Object>['OK', '${out[1]} / ${out[2]}']);
  } catch (e) {
    port.send(<Object>['ERR', e.toString().split('\n').first]);
  }
}

/// The same ladder with `buildSetup()` NOT called.
void bareJob(List<Object> msg) {
  final port = msg[0] as SendPort;
  final name = msg[1] as String;
  final withSetup = msg[2] as bool;
  if (withSetup) ft.buildSetup();
  final log = <String>[];
  for (final gram in ['LR', 'RR']) {
    final g = MetaGrammar.parseGrammar(gram == 'LR' ? gLRsrc : gRRsrc);
    var last = 'none';
    for (final k in [256, 512, 1024, 2048]) {
      final s = oneErr(k);
      try {
        if (name == 'm69') {
          e69.SuperDot3(rules: g, topRuleName: 'E').recoverCost(s);
        } else {
          e70.SuperDot3(rules: g, topRuleName: 'E').recoverCost(s);
        }
        last = '${s.length}';
      } on StackOverflowError {
        log.add('$gram $last');
        last = 'STOP';
        break;
      }
    }
    if (last != 'STOP') log.add('$gram >=$last');
  }
  port.send(<Object>['OK', log.join('  ')]);
}

Future<String> run(void Function(List<Object>) job, List<Object> extra) async {
  final rp = ReceivePort();
  final iso = await Isolate.spawn(job, <Object>[rp.sendPort, ...extra],
      onError: rp.sendPort, onExit: rp.sendPort);
  try {
    final v = await rp.first.timeout(const Duration(seconds: 600));
    if (v is List && v.length >= 2) return '${v[0]}: ${v[1]}';
    return 'DIED: $v';
  } on TimeoutException {
    return 'SLOW';
  } finally {
    iso.kill(priority: Isolate.immediate);
    rp.close();
  }
}

Future<void> main() async {
  for (final name in ['m69', 'm70']) {
    print('$name  table measureOne(depth):  ${await run(tableJob, [name])}');
    print('$name  same ladder + buildSetup: '
        '${await run(bareJob, [name, true])}');
    print('$name  same ladder, no setup:    '
        '${await run(bareJob, [name, false])}');
  }
}
