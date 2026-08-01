// _div.dart -- find the cases where two engines disagree.
//
// A speedup that was supposed to preserve behaviour and did not is a bug
// report, not a benchmark. This prints every case whose skeleton differs
// between two engines, so the claim "only the time moves" can be checked
// instead of assumed.
//
// Usage: dart run _div.dart <engineA> <engineB> [maxToPrint]
import 'package:squirrel_parser/squirrel_parser.dart';

import 'astdiff.dart';
import 'm87.dart' as g87;
import 'm88.dart' as g88;
import 'm89.dart' as g89;

typedef Build = MatchResult? Function(String) Function(
    Map<String, Clause>, String);

final Map<String, Build> made = {
  'm87': (r, t) => g87.SuperDot3(rules: r, topRuleName: t).recover,
  'm88': (r, t) => g88.SuperDot3(rules: r, topRuleName: t).recover,
  'm89': (r, t) => g89.SuperDot3(rules: r, topRuleName: t).recover,
};

void main(List<String> argv) {
  final a = argv[0], b = argv[1];
  final cap = argv.length > 2 ? int.parse(argv[2]) : 20;

  final cases = weighted(buildBattery());
  final byCorpus = <String, Corpus>{for (final c in corpora) c.name: c};
  final rules = <String, Map<String, Clause>>{
    for (final c in corpora) c.name: MetaGrammar.parseGrammar(c.grammar)
  };
  final ra = <String, MatchResult? Function(String)>{
    for (final c in corpora) c.name: made[a]!(rules[c.name]!, c.top)
  };
  final rb = <String, MatchResult? Function(String)>{
    for (final c in corpora) c.name: made[b]!(rules[c.name]!, c.top)
  };

  var n = 0;
  final byCat = <String, int>{};
  for (final k in cases) {
    final c = byCorpus[k.grammar]!;
    MatchResult? x, y;
    try {
      x = ra[k.grammar]!(k.mutant);
    } catch (_) {}
    try {
      y = rb[k.grammar]!(k.mutant);
    } catch (_) {}
    final sx = x == null ? ['<null>'] : skeleton(x, c.named);
    final sy = y == null ? ['<null>'] : skeleton(y, c.named);
    if (sx.join(' ') == sy.join(' ')) continue;
    n++;
    byCat[k.category] = (byCat[k.category] ?? 0) + 1;
    if (n <= cap) {
      print('--- ${k.grammar} / ${k.category}');
      print('    orig   ${k.original}');
      print('    mutant ${k.mutant}');
      print('    $a  ${sx.join(' ')}');
      print('    $b  ${sy.join(' ')}');
    }
  }
  print('');
  print('diverging cases: $n of ${cases.length}');
  final ks = byCat.keys.toList()..sort();
  for (final k in ks) {
    print('  $k ${byCat[k]}');
  }
}
