// _conf71.dart -- _conf70's cases and truths, with m71 added.
//
// `final_table.dart` prints shape/cover/bmin/cost/tree/pred, and every one of
// those is measured against a CFG-flavoured truth or a brute force over the
// relaxed reading. NONE of them asks the question m66-m69 exist to answer:
// does the engine agree with the TRUE PEG language, where the committed
// choice and the possessive star make the CFG reading wrong?
//
// So the table cannot distinguish m62 (789 LOC, 208ms, >=4096 both ladders)
// from m68 (1134 LOC, 219ms, 1024/2048) on the one axis that separates them.
// This gate is that axis, run over every engine the m70 study covers, so the
// tradeoff is a measurement rather than a recollection.
//
// Cases and truths are `_conf69.dart`'s, unchanged: brute-force distance to
// the true PEG language, null = no repair within 3 edits.
import 'dart:async';
import 'dart:isolate';

import 'package:squirrel_parser/squirrel_parser.dart';

import 'm50.dart' as e50;
import 'm51.dart' as e51;
import 'm52.dart' as e52;
import 'm53.dart' as e53;
import 'm57.dart' as e57;
import 'm60.dart' as e60;
import 'm62.dart' as e62;
import 'm64.dart' as e64;
import 'm66.dart' as e66;
import 'm67.dart' as e67;
import 'm68.dart' as e68;
import 'm69.dart' as e69;
import 'cgfr5.dart' as ecg5;
import 'm70.dart' as e70;
import 'm71.dart' as e71;
import 'm72.dart' as e72;

typedef Cost = int Function(Map<String, Clause> rules, String top, String s);

Cost _c(int Function(Map<String, Clause>, String, String) f) => f;

final engines = <String, Cost>{
  'm50': (r, t, s) => e50.SuperDot3(rules: r, topRuleName: t).recoverCost(s),
  'm51': (r, t, s) => e51.SuperDot3(rules: r, topRuleName: t).recoverCost(s),
  'm52': (r, t, s) => e52.SuperDot3(rules: r, topRuleName: t).recoverCost(s),
  'm53': (r, t, s) => e53.SuperDot3(rules: r, topRuleName: t).recoverCost(s),
  'm57': (r, t, s) => e57.SuperDot3(rules: r, topRuleName: t).recoverCost(s),
  'm60': (r, t, s) => e60.SuperDot3(rules: r, topRuleName: t).recoverCost(s),
  'm62': (r, t, s) => e62.SuperDot3(rules: r, topRuleName: t).recoverCost(s),
  'm64': (r, t, s) => e64.SuperDot3(rules: r, topRuleName: t).recoverCost(s),
  'm66': (r, t, s) => e66.SuperDot3(rules: r, topRuleName: t).recoverCost(s),
  'm67': (r, t, s) => e67.SuperDot3(rules: r, topRuleName: t).recoverCost(s),
  'm68': (r, t, s) => e68.SuperDot3(rules: r, topRuleName: t).recoverCost(s),
  'm69': (r, t, s) => e69.SuperDot3(rules: r, topRuleName: t).recoverCost(s),
  'cgfr5': (r, t, s) => ecg5.SuperDot3(rules: r, topRuleName: t).recoverCost(s),
  'm70': (r, t, s) => e70.SuperDot3(rules: r, topRuleName: t).recoverCost(s),
  'm71': (r, t, s) => e71.SuperDot3(rules: r, topRuleName: t).recoverCost(s),
  'm72': (r, t, s) => e72.SuperDot3(rules: r, topRuleName: t).recoverCost(s),
};

final cases = <(String, String, String, String, int?)>[
  ('possessive star', "S <- 'a'* \"ab\";\n", 'S', 'aab', null),
  ('possessive star+', "S <- 'a'* \"ab\";\n", 'S', 'aaaab', null),
  ('committed choice', "S <- ('a' / \"ab\") 'b';\n", 'S', 'abb', 1),
  ('committed nested', "S <- A 'c';\nA <- 'a' / \"ab\";\n", 'S', 'abc', 1),
  ('greedy optional', "S <- 'a'? \"ab\";\n", 'S', 'aab', 0),
];

/// One (engine, case) pair, in its own isolate under its own cap, because a
/// tape engine on a case with an EMPTY true language is exactly where a
/// non-terminating search shows up.
void oneIso(List<Object> msg) {
  final port = msg[0] as SendPort;
  final name = msg[1] as String;
  final idx = msg[2] as int;
  try {
    final (_, g, top, s, _) = cases[idx];
    final r = MetaGrammar.parseGrammar(g);
    port.send(<Object>['OK', engines[name]!(r, top, s)]);
  } catch (e) {
    port.send(<Object>['ERR', '$e']);
  }
}

Future<String> run(String name, int idx, Duration cap) async {
  final rp = ReceivePort();
  final iso = await Isolate.spawn(oneIso, <Object>[rp.sendPort, name, idx],
      onError: rp.sendPort, onExit: rp.sendPort);
  try {
    final v = await rp.first.timeout(cap);
    if (v is List && v.isNotEmpty && v.first == 'OK') return '${v[1]}';
    if (v is List && v.isNotEmpty && v.first == 'ERR') {
      final m = '${v[1]}';
      return m.contains('tack') && m.contains('verflow') ? 'SO' : 'ERR';
    }
    return 'DIED';
  } on TimeoutException {
    return 'SLOW';
  } finally {
    iso.kill(priority: Isolate.immediate);
    rp.close();
  }
}

Future<void> main(List<String> args) async {
  final cap = Duration(seconds: int.parse(args.isNotEmpty ? args[0] : '60'));
  final want = [for (final (_, _, _, _, t) in cases) t?.toString() ?? '-1'];
  print('true-PEG conformance, one isolate per cell, cap ${cap.inSeconds}s');
  print('truth   ${[for (final w in want) w.padLeft(6)].join()}');
  print('engine  ${[
    for (final (n, _, _, _, _) in cases) n.split(' ').last.padLeft(6)
  ].join()}   conf');
  for (final name in engines.keys) {
    final cells = <String>[];
    var ok = 0;
    for (var i = 0; i < cases.length; i++) {
      final got = await run(name, i, cap);
      cells.add(got);
      if (got == want[i]) ok++;
    }
    print('${name.padRight(7)} ${[
      for (final c in cells) c.padLeft(6)
    ].join()}    $ok/5');
  }
}
