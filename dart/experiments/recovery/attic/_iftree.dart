// Scratch: what r6 and r9 ACTUALLY read on the `if () {` case, so the claim in
// r9.dart's header can be checked against a tree rather than restated.
//
//   dart run _iftree.dart

import 'package:squirrel_parser/squirrel_parser.dart';
import 'astdiff.dart' show stmtGrammar;
import '_score1.dart' show resolve;

const inp = 'if (a) { if () { c=1; } }';

void show(MatchResult m, String src, [String ind = '  ']) {
  final lbl = m is SyntaxError
      ? 'ERR'
      : (m.clause == null
          ? 'ROOT'
          : (m.clause is Ref
              ? (m.clause as Ref).ruleName
              : m.clause.runtimeType.toString()));
  final txt = (m.pos >= 0 && m.len > 0 && m.pos + m.len <= src.length)
      ? ' ${src.substring(m.pos, m.pos + m.len).replaceAll('\n', r'\n')}'
      : '';
  print('$ind$lbl @${m.pos}+${m.len}$txt');
  for (final s in m.subClauseMatches) {
    show(s, src, '$ind  ');
  }
}

void main() {
  final rules = MetaGrammar.parseGrammar(stmtGrammar);
  for (var i = 0; i < inp.length; i++) {
    if (i >= 7 && i <= 14) print('  index $i = "${inp[i]}"');
  }
  for (final name in ['r6', 'r9']) {
    final run = resolve(name);
    if (run == null) {
      print('=== $name: not resolvable');
      continue;
    }
    print('=== $name on "$inp"');
    try {
      final t = run(rules, 'Program')(inp);
      if (t == null) {
        print('  <null>');
      } else {
        show(t, inp);
      }
    } catch (e) {
      print('  threw: $e');
    }
  }
}
