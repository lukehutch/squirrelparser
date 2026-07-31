// _marginal.dart -- is the LR/RR ladder column a threshold or a coin flip?
//
// `_depthrepro` ran the table's OWN `measureOne(name, 'depth')` and got m70
// >=4096 on BOTH ladders, where the official four-engine run printed RRmax 2048
// with the overflow inside `_verify`. Same code, same isolate shape, different
// answer. It also gave m69 RR 1024 where the official run and two bare ladders
// gave 2048.
//
// So the top rung is not a property that either holds or does not; it is a
// single trial of a threshold that sits at the FROZEN PARSER's own ceiling
// (LESSONS records k~2100, and the RR rung k=2048 is directly beneath it). A
// column that reports one trial of a coin flip is the same defect the
// thirty-second occasion named five times: a measurement that fails by printing
// a number instead of by stopping.
//
// This runs the deciding rung N times in a fresh isolate each time and counts.
import 'dart:async';
import 'dart:isolate';

import 'package:squirrel_parser/squirrel_parser.dart';

import 'm62.dart' as e62;
import 'm69.dart' as e69;
import 'm70.dart' as e70;

String oneErr(int k) {
  final c = List.generate(k, (i) => '${i % 10}').join('+');
  return '${c.substring(0, c.length ~/ 2)}+${c.substring(c.length ~/ 2)}';
}

const gLRsrc = "E <- E '+' T / T;\nT <- T '*' F / F;\nF <- [0-9] / '(' E ')';\n";
const gRRsrc = "E <- T '+' E / T;\nT <- F '*' T / F;\nF <- [0-9] / '(' E ')';\n";

/// The rung is run after the LOWER rungs of the same ladder, exactly as
/// `depthLimit` does -- reaching 4096 always means 256/512/1024/2048 ran first
/// in the same isolate.
void job(List<Object> msg) {
  final port = msg[0] as SendPort;
  final name = msg[1] as String;
  final gram = msg[2] as String;
  final top = msg[3] as int;
  final g = MetaGrammar.parseGrammar(gram == 'LR' ? gLRsrc : gRRsrc);
  int cost(String s) => switch (name) {
        'm62' => e62.SuperDot3(rules: g, topRuleName: 'E').recoverCost(s),
        'm69' => e69.SuperDot3(rules: g, topRuleName: 'E').recoverCost(s),
        _ => e70.SuperDot3(rules: g, topRuleName: 'E').recoverCost(s),
      };
  for (final k in [256, 512, 1024, 2048]) {
    if (2 * k > top) break;
    try {
      cost(oneErr(k));
    } on StackOverflowError catch (_, st) {
      final m = RegExp(r'#\d+\s+(\S+)').firstMatch(st.toString());
      port.send(<Object>['SO', '${2 * k}@${m?.group(1)}']);
      return;
    } catch (e) {
      port.send(<Object>['ERR', '${2 * k}@${e.runtimeType}']);
      return;
    }
  }
  port.send(<Object>['OK', '$top']);
}

Future<(String, String)> once(String name, String gram, int top) async {
  final rp = ReceivePort();
  final iso = await Isolate.spawn(job, <Object>[rp.sendPort, name, gram, top],
      onError: rp.sendPort, onExit: rp.sendPort);
  try {
    final v = await rp.first.timeout(const Duration(seconds: 300));
    if (v is List && v.length >= 2) return ('${v[0]}', '${v[1]}');
    return ('DIED', '$v');
  } on TimeoutException {
    return ('SLOW', '');
  } finally {
    iso.kill(priority: Isolate.immediate);
    rp.close();
  }
}

Future<void> main(List<String> argv) async {
  final n = argv.isEmpty ? 10 : int.parse(argv[0]);
  print('$n trials per cell, one fresh isolate each, lower rungs run first');
  print('engine gram  top   reached/$n  overflow sites');
  for (final (name, gram, top) in const <(String, String, int)>[
    ('m62', 'RR', 4096),
    ('m69', 'LR', 4096),
    ('m69', 'RR', 4096),
    ('m70', 'LR', 4096),
    ('m70', 'RR', 4096),
  ]) {
    var ok = 0;
    final sites = <String, int>{};
    for (var i = 0; i < n; i++) {
      final (tag, detail) = await once(name, gram, top);
      if (tag == 'OK') {
        ok++;
      } else {
        sites['$tag $detail'] = (sites['$tag $detail'] ?? 0) + 1;
      }
    }
    final s = sites.entries.map((e) => '${e.key} x${e.value}').join(', ');
    print('${name.padRight(6)} ${gram.padRight(4)} ${top.toString().padLeft(4)}'
        '   ${ok.toString().padLeft(2)}/$n        ${s.isEmpty ? '-' : s}');
  }
}
