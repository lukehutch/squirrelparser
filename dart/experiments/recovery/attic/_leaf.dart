// _leaf.dart -- print the repair LEAVES both engines chose, for the cases where
// I63 moved the score.
//
// The delta run says m100 wins every `truncate` case and loses every *-insert
// case. A skeleton shows the shape that resulted; it does not show the repairs
// that produced it, and the question -- whether `site`-as-runs was pricing
// LOCALITY while `site`-as-events prices VOLUME -- is a question about the
// repairs. So read them.
import 'package:squirrel_parser/squirrel_parser.dart';

import 'astdiff.dart';
import 'm98.dart' as runs;
import 'm100.dart' as events;

/// Every repair the tree carries, in input order. Each engine declares its own
/// `Filled`, so the caller supplies the test for one.
String repairs(MatchResult m, String input, String? Function(MatchResult) fill) {
  final out = <String>[];
  void walk(MatchResult n) {
    final f = fill(n);
    if (n is SyntaxError) {
      out.add(n.len == 0
          ? 'FILL?@${n.pos}'
          : 'SKIP "${input.substring(n.pos, n.pos + n.len)}"@${n.pos}');
    } else if (f != null) {
      out.add('FILL "$f"@${n.pos}');
    }
    n.subClauseMatches.forEach(walk);
  }

  walk(m);
  return out.isEmpty ? '(none)' : out.join('  ');
}

const cases = <(String, String)>[
  ('expr', '(a*b)+(c*dQ-(e+f)'),
  ('stmt', 'z a=1; b=2; { c=3; if (d) { e=4; } f=5; } g=6; }'),
  ('stmt', '{ a=1; b=2; { c=3; if (d) z e=4; } f=5; } g=6; }'),
  ('json', '{"a":{"b":{"c":[1,2,{"d":[3,4]}]}},"e":[[1",[2,3]]}'),
  ('expr', '(a*b"+(c*d)-(e+f)'),
  ('stmt', 'if (a) { b=1; } if (c) { d=2; " e=3;'),
  ('stmt', 'x=1; y=2; z=3; { p=4; q=5; " r=6;'),
  ('expr', '((a+b)*(c-d))/((e+f))(g-h))'),
  ('stmt', 'x=1; if (x) { y=2; z=3; ) w=4;'),
  ('stmt', 'x=1; if (x) '),
  ('stmt', 'if (a'),
  ('stmt', 'if (a) { if (b)'),
];

void main() {
  final rules = <String, Map<String, Clause>>{
    for (final c in corpora) c.name: MetaGrammar.parseGrammar(c.grammar)
  };
  final ra = <String, runs.SuperDot3>{
    for (final c in corpora)
      c.name: runs.SuperDot3(rules: rules[c.name]!, topRuleName: c.top)
  };
  final rb = <String, events.SuperDot3>{
    for (final c in corpora)
      c.name: events.SuperDot3(rules: rules[c.name]!, topRuleName: c.top)
  };

  for (final (g, s) in cases) {
    print('$g  «$s»');
    print('  m98  runs   cost ${ra[g]!.recoverCost(s)}  '
        '${repairs(ra[g]!.recover(s), s, (n) => n is runs.Filled ? n.text : null)}');
    print('  m100 events cost ${rb[g]!.recoverCost(s)}  '
        '${repairs(rb[g]!.recover(s), s, (n) => n is events.Filled ? n.text : null)}');
    print('');
  }
}
