// Scratch: what does ITERATIVE DEEPENING cost?
//
// Two runs of the same engine on the same case, each from a fresh instance:
//   honest  -- deepen from 0, as the engine ships
//   oracle  -- start at the budget the honest run settled on, so exactly one
//              round runs and every earlier round is skipped
//
// Their difference is the re-derivation the deepening pays for, and nothing
// else: same code, same clause objects, same memo discipline. A separate check
// confirms both runs return the same tree, so the oracle is not answering an
// easier question.
import 'package:squirrel_parser/squirrel_parser.dart';

import 'astdiff.dart';
import '_r4uo.dart' as o;

String ser(MatchResult m) {
  final b = StringBuffer();
  void walk(MatchResult k) {
    b.write('${k.runtimeType}:${k.clause}:${k.pos}:${k.len}(');
    for (final s in k.subClauseMatches) {
      walk(s);
    }
    b.write(')');
  }

  walk(m);
  return b.toString();
}

void main() {
  final cases = weighted(buildBattery());
  final rulesOf = <String, Map<String, Clause>>{
    for (final c in corpora) c.name: MetaGrammar.parseGrammar(c.grammar)
  };
  final eng = <String, o.Squirrel>{
    for (final c in corpora)
      c.name: o.Squirrel(rules: rulesOf[c.name]!, topRuleName: c.top)
  };

  var honest = 0, oracle = 0, mismatch = 0;
  final byBudget = <int, (int, int, int)>{};
  // Warm both paths first, so neither pays a JIT cost the other does not.
  for (var warm = 0; warm < 2; warm++) {
    honest = 0;
    oracle = 0;
    mismatch = 0;
    byBudget.clear();
    for (final k in cases) {
      final e = eng[k.grammar]!;
      final swa = Stopwatch()..start();
      final ta = ser(e.recover(k.mutant));
      swa.stop();
      final b = e.lastBudget;
      final swb = Stopwatch()..start();
      final tb = ser(e.recover(k.mutant, b));
      swb.stop();
      if (ta != tb) mismatch++;
      honest += swa.elapsedMicroseconds;
      oracle += swb.elapsedMicroseconds;
      final cur = byBudget[b] ?? (0, 0, 0);
      byBudget[b] = (
        cur.$1 + 1,
        cur.$2 + swa.elapsedMicroseconds,
        cur.$3 + swb.elapsedMicroseconds
      );
    }
  }

  print('honest ${(honest / 1000).toStringAsFixed(0)} ms   '
      'oracle ${(oracle / 1000).toStringAsFixed(0)} ms   '
      'deepening overhead '
      '${((honest - oracle) / honest * 100).toStringAsFixed(1)}%   '
      'tree mismatches $mismatch');
  print('');
  print('budget   cases     honest ms    oracle ms   overhead');
  final ks = byBudget.keys.toList()..sort();
  for (final b in ks) {
    final v = byBudget[b]!;
    print('${b.toString().padLeft(6)} ${v.$1.toString().padLeft(7)} '
        '${(v.$2 / 1000).toStringAsFixed(1).padLeft(12)} '
        '${(v.$3 / 1000).toStringAsFixed(1).padLeft(12)} '
        '${v.$2 == 0 ? '' : '${((v.$2 - v.$3) / v.$2 * 100).toStringAsFixed(0)}%'.padLeft(10)}');
  }
}
