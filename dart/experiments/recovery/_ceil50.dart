// WHICH recursion overflows? The table's scalability column steps by powers of
// two, so "m43 1024, m49 512" bounds the regression only to within a factor of
// two, and it does not say whether the native stack is spent by the SEARCH or by
// the reconstruction that follows it. m50 has to fix the ceiling, and a fix aimed
// at the wrong phase would be wasted, so this bisects the exact threshold for
// each phase separately: `recoverCost` is search alone, `recover` is search plus
// `_build`/`_collect`/`_emit`.
//
// One engine per process, selected by argv, because a probe of the native stack
// is sensitive to whatever else the process has on it.
import 'package:squirrel_parser/squirrel_parser.dart';
// Via the package URI, not a relative path: a relative import would be a second
// library and its `Clause` would not be the package's `Clause`.
import 'package:squirrel_parser/src/recovery/dot_recovery.dart' as gdot;
import 'm43.dart' as g43;
import 'm46.dart' as g46;
import 'm47.dart' as g47;
import 'm49.dart' as g49;

const rr = "E <- T '+' E / T;\nT <- F '*' T / F;\nF <- [0-9] / '(' E ')';\n";
const lr = "E <- E '+' T / T;\nT <- T '*' F / F;\nF <- [0-9] / '(' E ')';\n";

String oneErr(int k) {
  final c = List.generate(k, (i) => '${i % 10}').join('+');
  final mid = c.length ~/ 2;
  return '${c.substring(0, mid)}+${c.substring(mid)}';
}

typedef Phase = void Function(Map<String, Clause> rules, String s);

final Map<String, Map<String, Phase>> phases = {
  'm43': {
    'cost': (r, s) => g43.SuperDot3(rules: r, topRuleName: 'E').recoverCost(s),
    'full': (r, s) => g43.SuperDot3(rules: r, topRuleName: 'E').recover(s),
  },
  // The pair the regression is actually claimed between (LESSONS: "1024 -> 512,
  // entering at m47"), so it is the pair that has to be bisected.
  'm46': {
    'cost': (r, s) => g46.SuperDot3(rules: r, topRuleName: 'E').recoverCost(s),
    'full': (r, s) => g46.SuperDot3(rules: r, topRuleName: 'E').recover(s),
  },
  'm47': {
    'cost': (r, s) => g47.SuperDot3(rules: r, topRuleName: 'E').recoverCost(s),
    'full': (r, s) => g47.SuperDot3(rules: r, topRuleName: 'E').recover(s),
  },
  'm49': {
    'cost': (r, s) => g49.SuperDot3(rules: r, topRuleName: 'E').recoverCost(s),
    'full': (r, s) => g49.SuperDot3(rules: r, topRuleName: 'E').recover(s),
  },
  'dot': {
    'full': (r, s) =>
        gdot.DotRecovery(rules: r, topRuleName: 'E').recover(s),
  },
};

/// True if the phase completes without exhausting the native stack.
bool survives(Phase p, Map<String, Clause> rules, int k) {
  try {
    p(rules, oneErr(k));
    return true;
  } on StackOverflowError {
    return false;
  } catch (e) {
    // Any other failure is not a stack ceiling; report it as a survival so the
    // bisection does not silently attribute it to depth.
    print('      (k=$k non-stack failure ${e.runtimeType})');
    return true;
  }
}

/// Largest k that survives, bisected. `hi` is an assumed-failing upper bound;
/// grown first so the answer is never clipped by the initial guess.
int ceiling(Phase p, Map<String, Clause> rules) {
  var lo = 0, hi = 64;
  while (survives(p, rules, hi)) {
    lo = hi;
    hi *= 2;
    if (hi > 1 << 20) return hi; // effectively unbounded
  }
  while (hi - lo > 1) {
    final mid = (lo + hi) ~/ 2;
    if (survives(p, rules, mid)) {
      lo = mid;
    } else {
      hi = mid;
    }
  }
  return lo;
}

void main(List<String> argv) {
  final name = argv.isEmpty ? 'm49' : argv.first;
  final ps = phases[name];
  if (ps == null) throw ArgumentError('unknown engine $name');
  print('$name: largest surviving k (elements), 1-error input, 3 bisections');
  for (final (label, g) in [('RR', rr), ('LR', lr)]) {
    final rules = MetaGrammar.parseGrammar(g);
    for (final phase in ps.keys) {
      // Three independent bisections: the threshold DRIFTS with process state, so
      // a single number would read as a precision the measurement does not have.
      final ks = [for (var i = 0; i < 3; i++) ceiling(ps[phase]!, rules)];
      print('  $label ${phase.padRight(5)} k=${ks.join(',')}'
          '  (input len ~${oneErr(ks.first).length})');
    }
  }
}
