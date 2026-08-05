// _res1.dart -- the residual, itemized: every case where r9 or m143 is
// imperfect, with both scores, so the failure classes can be read instead of
// guessed. Also prints score(max(r9,m143)) -- the ensemble ceiling, which
// bounds how much of the residual is engine-reachable rather than metric
// ceiling.
import 'package:squirrel_parser/squirrel_parser.dart';

import 'astdiff.dart';
import 'm143.dart' as g143;
import 'r9.dart' as r9;

void main(List<String> argv) {
  final cases = weighted(buildBattery());
  final byCorpus = <String, Corpus>{for (final c in corpora) c.name: c};
  final rulesOf = <String, Map<String, Clause>>{
    for (final c in corpora) c.name: MetaGrammar.parseGrammar(c.grammar)
  };
  final original = <String, MatchResult>{};
  for (final c in corpora) {
    for (final doc in c.documents) {
      original['${c.name} $doc'] =
          Parser(rules: rulesOf[c.name]!, topRuleName: c.top, input: doc)
              .parse()
              .root;
    }
  }
  final ra = <String, MatchResult? Function(String)>{};
  final rb = <String, MatchResult? Function(String)>{};
  for (final c in corpora) {
    ra[c.name] = r9.Squirrel(rules: rulesOf[c.name]!, topRuleName: c.top).recover;
    rb[c.name] =
        g143.SuperDot3(rules: rulesOf[c.name]!, topRuleName: c.top).recover;
  }

  double ta = 0, tb = 0, tmax = 0;
  final rows = <(double, String)>[];
  for (var i = 0; i < cases.length; i++) {
    final k = cases[i];
    final c = byCorpus[k.grammar]!;
    final exp = expectedFor(k, original['${k.grammar} ${k.original}']!, c.named);
    double s(MatchResult? Function(String) f) {
      MatchResult? p;
      try {
        p = f(k.mutant);
      } catch (_) {
        p = null;
      }
      return scoreCase(
              produced: p, expected: exp, inputLen: k.mutant.length, named: c.named)
          .score;
    }

    final a = s(ra[k.grammar]!), b = s(rb[k.grammar]!);
    ta += a;
    tb += b;
    tmax += a > b ? a : b;
    if (a < 1.0 || b < 1.0) {
      rows.add((
        a,
        '${a.toStringAsFixed(3)} ${b.toStringAsFixed(3)} '
            '${k.grammar.padRight(4)} ${k.category.padRight(14)} i=$i '
            '${k.mutant.replaceAll('\n', r'\n')}'
      ));
    }
  }
  final n = cases.length;
  print('r9   ${(ta / n).toStringAsFixed(4)}');
  print('m143 ${(tb / n).toStringAsFixed(4)}');
  print('max  ${(tmax / n).toStringAsFixed(4)}   <- ensemble ceiling');
  print('imperfect rows (r9 m143 corpus category idx mutant):');
  rows.sort((x, y) => x.$1.compareTo(y.$1));
  for (final r in rows) {
    print(r.$2);
  }
}
