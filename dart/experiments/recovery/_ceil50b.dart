// The bisected stack ceiling, one engine per process (`dart ... _ceil50b.dart
// m50 cost`). The ladder in `lr_scale2.dart` reports powers of two and so
// straddles thresholds by up to 2x -- it is what made an 8% reduction read as a
// halving. This bisects the largest surviving k instead.
//
// `cost` is `recoverCost` alone: the SEARCH's ceiling. `full` is `recover`, which
// adds the witness descent -- a recursion over the output TREE, which for a
// right-recursive grammar is O(n) deep whatever the search does.
import 'package:squirrel_parser/squirrel_parser.dart';
import 'm43.dart' as g43;
import 'm49.dart' as g49;
import 'm50.dart' as g50;
import 'm51.dart' as g51;
import 'm52.dart' as g52;
import 'm53.dart' as g53;
import 'm57.dart' as g57;
import 'm59.dart' as g59;
import 'm60.dart' as g60;
import 'm61.dart' as g61;
import 'm62.dart' as g62;
import 'm63.dart' as g63;

const rr = "E <- T '+' E / T;\nT <- F '*' T / F;\nF <- [0-9] / '(' E ')';\n";

String mk(int k) {
  final c = List.generate(k, (i) => '${i % 10}').join('+');
  final mid = c.length ~/ 2;
  return '${c.substring(0, mid)}+${c.substring(mid)}';
}

typedef Phase = bool Function(Map<String, Clause> rules, String s);

final Map<String, Map<String, Phase>> phases = {
  'm43': {
    'cost': (r, s) =>
        g43.SuperDot3(rules: r, topRuleName: 'E').recoverCost(s) >= -1,
    'full': (r, s) =>
        g43.SuperDot3(rules: r, topRuleName: 'E').recover(s).root.len >= 0,
  },
  'm49': {
    'cost': (r, s) =>
        g49.SuperDot3(rules: r, topRuleName: 'E').recoverCost(s) >= -1,
    'full': (r, s) =>
        g49.SuperDot3(rules: r, topRuleName: 'E').recover(s).root.len >= 0,
  },
  'm50': {
    'cost': (r, s) =>
        g50.SuperDot3(rules: r, topRuleName: 'E').recoverCost(s) >= -1,
    'full': (r, s) =>
        g50.SuperDot3(rules: r, topRuleName: 'E').recover(s).root.len >= 0,
  },
  'm51': {
    'cost': (r, s) =>
        g51.SuperDot3(rules: r, topRuleName: 'E').recoverCost(s) >= -1,
    'full': (r, s) =>
        g51.SuperDot3(rules: r, topRuleName: 'E').recover(s).root.len >= 0,
  },
  'm53': {
    'cost': (r, s) =>
        g53.SuperDot3(rules: r, topRuleName: 'E').recoverCost(s) >= -1,
    'full': (r, s) =>
        g53.SuperDot3(rules: r, topRuleName: 'E').recover(s).root.len >= 0,
  },
  'm60': {
    'cost': (r, s) =>
        g60.SuperDot3(rules: r, topRuleName: 'E').recoverCost(s) >= -1,
    'full': (r, s) =>
        g60.SuperDot3(rules: r, topRuleName: 'E').recover(s).root.len >= 0,
  },
  'm61': {
    'cost': (r, s) =>
        g61.SuperDot3(rules: r, topRuleName: 'E').recoverCost(s) >= -1,
    'full': (r, s) =>
        g61.SuperDot3(rules: r, topRuleName: 'E').recover(s).root.len >= 0,
  },
  'm62': {
    'cost': (r, s) =>
        g62.SuperDot3(rules: r, topRuleName: 'E').recoverCost(s) >= -1,
    'full': (r, s) =>
        g62.SuperDot3(rules: r, topRuleName: 'E').recover(s).root.len >= 0,
  },
  'm63': {
    'cost': (r, s) =>
        g63.SuperDot3(rules: r, topRuleName: 'E').recoverCost(s) >= -1,
    'full': (r, s) =>
        g63.SuperDot3(rules: r, topRuleName: 'E').recover(s).root.len >= 0,
  },
  'm59': {
    'cost': (r, s) =>
        g59.SuperDot3(rules: r, topRuleName: 'E').recoverCost(s) >= -1,
    'full': (r, s) =>
        g59.SuperDot3(rules: r, topRuleName: 'E').recover(s).root.len >= 0,
  },
  'm57': {
    'cost': (r, s) =>
        g57.SuperDot3(rules: r, topRuleName: 'E').recoverCost(s) >= -1,
    'full': (r, s) =>
        g57.SuperDot3(rules: r, topRuleName: 'E').recover(s).root.len >= 0,
  },
  'm52': {
    'cost': (r, s) =>
        g52.SuperDot3(rules: r, topRuleName: 'E').recoverCost(s) >= -1,
    'full': (r, s) =>
        g52.SuperDot3(rules: r, topRuleName: 'E').recover(s).root.len >= 0,
  },
};

bool survives(Phase phase, Map<String, Clause> rules, int k) {
  try {
    return phase(rules, mk(k));
  } on StackOverflowError {
    return false;
  }
}

int ceiling(Phase phase, Map<String, Clause> rules) {
  var lo = 0, hi = 64;
  while (survives(phase, rules, hi)) {
    lo = hi;
    hi *= 2;
    if (hi > 1 << 16) return hi;
  }
  while (hi - lo > 1) {
    final mid = (lo + hi) ~/ 2;
    if (survives(phase, rules, mid)) {
      lo = mid;
    } else {
      hi = mid;
    }
  }
  return lo;
}

void main(List<String> args) {
  final engine = args.isEmpty ? 'm50' : args[0];
  final which = args.length > 1 ? args[1] : 'cost';
  final rules = MetaGrammar.parseGrammar(rr);
  final phase = phases[engine]![which]!;
  final ks = [for (var i = 0; i < 3; i++) ceiling(phase, rules)];
  print('$engine $which: k=${ks.join(',')}   (ladder n = 2k = '
      '${ks.map((k) => 2 * k).join(',')})');
}
