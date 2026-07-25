// Separate the two variables the previous complexity harness conflated.
//
// `complexity.dart` measures a Theta(n) damage regime -- every 64th character
// corrupted -- and reports an exponent around n^3.4. But in that regime the
// number of edits K grows linearly with the document length, so a single fitted
// exponent is measuring n and K at once and cannot distinguish
//
//     t ~ n^3        (genuinely cubic in document size)
// from
//     t ~ n * K^2    (linear in document size, quadratic in damage)
//
// which are the same curve when K = Theta(n). They are completely different
// claims about the algorithm. This file fits each variable with the other held
// fixed:
//
//   (a) K fixed, n growing  -> the exponent in DOCUMENT SIZE
//   (b) n fixed, K growing  -> the exponent in DAMAGE
import 'dart:math';
import 'package:squirrel_parser/squirrel_parser.dart';
import 'm26.dart' as g26;
import 'm27.dart' as g27;

const String jsonGrammar = '''
JSON <- WS Value WS;
Value <- Object / Array / String / Number / Boolean / Null;
Object <- '{' WS (Member (WS ',' WS Member)*)? WS '}';
Member <- String WS ':' WS Value;
Array <- '[' WS (Value (WS ',' WS Value)*)? WS ']';
String <- '"' Character* '"';
Character <- [^"\\\\] / ('\\\\' Escape);
Escape <- '"' / '\\\\' / '/' / 'b' / 'f' / 'n' / 'r' / 't' / ('u' [0-9a-fA-F] [0-9a-fA-F] [0-9a-fA-F] [0-9a-fA-F]);
Number <- Integer Fraction? Exponent?;
Integer <- '-'? (([1-9] [0-9]+) / [0-9]);
Fraction <- '.' [0-9]+;
Exponent <- ("e" / "E") ("+" / "-")? [0-9]+;
Boolean <- "true" / "false";
Null <- "null";
~WS <- [ \\t\\n\\r]*;
''';

String doc(int k) {
  final it = [for (var i = 0; i < k; i++) '{"id":$i,"nm":"n$i","ok":true}'];
  return '{"items":[${it.join(',')}],"total":$k}';
}

/// Exactly `k` corrupted characters, spread evenly through the document, so the
/// damage count is independent of the document length.
/// Exactly `k` corrupted characters, each of them the SAME KIND of character --
/// a member separator ':' -- spread evenly. Corrupting a fixed structural role
/// rather than a fixed offset is what makes the damage comparable across document
/// sizes; a proportional offset lands on a '{' at one size and a digit at
/// another, and those do not cost the same to repair.
String damage(String d, int k) {
  if (k == 0) return d;
  final colons = <int>[];
  for (var i = 0; i < d.length; i++) {
    if (d[i] == ':') colons.add(i);
  }
  final b = d.split('');
  final step = colons.length / (k + 1);
  for (var i = 1; i <= k; i++) {
    final at = colons[min(colons.length - 1, (step * i).floor())];
    b[at] = 'Q';
  }
  return b.join();
}

/// Milliseconds and the repair cost actually returned. The cost matters as much
/// as the clock: the requested damage count is NOT the repair cost -- corrupting
/// a `:` and corrupting a digit are both one edit to the document but need not be
/// one edit to repair -- and since cost drives the iterative deepening, a point
/// whose true cost is 3 cannot be compared against one whose true cost is 1.
(double, int)? time(int Function(String) f, String s) {
  var t = double.infinity;
  var cost = -1;
  for (var i = 0; i < 5; i++) {
    final sw = Stopwatch()..start();
    try {
      cost = f(s);
    } catch (_) {
      return null;
    }
    // Discard the first two runs: they pay for JIT warm-up, not for the algorithm.
    if (i >= 2) t = min(t, sw.elapsedMicroseconds / 1000);
  }
  return (t, cost);
}

/// Least-squares slope of log t against log x, ignoring sub-0.05 ms points where
/// the clock rather than the algorithm dominates.
String slope(List<int> xs0, List<(double, int)?> ts) {
  final xs = <double>[], ys = <double>[];
  for (var i = 0; i < xs0.length; i++) {
    final t = ts[i];
    if (t != null && t.$1 > 0.05 && xs0[i] > 0) {
      xs.add(log(xs0[i]));
      ys.add(log(t.$1));
    }
  }
  if (xs.length < 2) return 'n/a';
  final mx = xs.reduce((a, b) => a + b) / xs.length;
  final my = ys.reduce((a, b) => a + b) / ys.length;
  var num = 0.0, den = 0.0;
  for (var i = 0; i < xs.length; i++) {
    num += (xs[i] - mx) * (ys[i] - my);
    den += (xs[i] - mx) * (xs[i] - mx);
  }
  return (num / den).toStringAsFixed(2);
}

void main() {
  final rules = MetaGrammar.parseGrammar(jsonGrammar);
  final engines = <(String, int Function(String) Function())>[
    ('m26', () => g26.SuperDot3(rules: rules, topRuleName: 'JSON').recoverCost),
    ('m27', () => g27.SuperDot3(rules: rules, topRuleName: 'JSON').recoverCost),
  ];

  // ---------------------------------------------------------------- (a) n, K fixed
  final docs = [for (final k in [8, 16, 32, 64, 128]) doc(k)];
  final ns = [for (final d in docs) d.length];
  print('(a) EXPONENT IN DOCUMENT SIZE, damage held fixed');
  print('    document lengths: $ns   (t ms / c = repair cost actually returned)\n');
  print('${"engine".padRight(7)}${"K".padLeft(4)}   '
      '${ns.map((n) => "n=$n".padLeft(11)).join()}   exponent in n');
  for (final (name, make) in engines) {
    for (final k in [1, 2, 4, 8]) {
      final ts = [for (final d in docs) time(make(), damage(d, k))];
      print('${name.padRight(7)}${k.toString().padLeft(4)}   '
          '${ts.map((t) => (t == null ? "-" : "${t.$1.toStringAsFixed(1)}/c${t.$2}").padLeft(11)).join()}   '
          '${slope(ns, ts)}');
    }
  }

  // ---------------------------------------------------------------- (b) K, n fixed
  print('\n(b) EXPONENT IN DAMAGE, document size held fixed');
  final ks = [1, 2, 4, 8, 16];
  for (final dk in [8, 16]) {
    final d = doc(dk);
    print('    document length ${d.length}, damage counts $ks\n');
    print('${"engine".padRight(7)}   '
        '${ks.map((k) => "K=$k".padLeft(11)).join()}   exponent in K');
    for (final (name, make) in engines) {
      final ts = [for (final k in ks) time(make(), damage(d, k))];
      print('${name.padRight(7)}   '
          '${ts.map((t) => (t == null ? "-" : "${t.$1.toStringAsFixed(1)}/c${t.$2}").padLeft(11)).join()}   '
          '${slope(ks, ts)}');
    }
    print('');
  }

  print('If (a) is ~1 and (b) is ~2, the cost is O(n * K^2): LINEAR in document');
  print('size and QUADRATIC in damage. The n^3.4 reported by complexity.dart is');
  print('then the K = Theta(n) diagonal through that surface, not an exponent in n.');
}
