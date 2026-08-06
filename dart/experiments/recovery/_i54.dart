// _i54.dart -- settle the I54 fork on the three cases that actually constrain
// it, side by side, rather than on the battery aggregate alone.
//
// The battery cannot arbitrate this one by itself. `astdiff.dart:30-33` says so
// outright: "A `SyntaxError` span and a zero-width FILL both carry no rule
// label, so neither appears in the sequence." `skeleton` emits named-rule labels
// and parentheses and nothing else, so a reading that INVENTS a character and a
// reading that DELETES one are scored on the tree they end up claiming, not on
// whether an invention happened. The brief's no-invention rule is therefore
// close to invisible to the aggregate -- which is the I68 situation again, one
// level up. So the acceptance cases are the authority here and the aggregate is
// the tie-break, not the other way round.
//
// The three cases:
//
//   CX2      S <- A 'x' 'a';  A <- [ab];   on `xa`
//            cost 1 is reachable (undetermined A at 0, then the real x and a).
//            I54 suppresses it because `need == minSkip == 1` and the gate tests
//            `need < minSkip`. Engines that keep I54 answer 3.
//
//   BRIEF 1  `,3true` must repair as `,3,true`, not `,true`.
//   BRIEF 2  `[,2,` must repair as `[2,` -- delete the leading comma rather than
//            invent a Value, "since simply inventing a character to insert is a
//            bit ridiculous (it could be anything, so why pick 0)".
//
// BRIEF 2 is what I54 was standing in for, and the claim under test is that
// `blind` can hold that line on its own once it outranks `net` and `got` -- it
// counts fills whose clause does not determine its own text, which is precisely
// "invented a character of a class". Filling a Value is blind 1; deleting the
// comma is blind 0.
//
// THE 2x2, so a score change can be attributed to one change:
//
//              I54 on    I54 off
//     blind@4  m113      m114
//     blind@2  m118      m115
//
// m116 (blind ABOVE cost) is a recorded negative, not a candidate. The search is
// stratified by cost budget and returns on the first round that yields a
// whole-input way (m113.dart:559,582), so a key outranking cost cannot reach
// across rounds -- it only reorders inside one, and which ways share a round is
// a property of the doubling schedule. Schedule-dependent is the arbitrary
// heuristic D2 forbids, so m116 is disqualified whatever it scores.
//
// PREDICTION, recorded before running so this is a test and not a rationalisa-
// tion: m115 passes all three. `blind` at level 2 says "among equally cheap
// readings, prefer fewer inventions", which is the brief's overarching rule
// stated as a preference; m113 has it at level 4, below `net` and `got`, so it
// prefers explaining more input over avoiding an invention -- backwards. m114
// should FAIL brief 2 (nothing left to break the cost tie toward the skip).
// A hard ban on blind fills was considered and rejected by reasoning: truncated
// input often has no skip-only whole-input tree at all, so a ban would empty the
// truncate category, the heaviest-weighted one. Preference, not prohibition.
import 'package:squirrel_parser/squirrel_parser.dart';

import 'astdiff.dart' show corpora, skeleton;
import 'final_table.dart' show buildSetup;
import 'm113.dart' as e113;
import 'm114.dart' as e114;
import 'm115.dart' as e115;
import 'm116.dart' as e116;
import 'm117.dart' as e117;
import 'm118.dart' as e118;
import 'm119.dart' as e119;
import 'm121.dart' as e121;
import 'm122.dart' as e122;
import 'm123.dart' as e123;

const base = '{"a":1,"bc":[2,33,true],"d":{"e":null},"f":"gh"}';

const cx2 = '''
S <- A 'x' 'a';
A <- [ab];
''';

/// One engine, reduced to the two things this file compares: what it charges,
/// and which repairs it names.
typedef Probe = (String, int Function(String), String Function(String));

