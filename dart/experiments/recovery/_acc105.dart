// _acc105.dart -- do the brief's two named cases still hold after I61, I62, I63 and I64?
//
// Both new keys change which reading wins a tie, so the two the brief decides by
// hand are exactly what a tie-break change is most likely to break. Modelled on
// _dc77.dart: read the TREE and the repair leaves, not a repaired string.
import 'package:squirrel_parser/squirrel_parser.dart';

import 'final_table.dart' show buildSetup;
import 'm92.dart' as before;
import 'm105.dart' as after;

const base = '{"a":1,"bc":[2,33,true],"d":{"e":null},"f":"gh"}';

/// Every repair the tree carries, in input order. Each engine declares its own
/// `Filled`, so the caller supplies the test for one.
String repairs(MatchResult m, String input, String? Function(MatchResult) fill) {
  final out = <String>[];
  void walk(MatchResult n) {
    final f = fill(n);
    if (n is SyntaxError) {
      out.add(n.len == 0
          ? 'missing@${n.pos}'
          : 'delete "${input.substring(n.pos, n.pos + n.len)}"@${n.pos}');
    } else if (f != null) {
      out.add('insert "$f"@${n.pos}');
    }
    n.subClauseMatches.forEach(walk);
  }

  walk(m);
  return out.isEmpty ? '(none)' : out.join('  ');
}

void main() {
  final rules = buildSetup().$1;
  final a = before.SuperDot3(rules: rules, topRuleName: 'JSON');
  final b = after.SuperDot3(rules: rules, topRuleName: 'JSON');
  final cases = <(String, String, String)>[
    (
      'BRIEF 1: `,3true` must become `,3,true`, not `,true`',
      base.replaceFirst('[2,33,true]', '[2,3,3true]'),
      'insert a comma between `3` and `true`; do NOT delete the `3`',
    ),
    (
      'BRIEF 2: `[,2,` must become `[2,`',
      base.replaceFirst('[2,33,true]', '[,2,33,true]'),
      'delete the leading comma; do NOT invent a value before it',
    ),
    ('B021 `[2`->`2[`', '{"a":1,"bc":2[,33,true],"d":{"e":null},"f":"gh"}', ''),
    ('`ture`', base.replaceFirst('true', 'ture'), ''),
    ('`"a":"1`', base.replaceFirst('"a":1', '"a":"1'), ''),
    ('`"a":` (empty)', base.replaceFirst('"a":1', '"a":'), ''),
  ];
  for (final (name, s, want) in cases) {
    print('$name\n  input  $s');
    if (want.isNotEmpty) print('  want   $want');
    print('  m92    cost ${a.recoverCost(s)}   '
        '${repairs(a.recover(s), s, (n) => n is before.Filled ? n.text : null)}');
    print('  m105   cost ${b.recoverCost(s)}   '
        '${repairs(b.recover(s), s, (n) => n is after.Filled ? n.text : null)}');
    print('');
  }
}
