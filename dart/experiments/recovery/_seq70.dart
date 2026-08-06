// _seq70.dart -- the table's depth part, reproduced exactly, with the error
// PRINTED instead of swallowed.
//
// `final_table.dart`'s `depthLimit` runs the LR ladder and then the RR ladder
// in ONE spawned isolate, and its handler is
//
//     } on StackOverflowError { return last; }
//     catch (_)               { return last; }
//
// so ANY throw -- out of memory, a range error, anything -- is reported in the
// LRmax/RRmax column as though it were a depth ceiling. A rung that fails for a
// reason having nothing to do with stack depth is indistinguishable from one
// that overflowed. That is a pre-existing flaw in the column, and it is why
// m70 reads 2048 here and >=4096 when the same ladder is run on its own.
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

int cost(String eng, Map<String, Clause> g, String s) => eng == 'm62'
    ? e62.SuperDot3(rules: g, topRuleName: 'E').recoverCost(s)
    : e70.SuperDot3(rules: g, topRuleName: 'E').recoverCost(s);

void job(List<Object> msg) {
  final port = msg[0] as SendPort;
  final eng = msg[1] as String;
  final log = <String>[];
  for (final gram in ['LR', 'RR']) {
    final g = MetaGrammar.parseGrammar(gram == 'LR' ? gLRsrc : gRRsrc);
    for (final k in [256, 512, 1024, 2048]) {
      final s = oneErr(k);
      try {
        final c = cost(eng, g, s);
        log.add('$gram len=${s.length} OK cost=$c');
      } on StackOverflowError catch (_, st) {
        final m = RegExp(r'#\d+\s+(\S+)').firstMatch(st.toString());
        log.add('$gram len=${s.length} STACK OVERFLOW at ${m?.group(1)}');
        break;
      } catch (e) {
        // The case `depthLimit` cannot tell apart from an overflow.
        log.add('$gram len=${s.length} THREW ${e.runtimeType}: '
            '${e.toString().split('\n').first}');
        break;
      }
    }
  }
  port.send(<Object>['OK', log]);
}

Future<void> one(String eng) async {
  final rp = ReceivePort();
  final iso = await Isolate.spawn(job, <Object>[rp.sendPort, eng],
      onError: rp.sendPort, onExit: rp.sendPort);
  try {
    final v = await rp.first.timeout(const Duration(seconds: 600));
    print('$eng:');
    if (v is List && v.length >= 2 && v[1] is List) {
      for (final l in v[1] as List) {
        print('  $l');
      }
    } else {
      print('  DIED: $v');
    }
  } on TimeoutException {
    print('$eng: SLOW (>600s)');
  } finally {
    iso.kill(priority: Isolate.immediate);
    rp.close();
  }
}

Future<void> main() async {
  print('LR ladder then RR ladder, one spawned isolate, errors printed');
  for (final eng in ['m62', 'm70']) {
    await one(eng);
  }
}
