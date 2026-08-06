// Re-verification of the three cgfr2 defects claimed in occasion 31.
// Each case runs in its own isolate with a hard timeout, so a divergence is
// observed as a timeout rather than hanging the harness.
import 'dart:async';
import 'dart:isolate';
import 'package:squirrel_parser/squirrel_parser.dart';
import 'cgfr2.dart' as c2;
import 'cgfr4.dart' as c4;
import 'cgfr5.dart' as c5;
import 'm69.dart' as m69;

final cases = <(String, String, String, String)>[
  ('defect 1/2: possessive star', "S <- 'a'* \"ab\";\n", 'S', 'aab'),
  ('committed choice (works)', "S <- ('a' / \"ab\") 'b';\n", 'S', 'abb'),
  ('defect 3: positive lookahead', "S <- &[a-z] [a-z];\n", 'S', 'Q'),
  ('defect 3: lookahead, empty', "S <- &[a-z] [a-z];\n", 'S', ''),
  ('I25: intersection', "S <- &[a-z] [0-9m-q];\n", 'S', 'Z'),
];

void _work(List<Object> msg) {
  final port = msg[0] as SendPort;
  final which = msg[1] as String, g = msg[2] as String;
  final top = msg[3] as String, s = msg[4] as String;
  final r = MetaGrammar.parseGrammar(g);
  final cost = switch (which) {
    'cgfr2' => c2.SuperDot3(rules: r, topRuleName: top).recoverCost(s),
    'cgfr4' => c4.SuperDot3(rules: r, topRuleName: top).recoverCost(s),
    'cgfr5' => c5.SuperDot3(rules: r, topRuleName: top).recoverCost(s),
    _ => m69.SuperDot3(rules: r, topRuleName: top).recoverCost(s),
  };
  port.send(cost);
}

Future<String> run(String which, String g, String top, String s) async {
  final rp = ReceivePort();
  final iso = await Isolate.spawn(_work, [rp.sendPort, which, g, top, s],
      onError: rp.sendPort, onExit: rp.sendPort);
  try {
    final v = await rp.first.timeout(const Duration(seconds: 12));
    return v == null ? 'crash' : '$v';
  } on TimeoutException {
    return 'HANG';
  } finally {
    iso.kill(priority: Isolate.immediate);
    rp.close();
  }
}

void main() async {
  print('case                          cgfr2  cgfr4  cgfr5   m69');
  for (final (name, g, top, s) in cases) {
    final out = <String>[];
    for (final e in ['cgfr2', 'cgfr4', 'cgfr5', 'm69']) {
      out.add((await run(e, g, top, s)).padLeft(6));
    }
    print('${name.padRight(29)}${out.join(' ')}');
  }
}
