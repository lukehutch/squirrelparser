// Empirical big-O. Two separate claims, and only one of them is a measurement:
//
//   (a) Recovery does not change the complexity of REGULAR parsing. This is true
//       by construction, not by measurement: lib/src/parser/ is byte-identical
//       across every engine, and each engine is a pure client of the oracle
//       (`Parser.parse`, `Clause.match`). Nothing can change the parser's
//       asymptotics without changing the parser. What IS measurable, and what this
//       file measures, is the weaker operational claim: on input already in L(G),
//       recovery must degenerate to ONE pure parse, so its exponent must equal the
//       pure parser's, with only a constant factor between them.
//
//   (b) Recovery's own complexity, which is measured here as a log-log slope over
//       doubling input sizes -- the honest empirical exponent, to be compared
//       against the analytic worst-case bound rather than assumed equal to it.
//
// Three damage regimes, because the exponent depends on the regime, not just the
// engine: clean (no errors), one error (damage local, independent of n), and
// damage proportional to n (every 16th character corrupted).
import 'dart:math';
import 'package:squirrel_parser/squirrel_parser.dart';
import 'package:squirrel_parser/src/parser/combinators.dart';
import 'package:squirrel_parser/src/recovery/dot_recovery.dart';
import 'sd6.dart' as g6;
import 'm15.dart' as g15;
import 'm16.dart' as g16;
import 'm17.dart' as g17;
import 'm18.dart' as g18;
import 'm19.dart' as g19;
import 'm20.dart' as g20;
import 'm21.dart' as g21;
import 'm22.dart' as g22;
import 'm23.dart' as g23;
import 'm24.dart' as g24;
import 'm25.dart' as g25;
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

/// A valid JSON document of roughly `k * 30` characters.
String doc(int k) {
  final it = [for (var i = 0; i < k; i++) '{"id":$i,"nm":"n$i","ok":true}'];
  return '{"items":[${it.join(',')}],"total":$k}';
}

/// One typo in the middle: damage is O(1), independent of n.
String oneErr(String d) =>
    '${d.substring(0, d.length ~/ 2)}Q${d.substring(d.length ~/ 2 + 1)}';

/// Every 64th character replaced: damage is Theta(n), but sparse enough that the
/// largest rung is still reachable -- K ~ n/64 rather than n/16.
String manyErr(String d) {
  final b = d.split('');
  for (var i = 32; i < b.length; i += 64) {
    b[i] = 'Q';
  }
  return b.join();
}

typedef Run = int Function(String);

final engines = <(String, Run Function(Map<String, Clause>, String))>[
  ('dot', (r, t) {
    final e = DotRecovery(rules: r, topRuleName: t);
    return (s) => (e.recover(s), e.lastTotalCost).$2;
  }),
  ('v6', (r, t) => g6.SuperDot3(rules: r, topRuleName: t).recoverCost),
  ('m15', (r, t) => g15.SuperDot3(rules: r, topRuleName: t).recoverCost),
  ('m16', (r, t) => g16.SuperDot3(rules: r, topRuleName: t).recoverCost),
  ('m17', (r, t) => g17.SuperDot3(rules: r, topRuleName: t).recoverCost),
  ('m18', (r, t) => g18.SuperDot3(rules: r, topRuleName: t).recoverCost),
  ('m19', (r, t) => g19.SuperDot3(rules: r, topRuleName: t).recoverCost),
  ('m20', (r, t) => g20.SuperDot3(rules: r, topRuleName: t).recoverCost),
  ('m21', (r, t) => g21.SuperDot3(rules: r, topRuleName: t).recoverCost),
  ('m22', (r, t) => g22.SuperDot3(rules: r, topRuleName: t).recoverCost),
  ('m23', (r, t) => g23.SuperDot3(rules: r, topRuleName: t).recoverCost),
  ('m24', (r, t) => g24.SuperDot3(rules: r, topRuleName: t).recoverCost),
  ('m25', (r, t) => g25.SuperDot3(rules: r, topRuleName: t).recoverCost),
  ('m26', (r, t) => g26.SuperDot3(rules: r, topRuleName: t).recoverCost),
  ('m27', (r, t) => g27.SuperDot3(rules: r, topRuleName: t).recoverCost),
];

