// _r3unc.dart -- which cases does a candidate fail to cover, and how?
import 'package:squirrel_parser/squirrel_parser.dart';

import 'astdiff.dart';
import '_r3score.dart' show builds;

void main(List<String> argv) {
  final build = builds[argv[0]]!;
  final rulesOf = {
    for (final c in corpora) c.name: MetaGrammar.parseGrammar(c.grammar)
  };
  final byName = {for (final c in corpora) c.name: c};
  final origOf = <String, MatchResult>{};
  for (final c in corpora) {
    for (final doc in c.documents) {
      origOf['${c.name} $doc'] =
          Parser(rules: rulesOf[c.name]!, topRuleName: c.top, input: doc)
              .parse()
              .root;
    }
  }
  final made = {
    for (final c in corpora) c.name: build(rulesOf[c.name]!, c.top)
  };
  var n = 0;
  for (final k in weighted(buildBattery())) {
    final c = byName[k.grammar]!;
    MatchResult? got;
    try {
      got = made[k.grammar]!(k.mutant);
    } catch (_) {}
    final s = scoreCase(
        produced: got,
        expected: expectedFor(k, origOf['${k.grammar} ${k.original}']!, c.named),
        inputLen: k.mutant.length,
        named: c.named);
    if (s.covered) continue;
    if (++n > 8) continue;
    print('${k.grammar} ${k.category} `${k.mutant}`');
    print('   root pos=${got?.pos} len=${got?.len} of ${k.mutant.length} '
        '${got.runtimeType}');
    for (final kid in got?.subClauseMatches ?? const <MatchResult>[]) {
      print('     kid ${kid.runtimeType} pos=${kid.pos} len=${kid.len} '
          '${kid.clause?.runtimeType}');
    }
  }
  print('uncovered: $n');
}
