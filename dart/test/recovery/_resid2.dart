// Scratch: aggregate classification of c13's imperfect battery cases.
// For each case scoring < 1.0: grammar, category, score, and a coarse
// signature read off expected-vs-produced skeletons:
//   prefix     produced is a prefix of expected (engine stopped early)
//   suffix     produced is a suffix of expected (engine skipped the head)
//   swallow    produced has FEWER labels but is not prefix/suffix (a span
//              of expected labels is missing from the middle)
//   extra      produced has MORE labels (engine invented structure)
//   diverge    same length, different labels (renaming/reassociation)
//   other      none of the above
import 'package:squirrel_parser/squirrel_parser.dart';

import '../../experiments/recovery/c13.dart' as eng;
import 'astdiff.dart';

String signature(List<String> e, List<String> g) {
  if (g.isEmpty) return 'empty';
  if (e.length == g.length) {
    var same = true;
    for (var i = 0; i < e.length; i++) {
      if (e[i] != g[i]) {
        same = false;
        break;
      }
    }
    return same ? 'equal' : 'diverge';
  }
  if (g.length < e.length) {
    var prefix = true;
    for (var i = 0; i < g.length; i++) {
      if (e[i] != g[i]) {
        prefix = false;
        break;
      }
    }
    if (prefix) return 'prefix';
    var suffix = true;
    for (var i = 0; i < g.length; i++) {
      if (e[e.length - g.length + i] != g[i]) {
        suffix = false;
        break;
      }
    }
    if (suffix) return 'suffix';
    // Is produced a subsequence of expected (a middle span dropped)?
    var j = 0;
    for (var i = 0; i < e.length && j < g.length; i++) {
      if (e[i] == g[j]) j++;
    }
    return j == g.length ? 'swallow' : 'mixed';
  }
  return 'extra';
}

void main(List<String> argv) {
  final cases = weighted(buildBattery());
  final byCorpus = <String, Corpus>{for (final c in corpora) c.name: c};
  final rulesOf = <String, Map<String, Clause>>{
    for (final c in corpora) c.name: MetaGrammar.parseGrammar(c.grammar)
  };
  final original = <String, MatchResult>{};
  for (final c in corpora) {
    for (final doc in c.documents) {
      original['${c.name} $doc'] = Parser(
              rules: rulesOf[c.name]!, topRuleName: c.top, input: doc)
          .parse()
          .root;
    }
  }
  final made = <String, MatchResult? Function(String)>{
    for (final c in corpora)
      c.name: (String s) =>
          eng.Squirrel(rules: rulesOf[c.name]!, topRuleName: c.top).recover(s)
  };

  final counts = <String, int>{};
  final byCat = <String, int>{};
  final rows = <(double, int, String, String, String)>[];
  for (var i = 0; i < cases.length; i++) {
    final k = cases[i];
    final c = byCorpus[k.grammar]!;
    MatchResult? produced;
    try {
      produced = made[k.grammar]!(k.mutant);
    } catch (_) {}
    final exp =
        expectedFor(k, original['${k.grammar} ${k.original}']!, c.named);
    final s = scoreCase(
        produced: produced,
        expected: exp,
        inputLen: k.mutant.length,
        named: c.named);
    if (s.score >= 1.0) continue;
    final got =
        produced == null ? <String>[] : skeleton(produced, c.named);
    final sig = signature(exp, got);
    counts[sig] = (counts[sig] ?? 0) + 1;
    byCat['${k.category} $sig'] = (byCat['${k.category} $sig'] ?? 0) + 1;
    rows.add((s.score, i, k.grammar, k.category, sig));
  }
  rows.sort((a, b) => a.$1.compareTo(b.$1));

  print('imperfect: ${rows.length} of ${cases.length}');
  print('');
  print('by signature:');
  final sigs = counts.keys.toList()..sort();
  for (final s in sigs) {
    print('  ${s.padRight(8)} ${counts[s]}');
  }
  print('');
  print('by category x signature:');
  final cats = byCat.keys.toList()..sort();
  for (final s in cats) {
    print('  ${s.padRight(24)} ${byCat[s]}');
  }
  print('');
  final show = argv.isNotEmpty ? int.parse(argv[0]) : 25;
  print('worst $show:');
  for (var r = 0; r < show && r < rows.length; r++) {
    final (score, i, g, cat, sig) = rows[r];
    final k = cases[i];
    print('  i=$i $g $cat $sig ${score.toStringAsFixed(3)} '
        'mut=${k.mutant.replaceAll('\n', r'\n')}');
  }
}
