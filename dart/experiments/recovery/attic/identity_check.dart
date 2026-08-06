// Empirical test of the claim that the two regret formulations are THE SAME
// objective up to an additive constant:
//   deviation form (m15):  keep p -> w(p) - h(p),  discard p -> h(p)
//   absolute  form (m16):  keep p -> w(p),         discard p -> 2 h(p)
// difference = sum over ALL p of h(p), independent of the keep/discard split,
// so the two must agree on (cost, regret) for every input. If they ever differ,
// the claim is false and the factor 2 is a tuning parameter after all.
import 'package:squirrel_parser/squirrel_parser.dart';
import 'sd2_shape.dart' show jsonGrammar;
import 'm15.dart' as dev;
import 'm16.dart' as abs;

void main() {
  final rules = MetaGrammar.parseGrammar(jsonGrammar);
  final a = dev.SuperDot3(rules: rules, topRuleName: 'JSON');
  final b = abs.SuperDot3(rules: rules, topRuleName: 'JSON');
  const base = '{"a":1,"bc":[2,33,true],"d":{"e":null},"f":"gh"}';
  bool parses(String s) => !Parser(rules: rules, topRuleName: 'JSON', input: s)
      .parse()
      .hasSyntaxErrors;
  final all = <(String, String)>[];
  for (var j = 0; j < base.length; j++) {
    all.add(('del@$j', base.substring(0, j) + base.substring(j + 1)));
    if (j + 1 < base.length && base[j] != base[j + 1]) {
      all.add(('swap@$j',
          base.substring(0, j) + base[j + 1] + base[j] + base.substring(j + 2)));
    }
  }
  for (var j = 0; j <= base.length; j++) {
    for (final c in ['Q', 'z', '}', '"', ',', '5']) {
      all.add(('ins@$j($c)', base.substring(0, j) + c + base.substring(j)));
      if (j < base.length && base[j] != c) {
        all.add(
            ('sub@$j->$c', base.substring(0, j) + c + base.substring(j + 1)));
      }
    }
  }
  final battery = all.where((m) => !parses(m.$2)).toList();
  var n = 0, costDiff = 0, regretDiff = 0;
  final examples = <String>[];
  for (final (label, text) in battery) {
    a.recover(text);
    b.recover(text);
    n++;
    if (a.lastCost != b.lastCost) {
      costDiff++;
      if (examples.length < 5) {
        examples.add('$label cost ${a.lastCost} vs ${b.lastCost}');
      }
    } else if (a.lastRegret != b.lastRegret) {
      regretDiff++;
      if (examples.length < 5) {
        examples.add('$label regret ${a.lastRegret} vs ${b.lastRegret}');
      }
    }
  }
  print('inputs $n  cost disagreements $costDiff  '
      'regret disagreements $regretDiff');
  for (final e in examples) {
    print('  $e');
  }
  print(costDiff == 0 && regretDiff == 0
      ? 'IDENTICAL OBJECTIVE CONFIRMED on all $n inputs'
      : 'CLAIM REFUTED');
}
