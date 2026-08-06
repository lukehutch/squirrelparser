// Scratch: WHERE does the superlinear work go, and how much of it is thrown
// away? Runs the scaling shapes through the instrumented engine and reports,
// per size, the counters divided by n -- a column that stays flat is linear,
// one that doubles when n doubles is quadratic.
//
//   dart run _wrun.dart [shape ...]

import 'package:squirrel_parser/squirrel_parser.dart';

import '_scale.dart' show shapes;
import '_w2.dart' as w;

int _nodes(MatchResult m) {
  var n = 1;
  for (final s in m.subClauseMatches) {
    n += _nodes(s);
  }
  return n;
}

void main(List<String> argv) {
  final want = argv.toSet();
  final sizes = [64, 128, 256, 512];
  for (final sh in shapes) {
    if (want.isNotEmpty && !want.contains(sh.name)) continue;
    final rules = MetaGrammar.parseGrammar(sh.grammar);
    print('== ${sh.name} :: ${sh.grammar}');
    print('    n  rounds   ways/n   miss/n  hit%  LR>1  bumps  '
        'prune/n  items/pr  close/n  steps/close  wrap/n  used/wrap  '
        'cells  widest  recompute  IDLE(wasted)  clip%');
    for (final n in sizes) {
      final input = sh.gen(n);
      final eng = w.Squirrel(rules: rules, topRuleName: sh.top);
      w.resetCounters();
      MatchResult? root;
      try {
        root = eng.recover(input);
      } catch (_) {}
      final L = input.length.toDouble();
      final (cells, total, widest) = eng.chartSize();
      final used = root == null ? 0 : _nodes(root);
      String f(num x, [int d = 1]) => x.toStringAsFixed(d);
      print('${input.length.toString().padLeft(5)} '
          '${w.nRounds.toString().padLeft(7)} '
          '${f(w.nWays / L).padLeft(8)} '
          '${f(w.nMiss / L).padLeft(8)} '
          '${f(w.nHit / (w.nWays == 0 ? 1 : w.nWays) * 100).padLeft(5)} '
          '${w.nLRmulti.toString().padLeft(5)} '
          '${w.nBump.toString().padLeft(6)} '
          '${f(w.nPrune / L).padLeft(8)} '
          '${f(w.nPruneItems / (w.nPrune == 0 ? 1 : w.nPrune), 2).padLeft(9)} '
          '${f(w.nClose / L).padLeft(8)} '
          '${f(w.nCloseSteps / (w.nClose == 0 ? 1 : w.nClose), 2).padLeft(12)} '
          '${f(w.nWrap / L).padLeft(7)} '
          '${f(used / (w.nWrap == 0 ? 1 : w.nWrap) * 100, 2).padLeft(10)}% '
          '${cells.toString().padLeft(6)} '
          '${widest.toString().padLeft(7)} '
          '${w.nRecompute.toString().padLeft(10)} '
          '${w.nRecomputeIdle.toString().padLeft(9)} '
          '${f(w.nRecomputeIdle / (w.nRecompute == 0 ? 1 : w.nRecompute) * 100, 1).padLeft(6)}% '
          '${f(w.nClipped / ((w.nClipped + w.nUnclipped) == 0 ? 1 : (w.nClipped + w.nUnclipped)) * 100, 1).padLeft(6)}%');
    }
    print('');
  }
}
