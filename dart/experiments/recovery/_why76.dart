// _why76.dart -- is m76's false -1 a search miss or a certificate rejection?
//
// `recoverCost` returns -1 only after BOTH the relaxed and the tight pass fail
// `_certified`.  That is two very different defects wearing one answer, so this
// separates them before anything is edited: the previous guess was patched and
// changed 0 of 6461 answers, which is what guessing costs.
import 'package:squirrel_parser/squirrel_parser.dart';

import '_subset75.dart' show trueDist;
import '_m76fix.dart' as e76;

const g = "S <- (A / 'a') 'b';\nA <- 'a' &(\"bb\");\n";
const top = 'S';
const alpha = 'ab';

// The 12 failures, plus near-miss controls that m76 answers correctly.
const cases = [
  'bbb', 'aabb', 'babb', 'bbba', 'bbbb', // wrong
  'ab', 'bb', 'abb', 'bba', 'b', 'a', 'aab', // right
];

void main() {
  final r = MetaGrammar.parseGrammar(g);
  final e = e76.SuperDot3(rules: r, topRuleName: top);

  print('grammar: ${g.replaceAll('\n', ' ')}');
  print('${"input".padRight(7)} ${"true".padRight(5)} ${"cost".padRight(5)} '
      '${"verif".padRight(6)} ${"steps".padRight(7)} ${"fab".padRight(4)} verdict');
  for (final s in cases) {
    final t = trueDist(r, top, s, alpha, 3);
    int v;
    print('  "$s" (true ${t ?? ">3"}):');
    e76.SuperDot3.trace = true;
    try {
      v = e.recoverCost(s);
    } catch (err) {
      print('${'"$s"'.padRight(7)} THREW $err');
      continue;
    }
    final ok = t == null ? (v > 3 || v == -1) : v == t;
    print('${'"$s"'.padRight(7)} ${(t == null ? ">3" : "$t").padRight(5)} '
        '${v.toString().padRight(5)} ${e.lastVerified.toString().padRight(6)} '
        '${e.lastSteps.toString().padRight(7)} '
        '${e.lastFabrications.toString().padRight(4)} ${ok ? "ok" : "WRONG"}');
  }

  // Which repaired strings at distance <=3 are actually in the language?  If the
  // engine says -1 the claim is "none exists", so name the witness it missed.
  print('\nwitnesses the engine says do not exist:');
  for (final s in ['bbb', 'aabb', 'babb']) {
    final found = <String>[];
    var frontier = {s};
    final seen = {s};
    for (var k = 0; k <= 3 && found.isEmpty; k++) {
      for (final y in frontier) {
        final p = Parser(rules: r, topRuleName: top, input: y).parse();
        if (!p.hasSyntaxErrors && p.root != null && p.root!.len == y.length) {
          found.add('$y (cost $k)');
        }
      }
      if (found.isNotEmpty) break;
      final next = <String>{};
      for (final y in frontier) {
        for (var i = 0; i <= y.length; i++) {
          if (i < y.length) next.add(y.substring(0, i) + y.substring(i + 1));
          for (final c in alpha.split('')) {
            next.add(y.substring(0, i) + c + y.substring(i));
            if (i < y.length) {
              next.add(y.substring(0, i) + c + y.substring(i + 1));
            }
          }
        }
      }
      frontier = next.difference(seen);
      seen.addAll(frontier);
    }
    print('  "$s" -> ${found.isEmpty ? "NONE within 3" : found.join(", ")}');
  }
}
