// _rr70.dart -- why does m70 read RRmax 2048 in the table but >=4096 when the
// ladder is run on its own?
//
// Both harnesses call `recoverCost`, so the difference is the ISOLATE: the
// table measures the depth part in a spawned isolate, which gets a smaller
// stack than the main one. This probe reproduces the table's conditions and
// then asks the question the table cannot: what is still recursing?
//
// The suspect is not the search and not the witness descent -- both are frames
// on the heap now -- but `_verify`, which re-parses the EMITTED string with the
// frozen parser. m62 never verifies, so it never pays this; and the table's own
// `RR` note says what is left at the top of the ladder is "the pure parser's
// own ceiling (k~2100)", which the RR rung k=2048 sits directly beneath.
import 'dart:async';
import 'dart:isolate';

import 'package:squirrel_parser/squirrel_parser.dart';

import 'm62.dart' as e62;
import 'm70.dart' as e70;

String oneErr(int k) {
  final c = List.generate(k, (i) => '${i % 10}').join('+');
  return '${c.substring(0, c.length ~/ 2)}+${c.substring(c.length ~/ 2)}';
}

const gLRsrc = "E <- E '+' T / T;\nT <- T '*' F / F;\nF <- [0-9] / '(' E ')';\n";
const gRRsrc = "E <- T '+' E / T;\nT <- F '*' T / F;\nF <- [0-9] / '(' E ')';\n";

/// `what`: 'pure' the bare frozen parser, 'm62' / 'm70' the engines.
void job(List<Object> msg) {
  final port = msg[0] as SendPort;
  final what = msg[1] as String;
  final gram = msg[2] as String;
  final k = msg[3] as int;
  final s = oneErr(k);
  final g = MetaGrammar.parseGrammar(gram == 'LR' ? gLRsrc : gRRsrc);
  try {
    final Object out;
    if (what == 'pure') {
      final r = Parser(rules: g, topRuleName: 'E', input: s).parse();
      out = 'syntaxErrors=${r.hasSyntaxErrors}';
    } else if (what == 'm62') {
      out = e62.SuperDot3(rules: g, topRuleName: 'E').recoverCost(s);
    } else {
      out = e70.SuperDot3(rules: g, topRuleName: 'E').recoverCost(s);
    }
    port.send(<Object>['OK', '$out']);
  } on StackOverflowError catch (_, st) {
    final seen = <String>{};
    final top = <String>[];
    for (final f in st.toString().split('\n')) {
      final m = RegExp(r'#\d+\s+(\S+)').firstMatch(f);
      if (m == null) continue;
      if (seen.add(m.group(1)!)) top.add(m.group(1)!);
      if (top.length >= 5) break;
    }
    port.send(<Object>['SO', top.join(' <- ')]);
  } catch (e) {
    port.send(<Object>['ERR', e.toString().split('\n').first]);
  }
}

Future<String> run(String what, String gram, int k) async {
  final rp = ReceivePort();
  final iso = await Isolate.spawn(job, <Object>[rp.sendPort, what, gram, k],
      onError: rp.sendPort, onExit: rp.sendPort);
  try {
    final v = await rp.first.timeout(const Duration(seconds: 180));
    if (v is List && v.length >= 2) return '${v[0]}: ${v[1]}';
    return 'DIED';
  } on TimeoutException {
    return 'SLOW';
  } finally {
    iso.kill(priority: Isolate.immediate);
    rp.close();
  }
}

Future<void> main() async {
  print('spawned isolate (the table\'s conditions), rung k -> input length 2k');
  for (final gram in ['LR', 'RR']) {
    for (final k in [1024, 2048]) {
      for (final what in ['pure', 'm62', 'm70']) {
        final r = await run(what, gram, k);
        print('  $gram k=$k len=${2 * k}  ${what.padRight(4)}  $r');
      }
    }
  }
}
