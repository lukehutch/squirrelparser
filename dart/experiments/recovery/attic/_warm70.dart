// _warm70.dart -- m70's RRmax reads 2048 under `dart final_table.dart m70` in
// 3/3 official runs, and >=4096 under every standalone probe. `_depthrepro`
// already ruled out the ladder code and the setup allocation INSIDE the depth
// isolate. What it did not replicate is what the table does BEFORE that isolate
// exists: the parent calls `buildSetup()` at line 1522, and for the same engine
// the `main` and `lat` isolates have already run to completion in the same
// isolate group.
//
// Dart isolates spawned with `Isolate.spawn` share the group's code cache, so
// by the time the depth isolate runs, `Parser.match`, `Seq.match` and the engine
// are already JIT-optimized -- and an optimized frame is not the same size as an
// unoptimized one. This walks the difference in three steps:
//
//   A  spawn depth only                        (what `_depthrepro` did)
//   B  buildSetup() in the parent, then depth  (adds the parent's heap)
//   C  buildSetup(), main, lat, then depth     (exactly the table)
//
// C reproducing 2048 while A gives >=4096 locates the cause outside the engine.
// B then splits it: parent heap, or prior JIT warmth.
import 'dart:async';
import 'dart:isolate';

import 'final_table.dart' as ft;

void job(List<Object> msg) {
  final port = msg[0] as SendPort;
  try {
    final out = ft.measureOne(msg[1] as String, msg[2] as String);
    port.send(<Object>['OK', out.length > 2 ? '${out[1]} / ${out[2]}' : 'done']);
  } catch (e) {
    port.send(<Object>['ERR', e.toString().split('\n').first]);
  }
}

Future<String> part(String name, String which) async {
  final rp = ReceivePort();
  final iso = await Isolate.spawn(job, <Object>[rp.sendPort, name, which],
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
  final names = args.isEmpty ? ['m70'] : args.first.split(',');
  final mode = args.length > 1 ? args[1] : 'ABC';
  for (final name in names) {
    if (mode.contains('A')) {
      print('$name  A  depth only                 : ${await part(name, "depth")}');
    }
    if (mode.contains('B')) {
      ft.buildSetup();
      print('$name  B  parent buildSetup + depth  : ${await part(name, "depth")}');
    }
    if (mode.contains('C')) {
      ft.buildSetup();
      await part(name, 'main');
      await part(name, 'lat');
      print('$name  C  buildSetup, main, lat, depth: ${await part(name, "depth")}');
    }
  }
}
