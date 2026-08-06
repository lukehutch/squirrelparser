// _confg.dart -- _conf72's cases against the guarded-first candidate.
//
// `_tight72` read 0 tighten re-runs over 519 battery inputs and 12 latency
// cases, but JSON is not where I28's tighten was built to fire -- these five
// cases are. So the certificate is NOT dead code, and the question is narrower:
// if the tighten's own answer is the one that passes this gate, is starting
// guarded equivalent to relaxing and being sent back?
//
//   cert       relaxed, certificate demanded, tighten on failure  (shipped m72)
//   nocert     relaxed, certificate skipped     -- expected to FAIL, the control
//   guard      guarded from the start, no certificate             (the candidate)
//   guardcert  guarded from the start, certificate still demanded
import 'dart:async';
import 'dart:isolate';

import 'package:squirrel_parser/squirrel_parser.dart';

import 'm62.dart' as e62;
import 'm72.dart' as e72;
import '_m72cnt.dart' as cnt;

typedef Cost = int Function(Map<String, Clause> rules, String top, String s);

int _cnt(Map<String, Clause> r, String t, String s, bool sc, bool fg,
    [bool sv = false]) {
  cnt.SuperDot3.skipCert = sc;
  cnt.SuperDot3.forceGuard = fg;
  cnt.SuperDot3.skipVerify = sv;
  return cnt.SuperDot3(rules: r, topRuleName: t).recoverCost(s);
}

final engines = <String, Cost>{
  'm62': (r, t, s) => e62.SuperDot3(rules: r, topRuleName: t).recoverCost(s),
  'cert': (r, t, s) => e72.SuperDot3(rules: r, topRuleName: t).recoverCost(s),
  'nocert': (r, t, s) => _cnt(r, t, s, true, false),
  'guard': (r, t, s) => _cnt(r, t, s, true, true),
  'guardcert': (r, t, s) => _cnt(r, t, s, false, true),
  'nverify': (r, t, s) => _cnt(r, t, s, false, false, true),
};

final cases = <(String, String, String, String, int?)>[
  ('possessive star', "S <- 'a'* \"ab\";\n", 'S', 'aab', null),
  ('possessive star+', "S <- 'a'* \"ab\";\n", 'S', 'aaaab', null),
  ('committed choice', "S <- ('a' / \"ab\") 'b';\n", 'S', 'abb', 1),
  ('committed nested', "S <- A 'c';\nA <- 'a' / \"ab\";\n", 'S', 'abc', 1),
  ('greedy optional', "S <- 'a'? \"ab\";\n", 'S', 'aab', 0),
];

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
  print('truth      ${[for (final w in want) w.padLeft(6)].join()}');
  print('engine     ${[
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
    print('${name.padRight(10)} ${[
      for (final c in cells) c.padLeft(6)
    ].join()}    $ok/5');
  }
}
