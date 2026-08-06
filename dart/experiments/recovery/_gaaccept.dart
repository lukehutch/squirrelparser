// _accept.dart -- probe ONE engine on the three cases that constrain the design,
// and print one machine-readable line. One engine per process, for the same
// reason as _score1.dart: an engine that hangs on damaged input is killed by the
// caller's `timeout` rather than blocking every other engine's result.
//
// Usage: dart run _accept.dart <engineName>
// Prints: <name> <ok|x:tag,tag> cx2=<0|1> b1=<0|1> b2=<0|1>
//
// WHY THIS EXISTS SEPARATELY FROM THE BATTERY. The battery scores tree SHAPE
// against the shape a human would expect, over 1824 cases. It is the right
// metric and it is the one the brief asked for, but it cannot stand in for the
// brief's own acceptance cases, for two reasons:
//
//   1. It averages. `[,2,` is one case; six skeleton tokens out of 84 on one of
//      1824 cases is worth about 0.0002 of the aggregate. A hard requirement
//      that moves the metric by 0.0002 is not being enforced by the metric.
//   2. It is shape-only by construction. `astdiff.dart:30-33` records that a
//      `SyntaxError` span and a zero-width fill both carry no rule label, so
//      neither appears in the sequence -- a reading that INVENTS a character and
//      one that DELETES one are scored on what the tree ends up claiming. That
//      is usually what we want; here it is exactly what is under test.
//
// THE THREE CASES, and why each is checked the way it is.
//
//   CX2   `S <- A 'x' 'a';  A <- [ab];` on `xa`. Codex's counterexample. Filling
//         an undetermined A at 0 lets the real `x` and `a` match for nothing.
//         The failure mode is DELETING the `x` that is right there and then
//         asserting another one two columns along -- destroying evidence to buy
//         a reading the evidence already supported. So the check is on deleted
//         characters, not on cost: an engine that deletes nothing here passed,
//         whatever its cost model charges for the fill. Checking cost instead
//         would be checking each engine against its OWN objective, which every
//         engine trivially passes.
//
//   B1    `,3true` must repair as `,3,true`, not `,true` -- the missing comma is
//         one character, dropping the `3` is a whole Number. Checked as skeleton
//         equality against the INTENDED string (with the comma present), not
//         against the pristine corpus string, because the mutation here adds a
//         digit: the correct repair yields four Values in that array, not three.
//
//   B2    `[,2,` must repair as `[2,` -- delete the surplus comma rather than
//         assert a Value before it, "since simply inventing a character to
//         insert is a bit ridiculous (it could be anything, so why pick 0), and
//         deleting the initial comma immediately yields a valid list". Here the
//         intended string IS the pristine one, so the expected skeleton is the
//         corpus tree's. Inventing the Value shows up as 90 tokens against 84.
//
// Both B1 and B2 are checked through `skeleton`, so this file needs no knowledge
// of any engine's `Filled` type and works for every engine `resolve` can build,
// including the pre-m79 ones reached through the `SkipResult` adapter.
import 'package:squirrel_parser/squirrel_parser.dart';

import 'astdiff.dart' show corpora, skeleton;
import 'final_table.dart' show buildSetup;
import '_u10res.dart' show resolve;

const base = '{"a":1,"bc":[2,33,true],"d":{"e":null},"f":"gh"}';

const cx2Grammar = '''
S <- A 'x' 'a';
A <- [ab];
''';

/// Characters the recovery threw away. A zero-width `SyntaxError` marks a place
/// where something is missing and destroys nothing, so it does not count.
int _deleted(MatchResult m) {
  var n = 0;
  void walk(MatchResult x) {
    if (x is SyntaxError) n += x.len;
    x.subClauseMatches.forEach(walk);
  }

  walk(m);
  return n;
}

bool _sameShape(MatchResult? got, List<String> want, Set<String> named) {
  if (got == null) return false;
  final have = skeleton(got, named);
  if (have.length != want.length) return false;
  for (var i = 0; i < have.length; i++) {
    if (have[i] != want[i]) return false;
  }
  return true;
}

void main(List<String> argv) {
  if (argv.length != 1) {
    print('usage: dart run _accept.dart <engineName>');
    return;
  }
  final name = argv.single;
  final build = resolve(name);
  if (build == null) {
    print('$name unknown');
    return;
  }

  final fails = <String>[];

  // --- CX2 -----------------------------------------------------------------
  var cx2 = 0;
  try {
    final rules = MetaGrammar.parseGrammar(cx2Grammar);
    final t = build(rules, 'S')('xa');
    cx2 = (t != null && _deleted(t) == 0) ? 1 : 0;
  } catch (_) {
    cx2 = 0;
  }
  if (cx2 == 0) fails.add('cx2');

  // --- the brief's two acceptance cases ------------------------------------
  final jr = buildSetup().$1;
  final named = corpora.firstWhere((c) => c.name == 'json').named;

  List<String> shapeOf(String s) =>
      skeleton(Parser(rules: jr, topRuleName: 'JSON', input: s).parse().root,
          named);

  final run = build(jr, 'JSON');

  var b1 = 0;
  try {
    b1 = _sameShape(run(base.replaceFirst('[2,33,true]', '[2,3,3true]')),
            shapeOf(base.replaceFirst('[2,33,true]', '[2,3,3,true]')), named)
        ? 1
        : 0;
  } catch (_) {
    b1 = 0;
  }
  if (b1 == 0) fails.add('b1');

  var b2 = 0;
  try {
    b2 = _sameShape(run(base.replaceFirst('[2,33,true]', '[,2,33,true]')),
            shapeOf(base), named)
        ? 1
        : 0;
  } catch (_) {
    b2 = 0;
  }
  if (b2 == 0) fails.add('b2');

  print('$name ${fails.isEmpty ? "ok" : "x:${fails.join(",")}"} '
      'cx2=$cx2 b1=$b1 b2=$b2');
}
