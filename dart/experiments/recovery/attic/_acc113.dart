// _acc113.dart -- do the brief's two named cases survive I68 (no zero-length
// fill), and what does the newly-priced predicate actually do on real input?
//
// I68 removes a candidate that always cost 0, and cost is the FIRST key in
// `_better`, so every tie it used to win silently is re-decided. The two cases
// the brief settles by hand are exactly what that is most likely to break.
// Modelled on _dc77.dart: read the TREE and the repair leaves, not a repaired
// string.
//
// The second half runs the `stmt` corpus, whose `Name <- !Keyword [a-z]+` is the
// pattern that made the hole reachable on the battery (astdiff.dart:250-251).
import 'package:squirrel_parser/squirrel_parser.dart';

import 'astdiff.dart' show corpora;
import 'final_table.dart' show buildSetup;
import 'm105.dart' as before;
import 'm113.dart' as after;

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

void report(String name, String s, String want, before.SuperDot3 a,
    after.SuperDot3 b) {
  print('$name\n  input  $s');
  if (want.isNotEmpty) print('  want   $want');
  print('  m105   cost ${a.recoverCost(s)}   '
      '${repairs(a.recover(s), s, (n) => n is before.Filled ? n.text : null)}');
  print('  m113   cost ${b.recoverCost(s)}   '
      '${repairs(b.recover(s), s, (n) => n is after.Filled ? n.text : null)}');
  print('');
}

void main() {
  final rules = buildSetup().$1;
  final a = before.SuperDot3(rules: rules, topRuleName: 'JSON');
  final b = after.SuperDot3(rules: rules, topRuleName: 'JSON');
  for (final (name, s, want) in <(String, String, String)>[
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
  ]) {
    report(name, s, want, a, b);
  }

  // THE PREDICATE ON REAL INPUT. `Name <- !Keyword [a-z]+` guards every bare
  // word in the `stmt` corpus, so before I68 any word position could discharge
  // the guard for nothing -- which is how a free pass reached the battery.
  print('--- stmt corpus: Name <- !Keyword [a-z]+ ---\n');
  final st = corpora.firstWhere((c) => c.name == 'stmt');
  final sr = MetaGrammar.parseGrammar(st.grammar);
  final sa = before.SuperDot3(rules: sr, topRuleName: st.top);
  final sb = after.SuperDot3(rules: sr, topRuleName: st.top);
  for (final (name, s, want) in <(String, String, String)>[
    (
      'keyword where a name belongs',
      'if = 1;',
      '`if` cannot be a Name, so this costs SOMETHING',
    ),
    ('truncated if-block', 'if (a) { b=1;', ''),
    ('missing semicolon', 'x=1 y=2;', ''),
    ('deleted brace', 'if (a) { b=1; c=2;', ''),
  ]) {
    report(name, s, want, sa, sb);
  }
}
