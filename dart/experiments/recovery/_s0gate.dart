// _s0gate.dart -- every honesty gate's probes, replicated for the scratch
// engine _s0 (the tracked gate files must never import untracked scratch).
import 'package:squirrel_parser/squirrel_parser.dart';

import 'c4.dart' as s0;
import 'astdiff.dart';

MatchResult? rec(Map<String, Clause> rules, String top, String s) =>
    s0.Squirrel(rules: rules, topRuleName: top).recover(s);

int cost(Map<String, Clause> rules, String top, String s) =>
    s0.Squirrel(rules: rules, topRuleName: top).recoverCost(s);

int deleted(MatchResult m) {
  var n = 0;
  void walk(MatchResult x) {
    if (x is SyntaxError) n += x.len;
    x.subClauseMatches.forEach(walk);
  }

  walk(m);
  return n;
}

bool sameShape(MatchResult? got, List<String> want, Set<String> named) {
  if (got == null) return false;
  final have = skeleton(got, named);
  if (have.length != want.length) return false;
  for (var i = 0; i < have.length; i++) {
    if (have[i] != want[i]) return false;
  }
  return true;
}

String? arm(MatchResult m, Set<String> alts) {
  final c = m.clause;
  final n = c is Ref ? c.ruleName : null;
  if (n != null && alts.contains(n)) return n;
  for (final k in m.subClauseMatches) {
    final r = arm(k, alts);
    if (r != null) return r;
  }
  return null;
}

void main() {
  // --- _accept -------------------------------------------------------------
  const base = '{"a":1,"bc":[2,33,true],"d":{"e":null},"f":"gh"}';
  final jr = MetaGrammar.parseGrammar(jsonGrammar);
  final named = corpora.firstWhere((c) => c.name == 'json').named;
  List<String> shapeOf(String s) =>
      skeleton(Parser(rules: jr, topRuleName: 'JSON', input: s).parse().root,
          named);
  final cx2rules = MetaGrammar.parseGrammar("S <- A 'x' 'a';\nA <- [ab];\n");
  final tcx = rec(cx2rules, 'S', 'xa');
  final cx2 = tcx != null && deleted(tcx) == 0;
  final b1 = sameShape(
      rec(jr, 'JSON', base.replaceFirst('[2,33,true]', '[2,3,3true]')),
      shapeOf(base.replaceFirst('[2,33,true]', '[2,3,3,true]')),
      named);
  final b2 = sameShape(
      rec(jr, 'JSON', base.replaceFirst('[2,33,true]', '[,2,33,true]')),
      shapeOf(base),
      named);
  print('accept  cx2=${cx2 ? 1 : 0} b1=${b1 ? 1 : 0} b2=${b2 ? 1 : 0}'
      '${cx2 && b1 && b2 ? "  PASS" : "  FAIL"}');

  // --- _freespan -----------------------------------------------------------
  const g4 = "Top <- C 'q' 'r' 's';\nC <- E / W;\nE <- . 'a' 'b';\n"
      'W <- . . . .;\n';
  const g5 = "Top <- C 'q' 'r' 's' 't';\nC <- E / W;\nE <- . 'a' 'b';\n"
      'W <- . . . .;\n';
  const g6 = "Top <- V ';';\nV <- Str / Word;\nWord <- [a-z]*;\n"
      "Str <- '\"' [a-z]* '\"';\n";
  final fs = <(String, String, int)>[
    (g4, 'xxab', 3),
    (g4, 'xyab', 3),
    (g5, 'xxab', 4),
    (g5, 'xyab', 4),
    (g6, 'zzz', 1),
  ];
  var fsBad = 0;
  final fsGot = <int>[];
  for (final (g, s, want) in fs) {
    final c = cost(MetaGrammar.parseGrammar(g), 'Top', s);
    fsGot.add(c);
    if (c != want) fsBad++;
  }
  print('freespan ${fsGot.join(" ")}  ${fsBad == 0 ? "PASS" : "FAIL $fsBad/5"}');

  // --- _recommit -----------------------------------------------------------
  const armsOf = <String, Set<String>>{
    'json': {'Object', 'Array', 'String', 'Number', 'Boolean', 'Null'},
    'stmt': {'Block', 'If', 'Assign'},
  };
  final probes = <(String, String, String)>[
    ('json', '[1,[2,', 'Array'),
    ('json', '[1,[2,[3,', 'Array'),
    ('json', '[1,[2,[3,[4', 'Array'),
    ('json', '{"a":', 'Object'),
    ('json', '{"a":{"b":', 'Object'),
    ('json', '{"p":[1,2,3],"q":[4,5,6],"', 'Object'),
    ('json', '[{"x":[1,', 'Array'),
    ('stmt', '{ a=1; b=2;', 'Block'),
    ('stmt', '{ a=1; { b=2;', 'Block'),
    ('stmt', 'if (a) { b=1;', 'If'),
    ('stmt', 'if (a) { if (b) { c=', 'If'),
    ('stmt', 'x=1; if (a) { b=', 'Assign'),
    ('json', '[1,[2,[3,[4]]],5"', 'Array'),
    ('stmt', '{ a=1; { b=2; } if (c) d=3; "', 'Block'),
    ('stmt', '{ a=1; b=2; { c=3; if (d) { e=4; } f=5; } g=6; "', 'Block'),
    ('stmt', '{ a=1; b=2; { c=3; if (d) { e=4; } f=5; } g=6; \\\\', 'Block'),
  ];
  final rulesOf = {
    for (final c in corpora) c.name: MetaGrammar.parseGrammar(c.grammar)
  };
  var rcBad = <String>[];
  for (final (g, s, want) in probes) {
    final corpus = corpora.firstWhere((c) => c.name == g);
    String? got;
    try {
      final m = rec(rulesOf[g]!, corpus.top, s);
      got = m == null ? 'null' : arm(m, armsOf[g]!);
    } catch (_) {
      got = 'THREW';
    }
    if (got != want) rcBad.add('"$s" -> $got (want $want)');
  }
  print('recommit ${16 - rcBad.length}/16  '
      '${rcBad.isEmpty ? "PASS" : "FAIL: ${rcBad.join("; ")}"}');

  // --- _conf1 --------------------------------------------------------------
  const neg = "Top <- Item+;\nItem <- !Kw Word WS;\nKw <- \"if\";\n"
      'Word <- [a-z]+;\n~WS <- [ ]*;\n';
  const pos = "Top <- Item+;\nItem <- &Kw Word WS;\nKw <- \"if\";\n"
      'Word <- [a-z]+;\n~WS <- [ ]*;\n';
  final cf = <(String, String, bool)>[
    (neg, 'ab', true),
    (neg, 'if', false),
    (neg, 'if ab', false),
    (pos, 'if', true),
    (pos, 'ab', false),
    (pos, 'ab if', false),
  ];
  var freePasses = 0;
  final row = <String>[];
  for (final (g, s, ok) in cf) {
    int c;
    try {
      c = cost(MetaGrammar.parseGrammar(g), 'Top', s);
    } catch (_) {
      row.add('ERR');
      continue;
    }
    if (!ok && c == 0) freePasses++;
    row.add('$c');
  }
  print('conf1   ${row.join(" ")}  free-passes=$freePasses  '
      '${freePasses == 0 ? "PASS" : "FAIL"}');
}
