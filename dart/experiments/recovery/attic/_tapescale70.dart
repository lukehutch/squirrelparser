// _tapescale70.dart -- would catching the verify overflow help?
//
// m70's RR ladder stops at 2048 because `_verify` re-parses the emitted
// witness with the FROZEN parser, and that parser recurses once per position
// on a right-recursive grammar. The engine could catch the overflow and treat
// the witness as unverified, which is the SOUND direction -- an unverified
// witness routes to the tape, and the tape is exact.
//
// Sound, but is it better? Only if the tape can finish a 4096-character input.
// This measures the tape's actual scaling by forcing it: a lookahead makes
// `_wideG` true, so every input goes to the tape and none to the relaxed core.
import 'package:squirrel_parser/squirrel_parser.dart';

import 'm70.dart' as e70;

// The RR ladder grammar with a lookahead bolted on, so the router sends every
// input to the tape. `&[0-9(]` is implied by `F` anyway, so the LANGUAGE is
// unchanged -- only the route is.
const gSrc = "E <- &[0-9(] T '+' E / T;\n"
    "T <- F '*' T / F;\n"
    "F <- [0-9] / '(' E ')';\n";

String oneErr(int k) {
  final c = List.generate(k, (i) => '${i % 10}').join('+');
  return '${c.substring(0, c.length ~/ 2)}+${c.substring(c.length ~/ 2)}';
}

void main() {
  final g = MetaGrammar.parseGrammar(gSrc);
  print('tape forced by a lookahead; one error at the midpoint');
  print('  len     ms   cost  fellBack');
  for (final k in [64, 128, 256, 512, 1024, 2048]) {
    final s = oneErr(k);
    final e = e70.SuperDot3(rules: g, topRuleName: 'E');
    final t = Stopwatch()..start();
    final int c;
    try {
      c = e.recoverCost(s);
    } on StackOverflowError catch (_, st) {
      // WHERE it overflows decides whether this is the carried parser's
      // ceiling (nothing the recovery side can move) or `_tremap`, the one
      // reader I26 did not convert because the tape never runs on the
      // lookahead-free ladder grammars.
      final seen = <String>{};
      final names = <String>[];
      for (final x in st.toString().split('\n')) {
        final mm = RegExp(r'#\d+\s+(\S+)').firstMatch(x);
        if (mm != null && seen.add(mm.group(1)!)) names.add(mm.group(1)!);
      }
      print('  ${s.length.toString().padLeft(5)}  ${t.elapsedMilliseconds}'
          '  STACK OVERFLOW at ${names.take(8).join(" <- ")}');
      continue;
    }
    t.stop();
    print('  ${s.length.toString().padLeft(5)} '
        '${t.elapsedMilliseconds.toString().padLeft(6)} '
        '${c.toString().padLeft(6)}  ${e.lastFellBack}');
    if (t.elapsedMilliseconds > 60000) {
      print('  (already past a minute at len=${s.length}; '
          'len=4096 is out of reach)');
      break;
    }
  }
}
