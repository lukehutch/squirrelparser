// _restart72.dart -- is the ordered-insert restart guard actually doing work?
//
// I30 keeps every answer list in split order, and an ordered insertion can land
// BEHIND a parked `_Cons` frame's cursor where an appended one never could, so
// the frame restarts its walk whenever the head list has grown. The guard is
// correct, but it fires on ANY growth including a pure append, and a restart
// re-offers every split before the cursor. This counts what it costs on the
// same corpus the `latms` column times.
import 'package:squirrel_parser/squirrel_parser.dart';

import 'final_table.dart' show jsonGrammar;
import '_lat72.dart' show latCases;
import '_m72cnt.dart' as cnt;

void main() {
  final rules = MetaGrammar.parseGrammar(jsonGrammar);
  final cases = latCases();
  print('case  len  resumes  restarts  offers   inserts  appends');
  var tR = 0, tX = 0, tO = 0, tI = 0, tA = 0;
  for (var i = 0; i < cases.length; i++) {
    cnt.SuperDot3.cResume = 0;
    cnt.SuperDot3.cRestart = 0;
    cnt.SuperDot3.cOffer = 0;
    cnt.SuperDot3.cIns = 0;
    final e = cnt.SuperDot3(rules: rules, topRuleName: 'JSON');
    e.recoverCost(cases[i]);
    final r = cnt.SuperDot3.cResume,
        x = cnt.SuperDot3.cRestart,
        o = cnt.SuperDot3.cOffer,
        ins = cnt.SuperDot3.cIns,
        ap = cnt.SuperDot3.cApp;
    tR += r;
    tX += x;
    tO += o;
    tI += ins;
    tA += ap;
    print('${i.toString().padLeft(4)} ${cases[i].length.toString().padLeft(4)} '
        '${r.toString().padLeft(8)} ${x.toString().padLeft(9)} '
        '${o.toString().padLeft(7)} ${ins.toString().padLeft(9)} '
        '${ap.toString().padLeft(8)}');
  }
  print('TOTAL      ${tR.toString().padLeft(8)} ${tX.toString().padLeft(9)} '
      '${tO.toString().padLeft(7)} ${tI.toString().padLeft(9)} '
      '${tA.toString().padLeft(8)}');
  print('');
  print('_keepBest calls      = ${cnt.SuperDot3.cCall}');
  print('elements scanned     = ${cnt.SuperDot3.cScan}');
  print('mean scan length     = ${(cnt.SuperDot3.cScan / cnt.SuperDot3.cCall).toStringAsFixed(2)} entries');
  print('max list length      = ${cnt.SuperDot3.cMaxLen} entries');
  print('elements shifted     = ${cnt.SuperDot3.cShift}');
  print('shift / scan         = ${(cnt.SuperDot3.cShift / cnt.SuperDot3.cScan).toStringAsFixed(3)}');
  final h = cnt.SuperDot3.cHist;
  final tot = h.fold(0, (a, b) => a + b);
  var acc = 0;
  for (var i = 0; i < 64; i++) {
    if (h[i] == 0) continue;
    acc += h[i];
    if (i < 12 || i == 63) {
      print('  len ${i.toString().padLeft(2)}  ${h[i].toString().padLeft(9)}'
          '  ${(100 * acc / tot).toStringAsFixed(1)}% cum');
    }
  }
  print('');
  print('restarts / resumes = ${(tX / tR).toStringAsFixed(4)}');
  print('inserts / (ins+app) = ${(tI / (tI + tA)).toStringAsFixed(4)}');
}