String _marks(MatchResult m, String input, String? Function(MatchResult) fill) {
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

List<Probe> probes(Map<String, Clause> rules, String top) {
  final a = e113.SuperDot3(rules: rules, topRuleName: top);
  final b = e114.SuperDot3(rules: rules, topRuleName: top);
  final c = e115.SuperDot3(rules: rules, topRuleName: top);
  final d = e116.SuperDot3(rules: rules, topRuleName: top);
  final f = e118.SuperDot3(rules: rules, topRuleName: top);
  final g = e117.SuperDot3(rules: rules, topRuleName: top);
  final h = e119.SuperDot3(rules: rules, topRuleName: top);
  final p121 = e121.SuperDot3(rules: rules, topRuleName: top);
  final p122 = e122.SuperDot3(rules: rules, topRuleName: top);
  final p123 = e123.SuperDot3(rules: rules, topRuleName: top);
  return [
    ('m113', a.recoverCost,
        (s) => _marks(a.recover(s), s, (n) => n is e113.Filled ? n.text : null)),
    ('m114', b.recoverCost,
        (s) => _marks(b.recover(s), s, (n) => n is e114.Filled ? n.text : null)),
    ('m115', c.recoverCost,
        (s) => _marks(c.recover(s), s, (n) => n is e115.Filled ? n.text : null)),
    ('m116', d.recoverCost,
        (s) => _marks(d.recover(s), s, (n) => n is e116.Filled ? n.text : null)),
    ('m118', f.recoverCost,
        (s) => _marks(f.recover(s), s, (n) => n is e118.Filled ? n.text : null)),
    ('m117', g.recoverCost,
        (s) => _marks(g.recover(s), s, (n) => n is e117.Filled ? n.text : null)),
    ('m119', h.recoverCost,
        (s) => _marks(h.recover(s), s, (n) => n is e119.Filled ? n.text : null)),
    ('m121', p121.recoverCost,
        (s) => _marks(p121.recover(s), s, (x) => x is e121.Filled ? x.text : null)),
    ('m122', p122.recoverCost,
        (s) => _marks(p122.recover(s), s, (x) => x is e122.Filled ? x.text : null)),
    ('m123', p123.recoverCost,
        (s) => _marks(p123.recover(s), s, (x) => x is e123.Filled ? x.text : null)),
  ];
}

void run(String title, String want, List<Probe> ps, String input) {
  print('$title\n  input  $input\n  want   $want');
  for (final (name, cost, marks) in ps) {
    var c = '?', m = '(threw)';
    try {
      c = '${cost(input)}';
      m = marks(input);
    } catch (e) {
      m = '(threw ${e.runtimeType})';
    }
    print('  ${name.padRight(5)} cost ${c.padLeft(2)}   $m');
  }
  print('');
}

void main() {
  print('=== CX2: I54 suppresses a globally cheaper reading ===\n');
  final cr = MetaGrammar.parseGrammar(cx2);
  run("S <- A 'x' 'a';  A <- [ab];", 'cost 1 (fill A at 0, then the real x, a)',
      probes(cr, 'S'), 'xa');

  print('=== the brief\'s two acceptance cases ===\n');
  final jr = buildSetup().$1;
  final jp = probes(jr, 'JSON');
  run('BRIEF 1: `,3true` -> `,3,true`', 'insert "," between 3 and true',
      jp, base.replaceFirst('[2,33,true]', '[2,3,3true]'));
  run('BRIEF 2: `[,2,` -> `[2,`', 'delete "," -- do NOT invent a Value',
      jp, base.replaceFirst('[2,33,true]', '[,2,33,true]'));

  // Does the battery SEE a blind fill, or is it invisible the way the repair
  // marks are? `missing@13` is a zero-width SyntaxError, which `skeleton` does
  // not emit -- but m11x wraps it in a node for the filled CLAUSE (m114.dart:
  // 1153-1157 passes `c: sub, pos: pos`), and `Value` is in the json named set
  // (astdiff.dart:261). So the label should appear. Measure it rather than read
  // it: this decides whether the aggregate is evidence here or noise.
  print('=== what the battery actually sees (skeleton diff on BRIEF 2) ===\n');
  final named = corpora.firstWhere((c) => c.name == 'json').named;
  final dirty = base.replaceFirst('[2,33,true]', '[,2,33,true]');
  final clean =
      Parser(rules: jr, topRuleName: 'JSON', input: base).parse().root;
  final want = skeleton(clean, named);
  print('  expected  ${_sk(want)}');
  for (final (name, t) in <(String, MatchResult Function(String))>[
    ('m113', e113.SuperDot3(rules: jr, topRuleName: 'JSON').recover),
    ('m114', e114.SuperDot3(rules: jr, topRuleName: 'JSON').recover),
    ('m115', e115.SuperDot3(rules: jr, topRuleName: 'JSON').recover),
    ('m118', e118.SuperDot3(rules: jr, topRuleName: 'JSON').recover),
    ('m117', e117.SuperDot3(rules: jr, topRuleName: 'JSON').recover),
    ('m119', e119.SuperDot3(rules: jr, topRuleName: 'JSON').recover),
    ('m121', e121.SuperDot3(rules: jr, topRuleName: 'JSON').recover),
    ('m122', e122.SuperDot3(rules: jr, topRuleName: 'JSON').recover),
    ('m123', e123.SuperDot3(rules: jr, topRuleName: 'JSON').recover),
  ]) {
    final got = skeleton(t(dirty), named);
    print('  ${name.padRight(5)} ${got.length == want.length &&
            got.join() == want.join() ? "EXACT " : "DIFFER"} '
        'len ${got.length} vs ${want.length}   ${_sk(got)}');
  }
  print('');

  print('VERDICT KEY');
  print('  CX2     cost 1 = I54 removed and the global comparison reached it.');
  print('  BRIEF 2 must show delete ","  -- a zero-width fill here claims a');
  print('          Value no character supports, which is the reading the brief');
  print('          rejects, so it disqualifies the variant whatever it scores.');
}

String _sk(List<String> s) {
  final j = s.join(' ').replaceAll(' ( ', '(').replaceAll(' )', ')');
  return j.length <= 150 ? j : '${j.substring(0, 147)}...';
}
