// _r3lit.dart -- where does r3 lose to m143 on literal-damage?
//
// literal-damage is a character OUTSIDE quotes that is not a delimiter, quote or
// space: the body of `true`/`false`/`null`, a digit, an identifier, an operator.
// It carries weight 1.5 and is r3's biggest remaining deficit (0.869 vs 0.970).
import 'package:squirrel_parser/squirrel_parser.dart';

import 'astdiff.dart';
import 'm143.dart' as g143;
import 'r3.dart' as r3;

void main(List<String> argv) {
  final want = argv.isEmpty ? 'literal-damage' : argv[0];
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

  final seen = <String>{};
  final rows = <(double, double, Case)>[];
  final byGrammar = <String, List<double>>{};
  for (final k in weighted(buildBattery())) {
    if (k.category != want) continue;
    if (!seen.add('${k.grammar}\x00${k.mutant}')) continue;
    final c = byName[k.grammar]!;
    final exp = expectedFor(k, origOf['${k.grammar} ${k.original}']!, c.named);
    double run(MatchResult? Function(String) f) {
      MatchResult? got;
      try {
        got = f(k.mutant);
      } catch (_) {}
      return scoreCase(
              produced: got,
              expected: exp,
              inputLen: k.mutant.length,
              named: c.named)
          .score;
    }

    final a = run(r3.Squirrel(rules: rulesOf[k.grammar]!, topRuleName: c.top)
        .recover);
    final b = run(g143.SuperDot3(rules: rulesOf[k.grammar]!, topRuleName: c.top)
        .recover);
    rows.add((a, b, k));
    (byGrammar[k.grammar] ??= []).add(b - a);
  }

  print('$want: ${rows.length} distinct cases');
  for (final g in byGrammar.keys) {
    final d = byGrammar[g]!;
    final lost = d.where((x) => x > 1e-9).length;
    print('  $g: r3 behind on $lost/${d.length}, '
        'total deficit ${d.fold(0.0, (s, x) => s + x).toStringAsFixed(2)}');
  }
  rows.sort((x, y) => (y.$2 - y.$1).compareTo(x.$2 - x.$1));
  print('\nworst 14 (r3 score, m143 score, input):');
  for (final (a, b, k) in rows.take(14)) {
    print('  ${a.toStringAsFixed(3)} ${b.toStringAsFixed(3)} '
        '${k.grammar.padRight(5)} `${k.mutant}`');
  }
  // Show trees for the single worst.
  if (rows.isEmpty) return;
  final (_, _, k) = rows.first;
  final c = byName[k.grammar]!;
  print('\n--- worst: `${k.mutant}`  (from `${k.original}`)');
  final e3 = r3.Squirrel(rules: rulesOf[k.grammar]!, topRuleName: c.top);
  final t3 = e3.recover(k.mutant);
  print('r3   cost=${e3.lastCost} '
      '${skeleton(t3, c.named).where((t) => t != '(' && t != ')').join(' ')}');
  final t4 = g143.SuperDot3(rules: rulesOf[k.grammar]!, topRuleName: c.top)
      .recover(k.mutant);
  print('m143 '
      '${skeleton(t4, c.named).where((t) => t != '(' && t != ')').join(' ')}');
  print('want '
      '${expectedFor(k, origOf['${k.grammar} ${k.original}']!, c.named).join(' ').replaceAll('( ', '').replaceAll(' )', '')}');
}
