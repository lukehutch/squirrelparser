// Scratch probe: for chosen battery indices, show expected vs produced
// skeletons side by side, plus the engine's own bill. Usage:
//   dart run _resid.dart <engine> i=571 i=541 ...   (indices into weighted list)
//   dart run _resid.dart <engine> worst=25          (the N worst imperfect)
import 'package:squirrel_parser/squirrel_parser.dart';

import '../../experiments/recovery/c13.dart' as c12;
import 'astdiff.dart';

void main(List<String> argv) {
  if (argv.isEmpty) {
    print('usage: dart run _resid.dart <engine> [i=N | worst=N ...]');
    return;
  }
  final name = argv[0];
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

  final wanted = <int>{};
  var worstN = 0;
  for (final a in argv.skip(1)) {
    if (a.startsWith('i=')) {
      wanted.add(int.parse(a.substring(2)));
    } else if (a.startsWith('worst=')) {
      worstN = int.parse(a.substring(6));
    }
  }

  final rows = <(double, int)>[];
  final made = <String, MatchResult? Function(String)>{};
  for (final c in corpora) {
    made[c.name] = (String s) => c12.Squirrel(rules: rulesOf[c.name]!, topRuleName: c.top).recover(s);
  }
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
    if (s.score < 1.0) rows.add((s.score, i));
  }
  rows.sort((a, b) => a.$1.compareTo(b.$1));

  final pick = <int> {...wanted};
  if (worstN > 0) {
    for (var r = 0; r < worstN && r < rows.length; r++) {
      pick.add(rows[r].$2);
    }
  }

  for (final i in pick) {
    final k = cases[i];
    final c = byCorpus[k.grammar]!;
    MatchResult? produced;
    try {
      produced = made[k.grammar]!(k.mutant);
    } catch (_) {}
    final exp =
        expectedFor(k, original['${k.grammar} ${k.original}']!, c.named);
    final got = produced == null ? null : skeleton(produced, c.named);
    final s = scoreCase(
        produced: produced,
        expected: exp,
        inputLen: k.mutant.length,
        named: c.named);
    print('=== $name i=$i ${k.grammar} ${k.category} score=${s.score.toStringAsFixed(3)}');
    print('  mutant: ${k.mutant.replaceAll('\n', r'\n')}');
    print('  expect: ${exp.join(' ')}');
    if (got != null) print('  got   : ${got.join(' ')}');
    // First divergence point between the two sequences.
    if (got != null) {
      var d = 0;
      while (d < exp.length && d < got.length && exp[d] == got[d]) {
        d++;
      }
      print('  diverges at label $d of ${exp.length}');
    }
  }
}
