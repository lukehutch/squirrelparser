// _veto77.dart -- the certificate already knows; does acting on it help?
//
// _starwide77 showed m75 and m77 returning finite costs on the EMPTY-language
// grammar ("ab")* "abc" while reporting `lastVerified=false` on every one of
// them. So the certificate detects D-A's unsoundness and the cost path throws
// the detection away: `recoverCost` runs a relaxed pass, and if that fails to
// certify runs a tight pass and returns it UNCONDITIONALLY (m77.dart:1175-1183).
//
// That suggests a one-line fix. It is not obviously a good one: an uncertified
// answer means "the repair I found does not parse", NOT "no repair exists", so
// vetoing to -1 trades a too-high answer for a possibly-false -1. Which way it
// nets out is an empirical question, so this measures it instead of arguing it.
//
// Scored on the same 2387 strings as _wrong77, under two policies:
//   A  as returned                     (what m77 does today)
//   B  lastVerified ? cost : -1        (veto the uncertified answer)
//
// NOTE this is a HARNESS-side experiment. m77.dart is not modified.
import 'package:squirrel_parser/squirrel_parser.dart';

import '_subset75.dart' show grammars, trueDist;
import 'm77.dart' as chase;

class Tally {
  var wrong = 0, tooLow = 0, tooHigh = 0, falseImpossible = 0;
  void score(int? truth, int c) {
    final ok = truth == null ? (c > 3 || c == -1) : c == truth;
    if (ok) return;
    wrong++;
    if (truth == null) {
      if (c >= 0 && c <= 3) {
        tooLow++;
      } else {
        tooHigh++;
      }
    } else if (c == -1) {
      falseImpossible++;
    } else if (c < truth) {
      tooLow++;
    } else {
      tooHigh++;
    }
  }

  String get row => '${wrong.toString().padLeft(4)}  '
      'low=${tooLow.toString().padLeft(3)}  '
      'high=${tooHigh.toString().padLeft(3)}  '
      'false-1=${falseImpossible.toString().padLeft(3)}';
}

void main() {
  final a = Tally(), b = Tally();
  var checked = 0, uncertified = 0, uncertifiedAndRight = 0;
  // Where the veto CHANGES the verdict, which way did it go?
  var rescued = 0, broken = 0;
  final examples = <String>[];
  for (final (g, top, alpha) in grammars) {
    final r = MetaGrammar.parseGrammar(g);
    final e = chase.SuperDot3(rules: r, topRuleName: top);
    final strings = <String>[''];
    for (var len = 1; len <= 5; len++) {
      for (final p in strings.where((s) => s.length == len - 1).toList()) {
        for (final ch in alpha.split('')) {
          strings.add(p + ch);
        }
      }
    }
    for (final s in strings) {
      final truth = trueDist(r, top, s, alpha, 3);
      final c = e.recoverCost(s);
      final v = e.lastVerified;
      final c2 = v ? c : -1;
      checked++;
      a.score(truth, c);
      b.score(truth, c2);
      if (!v) {
        uncertified++;
        final okA = truth == null ? (c > 3 || c == -1) : c == truth;
        if (okA) uncertifiedAndRight++;
        final okB = truth == null ? (c2 > 3 || c2 == -1) : c2 == truth;
        if (!okA && okB) rescued++;
        if (okA && !okB) {
          broken++;
          if (examples.length < 8) {
            examples.add('"$s"  true=${truth ?? ">3"}  m77=$c  -> vetoed to -1'
                '   ${g.replaceAll('\n', ' ').trim()}');
          }
        }
      }
    }
  }
  print('checked=$checked');
  print('uncertified answers                = $uncertified');
  print('  of those, ALREADY correct        = $uncertifiedAndRight'
      '   <-- the veto would break these');
  print('');
  print('A  as returned (today)   ${a.row}');
  print('B  veto to -1            ${b.row}');
  print('');
  print('veto rescued $rescued, broke $broken');
  if (examples.isNotEmpty) {
    print('\nbroken by the veto:');
    for (final x in examples) {
      print('  $x');
    }
  }
}
