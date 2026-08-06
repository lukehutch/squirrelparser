// Same PEG-conformance probe, but across every engine, to find out whether
// accepting non-PEG parses is an m26 regression or an axiom-level flaw the whole
// line inherited from the `dot` baseline.
import 'package:squirrel_parser/squirrel_parser.dart';
import 'package:squirrel_parser/src/recovery/dot_recovery.dart';
import 'sd6.dart' as g6;
import 'm15.dart' as g15;
import 'm16.dart' as g16;
import 'm22.dart' as g22;
import 'm26.dart' as g26;

bool inLang(Map<String, Clause> r, String t, String s) {
  final p = Parser(rules: r, topRuleName: t, input: s).parse();
  return !p.hasSyntaxErrors && p.root != null && p.root!.len == s.length;
}

final cases = <(String, String, String, String, int?)>[
  ('possessive star', "S <- 'a'* \"ab\";\n", 'S', 'aab', null),
  ('possessive star+', "S <- 'a'* \"ab\";\n", 'S', 'aaaab', null),
  ('committed choice', "S <- ('a' / \"ab\") 'b';\n", 'S', 'abb', 1),
  ('committed nested', "S <- A 'c';\nA <- 'a' / \"ab\";\n", 'S', 'abc', 1),
  ('greedy optional', "S <- 'a'? \"ab\";\n", 'S', 'aab', 0),
];

void main() {
  final engines = <(String, int Function(Map<String, Clause>, String, String))>[
    ('dot', (r, t, s) { final e = DotRecovery(rules: r, topRuleName: t); e.recover(s); return e.lastTotalCost; }),
    ('v6', (r, t, s) => g6.SuperDot3(rules: r, topRuleName: t).recoverCost(s)),
    ('m15', (r, t, s) => g15.SuperDot3(rules: r, topRuleName: t).recoverCost(s)),
    ('m16', (r, t, s) => g16.SuperDot3(rules: r, topRuleName: t).recoverCost(s)),
    ('m22', (r, t, s) => g22.SuperDot3(rules: r, topRuleName: t).recoverCost(s)),
    ('m26', (r, t, s) => g26.SuperDot3(rules: r, topRuleName: t).recoverCost(s)),
  ];
  print('truth = brute-force distance to the PEG language (null = none within 3)\n');
  final head = ['case'.padRight(18), 'truth'.padLeft(6)];
  for (final e in engines) head.add(e.$1.padLeft(6));
  print(head.join(' '));
  for (final (name, g, top, s, truth) in cases) {
    final r = MetaGrammar.parseGrammar(g);
    final row = [name.padRight(18), (truth?.toString() ?? '>3').padLeft(6)];
    for (final (_, run) in engines) {
      String v;
      try { v = run(r, top, s).toString(); } catch (_) { v = 'X'; }
      final ok = truth != null && v == truth.toString();
      row.add((ok ? v : '$v!').padLeft(6));
    }
    print(row.join(' '));
    assert(inLang(r, top, s) == (truth == 0));
  }
  print('\n! = disagrees with brute-force truth');
}
