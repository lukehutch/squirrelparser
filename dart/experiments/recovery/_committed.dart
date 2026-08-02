// Codex's control, run verbatim against r1 and against the fix.
//
// Claim: `_stops` recurses into subtrees the parser already MATCHED, so a repair
// can delete input that the pure parser had committed to. `_freespan` misses it
// because its probes damage the tail, and this damage is interior.
//
// `Top <- Chunk 'z'; Chunk <- 'a'* 'b'` on `abab`: the pure parser matches
// `Chunk` as `ab` at 0..2. If recovery emits a deletion overlapping 0..2 it has
// destroyed a match the parser already made.
import 'package:squirrel_parser/squirrel_parser.dart';

import 'r1.dart' as r1;
import 'r2.dart' as r2;
import 'r3.dart' as r3;
import 'r4.dart' as r4;
import 'r5.dart' as r5;

void collectErrors(MatchResult m, List<SyntaxError> out) {
  if (m is SyntaxError) out.add(m);
  for (final child in m.subClauseMatches) {
    collectErrors(child, out);
  }
}

typedef Run = MatchResult Function(Map<String, Clause>, String, String);

final engines = <String, Run>{
  'r1': (r, t, s) => r1.Squirrel(rules: r, topRuleName: t).recover(s),
  'r2': (r, t, s) => r2.Squirrel(rules: r, topRuleName: t).recover(s),
  'r3': (r, t, s) => r3.Squirrel(rules: r, topRuleName: t).recover(s),
  'r4': (r, t, s) => r4.Squirrel(rules: r, topRuleName: t).recover(s),
  'r5': (r, t, s) => r5.Squirrel(rules: r, topRuleName: t).recover(s),
};

void main() {
  final a = Str('a');
  final rules = <String, Clause>{
    'Top': Seq([Ref('Chunk'), Str('z')]),
    'Chunk': Seq([ZeroOrMore(a), Str('b')]),
  };
  const input = 'abab';

  final pure = Parser(rules: rules, topRuleName: 'Top', input: input);
  final committed = pure.matchRule('Chunk', 0);
  print('pure Chunk at 0: pos=${committed.pos} len=${committed.len} '
      'mismatch=${committed.isMismatch}');
  if (committed.isMismatch || committed.pos != 0 || committed.len != 2) {
    throw StateError('control setup failed');
  }
  if (!pure.parse().hasSyntaxErrors) {
    throw StateError('input unexpectedly accepted');
  }
  final end = committed.pos + committed.len;

  for (final e in engines.entries) {
    final tree = e.value(rules, 'Top', input);
    final errors = <SyntaxError>[];
    collectErrors(tree, errors);
    final overlaps = errors
        .where((x) =>
            x.len > 0 && x.pos < end && x.pos + x.len > committed.pos)
        .toList();
    print('${e.key.padRight(5)} errors=${errors.map((x) => '${x.pos}..${x.pos + x.len}').toList()}'
        '  ${overlaps.isEmpty ? 'OK' : 'FAILS: deletes committed ${overlaps.map((x) => '${x.pos}..${x.pos + x.len}').toList()}'}');
  }
}
