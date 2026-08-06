// _r3gap.dart -- where exactly does r3 still lose to m143, and to what?
//
// The category table says delim-insert (-0.022), literal-damage (-0.020),
// junk-insert (-0.016) and truncate (-0.015) are the whole remaining gap. A
// category average cannot say WHY, so this prints, per losing case, the
// skeleton the battery expected against the two engines' skeletons and the
// marks each chose. A pattern across those is what a tweak could close.
import 'package:squirrel_parser/squirrel_parser.dart';

import 'astdiff.dart';
import '_score1.dart' show resolve;

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

void main(List<String> argv) {
  final want = argv.isEmpty ? null : argv[0];
  final show = argv.length > 1 ? int.parse(argv[1]) : 6;
  final a = resolve('r3')!, b = resolve('m143')!;
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
  final mkA = {for (final c in corpora) c.name: a(rulesOf[c.name]!, c.top)};
  final mkB = {for (final c in corpora) c.name: b(rulesOf[c.name]!, c.top)};

  final losses = <(double, Case, MatchResult?, MatchResult?, List<String>)>[];
  final byCat = <String, List<double>>{};
  final seen = <String>{};
  for (final k in weighted(buildBattery())) {
    if (!seen.add('${k.grammar}\x00${k.mutant}\x00${k.category}')) continue;
    final c = byName[k.grammar]!;
    final exp = expectedFor(k, origOf['${k.grammar} ${k.original}']!, c.named);
    MatchResult? ra, rb;
    try {
      ra = mkA[k.grammar]!(k.mutant);
    } catch (_) {}
    try {
      rb = mkB[k.grammar]!(k.mutant);
    } catch (_) {}
    final sa = scoreCase(
        produced: ra, expected: exp, inputLen: k.mutant.length, named: c.named);
    final sb = scoreCase(
        produced: rb, expected: exp, inputLen: k.mutant.length, named: c.named);
    final d = sb.score - sa.score;
    (byCat[k.category] ??= []).add(d);
    if (d > 1e-9) losses.add((d, k, ra, rb, exp));
  }

  print('deficit of r3 against m143, by category:');
  final cats = byCat.keys.toList()
    ..sort((x, y) =>
        byCat[y]!.fold(0.0, (s, v) => s + v).compareTo(
            byCat[x]!.fold(0.0, (s, v) => s + v)));
  for (final c in cats) {
    final v = byCat[c]!;
    final tot = v.fold(0.0, (s, x) => s + x);
    final lost = v.where((x) => x > 1e-9).length;
    print('  ${c.padRight(16)} total ${tot.toStringAsFixed(2).padLeft(6)}  '
        'over ${lost.toString().padLeft(3)} of ${v.length} cases  '
        'mean loss ${(lost == 0 ? 0 : tot / lost).toStringAsFixed(3)}');
  }

  losses.sort((x, y) => y.$1.compareTo(x.$1));
  final pick = want == null
      ? losses
      : losses.where((l) => l.$2.category == want).toList();
  print('\nworst ${show} losses${want == null ? '' : ' in $want'} '
      '(${pick.length} losing cases):');
  for (final (d, k, ra, rb, exp) in pick.take(show)) {
    final ma = <String>[], mb = <String>[];
    if (ra != null) marks(ra, k.mutant, ma);
    if (rb != null) marks(rb, k.mutant, mb);
    final c = byName[k.grammar]!;
    print('\n  -${d.toStringAsFixed(3)}  ${k.grammar} ${k.category}');
    print('    input `${k.mutant}`');
    print('    want  ${flat(exp)}');
    print('    r3    ${flat(skeleton(ra!, c.named))}');
    print('       marks: ${ma.join(' ')}');
    print('    m143  ${flat(skeleton(rb!, c.named))}');
    print('       marks: ${mb.join(' ')}');
  }
}
