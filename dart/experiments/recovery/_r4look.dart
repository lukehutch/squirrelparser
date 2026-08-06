// _r4look.dart -- two views over the candidates in `_r4score.dart`'s map.
//
//   dart run _r4look.dart diff A B      per-case score differences, worst first
//   dart run _r4look.dart tree V ...    the tree V produces for each probe
import 'package:squirrel_parser/squirrel_parser.dart';

import 'astdiff.dart';
import '_r4score.dart' show builds;

const probes = <(String, String)>[
  ('json', '{"a":[1,[2,'),
  ('json', '{"a":1,"bc":[2,33,ture],"d":{"e":null},"f":"gh"}'),
  ('json', '{"a:1,"bc":[2,33,true],"d":{"e":null},"f":"gh"}'),
  ('json', '{"a":1,"bc":[2,33,true],"d'),
  ('json', '{"p":[1,2,3],"q":[4,5,6],"'),
  ('stmt', 'x=1; y=2; z=3; { p=4; q=5; " r=6;'),
  ('expr', 'a*(b+'),
  ('expr', 'a*'),
];

void dump(MatchResult m, String s, String pad, StringBuffer b) {
  // `Repaired` is declared inside each engine, so recognise it by name.
  final tag = m is SyntaxError
      ? (m.len == 0 ? 'FILL' : 'DEL `${s.substring(m.pos, m.pos + m.len)}`')
      : '${m.runtimeType == Match ? '' : 'R '}${name(m)}';
  b.writeln('$pad$tag  [${m.pos},${m.pos + m.len})'
      '${m.len > 0 && m.subClauseMatches.isEmpty ? ' `${s.substring(m.pos, m.pos + m.len)}`' : ''}');
  for (final k in m.subClauseMatches) {
    dump(k, s, '$pad  ', b);
  }
}

String name(MatchResult m) {
  final c = m.clause;
  if (c == null) return '.';
  if (c is Ref) return c.ruleName;
  return c.runtimeType.toString();
}

void main(List<String> argv) {
  final rulesOf = {
    for (final c in corpora) c.name: MetaGrammar.parseGrammar(c.grammar)
  };
  final byName = {for (final c in corpora) c.name: c};

  if (argv[0] == 'marks') {
    // marks <variant,...> <g> <in> -- the repair marks and the skeleton
    final g = argv[2], s = argv[3], c = byName[g]!;
    for (final v in argv[1].split(',')) {
      final r = builds[v]!(rulesOf[g]!, c.top)(s);
      final m = <String>[];
      void walk(MatchResult k) {
        if (k is SyntaxError) {
          m.add(k.len == 0
              ? 'fill@${k.pos}'
              : 'del@${k.pos}:${s.substring(k.pos, k.pos + k.len)}');
        }
        for (final j in k.subClauseMatches) {
          walk(j);
        }
      }
      if (r != null) walk(r);
      print('${v.padRight(6)} ${skeleton(r!, c.named).join(' ')}');
      print('       marks: ${m.join(' ')}');
    }
    return;
  }

  if (argv[0] == 'tree') {
    // tree <variant,...>            -- the standing probe list
    // tree <variant,...> <g> <in>   -- one named input
    final vs = argv[1].split(',');
    final list = argv.length > 2 ? [(argv[2], argv[3])] : probes;
    for (final (g, s) in list) {
      for (final v in vs) {
        final c = byName[g]!;
        final r = builds[v]!(rulesOf[g]!, c.top)(s);
        final b = StringBuffer();
        if (r != null) dump(r, s, '  ', b);
        print('\n=== $v  $g `$s`\n$b');
      }
    }
    return;
  }

  // -- diff ------------------------------------------------------------------
  final a = argv[1], bn = argv[2];
  final cases = weighted(buildBattery());
  final original = <String, MatchResult>{};
  for (final c in corpora) {
    for (final doc in c.documents) {
      original['${c.name} $doc'] =
          Parser(rules: rulesOf[c.name]!, topRuleName: c.top, input: doc)
              .parse()
              .root;
    }
  }
  final ea = {for (final c in corpora) c.name: builds[a]!(rulesOf[c.name]!, c.top)};
  final eb = {for (final c in corpora) c.name: builds[bn]!(rulesOf[c.name]!, c.top)};

  final rows = <(double, String, String, double, double)>[];
  final seen = <String>{};
  for (final k in cases) {
    if (!seen.add('${k.grammar}\x00${k.mutant}')) continue;
    final c = byName[k.grammar]!;
    final exp = expectedFor(k, original['${k.grammar} ${k.original}']!, c.named);
    double run(MatchResult? Function(String) f) {
      MatchResult? r;
      try {
        r = f(k.mutant);
      } catch (_) {}
      return scoreCase(
              produced: r, expected: exp, inputLen: k.mutant.length, named: c.named)
          .score;
    }
    final sa = run(ea[k.grammar]!), sb = run(eb[k.grammar]!);
    if ((sa - sb).abs() > 1e-9) rows.add((sb - sa, k.category, k.mutant, sa, sb));
  }
  rows.sort((x, y) => x.$1.compareTo(y.$1));
  var up = 0, down = 0;
  for (final r in rows) {
    r.$1 > 0 ? up++ : down++;
  }
  print('$a -> $bn: $down worse, $up better, over ${seen.length} distinct cases\n');
  print('  delta      $a      $bn  category         input');
  for (final r in rows) {
    print('${r.$1.toStringAsFixed(3).padLeft(7)} '
        '${r.$4.toStringAsFixed(3).padLeft(7)} ${r.$5.toStringAsFixed(3).padLeft(7)}  '
        '${r.$2.padRight(15)} `${r.$3}`');
  }
}
