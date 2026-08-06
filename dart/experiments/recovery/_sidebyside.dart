// _sidebyside.dart -- the warm/cold split is now located but not explained.
//
//   cold isolate group : bare parser tops out at len 4096; m70 RR reaches 4096
//   warm isolate group : bare parser tops out at len 8192; m70 RR stops at 2048
//
// Warm makes the ORACLE deeper and the ENGINE shallower, which rules out a
// single "optimized frames are bigger" story. The remaining question is local:
// in ONE isolate, under one JIT state, how far does each get? This runs both
// ladders back to back inside the same warm depth isolate, and also prints how
// long the string is that `_verify` hands to the parser -- if the witness is
// materially longer than the input, the engine's parse is simply deeper than
// the bare-parser probe's and the two ceilings were never comparable.
import 'dart:async';
import 'dart:isolate';

import 'package:squirrel_parser/squirrel_parser.dart';

import 'final_table.dart' as ft;
import 'm70.dart' as e70;

String oneErr(int k) {
  final c = List.generate(k, (i) => '${i % 10}').join('+');
  return '${c.substring(0, c.length ~/ 2)}+${c.substring(c.length ~/ 2)}';
}

const gRRsrc = "E <- T '+' E / T;\nT <- F '*' T / F;\nF <- [0-9] / '(' E ')';\n";

void bothJob(List<Object> msg) {
  final port = msg[0] as SendPort;
  final g = MetaGrammar.parseGrammar(gRRsrc);
  final out = <String>[];

  var last = 'none';
  for (final k in [512, 1024, 2048, 4096]) {
    final s = oneErr(k);
    try {
      Parser(rules: g, topRuleName: 'E', input: s).parse();
      last = '>=${s.length}';
    } on StackOverflowError {
      break;
    }
  }
  out.add('bare parser  $last');

  last = 'none';
  for (final k in [512, 1024, 2048]) {
    final s = oneErr(k);
    try {
      e70.SuperDot3(rules: g, topRuleName: 'E').recoverCost(s);
      last = '>=${s.length}';
    } on StackOverflowError {
      break;
    }
  }
  out.add('m70 recoverCost  $last');

  // And the bare parser again, AFTER the engine has run in this isolate: if its
  // ceiling is unchanged, the stack the engine lost is not the parser's.
  last = 'none';
  for (final k in [512, 1024, 2048, 4096]) {
    final s = oneErr(k);
    try {
      Parser(rules: g, topRuleName: 'E', input: s).parse();
      last = '>=${s.length}';
    } on StackOverflowError {
      break;
    }
  }
  out.add('bare parser, after the engine  $last');
  port.send(<Object>['OK', out.join('\n    ')]);
}

void engJob(List<Object> msg) {
  final port = msg[0] as SendPort;
  ft.measureOne(msg[1] as String, msg[2] as String);
  port.send(<Object>['OK', 'done']);
}

Future<String> spawn(void Function(List<Object>) j, List<Object> extra) async {
  final rp = ReceivePort();
  final iso = await Isolate.spawn(j, <Object>[rp.sendPort, ...extra],
      onError: rp.sendPort, onExit: rp.sendPort);
  try {
    final v = await rp.first.timeout(const Duration(seconds: 300));
    if (v is List && v.length >= 2) return '${v[1]}';
    return 'DIED: $v';
  } on TimeoutException {
    return 'SLOW';
  } finally {
    iso.kill(priority: Isolate.immediate);
    rp.close();
  }
}

Future<void> main(List<String> args) async {
  if (args.isNotEmpty && args.first == 'warm') {
    ft.buildSetup();
    await spawn(engJob, ['m70', 'main']);
    print('WARM (m70 main ran first)\n    ${await spawn(bothJob, [])}');
  } else {
    print('COLD (nothing ran first)\n    ${await spawn(bothJob, [])}');
  }
}
