// Whose ceiling is it? Recovery calls the oracle at EVERY cell -- `_compute`'s
// budget-0 case is `node.orig.match(_parser, pos)` -- and on a right-recursive
// grammar the pure parser recurses once per position itself. So if the pure
// parser's own right-recursive ceiling is near recovery's bisected ~524
// elements, then recovery's ceiling IS the parser's, no restructuring of the
// SEARCH can raise it, and the fix is in `lib/` where this work may not go.
//
// If instead the parser survives several times further, recovery's descent is
// the binding constraint and is worth attacking.
import 'package:squirrel_parser/squirrel_parser.dart';

const rr = "E <- T '+' E / T;\nT <- F '*' T / F;\nF <- [0-9] / '(' E ')';\n";
const lr = "E <- E '+' T / T;\nT <- T '*' F / F;\nF <- [0-9] / '(' E ')';\n";

String clean(int k) => List.generate(k, (i) => '${i % 10}').join('+');

String oneErr(int k) {
  final c = clean(k);
  final mid = c.length ~/ 2;
  return '${c.substring(0, mid)}+${c.substring(mid)}';
}

bool survives(Map<String, Clause> rules, String s) {
  try {
    Parser(rules: rules, topRuleName: 'E', input: s).parse();
    return true;
  } on StackOverflowError {
    return false;
  }
}

int ceiling(Map<String, Clause> rules, String Function(int) mk) {
  var lo = 0, hi = 64;
  while (survives(rules, mk(hi))) {
    lo = hi;
    hi *= 2;
    if (hi > 1 << 22) return hi;
  }
  while (hi - lo > 1) {
    final mid = (lo + hi) ~/ 2;
    if (survives(rules, mk(mid))) {
      lo = mid;
    } else {
      hi = mid;
    }
  }
  return lo;
}

void main() {
  print('PURE PARSER (no recovery): largest surviving k, 3 bisections');
  for (final (label, g) in [('RR', rr), ('LR', lr)]) {
    final rules = MetaGrammar.parseGrammar(g);
    for (final (kind, mk) in [('clean', clean), ('1err', oneErr)]) {
      final ks = [for (var i = 0; i < 3; i++) ceiling(rules, mk)];
      print('  $label ${kind.padRight(5)} k=${ks.join(',')}'
          '  (input len ~${mk(ks.first).length})');
    }
  }
}
