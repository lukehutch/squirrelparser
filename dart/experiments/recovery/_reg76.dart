// _reg76.dart -- the 12 false -1 that appeared in m76 between two runs.
//
// `S <- (A / 'a') 'b'; A <- 'a' &("bb");` scored 0 wrong for all three engines
// on an earlier m76 and 12 wrong on the current one, so this isolates the whole
// 63-string alphabet of that one grammar and prints truth beside each engine.
// It is a REGRESSION probe, not a gate: the point is a minimal reproduction.
//
// The shape is an ordered choice whose FIRST alternative ends in a lookahead --
// the case where a committed choice has to retain the second alternative as a
// live follower while a predicate is still outstanding.
import 'package:squirrel_parser/squirrel_parser.dart';

import '_gate77.dart' show enumerate, Tally;
import '_subset75.dart' show trueDist;
import 'm75.dart' as e75;
import 'm76.dart' as e76;
import 'm77.dart' as e77;

const g = "S <- (A / 'a') 'b';\nA <- 'a' &(\"bb\");\n";
const top = 'S';
const alpha = 'ab';

void main() {
  final r = MetaGrammar.parseGrammar(g);
  final a = e75.SuperDot3(rules: r, topRuleName: top);
  final b = e76.SuperDot3(rules: r, topRuleName: top);
  final c = e77.SuperDot3(rules: r, topRuleName: top);

  print('grammar: ${g.replaceAll('\n', ' ')}');
  print('${"input".padRight(8)} ${"true".padLeft(5)} '
      '${"m75".padLeft(5)} ${"m76".padLeft(5)} ${"m77".padLeft(5)}   note');
  var bad = 0;
  for (final s in enumerate(alpha, 5)) {
    final t = trueDist(r, top, s, alpha, 3);
    int run(int Function(String) f) {
      try {
        return f(s);
      } catch (_) {
        return -999;
      }
    }

    final v75 = run(a.recoverCost);
    final v76 = run(b.recoverCost);
    final v77 = run(c.recoverCost);
    // `trueDist` returns null for "further than 3", which is NOT the same as
    // "impossible": an engine answering 4 there is right.  Scoring it as -1
    // invents three failures that are the probe's, not the engine's, so the
    // gate's own rule is reused rather than restated.
    final wrong = !Tally('x').score(t, v76);
    if (wrong) bad++;
    // Only the disagreements are worth reading; the rest is 51 lines of noise.
    if (wrong) {
      print('${'"$s"'.padRight(8)} ${(t == null ? ">3" : "$t").padLeft(5)} '
          '${v75.toString().padLeft(5)} ${v76.toString().padLeft(5)} '
          '${v77.toString().padLeft(5)}   <-- m76 wrong');
    }
  }
  print('\nm76 wrong: $bad of 63');

  // Does the same shape without the lookahead survive?  If it does, the
  // lookahead-inside-a-committed-choice is the trigger rather than the choice.
  for (final ctl in [
    ("S <- (A / 'a') 'b';\nA <- 'a' 'b';\n", 'choice, no lookahead'),
    ("S <- (A / 'a') 'b';\nA <- 'a' &('b');\n", 'choice, ONE-char lookahead'),
    ("S <- A 'b';\nA <- 'a' &(\"bb\");\n", 'lookahead, NO choice'),
  ]) {
    final (text, label) = ctl;
    final rr = MetaGrammar.parseGrammar(text);
    final e = e76.SuperDot3(rules: rr, topRuleName: top);
    final tal = Tally(label);
    for (final s in enumerate(alpha, 5)) {
      final t = trueDist(rr, top, s, alpha, 3);
      int v;
      try {
        v = e.recoverCost(s);
      } catch (_) {
        v = -999;
      }
      tal.score(t, v);
    }
    print('control  ${label.padRight(28)} m76 wrong: ${tal.wrong} of 63  '
        '(low ${tal.tooLow}, high ${tal.tooHigh}, false-1 ${tal.falseImpossible})');
  }
}
