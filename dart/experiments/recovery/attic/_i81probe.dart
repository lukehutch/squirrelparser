// _i81probe.dart -- adversarial cases for I81, the rule that drops a named node
// covering zero characters at or past the end of the input.
//
// I81 is only safe if the pure-memo escape hatch really fires. These grammars
// are built so that a named rule legitimately matches EMPTY at end of input --
// the exact shape where dropping the node would be wrong. If any `KEEP` row
// below loses its node, the rule is unsound and must be narrowed.
import 'package:squirrel_parser/squirrel_parser.dart';

import 'm132.dart' as m132;
import 'm143.dart' as m143;

/// The named-rule labels of [m], in tree order.
List<String> skel(MatchResult m, Set<String> named) {
  final out = <String>[];
  void walk(MatchResult n) {
    final c = n.clause;
    final name = c is Ref ? c.ruleName : null;
    final show = name != null && named.contains(name);
    if (show) out.add(name);
    for (final k in n.subClauseMatches) {
      walk(k);
    }
  }

  walk(m);
  return out;
}

class Probe {
  final String label, grammar, top, input, want;
  final Set<String> named;
  const Probe(this.label, this.grammar, this.top, this.input, this.named,
      this.want);
}

const probes = <Probe>[
  // KEEP: `Tail` matches empty by construction, so a zero-width `Tail` at the
  // end of the input is a reading the frozen parser genuinely admits.
  Probe(
      'KEEP empty-matching rule at EOF',
      "Doc <- '[' Item Tail; Item <- [0-9]; Tail <- (',' Item)*;",
      'Doc',
      '[1',
      {'Doc', 'Item', 'Tail'},
      'Tail'),
  // KEEP: an optional named rule at the end. `Opt <- 'x'?` admits empty.
  Probe('KEEP optional rule at EOF', "Doc <- 'a' Opt; Opt <- 'x'?;", 'Doc', 'a',
      {'Doc', 'Opt'}, 'Opt'),
  // KEEP: a named rule wrapping a zero-or-more, which admits empty.
  Probe('KEEP star rule at EOF', "Doc <- 'a' Rest; Rest <- [0-9]*;", 'Doc', 'a',
      {'Doc', 'Rest'}, 'Rest'),
  // DROP: `Num` requires a digit, so it can never read empty. A zero-width
  // `Num` past the end of the input is invention -- this is I81's target.
  Probe('DROP digit-requiring rule at EOF', "Doc <- '[' Num; Num <- [0-9]+;",
      'Doc', '[', {'Doc', 'Num'}, 'Num'),
];

void main() {
  print('${'case'.padRight(34)}${'engine'.padRight(7)}skeleton');
  var bad = 0;
  for (final p in probes) {
    final rules = MetaGrammar.parseGrammar(p.grammar);
    final keep = p.label.startsWith('KEEP');
    for (final e in ['m132', 'm143']) {
      final r = e == 'm132'
          ? m132.SuperDot3(rules: rules, topRuleName: p.top).recover(p.input)
          : m143.SuperDot3(rules: rules, topRuleName: p.top).recover(p.input);
      final s = skel(r, p.named);
      final has = s.contains(p.want);
      final verdict = e == 'm132'
          ? ''
          : (keep == has ? '  ok' : '  <-- WRONG, expected ${keep ? 'KEEP' : 'DROP'} of ${p.want}');
      if (e == 'm143' && keep != has) bad++;
      print('${p.label.padRight(34)}${e.padRight(7)}${s.join(' ')}$verdict');
    }
  }
  print('');
  print(bad == 0
      ? 'I81 sound on all ${probes.length} adversarial probes'
      : 'I81 UNSOUND on $bad probe(s)');
}
