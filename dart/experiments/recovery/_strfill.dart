// Does `Str` with length > 1 actually occur in the battery's grammars, and does
// pricing it by its length change any rule's `_minFill`? A score that does not
// move is only evidence if the branch under test is reached AND changes a value
// the engine reads.
import 'package:squirrel_parser/squirrel_parser.dart';

import 'astdiff.dart';

const int _never = 1 << 30;

/// r9's `_minFill` fixed point, with the `Str` pricing under a flag.
Map<Clause, int> fills(Map<String, Clause> rules, {required bool byLength}) {
  final fill = <Clause, int>{};
  final all = <Clause>[];
  void collect(Clause k) {
    if (fill.containsKey(k)) return;
    fill[k] = _never;
    all.add(k);
    if (k is Ref) {
      final r = rules[k.ruleName];
      if (r != null) collect(r);
    } else if (k is HasOneSubClause) {
      collect(k.subClause);
    } else if (k is HasMultipleSubClauses) {
      k.subClauses.forEach(collect);
    }
  }

  rules.values.forEach(collect);

  int fillOf(Clause c) {
    if (c is Ref) return fill[rules[c.ruleName]] ?? _never;
    if (c is Seq) {
      var n = 0;
      for (final k in c.subClauses) {
        final v = fill[k]!;
        if (v >= _never) return _never;
        n += v;
      }
      return n;
    }
    if (c is First) {
      var n = _never;
      for (final k in c.subClauses) {
        if (fill[k]! < n) n = fill[k]!;
      }
      return n;
    }
    if (c is Repetition) return c.requireOne ? fill[c.subClause]! : 0;
    if (c is Optional || c is FollowedBy || c is NotFollowedBy) return 0;
    if (byLength && c is Str) return c.text.length;
    return c is Nothing ? 0 : 1;
  }

  for (var moved = true; moved;) {
    moved = false;
    for (final k in all) {
      final v = fillOf(k);
      if (v < fill[k]!) {
        fill[k] = v;
        moved = true;
      }
    }
  }
  return fill;
}

void main() {
  for (final c in corpora) {
    final rules = MetaGrammar.parseGrammar(c.grammar);
    final flat = fills(rules, byLength: false);
    final len = fills(rules, byLength: true);
    final changed = <String>[];
    for (final e in rules.entries) {
      final a = flat[e.value], b = len[e.value];
      if (a != b) changed.add('${e.key} $a->$b');
    }
    // Every clause, not just rule tops: `_seq` gives up a SLOT, and a slot is
    // usually not a rule top.
    var slots = 0;
    for (final k in flat.keys) {
      if (flat[k] != len[k]) slots++;
    }
    print('${c.name}: rules changed = ${changed.length} $changed');
    print('${c.name}: clauses changed = $slots of ${flat.length}');
  }
}
