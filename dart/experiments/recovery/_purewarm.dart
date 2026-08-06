// _purewarm.dart -- `_warm70` located m70's RRmax discrepancy outside the
// engine. Three conditions, each a separate process:
//
//   A  spawn the depth isolate only                      >=4096 / >=4096
//   B  buildSetup() in the parent, then depth            >=4096 / >=4096
//   C  buildSetup(), then main, lat, depth (the table)   >=4096 /   2048
//
// So the RR ceiling appears only after other isolates in the SAME ISOLATE GROUP
// have run. Dart isolates spawned with `Isolate.spawn` share the group's JIT
// code cache, so by the time the depth ladder runs, `Parser.match`, `Seq.match`,
// `First.match` and `Ref.match` are optimized -- and an optimized frame is not
// the same size as an unoptimized one. If that is the mechanism, then the
// FROZEN PARSER ON ITS OWN must show the same split, with no engine involved.
//
// This measures exactly that: the bare `Parser(...).parse()` on the RR ladder
// grammar at len=4096, cold and warm, plus which of `main`/`lat` is doing the
// warming.
import 'dart:async';
import 'dart:isolate';

import 'package:squirrel_parser/squirrel_parser.dart';

import 'final_table.dart' as ft;

String oneErr(int k) {
  final c = List.generate(k, (i) => '${i % 10}').join('+');
  return '${c.substring(0, c.length ~/ 2)}+${c.substring(c.length ~/ 2)}';
}

const gRRsrc = "E <- T '+' E / T;\nT <- F '*' T / F;\nF <- [0-9] / '(' E ')';\n";

/// The bare frozen parser climbing the RR ladder. No engine, no recovery.
void pureJob(List<Object> msg) {
  final port = msg[0] as SendPort;
  final g = MetaGrammar.parseGrammar(gRRsrc);
  var last = 'none';
  for (final k in [256, 512, 1024, 2048, 4096]) {
    final s = oneErr(k);
    try {
      Parser(rules: g, topRuleName: 'E', input: s).parse();
      last = '>=${s.length}';
    } on StackOverflowError {
      port.send(<Object>['OK', 'pure parser tops out at $last']);
      return;
    }
  }
  port.send(<Object>['OK', 'pure parser tops out at $last']);
}

void engJob(List<Object> msg) {
  final port = msg[0] as SendPort;
  final out = ft.measureOne(msg[1] as String, msg[2] as String);
  port.send(<Object>['OK', out.length > 2 ? '${out[1]} / ${out[2]}' : 'done']);
}

Future<String> spawn(void Function(List<Object>) j, List<Object> extra) async {
  final rp = ReceivePort();
  final iso = await Isolate.spawn(j, <Object>[rp.sendPort, ...extra],
      onError: rp.sendPort, onExit: rp.sendPort);
  try {
    final v = await rp.first.timeout(const Duration(seconds: 300));
    if (v is List && v.length >= 2) return '${v[1]}';
    return 'DIED';
  } on TimeoutException {
    return 'SLOW';
  } finally {
    iso.kill(priority: Isolate.immediate);
    rp.close();
  }
}

Future<void> main(List<String> args) async {
  final mode = args.isEmpty ? 'cold' : args.first;
  switch (mode) {
    case 'cold':
      print('cold  (nothing run first)            : ${await spawn(pureJob, [])}');
    case 'warm':
      ft.buildSetup();
      await spawn(engJob, ['m70', 'main']);
      await spawn(engJob, ['m70', 'lat']);
      print('warm  (m70 main + lat run first)     : ${await spawn(pureJob, [])}');
    case 'warmmain':
      ft.buildSetup();
      await spawn(engJob, ['m70', 'main']);
      print('warm  (m70 main only)                : ${await spawn(pureJob, [])}');
    case 'warmlat':
      ft.buildSetup();
      await spawn(engJob, ['m70', 'lat']);
      print('warm  (m70 lat only)                 : ${await spawn(pureJob, [])}');
    case 'depthmain':
      ft.buildSetup();
      await spawn(engJob, ['m70', 'main']);
      print('m70 depth after main only            : '
          '${await spawn(engJob, ["m70", "depth"])}');
    case 'depthlat':
      ft.buildSetup();
      await spawn(engJob, ['m70', 'lat']);
      print('m70 depth after lat only             : '
          '${await spawn(engJob, ["m70", "depth"])}');
  }
}
