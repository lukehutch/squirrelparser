// _gate77.dart -- a gate that can actually SEE D-A. The current one cannot.
//
// _veto77 measured the subset gate's residual as 98 wrong of 2387 with `tooLow`
// = 0. Zero. The gate never once catches the engine accepting a repair that does
// not exist -- yet _starwide77 shows m75 and m77 returning 3/2/0/0/1 on the
// EMPTY-language grammar ("ab")* "abc". The gate stays green while the defect is
// present, which proves the case is untested, not that it works.
//
// The reason is visible in _subset75's grammar list: its one empty-language
// grammar is 'a'* "ab", whose star body is ONE character, so `_oneCharClass` is
// not null and the obligation is really carried. Every multi-character body is
// missing, and that is exactly where `_notFirst` falls back to `_free`.
//
// So this is the same harness over a superset of the grammars: all 14 from
// _subset75 plus nine chosen to make both faces of D-A observable ---
//
//   UNDER-restriction (accepts a repair that does not exist) needs a star whose
//   FOLLOWER BEGINS WITH THE STAR'S BODY, so possessiveness has to be proved,
//   with a body longer than one character.
//
//   OVER-restriction (misses a repair that does exist) needs a MULTI-CHARACTER
//   LOOKAHEAD BODY, where `_looks` returns null and m77.dart:489-493 falls back
//   to matching `node.orig` against the ORIGINAL input via `_parser`
//   (m77.dart:1194), so no repair can ever satisfy it.
//
// RED BEFORE GREEN: this is expected to fail on m75 and m77 today. It is the
// scoreboard for a D-A fix, not a claim that one exists.
import 'package:squirrel_parser/squirrel_parser.dart';

import '_subset75.dart' show grammars, trueDist;
import 'm75.dart' as e75;
import 'm77.dart' as e77;

/// Multi-character star bodies and lookahead bodies -- the shapes `_oneCharClass`
/// cannot describe. Truth comes from brute-force enumeration either way, so a
/// grammar with an empty language is scored as honestly as any other.
final extra = <(String, String, String, String)>[
  // --- possessive star, follower overlaps the body: UNDER-restriction ---
  ("S <- (\"ab\")* \"abc\";\n", 'S', 'abc', 'EMPTY: follower begins with body'),
  ("S <- (\"ab\")* \"aba\";\n", 'S', 'ab', 'EMPTY: follower begins with body'),
  ("S <- (\"ab\")* 'a';\n", 'S', 'ab', 'non-empty control, multi-char body'),
  ("S <- (\"ab\")* !.;\n", 'S', 'ab', 'non-empty control, EOF follower'),
  ("S <- (\"ab\")* \"cd\";\n", 'S', 'abcd', 'non-empty control, disjoint'),
  // --- multi-character lookahead bodies, both polarities: OVER-restriction ---
  ("S <- !(\"ab\") 'a' 'c';\n", 'S', 'abc', 'NEGATIVE multi-char lookahead'),
  ("S <- &(\"ab\") 'a' 'b' 'c';\n", 'S', 'abc', 'POSITIVE multi-char lookahead'),
  ("S <- (A / 'a') 'b';\nA <- 'a' &(\"bb\");\n", 'S', 'ab',
      'multi-char lookahead inside a choice'),
  ("S <- !(\"ab\" \"cd\") 'a' 'b';\n", 'S', 'abcd', 'Seq lookahead body'),
];

class Tally {
  final String name;
  var wrong = 0, tooLow = 0, tooHigh = 0, falseImpossible = 0, checked = 0;
  Tally(this.name);

  bool score(int? truth, int c) {
    checked++;
    final ok = truth == null ? (c > 3 || c == -1) : c == truth;
    if (ok) return true;
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
    return false;
  }

  String get row => '${name.padRight(5)} '
      'wrong=${wrong.toString().padLeft(4)} / $checked   '
      'LOW=${tooLow.toString().padLeft(3)}  '
      'high=${tooHigh.toString().padLeft(3)}  '
      'false-1=${falseImpossible.toString().padLeft(3)}';
}

List<String> enumerate(String alpha, int maxLen) {
  final out = <String>[''];
  for (var len = 1; len <= maxLen; len++) {
    for (final p in out.where((s) => s.length == len - 1).toList()) {
      for (final ch in alpha.split('')) {
        out.add(p + ch);
      }
    }
  }
  return out;
}

void main() {
  final all = <(String, String, String, String)>[
    for (final (g, t, a) in grammars) (g, t, a, 'inherited from _subset75'),
    ...extra,
  ];

  final t75 = Tally('m75'), t77 = Tally('m77');
  // Only the added grammars, so the new signal is not diluted by the old ones.
  final x75 = Tally('m75+'), x77 = Tally('m77+');
  final worst = <String>[];

  for (final (g, top, alpha, note) in all) {
    final isNew = note != 'inherited from _subset75';
    final r = MetaGrammar.parseGrammar(g);
    final a = e75.SuperDot3(rules: r, topRuleName: top);
    final b = e77.SuperDot3(rules: r, topRuleName: top);
    // Per-grammar counts come from a Tally too. Hand-rolling the direction test
    // here got it wrong once: `c < truth` is also true when c is -1, which
    // silently reported every false -1 as an unsound too-low answer.
    final per = Tally(top);
    var n = 0;
    for (final s in enumerate(alpha, 5)) {
      final truth = trueDist(r, top, s, alpha, 3);
      final c75 = a.recoverCost(s);
      final c77 = b.recoverCost(s);
      t75.score(truth, c75);
      t77.score(truth, c77);
      per.score(truth, c77);
      if (isNew) {
        x75.score(truth, c75);
        x77.score(truth, c77);
      }
      n++;
    }
    if (per.wrong > 0) {
      worst.add('${per.wrong.toString().padLeft(4)}/$n wrong   '
          'LOW=${per.tooLow.toString().padLeft(3)} '
          'high=${per.tooHigh.toString().padLeft(3)} '
          'false-1=${per.falseImpossible.toString().padLeft(3)}'
          '   ${g.replaceAll('\n', ' ').trim()}'
          '${isNew ? "   [NEW: $note]" : ""}');
    }
  }

  print('=== all ${all.length} grammars ===');
  print(t75.row);
  print(t77.row);
  print('\n=== the ${extra.length} added grammars only ===');
  print(x75.row);
  print(x77.row);
  print('\nper-grammar residual, worst first:');
  worst.sort((p, q) => q.compareTo(p));
  for (final w in worst) {
    print('  $w');
  }
  print('\nTOO LOW is the number that matters here: it is the count of repairs');
  print('the engine claims exist and do not. The old gate reports 0 because it');
  print('contains no grammar that can exhibit one.');
}
