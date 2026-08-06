// _r4probe.dart -- print what each engine actually does to a named probe, so a
// candidate is designed against the tree it produces rather than against a
// guess about it.
import 'package:squirrel_parser/squirrel_parser.dart';

import 'astdiff.dart';
import 'r2.dart' as r2;
import 'r3.dart' as r3;
import 'r4.dart' as r4;
import 'm143.dart' as m143;

void marks(MatchResult m, String s, List<String> out) {
  if (m is SyntaxError) {
    out.add(m.len == 0
        ? 'fill@${m.pos}'
        : 'del@${m.pos}:${s.substring(m.pos, m.pos + m.len)}');
  }
  for (final k in m.subClauseMatches) {
    marks(k, s, out);
  }
}

String flat(List<String> sk) {
  final b = StringBuffer();
  for (final t in sk) {
    b.write(t == '(' || t == ')' ? t : ' $t');
  }
  return b.toString().replaceAll(' (', '(').trim();
}

/// grammar name -> probe inputs
const probes = <(String, String)>[
  ('json', '{"a":[1,[2,'),
  ('json', '{"a":1,"bc":[2,33,ture],"d":{"e":null},"f":"gh"}'),
  ('json', '{"a:1,"bc":[2,33,true],"d":{"e":null},"f":"gh"}'),
  ('stmt', 'x=1; y=2; z=3; { p=4; q=5; " r=6;'),
  ('stmt', 'x=1; y=2; z=3; { p=4; q=5; z} r=6;'),
  ('stmt', '{ a=1; { b=2; } if (c) d=3; z}'),
  ('expr', 'a*'),
  ('expr', '1+2*3'),
  ('json', '{"a":1,"b":[2,3]}'),
  ('stmt', 'x=1; if (x) { y=2; } z=3;'),
];

void main(List<String> argv) {
  final rulesOf = {
    for (final c in corpora) c.name: MetaGrammar.parseGrammar(c.grammar)
  };
  final byName = {for (final c in corpora) c.name: c};
  final engines = <String, MatchResult? Function(Map<String, Clause>, String, String)>{
    'r2': (r, t, s) => r2.Squirrel(rules: r, topRuleName: t).recover(s),
    'r3': (r, t, s) => r3.Squirrel(rules: r, topRuleName: t).recover(s),
    'r4': (r, t, s) => r4.Squirrel(rules: r, topRuleName: t).recover(s),
    'm143': (r, t, s) => m143.SuperDot3(rules: r, topRuleName: t).recover(s),
  };

  // Also score each probe against what the battery expects, where the probe is
  // a real battery case -- otherwise the tree alone is the report.
  final expByMutant = <String, (Case, List<String>)>{};
  final origOf = <String, MatchResult>{};
  for (final c in corpora) {
    for (final doc in c.documents) {
      origOf['${c.name} $doc'] =
          Parser(rules: rulesOf[c.name]!, topRuleName: c.top, input: doc)
              .parse()
              .root;
    }
  }
  for (final k in buildBattery()) {
    expByMutant.putIfAbsent(
        '${k.grammar}\x00${k.mutant}',
        () => (
              k,
              expectedFor(k, origOf['${k.grammar} ${k.original}']!,
                  byName[k.grammar]!.named)
            ));
  }

  final want = argv.isEmpty ? null : argv;
  for (final (g, s) in probes) {
    if (want != null && !want.any((w) => s.contains(w))) continue;
    final c = byName[g]!;
    final e = expByMutant['$g\x00$s'];
    print('\n=== $g `$s`  ${e == null ? '(not a battery case)' : e.$1.category}');
    if (e != null) print('    want  ${flat(e.$2)}');
    for (final name in engines.keys) {
      MatchResult? r;
      try {
        r = engines[name]!(rulesOf[g]!, c.top, s);
      } catch (err) {
        print('    ${name.padRight(5)} CRASH $err');
        continue;
      }
      final m = <String>[];
      marks(r!, s, m);
      final sc = e == null
          ? null
          : scoreCase(
              produced: r,
              expected: e.$2,
              inputLen: s.length,
              named: c.named);
      print('    ${name.padRight(5)} ${sc == null ? '' : sc.score.toStringAsFixed(3)}'
          '  ${flat(skeleton(r, c.named))}');
      print('          marks: ${m.join(' ')}');
    }
  }
}
