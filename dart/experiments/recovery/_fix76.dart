// _fix76.dart -- does the mark-checked committed choice close m76's 12?
//
// A fix must be run against what it must not regress, so this scores the patched
// copy on the SAME 23 grammars and the same truth as _cmp76, not only on the one
// grammar that exposed the defect.  A candidate that fixes 12 and breaks 30 is a
// worse engine, and the 6461-string total is the only thing that can say so.
//
// _m76fix.dart is a scratch COPY of m76.dart; Codex's file is never edited.
import 'package:squirrel_parser/squirrel_parser.dart';

import '_gate77.dart' show extra, Tally, enumerate;
import '_subset75.dart' show grammars, trueDist;
import 'm76.dart' as base;
import '_m76fix.dart' as fixed;

void main() {
  final all = <(String, String, String)>[
    for (final (g, t, a) in grammars) (g, t, a),
    for (final (g, t, a, _) in extra) (g, t, a),
  ];

  final tb = Tally('m76'), tf = Tally('m76+fix');
  final rows = <String>[];
  var moved = 0;

  for (final (g, top, alpha) in all) {
    final r = MetaGrammar.parseGrammar(g);
    final b = base.SuperDot3(rules: r, topRuleName: top);
    final f = fixed.SuperDot3(rules: r, topRuleName: top);
    final pb = Tally('b'), pf = Tally('f');
    var n = 0;
    for (final s in enumerate(alpha, 5)) {
      final truth = trueDist(r, top, s, alpha, 3);
      int run(int Function(String) fn) {
        try {
          return fn(s);
        } catch (_) {
          return -999;
        }
      }

      final vb = run(b.recoverCost), vf = run(f.recoverCost);
      tb.score(truth, vb);
      tf.score(truth, vf);
      pb.score(truth, vb);
      pf.score(truth, vf);
      if (vb != vf) moved++;
      n++;
    }
    if (pb.wrong > 0 || pf.wrong > 0) {
      rows.add('${g.replaceAll('\n', ' ').trim().padRight(46)}  '
          'm76 ${pb.wrong.toString().padLeft(4)}   '
          'fix ${pf.wrong.toString().padLeft(4)}   of $n');
    }
  }

  print(tb.row);
  print(tf.row);
  print('\nanswers changed by the fix: $moved');
  print('per-grammar (only rows where either is wrong):');
  for (final r in rows) {
    print('  $r');
  }
}
