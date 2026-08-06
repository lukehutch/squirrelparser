// THE SWALLOW GATE. `Str <- '"' Chr* '"'` with `Chr <- [^"\\] / ...` costs a
// bounded number of obligations and then absorbs an UNBOUNDED span, because an
// inverted class accepts anything and so explains nothing about what it took.
// Any repair whose price grows with the damage therefore loses to it eventually,
// and the reading that wins is "the rest of the document is one long string".
//
// Measured grammar-independently, with no rule named: a character is ABSORBED
// when the leaf covering it is an inverted `CharSet` or an `AnyChar`, which is
// exactly the complement of `_Way.net`. The undamaged document's own parse is
// the control -- a document that really does contain a long string should not
// be reported -- so what is scored is how much MORE the repair absorbs than the
// truth does, as a fraction of the input.
import 'package:squirrel_parser/squirrel_parser.dart';

import 'astdiff.dart';
import '_r9base.dart' as r9;

/// Characters covered by a leaf that constrains nothing about them.
int absorbed(MatchResult t) {
  var n = 0;
  void walk(MatchResult m) {
    final c = m.clause;
    if (m.subClauseMatches.isEmpty &&
        ((c is CharSet && c.inverted) || c is AnyChar)) {
      n += m.len;
      return;
    }
    for (final k in m.subClauseMatches) {
      walk(k);
    }
  }

  walk(t);
  return n;
}

void main(List<String> argv) {
  final cut = argv.isEmpty ? 0.5 : double.parse(argv[0]);
  final all = buildBattery();
  final rulesOf = {
    for (final c in corpora) c.name: MetaGrammar.parseGrammar(c.grammar)
  };
  final eng = {
    for (final c in corpora)
      c.name: r9.Squirrel(rules: rulesOf[c.name]!, topRuleName: c.top)
  };
  final truth = <String, int>{};
  for (final c in corpora) {
    for (final doc in c.documents) {
      truth['${c.name} $doc'] = absorbed(
          Parser(rules: rulesOf[c.name]!, topRuleName: c.top, input: doc)
              .parse()
              .root);
    }
  }

  final hits = <(double, Case, int, int)>[];
  final worst = <String, double>{};
  for (final k in all) {
    MatchResult t;
    try {
      t = eng[k.grammar]!.recover(k.mutant);
    } catch (_) {
      continue;
    }
    final got = absorbed(t), was = truth['${k.grammar} ${k.original}']!;
    final extra = (got - was) / k.mutant.length;
    if (extra > (worst[k.grammar] ?? -1)) worst[k.grammar] = extra;
    if (extra >= cut) hits.add((extra, k, got, was));
  }
  hits.sort((a, b) => b.$1.compareTo(a.$1));
  print('battery ${all.length} cases, threshold ${(cut * 100).round()}%');
  for (final e in hits) {
    print('  ${(e.$1 * 100).round().toString().padLeft(3)}%  '
        '${e.$2.grammar} ${e.$2.category.padRight(14)} '
        'absorbs ${e.$3} of ${e.$2.mutant.length} (truth ${e.$4})  '
        '"${e.$2.mutant}"');
  }
  print('SWALLOWS: ${hits.length}');
  for (final c in corpora) {
    print('  worst extra absorption, ${c.name}: '
        '${((worst[c.name] ?? 0) * 100).round()}%');
  }
}