/// Best-of-3 milliseconds, or null if it could not complete at this size.
double? time(Run f, String s) {
  var t = double.infinity;
  for (var i = 0; i < 3; i++) {
    final sw = Stopwatch()..start();
    try {
      f(s);
    } catch (_) {
      return null;
    }
    t = min(t, sw.elapsedMicroseconds / 1000);
  }
  return t;
}

/// Log-log slope over consecutive size doublings: the empirical exponent p in
/// t ~ n^p. Uses only points above 0.05 ms, since below that the clock dominates
/// and the "slope" is measuring timer noise rather than the algorithm.
String slope(List<int> ns, List<double?> ts) {
  final xs = <double>[], ys = <double>[];
  for (var i = 0; i < ns.length; i++) {
    final t = ts[i];
    if (t != null && t > 0.05) {
      xs.add(log(ns[i]));
      ys.add(log(t));
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

  final cleanNs = <int>[], errNs = <int>[], manyNs = <int>[];
  final cleanIn = <String>[], errIn = <String>[], manyIn = <String>[];
  for (final k in [8, 16, 32, 64, 128]) {
    final d = doc(k);
    cleanNs.add(d.length);
    cleanIn.add(d);
    errNs.add(d.length);
    errIn.add(oneErr(d));
  }
  // Theta(n) damage is far more expensive, so it gets a shorter ladder.
  for (final k in [2, 4, 8, 16]) {
    final d = doc(k);
    manyNs.add(d.length);
    manyIn.add(manyErr(d));
  }

  // (a) The pure parser's own exponent, as the reference the clean column must match.
  final pureT = [
    for (final s in cleanIn)
      time((x) {
        final p = Parser(rules: rules, topRuleName: 'JSON', input: x).parse();
        return p.hasSyntaxErrors ? 1 : 0;
      }, s)
  ];
  print('sizes clean/1err: $cleanNs');
  print('sizes  n-errors : $manyNs');
  print('\npure parser exponent (reference): ${slope(cleanNs, pureT)}');
  print('pure parser ms: ${pureT.map((t) => t?.toStringAsFixed(2) ?? "-").join("  ")}');

  final rows = <List<String>>[];
  for (final (name, make) in engines) {
    final cT = [for (final s in cleanIn) time(make(rules, 'JSON'), s)];
    final eT = [for (final s in errIn) time(make(rules, 'JSON'), s)];
    final mT = [for (final s in manyIn) time(make(rules, 'JSON'), s)];
    // Ratio of recovery to pure parse on clean input at the largest size both
    // completed: the constant factor recovery adds on the common path.
    var ratio = '-';
    for (var i = cleanNs.length - 1; i >= 0; i--) {
      if (cT[i] != null && pureT[i] != null && pureT[i]! > 0.05) {
        ratio = '${(cT[i]! / pureT[i]!).toStringAsFixed(2)}x';
        break;
      }
    }
    rows.add([
      name,
      slope(cleanNs, cT),
      ratio,
      slope(errNs, eT),
      slope(manyNs, mT),
      mT.last?.toStringAsFixed(0) ?? 'STACK',
    ]);
    print('  ...$name done');
  }

  const head = ['engine', 'clean^p', 'clean/pure', '1err^p', 'nerr^p', 'nerr@last ms'];
  final w = [
    for (var c = 0; c < head.length; c++)
      [head[c].length, for (final r in rows) r[c].length].reduce(max)
  ];
  String fmt(List<String> r) =>
      [for (var c = 0; c < r.length; c++) r[c].padLeft(w[c])].join('  ');
  print('\n${fmt(head)}');
  for (final r in rows) {
    print(fmt(r));
  }
  print('\nclean^p: empirical exponent on valid input -- must equal the pure '
      "parser's.\nclean/pure: constant factor recovery adds on the common path.  "
      '1err^p: exponent\nwith O(1) damage.  nerr^p: exponent with Theta(n) damage '
      '(every 64th char).\n'
      'CAVEAT on clean/pure: the pure reference runs FIRST, JIT-cold, so its ms are\n'
      'inflated and the ratio is biased low. Ratios below 1.0 are an ordering\n'
      'artifact, not evidence that recovery beats parsing.');
}
