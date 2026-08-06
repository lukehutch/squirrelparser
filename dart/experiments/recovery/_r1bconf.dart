// _conf1 and _freespan run against _r1b, copied rather than registered: both are
// tracked gates being read by an audit run, and adding a scratch engine to them
// would move them under the auditor.
import 'package:squirrel_parser/squirrel_parser.dart';

import '_conf1.dart' show negGrammar, posGrammar, pegAccepts;
import '_freespan.dart' show probes;
import '_r1b.dart' as r1b;
import 'r1.dart' as r1;

void main() {
  print('=== conformance: which engines hand a failing predicate a free pass?');
  final cases = <(String, String, String)>[
    ('neg', negGrammar, 'ab'),
    ('neg', negGrammar, 'if'),
    ('neg', negGrammar, 'if ab'),
    ('pos', posGrammar, 'if'),
    ('pos', posGrammar, 'ab'),
    ('pos', posGrammar, 'ab if'),
  ];
  final rules = {
    'neg': MetaGrammar.parseGrammar(negGrammar),
    'pos': MetaGrammar.parseGrammar(posGrammar),
  };
  final accepts = [for (final (g, _, s) in cases) pegAccepts(rules[g]!, 'Top', s)];
  for (final (name, cost) in <(String, int Function(Map<String, Clause>, String, String))>[
    ('r1', (r, t, s) => r1.Squirrel(rules: r, topRuleName: t).recoverCost(s)),
    ('r1b', (r, t, s) => r1b.Squirrel(rules: r, topRuleName: t).recoverCost(s)),
  ]) {
    final costs = <String>[];
    var free = 0;
    for (var i = 0; i < cases.length; i++) {
      final (g, _, s) = cases[i];
      final c = cost(rules[g]!, 'Top', s);
      if (!accepts[i] && c == 0) free++;
      costs.add('$c');
    }
    print('  ${name.padRight(4)} free-passes=${free == 0 ? '.' : '$free/4'}'
        '   costs=${costs.join(' ')}');
  }

  print('');
  print('=== free span: may a repair DELETE input that already matched?');
  final gs = {for (final (g, src, _, _) in probes) g: MetaGrammar.parseGrammar(src)};
  for (final (name, cost) in <(String, int Function(Map<String, Clause>, String, String))>[
    ('r1', (r, t, s) => r1.Squirrel(rules: r, topRuleName: t).recoverCost(s)),
    ('r1b', (r, t, s) => r1b.Squirrel(rules: r, topRuleName: t).recoverCost(s)),
  ]) {
    final row = <String>[];
    for (final (g, _, s, want) in probes) {
      row.add('$g/$s=${cost(gs[g]!, 'Top', s)}(want<=$want)');
    }
    print('  ${name.padRight(4)} ${row.join('  ')}');
  }
}
