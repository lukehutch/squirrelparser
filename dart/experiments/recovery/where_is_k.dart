// Where does the factor of K^2.4 actually come from?
//
// Two candidate sources, and they are distinguishable by counting rather than by
// timing:
//
//   (i)  MAP WIDTH. Each memo entry holds a map from end position to Delta. If
//        that map is O(K) wide, `_chain` pairs head ends against tail ends for
//        O(K^2) work per entry, and the total is |G| * n * K^2.
//
//   (ii) BUDGET-DRIVEN RECOMPUTATION. A3 states that the budget is a FILTER on
//        Delta and NOT a memo key -- but `_chain` calls
//        `_ends(c, to, h.key, b - _cost(h.value))` with a REDUCED budget, and
//        `_Entry.ends` recomputes whenever the stored `budget` differs from the
//        requested one. So a single (item, pos) is recomputed once per distinct
//        budget it is ever asked with, which is up to K times. m26 violates its
//        own axiom, and that alone would produce a spurious factor of K.
//
// `_steps` counts `_compute` calls, and the two candidates predict opposite things
// about it. Under (i) the number of computations is set by the number of
// (item, pos) keys, which does not depend on K, so steps stays roughly FLAT while
// the time per step grows. Under (ii) each entry is recomputed once per distinct
// budget, so steps itself grows like K -- and if steps grows like the measured
// K^2.4, then the whole exponent is in the computation COUNT and none of it is in
// map width. The measurement decides.
import 'package:squirrel_parser/squirrel_parser.dart';
import 'm26.dart' as g26;
import 'm29.dart' as g29;

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

String damage(String d, int k) {
  if (k == 0) return d;
  final colons = <int>[];
  for (var i = 0; i < d.length; i++) {
    if (d[i] == ':') colons.add(i);
  }
  final b = d.split('');
  final step = colons.length / (k + 1);
  for (var i = 1; i <= k; i++) {
    final at = colons[(step * i).floor().clamp(0, colons.length - 1)];
    b[at] = 'Q';
  }
  return b.join();
}

void main() {
  final rules = MetaGrammar.parseGrammar(jsonGrammar);
  for (final dk in [8, 16]) {
    final d = doc(dk);
    print('document length ${d.length}');
    print('${"K".padLeft(3)}${"cost".padLeft(6)}${"steps".padLeft(12)}'
        '${"steps/K".padLeft(11)}${"x prev".padLeft(9)}${"m26 steps".padLeft(12)}');
    var prev = 0;
    for (final k in [1, 2, 4, 8, 16]) {
      final e26 = g26.SuperDot3(rules: rules, topRuleName: 'JSON');
      e26.recoverCost(damage(d, k));
      final e = g29.SuperDot3(rules: rules, topRuleName: 'JSON');
      final cost = e.recoverCost(damage(d, k));
      final steps = e.lastSteps;
      final s26 = e26.lastSteps;
      // Each rung doubles K, so "x prev" is 2^(exponent in K): 2 means steps grow
      // linearly with K, 4 means quadratically, 5.3 means K^2.4.
      print('${k.toString().padLeft(3)}${cost.toString().padLeft(6)}'
          '${steps.toString().padLeft(12)}'
          '${(steps / k).toStringAsFixed(0).padLeft(11)}'
          '${(prev == 0 ? "-" : (steps / prev).toStringAsFixed(2)).padLeft(9)}'
          '${s26.toString().padLeft(12)}');
      prev = steps;
    }
    print('');
  }
  print('"x prev" near 2   => steps grow like K: the exponent is NOT in the count,');
  print('                     it is in the work per computation (map width).');
  print('"x prev" near 5.3 => steps grow like K^2.4: the whole exponent is in the');
  print('                     computation count, i.e. m26 recomputing entries once');
  print('                     per budget, in violation of its own A3.');
}
